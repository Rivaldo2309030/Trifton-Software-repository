import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static final _databaseName = "embarques.db";
  static final _databaseVersion = 1;

  // Tabla de embarques
  static final tableEmbarque = 'embarque';
  static final columnId = 'idfolioembarque_local';
  static final columnIdAlmacen = 'idalmacen';
  static final columnIdUsuario = 'idusuario';
  static final columnIdAlmacenista = 'idalmacenista';
  static final columnIdCliente = 'idcliente';
  static final columnRegTimestamp = 'regtimestamp';
  static final columnSynced = 'synced'; // 0 = false, 1 = true

  // Tabla de detalle de embarques
  static final tableEmbarqueDetalle = 'embarque_detalle';
  static final columnIdDetalle = 'iddetalle_local';
  static final columnIdFolioEmbarque = 'idfolioembarque_local_fk';
  static final columnIdProducto = 'idproducto';
  static final columnIdUnidad = 'idunidad';
  static final columnCantidad = 'cantidad';
  static final columnPrecioUnitario = 'preciounitario';
  static final columnSubtotal = 'subtotal';

  // Hacemos de esta una clase singleton
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Solo tener una referencia a la base de datos
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Abre la base de datos y la crea si no existe
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(path,
        version: _databaseVersion,
        onCreate: _onCreate);
  }

  // SQL para crear la base de datos
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableEmbarque (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnIdAlmacen INTEGER NOT NULL,
        $columnIdUsuario INTEGER NOT NULL,
        $columnIdAlmacenista INTEGER NOT NULL,
        $columnIdCliente INTEGER NOT NULL,
        $columnRegTimestamp TEXT NOT NULL,
        $columnSynced INTEGER NOT NULL DEFAULT 0
      )
      ''');
    await db.execute('''
      CREATE TABLE $tableEmbarqueDetalle (
        $columnIdDetalle INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnIdFolioEmbarque INTEGER NOT NULL,
        $columnIdProducto INTEGER NOT NULL,
        $columnIdUnidad INTEGER NOT NULL,
        $columnCantidad REAL NOT NULL,
        $columnPrecioUnitario REAL NOT NULL,
        $columnSubtotal REAL NOT NULL,
        FOREIGN KEY ($columnIdFolioEmbarque) REFERENCES $tableEmbarque ($columnId) ON DELETE CASCADE
      )
      ''');
  }

  // Método para insertar un embarque completo (encabezado y detalles)
  Future<int> insertEmbarque(Map<String, dynamic> payload) async {
    Database db = await instance.database;
    int embarqueId = -1;

    await db.transaction((txn) async {
      // Insertar el encabezado del embarque
      Map<String, dynamic> embarqueRow = {
        columnIdAlmacen: payload['idalmacen'],
        columnIdUsuario: payload['idusuario'],
        columnIdAlmacenista: payload['idalmacenista'],
        columnIdCliente: payload['idcliente'],
        columnRegTimestamp: DateTime.now().toIso8601String(),
        columnSynced: 0
      };
      embarqueId = await txn.insert(tableEmbarque, embarqueRow);

      // Insertar los detalles
      List<Map<String, dynamic>> detalles = payload['detalles'];
      for (var detalle in detalles) {
        double cantidad = (detalle['cantidad'] as num).toDouble();
        double precio = (detalle['preciounitario'] as num).toDouble();
        Map<String, dynamic> detalleRow = {
          columnIdFolioEmbarque: embarqueId,
          columnIdProducto: detalle['idproducto'],
          columnIdUnidad: detalle['idunidad'],
          columnCantidad: cantidad,
          columnPrecioUnitario: precio,
          columnSubtotal: cantidad * precio
        };
        await txn.insert(tableEmbarqueDetalle, detalleRow);
      }
    });
    return embarqueId;
  }
}
