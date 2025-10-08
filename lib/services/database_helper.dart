import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static final _databaseName = "embarques.db";
  static final _databaseVersion = 2; // Versión incrementada

  // --- Singleton ---
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade); // Callback de actualización añadido
  }

  Future _onCreate(Database db, int version) async {
    // --- Embarque Tables ---
    await db.execute('''
      CREATE TABLE embarque_offline (
        idfolioembarque_local INTEGER PRIMARY KEY AUTOINCREMENT,
        idalmacen INTEGER NOT NULL,
        idusuario INTEGER NOT NULL,
        idalmacenista INTEGER NOT NULL,
        idcliente INTEGER NOT NULL,
        regtimestamp TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
      ''');
    await db.execute('''
      CREATE TABLE embarque_detalle_offline (
        iddetalle_local INTEGER PRIMARY KEY AUTOINCREMENT,
        idfolioembarque_local_fk INTEGER NOT NULL,
        idproducto INTEGER NOT NULL,
        idunidad INTEGER NOT NULL,
        cantidad REAL NOT NULL,
        preciounitario REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (idfolioembarque_local_fk) REFERENCES embarque_offline (idfolioembarque_local) ON DELETE CASCADE
      )
      ''');

    // --- Catalog Tables ---
    await db.execute('CREATE TABLE almacenes_cat (id INTEGER PRIMARY KEY, nombre TEXT NOT NULL)');
    await db.execute('CREATE TABLE clientes_cat (id INTEGER PRIMARY KEY, nombre TEXT NOT NULL)');
    await db.execute('CREATE TABLE productos_cat (id INTEGER PRIMARY KEY, nombre TEXT NOT NULL)');
    await db.execute('CREATE TABLE unidades_cat (id INTEGER PRIMARY KEY, nombre TEXT NOT NULL)');
    await db.execute('CREATE TABLE almacenistas_cat (id INTEGER PRIMARY KEY, nombre TEXT NOT NULL)');

    // --- Precios Table ---
    await db.execute('''
      CREATE TABLE precios_cat (
        idcliente INTEGER NOT NULL,
        idproducto INTEGER NOT NULL,
        idunidad INTEGER NOT NULL,
        preciounitario REAL NOT NULL,
        PRIMARY KEY (idcliente, idproducto, idunidad)
      )
    ''');
  }

  // Se llama si la base de datos ya existe con una versión anterior.
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Si actualizamos desde la v1, la tabla de precios no existe, así que la creamos.
      await db.execute('''
        CREATE TABLE precios_cat (
          idcliente INTEGER NOT NULL,
          idproducto INTEGER NOT NULL,
          idunidad INTEGER NOT NULL,
          preciounitario REAL NOT NULL,
          PRIMARY KEY (idcliente, idproducto, idunidad)
        )
      ''');
    }
  }

  // --- Embarque Methods ---
  Future<int> insertEmbarque(Map<String, dynamic> payload) async {
    Database db = await instance.database;
    int embarqueId = -1;
    await db.transaction((txn) async {
      Map<String, dynamic> embarqueRow = {
        'idalmacen': payload['idalmacen'],
        'idusuario': payload['idusuario'],
        'idalmacenista': payload['idalmacenista'],
        'idcliente': payload['idcliente'],
        'regtimestamp': DateTime.now().toIso8601String(),
        'synced': 0
      };
      embarqueId = await txn.insert('embarque_offline', embarqueRow);

      List<Map<String, dynamic>> detalles = payload['detalles'];
      for (var detalle in detalles) {
        double cantidad = (detalle['cantidad'] as num).toDouble();
        double precio = (detalle['preciounitario'] as num).toDouble();
        Map<String, dynamic> detalleRow = {
          'idfolioembarque_local_fk': embarqueId,
          'idproducto': detalle['idproducto'],
          'idunidad': detalle['idunidad'],
          'cantidad': cantidad,
          'preciounitario': precio,
          'subtotal': cantidad * precio
        };
        await txn.insert('embarque_detalle_offline', detalleRow);
      }
    });
    return embarqueId;
  }

  // --- Catalog Methods ---

  Future<void> batchUpdateCatalog(String tableName, List<Map<String, dynamic>> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableName); // Clear old data
      for (final item in items) {
        await txn.insert(tableName, item, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCatalog(String tableName) async {
    final db = await database;
    return await db.query(tableName);
  }

  // --- Precios Methods ---

  Future<void> insertOrUpdatePrecio(Map<String, dynamic> precioData) async {
    final db = await database;
    await db.insert(
      'precios_cat',
      precioData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<double?> getPrecio(int idCliente, int idProducto, int idUnidad) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'precios_cat',
      columns: ['preciounitario'],
      where: 'idcliente = ? AND idproducto = ? AND idunidad = ?',
      whereArgs: [idCliente, idProducto, idUnidad],
    );

    if (maps.isNotEmpty) {
      return maps.first['preciounitario'] as double?;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedEmbarques() async {
    final db = await database;
    // Usamos un rawQuery para poder hacer el JOIN fácilmente
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT
        eo.idfolioembarque_local,
        eo.regtimestamp,
        cc.nombre AS nombrecliente
      FROM embarque_offline AS eo
      LEFT JOIN clientes_cat AS cc ON eo.idcliente = cc.id
      WHERE eo.synced = 0
      ORDER BY eo.idfolioembarque_local DESC
    ''');
    return result;
  }

  // --- Métodos para Sincronización ---

  Future<Map<String, dynamic>> getFullEmbarque(int localId) async {
    final db = await database;
    // 1. Obtener la cabecera
    final List<Map<String, dynamic>> headers = await db.query(
      'embarque_offline',
      where: 'idfolioembarque_local = ?',
      whereArgs: [localId],
    );
    if (headers.isEmpty) {
      return {};
    }
    final header = headers.first;

    // 2. Obtener los detalles
    final List<Map<String, dynamic>> details = await db.query(
      'embarque_detalle_offline',
      where: 'idfolioembarque_local_fk = ?',
      whereArgs: [localId],
    );

    // 3. Construir el payload que la API espera
    final Map<String, dynamic> payload = {
      'idalmacen': header['idalmacen'],
      'idusuario': header['idusuario'],
      'idalmacenista': header['idalmacenista'],
      'idcliente': header['idcliente'],
      'detalles': details.map((d) => {
        'idproducto': d['idproducto'],
        'idunidad': d['idunidad'],
        'cantidad': d['cantidad'],
        'preciounitario': d['preciounitario'],
      }).toList(),
    };

    return payload;
  }

  Future<void> deleteLocalEmbarque(int localId) async {
    final db = await database;
    await db.delete(
      'embarque_offline',
      where: 'idfolioembarque_local = ?',
      whereArgs: [localId],
    );
  }
}
}
