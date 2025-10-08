import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static final _databaseName = "embarques.db";
  static final _databaseVersion = 1;

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
        version: _databaseVersion, onCreate: _onCreate);
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
}