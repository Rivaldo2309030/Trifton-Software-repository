import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert'; // For utf8
import 'package:crypto/crypto.dart'; // For sha256

class DatabaseHelper {
  static final _databaseName = "embarques.db";
  static final _databaseVersion = 11; // <<< VERSION INCREMENTADA

  // --- Singleton ---
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  Future<Database?> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database;
  }

  Future<Database?> _initDatabase() async {
    if (kIsWeb) {
      print("Plataforma web detectada, omitiendo inicialización de SQLite.");
      return null;
    }
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
    await db.execute(
      'CREATE TABLE almacenes_cat (id INTEGER PRIMARY KEY, nombre TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE clientes_cat (id INTEGER PRIMARY KEY, nombre TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE productos_cat (id INTEGER PRIMARY KEY, nombre TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE unidades_cat (id INTEGER PRIMARY KEY, nombre TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE almacenistas_cat (id INTEGER PRIMARY KEY, nombre TEXT NOT NULL)',
    );

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

    // --- User Credentials Table (for offline login) ---
    await db.execute('''
      CREATE TABLE user_credentials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        id_usuario INTEGER NOT NULL,
        nombre_usuario TEXT NOT NULL
      )
    ''');

    // --- Notas Offline Tables (Cache from server) ---
    await db.execute('''
      CREATE TABLE notas_offline (
        idnota INTEGER PRIMARY KEY,
        idcliente INTEGER NOT NULL,
        total REAL NOT NULL,
        saldo REAL NOT NULL,
        regtimestamp TEXT NOT NULL,
        nombre_cliente TEXT NOT NULL,
        idalmacen INTEGER NOT NULL,
        nombre_almacen_salida TEXT NOT NULL,
        nombre_almacen_origen TEXT,
        monto_pagado_acumulado REAL NOT NULL DEFAULT 0.0,
        nombre_vendedor TEXT
      )
    ''');

    // --- TABLA NOTA_DETALLE_OFFLINE ACTUALIZADA ---
    await db.execute('''
      CREATE TABLE nota_detalle_offline (
        iddetalle INTEGER PRIMARY KEY,
        idnota_fk INTEGER NOT NULL,
        idproducto INTEGER,
        idunidad INTEGER,
        cantidad REAL NOT NULL,
        precio REAL NOT NULL,
        total REAL NOT NULL,
        idestatus INTEGER,
        nombreproducto TEXT NOT NULL,
        nombreunidad TEXT NOT NULL,
        regtimestamp TEXT,
        estado INTEGER,
        FOREIGN KEY (idnota_fk) REFERENCES notas_offline (idnota) ON DELETE CASCADE
      )
    ''');

    await _createPagosOfflineTable(db);
    await _createEmpresaInfoTable(db);

    // --- Tables for data created offline to be synced ---
    await _createPagosPorSincronizarTable(db);
    await _createNotasPorSincronizarTable(db);

    // --- NUEVA TABLA PARA CACHE DE CONSULTA DE EMBARQUES ---
    await db.execute('''
      CREATE TABLE embarques_consulta (
        idfolioembarque INTEGER PRIMARY KEY,
        regtimestamp TEXT,
        nombre_cliente TEXT,
        nombreusuario TEXT,
        nombre_almacenista TEXT,
        estado_embarque INTEGER,
        fecha_filtro TEXT,
        idcliente INTEGER,
        idalmacen INTEGER,
        idusuario INTEGER,
        idalmacenista INTEGER
      )
    ''');
  }

  Future<void> _createPagosOfflineTable(Database db) async {
    await db.execute('''
      CREATE TABLE pagos_offline (
        idpago INTEGER PRIMARY KEY,
        idnota INTEGER NOT NULL,
        monto REAL NOT NULL,
        tipo_pago TEXT NOT NULL,
        regtimestamp TEXT NOT NULL,
        FOREIGN KEY (idnota) REFERENCES notas_offline (idnota) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createEmpresaInfoTable(Database db) async {
    await db.execute('''
      CREATE TABLE empresa_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        direccion TEXT NOT NULL,
        telefono TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createPagosPorSincronizarTable(Database db) async {
    await db.execute('''
      CREATE TABLE pagos_por_sincronizar (
        id_pago_local INTEGER PRIMARY KEY AUTOINCREMENT,
        idnota INTEGER NOT NULL,
        monto REAL NOT NULL,
        tipo_pago TEXT NOT NULL,
        regtimestamp TEXT NOT NULL,
        id_usuario INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createNotasPorSincronizarTable(Database db) async {
    await db.execute('''
      CREATE TABLE notas_por_sincronizar (
        id_nota_local INTEGER PRIMARY KEY AUTOINCREMENT,
        id_embarque INTEGER NOT NULL,
        regtimestamp TEXT NOT NULL,
        id_usuario INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
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
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE user_credentials (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          id_usuario INTEGER NOT NULL,
          nombre_usuario TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE notas_offline (
          idnota INTEGER PRIMARY KEY,
          total REAL NOT NULL,
          saldo REAL NOT NULL,
          regtimestamp TEXT NOT NULL,
          nombre_cliente TEXT NOT NULL,
          idalmacen INTEGER NOT NULL,
          nombre_almacen_salida TEXT NOT NULL,
          nombre_almacen_origen TEXT,
          monto_pagado_acumulado REAL NOT NULL DEFAULT 0.0
        )
      ''');
      await db.execute('''
        CREATE TABLE nota_detalle_offline (
          iddetalle INTEGER PRIMARY KEY AUTOINCREMENT,
          idnota_fk INTEGER NOT NULL,
          cantidad REAL NOT NULL,
          precio REAL NOT NULL,
          total REAL NOT NULL,
          idestatus INTEGER NOT NULL,
          nombreproducto TEXT NOT NULL,
          nombreunidad TEXT NOT NULL,
          FOREIGN KEY (idnota_fk) REFERENCES notas_offline (idnota) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 5) {
      await _createPagosOfflineTable(db);
    }
    if (oldVersion < 6) {
      await _createEmpresaInfoTable(db);
      await db.execute(
        'ALTER TABLE notas_offline ADD COLUMN nombre_vendedor TEXT',
      );
    }
    if (oldVersion < 7) {
      await db.execute('DROP TABLE IF EXISTS pagos_offline');
      await _createPagosOfflineTable(db);
    }
    if (oldVersion < 8) {
      await _createPagosPorSincronizarTable(db);
      await _createNotasPorSincronizarTable(db);
    }
    if (oldVersion < 9) {
      await db.execute(
        'ALTER TABLE notas_offline ADD COLUMN idcliente INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS embarques_consulta (
          idfolioembarque INTEGER PRIMARY KEY,
          regtimestamp TEXT,
          nombre_cliente TEXT,
          nombreusuario TEXT,
          nombre_almacenista TEXT,
          estado_embarque INTEGER,
          fecha_filtro TEXT,
          idcliente INTEGER,
          idalmacen INTEGER,
          idusuario INTEGER,
          idalmacenista INTEGER
        )
      ''');
    }
    // --- NUEVA MIGRACIÓN PARA v11 ---
    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE nota_detalle_offline ADD COLUMN idproducto INTEGER');
        await db.execute('ALTER TABLE nota_detalle_offline ADD COLUMN idunidad INTEGER');
        await db.execute('ALTER TABLE nota_detalle_offline ADD COLUMN regtimestamp TEXT');
        await db.execute('ALTER TABLE nota_detalle_offline ADD COLUMN estado INTEGER');
      } catch (e) {
        print('Error al migrar nota_detalle_offline a v11: $e. Recreando tabla.');
        await db.execute('DROP TABLE IF EXISTS nota_detalle_offline');
        await db.execute('''
          CREATE TABLE nota_detalle_offline (
            iddetalle INTEGER PRIMARY KEY,
            idnota_fk INTEGER NOT NULL,
            idproducto INTEGER,
            idunidad INTEGER,
            cantidad REAL NOT NULL,
            precio REAL NOT NULL,
            total REAL NOT NULL,
            idestatus INTEGER,
            nombreproducto TEXT NOT NULL,
            nombreunidad TEXT NOT NULL,
            regtimestamp TEXT,
            estado INTEGER,
            FOREIGN KEY (idnota_fk) REFERENCES notas_offline (idnota) ON DELETE CASCADE
          )
        ''');
      }
    }
  }

  // --- Empresa Info Methods ---
  Future<void> saveEmpresaInfo(Map<String, dynamic> empresaData) async {
    final db = await database;
    if (db == null) return;
    // La API devuelve un objeto, no una lista. Lo insertamos directamente.
    final Map<String, dynamic> cleanData = {
      'nombre': empresaData['nombre'] ?? 'N/A',
      'direccion': empresaData['direccion'] ?? 'N/A',
      'telefono': empresaData['telefono'] ?? 'N/A',
    };
    await db.transaction((txn) async {
      await txn.delete('empresa_info'); 
      await txn.insert('empresa_info', cleanData);
    });
  }

  Future<Map<String, dynamic>?> getEmpresaInfo() async {
    final db = await database;
    if (db == null) return null;
    final List<Map<String, dynamic>> maps = await db.query(
      'empresa_info',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // --- User Credential Methods for Offline Login ---

  Future<void> saveUserCredentials(
    int idUsuario,
    String username,
    String nombreUsuario,
    String password,
  ) async {
    final db = await database;
    if (db == null) return;

    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    String hashedPassword = digest.toString();

    await db.transaction((txn) async {
      await txn.delete('user_credentials');
      await txn.insert('user_credentials', {
        'id_usuario': idUsuario,
        'username': username.toLowerCase(),
        'nombre_usuario': nombreUsuario,
        'password_hash': hashedPassword,
      });
    });
  }

  Future<Map<String, dynamic>?> verifyOfflineLogin(
    String username,
    String password,
  ) async {
    final db = await database;
    if (db == null) return null;

    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    String hashedPassword = digest.toString();

    final List<Map<String, dynamic>> maps = await db.query(
      'user_credentials',
      where: 'username = ? AND password_hash = ?',
      whereArgs: [username.toLowerCase(), hashedPassword],
    );

    if (maps.isNotEmpty) {
      return {
        'idusuario': maps.first['id_usuario'],
        'username': maps.first['nombre_usuario'],
      };
    }
    return null;
  }

  // --- Embarque Methods ---
  Future<int> insertEmbarque(Map<String, dynamic> payload) async {
    Database? db = await instance.database;
    if (db == null) return -1;

    int embarqueId = -1;
    await db.transaction((txn) async {
      Map<String, dynamic> embarqueRow = {
        'idalmacen': payload['idalmacen'],
        'idusuario': payload['idusuario'],
        'idalmacenista': payload['idalmacenista'],
        'idcliente': payload['idcliente'],
        'regtimestamp': DateTime.now().toIso8601String(),
        'synced': 0,
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
          'subtotal': cantidad * precio,
        };
        await txn.insert('embarque_detalle_offline', detalleRow);
      }
    });
    return embarqueId;
  }

  // --- Catalog Methods ---

  Future<void> batchUpdateCatalog(
    String tableName,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await database;
    if (db == null) return;

    await db.transaction((txn) async {
      await txn.delete(tableName); // Clear old data
      for (final item in items) {
        await txn.insert(
          tableName,
          item,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> batchUpdatePrecios(List<Map<String, dynamic>> items) async {
    final db = await database;
    if (db == null) return;
    await db.transaction((txn) async {
      await txn.delete('precios_cat');
      for (final item in items) {
        await txn.insert('precios_cat', item, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> batchUpdateNotas(List<Map<String, dynamic>> items) async {
    final db = await database;
    if (db == null) return;
    await db.transaction((txn) async {
      await txn.delete('notas_offline');
      for (final item in items) {
        await txn.insert('notas_offline', item, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> batchUpdateNotaDetalles(List<Map<String, dynamic>> items) async {
    final db = await database;
    if (db == null) return;
    await db.transaction((txn) async {
      await txn.delete('nota_detalle_offline');
      for (final item in items) {
        await txn.insert('nota_detalle_offline', item, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> batchUpdatePagos(List<Map<String, dynamic>> items) async {
    final db = await database;
    if (db == null) return;
    await db.transaction((txn) async {
      await txn.delete('pagos_offline');
      for (final item in items) {
        await txn.insert('pagos_offline', item, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCatalog(String tableName) async {
    final db = await database;
    if (db == null) return [];
    return await db.query(tableName);
  }

  // --- Precios Methods ---

  Future<void> insertOrUpdatePrecio(Map<String, dynamic> precioData) async {
    final db = await database;
    if (db == null) return;

    await db.insert(
      'precios_cat',
      precioData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<double?> getPrecio(int idCliente, int idProducto, int idUnidad) async {
    final db = await database;
    if (db == null) return null;

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

  // --- Métodos para Sincronización de Subida ---

  Future<List<Map<String, dynamic>>> getUnsyncedEmbarques() async {
    final db = await database;
    if (db == null) return [];

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

  Future<Map<String, dynamic>> getFullEmbarque(int localId) async {
    final db = await database;
    if (db == null) return {};

    final List<Map<String, dynamic>> headers = await db.query(
      'embarque_offline',
      where: 'idfolioembarque_local = ?',
      whereArgs: [localId],
    );
    if (headers.isEmpty) {
      return {};
    }
    final header = headers.first;

    final List<Map<String, dynamic>> details = await db.query(
      'embarque_detalle_offline',
      where: 'idfolioembarque_local_fk = ?',
      whereArgs: [localId],
    );

    final Map<String, dynamic> payload = {
      'idalmacen': header['idalmacen'],
      'idusuario': header['idusuario'],
      'idalmacenista': header['idalmacenista'],
      'idcliente': header['idcliente'],
      'detalles': details
          .map(
            (d) => {
              'idproducto': d['idproducto'],
              'idunidad': d['idunidad'],
              'cantidad': d['cantidad'],
              'preciounitario': d['preciounitario'],
            },
          )
          .toList(),
    };

    return payload;
  }

  Future<void> deleteLocalEmbarque(int localId) async {
    final db = await database;
    if (db == null) return;

    await db.delete(
      'embarque_offline',
      where: 'idfolioembarque_local = ?',
      whereArgs: [localId],
    );
  }

  // --- Nuevos Métodos para Pagos y Notas por Sincronizar ---

  Future<int> insertPagoParaSincronizar(Map<String, dynamic> pagoData) async {
    final db = await database;
    if (db == null) return -1;
    return await db.insert('pagos_por_sincronizar', pagoData);
  }

  Future<List<Map<String, dynamic>>> getPagosParaSincronizar() async {
    final db = await database;
    if (db == null) return [];
    return await db.query('pagos_por_sincronizar', where: 'synced = 0');
  }

  Future<void> marcarPagoComoSincronizado(int idLocal) async {
    final db = await database;
    if (db == null) return;
    await db.update(
      'pagos_por_sincronizar',
      {'synced': 1},
      where: 'id_pago_local = ?',
      whereArgs: [idLocal],
    );
  }

  // --- Notas Offline Methods (Cache) ---

  Future<int> insertNotaOffline(Map<String, dynamic> notaMap) async {
    final db = await database;
    if (db == null) return -1;
    return await db.insert(
      'notas_offline',
      notaMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertNotaDetallesOffline(
    List<Map<String, dynamic>> detalles,
  ) async {
    final db = await database;
    if (db == null) return;
    await db.transaction((txn) async {
      for (var detalle in detalles) {
        await txn.insert(
          'nota_detalle_offline',
          detalle,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getNotasOffline() async {
    final db = await database;
    if (db == null) return [];
    return await db.query('notas_offline', orderBy: 'regtimestamp DESC');
  }

  Future<List<Map<String, dynamic>>> getClientesConSaldo() async {
    final db = await database;
    if (db == null) return [];
    return await db.rawQuery('''
      SELECT DISTINCT idcliente, nombre_cliente 
      FROM notas_offline 
      WHERE saldo > 0 
      ORDER BY nombre_cliente ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getNotasForCliente(int idCliente) async {
    final db = await database;
    if (db == null) return [];
    return await db.query(
      'notas_offline',
      where: 'idcliente = ?',
      whereArgs: [idCliente],
      orderBy: 'regtimestamp DESC',
    );
  }

  Future<void> updateNotaSaldo(
    int idnota,
    double nuevoSaldo,
    double nuevoMontoPagado,
  ) async {
    final db = await database;
    if (db == null) return;
    await db.update(
      'notas_offline',
      {'saldo': nuevoSaldo, 'monto_pagado_acumulado': nuevoMontoPagado},
      where: 'idnota = ?',
      whereArgs: [idnota],
    );
  }

  Future<List<Map<String, dynamic>>> getNotaDetallesOffline(int idnota) async {
    final db = await database;
    if (db == null) return [];
    return await db.query(
      'nota_detalle_offline',
      where: 'idnota_fk = ?',
      whereArgs: [idnota],
    );
  }

  Future<void> clearAllNotasData() async {
    final db = await database;
    if (db == null) return;
    await db.delete('notas_offline');
    await db.delete('nota_detalle_offline');
    await db.delete('pagos_offline');
  }

  // --- Pagos Offline Methods (Cache) ---

  Future<void> insertPagosOffline(List<Map<String, dynamic>> pagos) async {
    final db = await database;
    if (db == null || pagos.isEmpty) return;

    await db.transaction((txn) async {
      final idnota = pagos.first['idnota'];
      await txn.delete(
        'pagos_offline',
        where: 'idnota = ?',
        whereArgs: [idnota],
      );

      for (var pago in pagos) {
        await txn.insert(
          'pagos_offline',
          pago,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getPagosForNota(int idnota) async {
    final db = await database;
    if (db == null) return [];
    return await db.query(
      'pagos_offline',
      where: 'idnota = ?',
      whereArgs: [idnota],
      orderBy: 'regtimestamp DESC',
    );
  }

  Future<Map<String, dynamic>?> getLatestPagoForNota(int idnota) async {
    final db = await database;
    if (db == null) return null;

    final List<Map<String, dynamic>> maps = await db.query(
      'pagos_offline',
      where: 'idnota = ?',
      whereArgs: [idnota],
      orderBy: 'regtimestamp DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  /// Busca el pago más reciente para una nota, buscando tanto en los pagos
  /// ya sincronizados como en los que están pendientes por subir.
  Future<Map<String, dynamic>?> getLatestPagoForNotaIncludingPending(int idnota) async {
    final db = await database;
    if (db == null) return null;

    // 1. Obtener el último pago de la tabla de sincronizados
    final List<Map<String, dynamic>> syncedMaps = await db.query(
      'pagos_offline',
      where: 'idnota = ?',
      whereArgs: [idnota],
      orderBy: 'regtimestamp DESC',
      limit: 1,
    );
    Map<String, dynamic>? latestSynced = syncedMaps.isNotEmpty ? syncedMaps.first : null;

    // 2. Obtener el último pago de la tabla de pendientes
    final List<Map<String, dynamic>> pendingMaps = await db.query(
      'pagos_por_sincronizar',
      where: 'idnota = ?',
      whereArgs: [idnota],
      orderBy: 'regtimestamp DESC',
      limit: 1,
    );
    Map<String, dynamic>? latestPending = pendingMaps.isNotEmpty ? pendingMaps.first : null;

    // 3. Comparar y devolver el más reciente
    if (latestSynced == null && latestPending == null) {
      return null; // No hay pagos de ningún tipo
    }
    if (latestSynced != null && latestPending == null) {
      return latestSynced; // Solo hay sincronizados
    }
    if (latestSynced == null && latestPending != null) {
      // Solo hay pendientes, normalizar el mapa antes de devolver
      return {
        'idpago': latestPending['id_pago_local'], // Usar id local como referencia
        'idnota': latestPending['idnota'],
        'monto': latestPending['monto'],
        'tipo_pago': latestPending['tipo_pago'],
        'regtimestamp': latestPending['regtimestamp'],
      };
    }

    // Si hay ambos, comparar por fecha
    final syncedDate = DateTime.parse(latestSynced!['regtimestamp'] as String);
    final pendingDate = DateTime.parse(latestPending!['regtimestamp'] as String);

    if (pendingDate.isAfter(syncedDate)) {
      // El pendiente es más nuevo, normalizar y devolver
       return {
        'idpago': latestPending['id_pago_local'],
        'idnota': latestPending['idnota'],
        'monto': latestPending['monto'],
        'tipo_pago': latestPending['tipo_pago'],
        'regtimestamp': latestPending['regtimestamp'],
      };
    } else {
      // El sincronizado es más nuevo o igual
      return latestSynced;
    }
  }

  Future<void> clearAllPagosOffline() async {
    final db = await database;
    if (db == null) return;
    await db.delete('pagos_offline');
  }

  // =========================================================
  //  EMBARQUES CONSULTA (caché de lo que vino del servidor)
  // =========================================================

  /// Guarda en SQLite los embarques que te trajo el servidor
  /// para una fecha dada. Primero borra los de esa fecha
  /// y luego inserta los nuevos.
  Future<void> cacheEmbarquesConsulta(
    List<dynamic> embarques, {
    required String fecha,
  }) async {
    final db = await database;
    if (db == null) return;

    await db.transaction((txn) async {
      // limpiar lo de esa fecha
      await txn.delete(
        'embarques_consulta',
        where: 'fecha_filtro = ?',
        whereArgs: [fecha],
      );

      for (final e in embarques) {
        int idfolioembarque;
        String regtimestamp;
        String nombreCliente;
        String nombreUsuario;
        String nombreAlmacenista;
        int estadoEmbarque;
        int idcliente;
        int idalmacen;
        int idusuario;
        int idalmacenista;

        if (e is Map<String, dynamic>) {
          idfolioembarque = e['idfolioembarque'] as int;
          regtimestamp = e['regtimestamp'] as String;
          nombreCliente = e['nombre_cliente'] as String;
          nombreUsuario = e['nombreusuario'] as String;
          nombreAlmacenista = e['nombre_almacenista'] as String;
          estadoEmbarque = (e['esActivo'] == true || e['estado_embarque'] == 1)
              ? 1
              : 0;
          idcliente = e['idcliente'] as int;
          idalmacen = e['idalmacen'] as int;
          idusuario = e['idusuario'] as int;
          idalmacenista = e['idalmacenista'] as int;
        } else {
          // asumimos modelo EmbarqueConsulta
          idfolioembarque = e.idfolioembarque as int;
          regtimestamp = e.regtimestamp as String;
          nombreCliente = e.nombre_cliente as String;
          nombreUsuario = e.nombreusuario as String;
          nombreAlmacenista = e.nombre_almacenista as String;
          estadoEmbarque = e.esActivo == true ? 1 : 0;
          idcliente = e.idcliente as int;
          idalmacen = e.idalmacen as int;
          idusuario = e.idusuario as int;
          idalmacenista = e.idalmacenista as int;
        }

        await txn.insert('embarques_consulta', {
          'idfolioembarque': idfolioembarque,
          'regtimestamp': regtimestamp,
          'nombre_cliente': nombreCliente,
          'nombreusuario': nombreUsuario,
          'nombre_almacenista': nombreAlmacenista,
          'estado_embarque': estadoEmbarque,
          'fecha_filtro': fecha,
          'idcliente': idcliente,
          'idalmacen': idalmacen,
          'idusuario': idusuario,
          'idalmacenista': idalmacenista,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Lee de SQLite los embarques que ya estaban sincronizados
  /// para esa fecha (y opcionalmente por almacén)
  Future<List<Map<String, dynamic>>> getEmbarquesConsulta({
    required String fecha,
    int? idAlmacen,
  }) async {
    final db = await database;
    if (db == null) return [];

    if (idAlmacen != null) {
      return await db.query(
        'embarques_consulta',
        where: 'fecha_filtro = ? AND idalmacen = ?',
        whereArgs: [fecha, idAlmacen],
        orderBy: 'regtimestamp DESC',
      );
    } else {
      return await db.query(
        'embarques_consulta',
        where: 'fecha_filtro = ?',
        whereArgs: [fecha],
        orderBy: 'regtimestamp DESC',
      );
    }
  }

  // ---------------------------------------------------------
  // Cuando un embarque OFFLINE se sincroniza al servidor,
  // lo pasamos a la tabla embarques_consulta para que aparezca
  // de inmediato en la pestaña de CONSULTAR (online u offline)
  // ---------------------------------------------------------
  Future<void> insertEmbarqueConsultaFromOffline({
    required int localId, // id en embarque_offline
    required int serverId, // id que te regresó el servidor
  }) async {
    final db = await database;
    if (db == null) return;

    // 1. leer encabezado offline
    final List<Map<String, dynamic>> headers = await db.query(
      'embarque_offline',
      where: 'idfolioembarque_local = ?',
      whereArgs: [localId],
      limit: 1,
    );

    if (headers.isEmpty) return;

    final header = headers.first;

    final int idcliente = header['idcliente'] as int;
    final int idalmacen = header['idalmacen'] as int;
    final int idusuario = header['idusuario'] as int;
    final int idalmacenista = header['idalmacenista'] as int;
    final String regtimestamp = header['regtimestamp'] as String;

    // fecha_filtro = solo la fecha (igual que haces en la pantalla)
    final String fechaFiltro = regtimestamp.split('T').first;

    // 2. sacar nombres desde los catálogos
    String nombreCliente = 'N/A';
    final cli = await db.query(
      'clientes_cat',
      where: 'id = ?',
      whereArgs: [idcliente],
      limit: 1,
    );
    if (cli.isNotEmpty) {
      nombreCliente = cli.first['nombre'] as String;
    }

    String nombreAlmacenista = 'N/A';
    final alm = await db.query(
      'almacenistas_cat',
      where: 'id = ?',
      whereArgs: [idalmacenista],
      limit: 1,
    );
    if (alm.isNotEmpty) {
      nombreAlmacenista = alm.first['nombre'] as String;
    }

    // como solo guardas un usuario offline, tomamos el primero
    String nombreUsuario = 'Usuario';
    final user = await db.query('user_credentials', limit: 1);
    if (user.isNotEmpty) {
      nombreUsuario = user.first['nombre_usuario'] as String;
    }

    // 3. insertar/actualizar en embarques_consulta
    await db.insert('embarques_consulta', {
      'idfolioembarque': serverId, // el id real del servidor
      'regtimestamp': regtimestamp,
      'nombre_cliente': nombreCliente,
      'nombreusuario': nombreUsuario,
      'nombre_almacenista': nombreAlmacenista,
      'estado_embarque': 1,
      'fecha_filtro': fechaFiltro,
      'idcliente': idcliente,
      'idalmacen': idalmacen,
      'idusuario': idusuario,
      'idalmacenista': idalmacenista,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // 4. marcar como sincronizado (o lo borras si quieres)
    await db.update(
      'embarque_offline',
      {'synced': 1},
      where: 'idfolioembarque_local = ?',
      whereArgs: [localId],
    );
  }
}
