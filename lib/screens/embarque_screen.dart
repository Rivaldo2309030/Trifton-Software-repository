import 'package:distribuidora/screens/auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:distribuidora/services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:distribuidora/services/api_config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// --- Modelos de Datos Refactorizados ---

class Estatus {
  final int id;
  final String clave;
  Estatus({required this.id, required this.clave});

  factory Estatus.fromJson(Map<String, dynamic> json) {
    return Estatus(
      id: int.tryParse(json['idestatus'].toString()) ?? 0,
      clave: json['clave'] ?? 'N/A',
    );
  }
}

class EmbarqueDetalleProducto {
  final int iddetalle;
  final String nombreproducto;
  final double cantidad;
  int idestatus; // Mutable
  final int idproducto;
  final int idunidad;

  EmbarqueDetalleProducto({
    required this.iddetalle,
    required this.nombreproducto,
    required this.cantidad,
    required this.idestatus,
    required this.idproducto,
    required this.idunidad,
  });

  factory EmbarqueDetalleProducto.fromJson(Map<String, dynamic> json) {
    return EmbarqueDetalleProducto(
      iddetalle: int.tryParse(json['iddetalle'].toString()) ?? 0,
      nombreproducto: json['nombreproducto'] ?? 'N/A',
      cantidad: (json['cantidad'] as num).toDouble(),
      idestatus: int.tryParse(json['idestatus'].toString()) ?? 0,
      idproducto: int.tryParse(json['idproducto'].toString()) ?? 0,
      idunidad: int.tryParse(json['idunidad'].toString()) ?? 0,
    );
  }
}

class Almacen {
  final int id;
  final String nombre;
  Almacen({required this.id, required this.nombre});

  factory Almacen.fromJson(Map<String, dynamic> json) {
    return Almacen(
      id: int.tryParse(json['idalmacen'].toString()) ?? 0,
      nombre: json['nombrealmacen'],
    );
  }

  factory Almacen.fromDbMap(Map<String, dynamic> map) {
    return Almacen(id: map['id'], nombre: map['nombre']);
  }

  Map<String, dynamic> toDbMap() {
    return {'id': id, 'nombre': nombre};
  }
}

class Unidad {
  final int id;
  final String nombre;
  Unidad({required this.id, required this.nombre});

  factory Unidad.fromJson(Map<String, dynamic> json) {
    return Unidad(
      id: int.tryParse(json['idunidad'].toString()) ?? 0,
      nombre: json['nombreunidad'],
    );
  }

  factory Unidad.fromDbMap(Map<String, dynamic> map) {
    return Unidad(id: map['id'], nombre: map['nombre']);
  }

  Map<String, dynamic> toDbMap() {
    return {'id': id, 'nombre': nombre};
  }
}

class Cliente {
  final int id;
  final String nombre;

  Cliente({required this.id, required this.nombre});

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: int.tryParse(json['idcliente'].toString()) ?? 0,
      nombre: json['nombrecliente'] ?? 'N/A',
    );
  }

  factory Cliente.fromDbMap(Map<String, dynamic> map) {
    return Cliente(id: map['id'], nombre: map['nombre']);
  }

  Map<String, dynamic> toDbMap() {
    return {'id': id, 'nombre': nombre};
  }
}

class Almacenista {
  final int id;
  final String nombre;
  Almacenista({required this.id, required this.nombre});

  factory Almacenista.fromJson(Map<String, dynamic> json) {
    return Almacenista(
      id: int.tryParse(json['idalmacenista'].toString()) ?? 0,
      nombre: json['nombre'],
    );
  }

  factory Almacenista.fromDbMap(Map<String, dynamic> map) {
    return Almacenista(id: map['id'], nombre: map['nombre']);
  }

  Map<String, dynamic> toDbMap() {
    return {'id': id, 'nombre': nombre};
  }
}

class Producto {
  final int id;
  final String nombre;

  Producto({required this.id, required this.nombre});

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: int.tryParse(json['idproducto'].toString()) ?? 0,
      nombre: json['nombreproducto'],
    );
  }

  factory Producto.fromDbMap(Map<String, dynamic> map) {
    return Producto(id: map['id'], nombre: map['nombre']);
  }

  Map<String, dynamic> toDbMap() {
    return {'id': id, 'nombre': nombre};
  }
}

final Set<int> _selectedEmbarques = {};

// --- Modelo para la pestaña de Consulta (Actualizado) ---
class EmbarqueConsulta {
  final int idfolioembarque;
  final String regtimestamp;
  final String nombre_cliente;
  final String nombreusuario;
  final String nombre_almacenista;
  final bool esActivo;
  bool _selectAll = false;
  // IDs añadidos
  final int idcliente;
  final int idalmacen;
  final int idusuario;
  final int idalmacenista; // Nuevo: ID del almacenista

  EmbarqueConsulta({
    required this.idfolioembarque,
    required this.regtimestamp,
    required this.nombre_cliente,
    required this.nombreusuario,
    required this.nombre_almacenista,
    required this.esActivo,
    required this.idcliente,
    required this.idalmacen,
    required this.idusuario,
    required this.idalmacenista, // Nuevo
  });

  factory EmbarqueConsulta.fromJson(Map<String, dynamic> json) {
    return EmbarqueConsulta(
      idfolioembarque: int.tryParse(json['idfolioembarque'].toString()) ?? 0,
      regtimestamp: json['regtimestamp'] ?? '',
      nombre_cliente: json['nombre_cliente'] ?? 'N/A',
      nombreusuario: json['nombreusuario'] ?? 'N/A',
      nombre_almacenista: json['nombre_almacenista'] ?? 'N/A',
      esActivo: (int.tryParse(json['estado_embarque'].toString()) ?? 0) == 1,
      // Parsear los nuevos IDs
      idcliente: int.tryParse(json['idcliente'].toString()) ?? 0,
      idalmacen: int.tryParse(json['idalmacen'].toString()) ?? 0,
      idusuario: int.tryParse(json['idusuario'].toString()) ?? 0,
      idalmacenista:
          int.tryParse(json['idalmacenista'].toString()) ?? 0, // Nuevo
    );
  }
}

class EmbarqueScreen extends StatefulWidget {
  const EmbarqueScreen({super.key});

  @override
  State<EmbarqueScreen> createState() => _EmbarqueScreenState();
}

class _EmbarqueScreenState extends State<EmbarqueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Info de Usuario ---
  String _username = 'Usuario';
  Key _autocompleteKey = UniqueKey();

  // --- Estado para la pestaña de Consulta ---
  List<EmbarqueConsulta> _embarquesConsultados = [];
  bool _isConsultando = true;
  DateTime _fechaFiltro = DateTime.now();
  int? _editingEmbarqueId; // ID del embarque que se está editando
  int? _selectedAlmacenFiltroId; // <<< NUEVO ESTADO PARA FILTRO DE ALMACÉN

  // --- Catalogos (dinamicos) ---
  List<Almacen> _almacenes = [];
  List<Unidad> _unidades = [];
  List<Producto> _productos = [];
  List<Cliente> _clientes = [];
  List<Almacenista> _almacenistas = [];
  List<Estatus> _estatusList = [];
  bool _isLoading = true;

  // --- Estado de filtros/encabezado ---
  int? _selectedAlmacenId;
  int? _selectedAlmacenistaId;
  int? _selectedUnidadId;
  int? _selectedClienteId;
  int _rowsPerPage = 10;
  int _currentPage = 0;
  bool _selectAll = false; // para saber si el header está marcado
  final Set<int> _selectedEmbarques =
      {}; // aquí guardamos los folios seleccionados

  String? _nombreAlmacenFiltro() {
    if (_selectedAlmacenFiltroId == null) return null;
    final alm = _almacenes.firstWhere(
      (a) => a.id == _selectedAlmacenFiltroId,
      orElse: () => Almacen(id: 0, nombre: ''),
    );
    return alm.nombre.isEmpty ? null : alm.nombre;
  }

  final TextEditingController _productoAutocompleteCtrl =
      TextEditingController();

  // --- ESTADO PARA NUEVA SELECCION DE PRODUCTOS ---
  Producto? _selectedProducto;
  double? _precioUnitarioDinamico; // Para guardar el precio obtenido de la API

  // --- Controles para agregar producto ---
  final TextEditingController cantidadCtrl = TextEditingController(text: '1');

  // --- Lista de renglones en la tabla ---
  final List<Map<String, dynamic>> filas = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
    _fetchCatalogos();
    _fetchEstatusList();
    _consultarEmbarques(); // Carga inicial para la pestaña de consulta

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 1) {
          _refreshConsultaAuto(); // decide si va online u offline
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _productoAutocompleteCtrl.dispose();
    cantidadCtrl.dispose();
    for (var fila in filas) {
      (fila['precio_controller'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'Usuario';
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('idusuario');
    await prefs.remove('username');

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _refreshConsultaAuto() async {
    final hayNet = await _tieneInternet();
    if (hayNet) {
      _consultarEmbarques(); // como siempre
    } else {
      _consultarEmbarques(forceOffline: true); // directo sqlite
    }
  }

  Future<void> _fetchEstatusList() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}api_estatus_movimiento.php'),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final List<dynamic> data = decoded['data'];
          if (mounted) {
            setState(() {
              _estatusList = data
                  .map((json) => Estatus.fromJson(json))
                  .toList();
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching estatus list: $e');
    }
  }

  Future<void> _fetchCatalogos() async {
    setState(() {
      _isLoading = true;
    });
    await _loadCatalogsFromDb();
    setState(() {
      _isLoading = false;
    });
    await _syncCatalogsFromServer();
  }

  Future<void> _loadCatalogsFromDb() async {
    try {
      final db = DatabaseHelper.instance;
      final almacenesData = await db.getCatalog('almacenes_cat');
      final clientesData = await db.getCatalog('clientes_cat');
      final productosData = await db.getCatalog('productos_cat');
      final unidadesData = await db.getCatalog('unidades_cat');
      final almacenistasData = await db.getCatalog('almacenistas_cat');

      if (mounted) {
        setState(() {
          _almacenes = almacenesData
              .map((map) => Almacen.fromDbMap(map))
              .toList();
          _clientes = clientesData
              .map((map) => Cliente.fromDbMap(map))
              .toList();
          _productos = productosData
              .map((map) => Producto.fromDbMap(map))
              .toList();
          _unidades = unidadesData.map((map) => Unidad.fromDbMap(map)).toList();
          _almacenistas = almacenistasData
              .map((map) => Almacenista.fromDbMap(map))
              .toList();
        });
      }
    } catch (e) {
      _snack('Error al cargar catálogos locales: $e', color: Colors.red);
    }
  }

  Future<void> _syncCatalogsFromServer() async {
    final db = DatabaseHelper.instance;

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('${ApiConfig.baseUrl}api_almacenes.php')),
        http.get(Uri.parse('${ApiConfig.baseUrl}api_unidades.php')),
        http.get(Uri.parse('${ApiConfig.baseUrl}api_productos.php')),
        http.get(Uri.parse('${ApiConfig.baseUrl}api_clientes.php')),
        http.get(Uri.parse('${ApiConfig.baseUrl}api_almacenistas.php')),
      ]);

      if (!mounted) return;

      // Almacenes
      if (responses[0].statusCode == 200) {
        final List<dynamic> data = json.decode(responses[0].body);
        final List<Almacen> almacenes = data
            .map((item) => Almacen.fromJson(item))
            .toList();
        await db.batchUpdateCatalog(
          'almacenes_cat',
          almacenes.map((e) => e.toDbMap()).toList(),
        );
        if (mounted) setState(() => _almacenes = almacenes);
      }

      // Unidades
      if (responses[1].statusCode == 200) {
        final List<dynamic> data = json.decode(responses[1].body);
        final List<Unidad> unidades = data
            .map((item) => Unidad.fromJson(item))
            .toList();
        await db.batchUpdateCatalog(
          'unidades_cat',
          unidades.map((e) => e.toDbMap()).toList(),
        );
        if (mounted) setState(() => _unidades = unidades);
      }

      // Productos
      if (responses[2].statusCode == 200) {
        final List<dynamic> data = json.decode(responses[2].body);
        final List<Producto> productos = data
            .map((item) => Producto.fromJson(item))
            .toList();
        await db.batchUpdateCatalog(
          'productos_cat',
          productos.map((e) => e.toDbMap()).toList(),
        );
        if (mounted) setState(() => _productos = productos);
      }

      // Clientes
      if (responses[3].statusCode == 200) {
        final List<dynamic> data = json.decode(responses[3].body);
        final List<Cliente> clientes = data
            .map((item) => Cliente.fromJson(item))
            .toList();
        await db.batchUpdateCatalog(
          'clientes_cat',
          clientes.map((e) => e.toDbMap()).toList(),
        );
        if (mounted) setState(() => _clientes = clientes);
      }

      // Almacenistas
      if (responses[4].statusCode == 200) {
        final List<dynamic> data = json.decode(responses[4].body);
        final List<Almacenista> almacenistas = data
            .map((item) => Almacenista.fromJson(item))
            .toList();
        await db.batchUpdateCatalog(
          'almacenistas_cat',
          almacenistas.map((e) => e.toDbMap()).toList(),
        );
        if (mounted) setState(() => _almacenistas = almacenistas);
      }
    } on SocketException {
      print("Sin conexión para sincronizar catálogos. Usando datos locales.");
      // Falla silenciosamente, los datos locales ya fueron cargados.
    } catch (e) {
      print('Error en _syncCatalogsFromServer: $e');
      // Opcional: mostrar un snackbar no intrusivo
      // _snack('No se pudieron sincronizar los catálogos.', color: Colors.orange);
    }
  }

  Future<void> _fetchPrecio() async {
    if (_selectedProducto == null ||
        _selectedClienteId == null ||
        _selectedUnidadId == null) {
      setState(() => _precioUnitarioDinamico = null);
      return;
    }

    final db = DatabaseHelper.instance;
    final idCliente = _selectedClienteId!;
    final idProducto = _selectedProducto!.id;
    final idUnidad = _selectedUnidadId!;

    // 1. Carga optimista desde la caché local para una UI instantánea
    final localPrice = await db.getPrecio(idCliente, idProducto, idUnidad);
    if (localPrice != null) {
      setState(() {
        _precioUnitarioDinamico = localPrice;
      });
    }

    // 2. Validar con el servidor si hay conexión
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}api_precios.php?idcliente=$idCliente&idproducto=$idProducto&idunidad=$idUnidad',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['preciounitario'] != null) {
          final serverPrice =
              double.tryParse(data['preciounitario'].toString()) ?? 0.0;

          // 3. Actualizar UI y caché si el precio del servidor es diferente
          if (_precioUnitarioDinamico != serverPrice) {
            setState(() {
              _precioUnitarioDinamico = serverPrice;
            });
            await db.insertOrUpdatePrecio({
              'idcliente': idCliente,
              'idproducto': idProducto,
              'idunidad': idUnidad,
              'preciounitario': serverPrice,
            });
          }
        } else {
          if (localPrice == null) {
            // Si no teníamos precio local y el servidor tampoco tiene
            _snack(
              'No se encontró un precio para esta combinación. Se usará 0.0.',
              color: Colors.orange,
            );
            setState(() => _precioUnitarioDinamico = 0.0);
          }
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } on SocketException {
      if (localPrice == null) {
        // Si no hay conexión y tampoco teníamos precio local
        _snack(
          'Sin conexión. Ingresa el precio manualmente.',
          color: Colors.orange,
        );
        setState(() => _precioUnitarioDinamico = 0.0);
      }
      // Si hay un precio local, simplemente se usa y no se muestra error.
    } catch (e) {
      if (localPrice == null) {
        // Si falla por otra razón y no hay precio local
        _snack('Error al obtener precio: $e. Se usará 0.0.', color: Colors.red);
        setState(() => _precioUnitarioDinamico = 0.0);
      }
    }
  }

  void _snack(String msg, {Color color = Colors.black87}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  String _nextCodigo() {
    final next = filas.length + 1;
    return next.toString().padLeft(3, '0');
  }

  void _agregarFila() {
    // Validaciones de encabezado actualizadas
    if (_selectedAlmacenId == null ||
        _selectedAlmacenistaId == null ||
        _selectedClienteId == null) {
      _snack('Completa todos los campos del encabezado.', color: Colors.red);
      return;
    }

    if (_selectedUnidadId == null) {
      _snack('Selecciona una unidad para el producto.', color: Colors.red);
      return;
    }

    if (_selectedProducto == null) {
      _snack('Selecciona un producto de la lista.', color: Colors.red);
      return;
    }

    if (_precioUnitarioDinamico == null) {
      _snack(
        'No se pudo obtener un precio para este producto. Verifica la configuración.',
        color: Colors.red,
      );
      return;
    }

    int cantidad = int.tryParse(cantidadCtrl.text) ?? 1;
    if (cantidad < 1) cantidad = 1;

    setState(() {
      filas.add({
        'cod': _nextCodigo(),
        'cantidad': cantidad,
        'unidad': _unidades
            .firstWhere(
              (u) => u.id == _selectedUnidadId,
              orElse: () => Unidad(id: 0, nombre: 'N/A'),
            )
            .nombre,
        'producto': _selectedProducto!.nombre,
        'precio_controller': TextEditingController(
          text: _precioUnitarioDinamico!.toStringAsFixed(2),
        ),
        'idproducto': _selectedProducto!.id,
        'idunidad': _selectedUnidadId,
        'idestatus': 1, // ID de estatus por defecto 'EE'
      });

      // Limpiar controles (parcialmente, según nuevo requerimiento)
      cantidadCtrl.text = '1';
      _precioUnitarioDinamico = null;
    });
  }

  void _cambiarCantidad(int index, int delta) {
    setState(() {
      final nueva = (filas[index]['cantidad'] as int) + delta;
      filas[index]['cantidad'] = nueva < 1 ? 1 : nueva;
    });
  }

  void _eliminar(int index) {
    setState(() {
      filas.removeAt(index);
      for (int i = 0; i < filas.length; i++) {
        filas[i]['cod'] = (i + 1).toString().padLeft(3, '0');
      }
    });
  }

  double get total => filas.fold<double>(0.0, (sum, f) {
    final precio =
        double.tryParse(
          (f['precio_controller'] as TextEditingController).text,
        ) ??
        0.0;
    return sum + (f['cantidad'] as int) * precio;
  });

  // --- Lógica de Guardado (Online/Offline) ---

  void _limpiarFormulario() {
    setState(() {
      filas.clear();
      _selectedAlmacenId = null;
      _selectedAlmacenistaId = null;
      _selectedUnidadId = null;
      _selectedClienteId = null;
      _selectedProducto = null;
      _productoAutocompleteCtrl.clear();
      cantidadCtrl.text = '1';
      _precioUnitarioDinamico = null;
      _editingEmbarqueId = null; // Reiniciar modo edición
      _autocompleteKey =
          UniqueKey(); // Forzar la reconstrucción del Autocomplete
    });
  }

  Future<bool> _tieneInternet() async {
    // primero revisa si hay algún tipo de red
    final con = await Connectivity().checkConnectivity();
    if (con == ConnectivityResult.none) return false;

    // luego prueba que sí salga a internet
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 2));
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncEmbarquesPendientes() async {
    final db = DatabaseHelper.instance;
    final pendientes = await db.getUnsyncedEmbarques();

    for (final p in pendientes) {
      final int localId = p['idfolioembarque_local'] as int;

      // armo el payload completo (encabezado + detalle)
      final payload = await db.getFullEmbarque(localId);

      // lo mando al servidor
      final resp = await http.post(
        Uri.parse('${ApiConfig.baseUrl}api_embarques.php'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(payload),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final decoded = jsonDecode(resp.body);

        // aquí SUPONGO que el server te regresa el id real:
        final int serverId = decoded['idfolioembarque'] as int;

        // 🔥 aquí está la magia: lo paso a embarques_consulta
        await db.insertEmbarqueConsultaFromOffline(
          localId: localId,
          serverId: serverId,
        );

        // si ya no quieres guardar el offline, lo borras:
        await db.deleteLocalEmbarque(localId);
      }
    }
  }

  Future<Map<String, dynamic>> _buildPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final idUsuario = prefs.getInt('idusuario');

    if (idUsuario == null) {
      _snack(
        'Error crítico: No se pudo identificar al usuario. Vuelve a iniciar sesión.',
        color: Colors.red,
      );
      return {};
    }

    if (_selectedAlmacenId == null ||
        _selectedAlmacenistaId == null ||
        _selectedClienteId == null) {
      _snack('Faltan datos del encabezado.', color: Colors.red);
      return {};
    }

    if (filas.isEmpty) {
      _snack('No hay productos en el detalle del embarque.', color: Colors.red);
      return {};
    }

    final List<Map<String, dynamic>> detallesPayload = filas.map((fila) {
      return {
        'idproducto': fila['idproducto'],
        'idunidad': fila['idunidad'],
        'cantidad': fila['cantidad'],
        'preciounitario':
            double.tryParse(
              (fila['precio_controller'] as TextEditingController).text,
            ) ??
            0.0,
        'idestatus': fila['idestatus'], // Añadido para el guardado
      };
    }).toList();

    return {
      'idalmacen': _selectedAlmacenId,
      'idusuario': idUsuario, // ID de usuario obtenido de SharedPreferences
      'idalmacenista': _selectedAlmacenistaId,
      'idcliente': _selectedClienteId,
      'detalles': detallesPayload,
    };
  }

  Future<void> _guardarEmbarqueLocalmente({
    Map<String, dynamic>? payload,
  }) async {
    final Map<String, dynamic> dataToSave = payload ?? await _buildPayload();
    if (dataToSave.isEmpty) return;

    try {
      final dbHelper = DatabaseHelper.instance;
      final id = await dbHelper.insertEmbarque(dataToSave);
      _snack(
        '✅ Embarque guardado localmente (ID: $id). Se sincronizará más tarde.',
        color: Colors.blueGrey,
      );
      _limpiarFormulario();
    } catch (e) {
      _snack('❌ Error al guardar localmente: $e', color: Colors.red);
      print('Error en _guardarEmbarqueLocalmente: $e');
    }
  }

  Future<void> _guardarEmbarqueEnServidor() async {
    final bool isEditing = _editingEmbarqueId != null;
    final Map<String, dynamic> payload = await _buildPayload();
    if (payload.isEmpty) return;

    final String apiEndpoint = isEditing
        ? 'api_editar_embarque.php'
        : 'api_embarques.php';
    final url = Uri.parse('${ApiConfig.baseUrl}$apiEndpoint');

    // Si estamos editando, añadimos el ID del embarque al payload
    if (isEditing) {
      payload['idfolioembarque'] = _editingEmbarqueId;
    }

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        _snack(
          data['message'] ??
              (isEditing ? '✅ Embarque actualizado' : '✅ Embarque guardado'),
          color: Colors.green,
        );
        _limpiarFormulario();
        _consultarEmbarques();
        _tabController.animateTo(1); // Volver a la pestaña de consulta
      } else {
        final errorData = json.decode(response.body);
        final errorMessage =
            '❌ Error del servidor: ${errorData['error'] ?? 'Desconocido'}.';
        if (kIsWeb) {
          _snack(errorMessage, color: Colors.red);
        } else {
          // En modo de creación, se puede intentar el guardado local. En edición no.
          if (!isEditing) {
            _snack(
              '$errorMessage Intentando guardado local.',
              color: Colors.orange,
            );
            await _guardarEmbarqueLocalmente(payload: payload);
          } else {
            _snack(errorMessage, color: Colors.red);
          }
        }
      }
    } on SocketException catch (_) {
      if (kIsWeb || isEditing) {
        print(
          '🔌 Sin conexión. No se puede ${isEditing ? 'editar' : 'guardar en la web'}.',
        );
      } else {
        print('🔌 Sin conexión. Guardando localmente...');
        await _guardarEmbarqueLocalmente(payload: payload);
      }
    } catch (e) {
      final errorMessage = '❌ Error inesperado: $e.';
      if (kIsWeb || isEditing) {
        _snack(errorMessage, color: Colors.red);
      } else {
        _snack('$errorMessage Guardando localmente...', color: Colors.orange);
        print('Error en _guardarEmbarqueEnServidor: $e');
        await _guardarEmbarqueLocalmente(payload: payload);
      }
    }
  }

  Future<void> _consultarEmbarques({
    DateTime? fecha,
    bool forceOffline = false,
  }) async {
    if (!mounted) return;
    setState(() {
      _isConsultando = true;
    });

    final fechaAFiltrar = fecha ?? _fechaFiltro;
    final formattedDate =
        "${fechaAFiltrar.year}-${fechaAFiltrar.month.toString().padLeft(2, '0')}-${fechaAFiltrar.day.toString().padLeft(2, '0')}";

    // ⬇️ si me dijeron "offline", leo directo de sqlite y regreso
    if (forceOffline) {
      final db = DatabaseHelper.instance;
      final offlineData = await db.getEmbarquesConsulta(
        fecha: formattedDate,
        idAlmacen: _selectedAlmacenFiltroId,
      );

      if (mounted) {
        setState(() {
          _embarquesConsultados = offlineData
              .map(
                (m) => EmbarqueConsulta(
                  idfolioembarque: m['idfolioembarque'] as int,
                  regtimestamp: m['regtimestamp'] as String,
                  nombre_cliente: m['nombre_cliente'] as String,
                  nombreusuario: m['nombreusuario'] as String,
                  nombre_almacenista: m['nombre_almacenista'] as String,
                  esActivo: (m['estado_embarque'] as int) == 1,
                  idcliente: m['idcliente'] as int,
                  idalmacen: m['idalmacen'] as int,
                  idusuario: m['idusuario'] as int,
                  idalmacenista: m['idalmacenista'] as int,
                ),
              )
              .toList();
          _isConsultando = false;
        });
      }
      return;
    }

    // ⬇️ de aquí para abajo dejas tu try/catch tal cual lo tenías
    try {
      String urlString =
          '${ApiConfig.baseUrl}api_consulta_embarques.php?fecha=$formattedDate';
      if (_selectedAlmacenFiltroId != null) {
        urlString += '&idalmacen=$_selectedAlmacenFiltroId';
      }

      final url = Uri.parse(urlString);
      final response = await http.get(url);

      if (mounted) {
        if (response.statusCode == 200) {
          final Map<String, dynamic> decoded = json.decode(response.body);
          if (decoded['success'] == true) {
            final List<dynamic> data = decoded['data'];
            final embarques = data
                .map((json) => EmbarqueConsulta.fromJson(json))
                .toList();

            final db = DatabaseHelper.instance;
            await db.cacheEmbarquesConsulta(embarques, fecha: formattedDate);

            setState(() {
              _embarquesConsultados = embarques;
              _currentPage = 0;
              _selectedEmbarques.clear();
              _selectAll = false;
            });
          } else {
            throw Exception(
              decoded['error'] ?? 'Error desconocido del servidor',
            );
          }
        } else {
          throw Exception('Error de conexión: ${response.statusCode}');
        }
      }
    } on SocketException {
      final db = DatabaseHelper.instance;
      final offlineData = await db.getEmbarquesConsulta(
        fecha: formattedDate,
        idAlmacen: _selectedAlmacenFiltroId,
      );

      if (mounted) {
        setState(() {
          _embarquesConsultados = offlineData
              .map(
                (m) => EmbarqueConsulta(
                  idfolioembarque: m['idfolioembarque'] as int,
                  regtimestamp: m['regtimestamp'] as String,
                  nombre_cliente: m['nombre_cliente'] as String,
                  nombreusuario: m['nombreusuario'] as String,
                  nombre_almacenista: m['nombre_almacenista'] as String,
                  esActivo: (m['estado_embarque'] as int) == 1,
                  idcliente: m['idcliente'] as int,
                  idalmacen: m['idalmacen'] as int,
                  idusuario: m['idusuario'] as int,
                  idalmacenista: m['idalmacenista'] as int,
                ),
              )
              .toList();
          _currentPage = 0;
        });
      }
    } catch (e) {
      final db = DatabaseHelper.instance;
      final offlineData = await db.getEmbarquesConsulta(
        fecha: formattedDate,
        idAlmacen: _selectedAlmacenFiltroId,
      );

      if (mounted) {
        _snack('Error al consultar embarques: $e', color: Colors.red);
        setState(() {
          _embarquesConsultados = offlineData
              .map(
                (m) => EmbarqueConsulta(
                  idfolioembarque: m['idfolioembarque'] as int,
                  regtimestamp: m['regtimestamp'] as String,
                  nombre_cliente: m['nombre_cliente'] as String,
                  nombreusuario: m['nombreusuario'] as String,
                  nombre_almacenista: m['nombre_almacenista'] as String,
                  esActivo: (m['estado_embarque'] as int) == 1,
                  idcliente: m['idcliente'] as int,
                  idalmacen: m['idalmacen'] as int,
                  idusuario: m['idusuario'] as int,
                  idalmacenista: m['idalmacenista'] as int,
                ),
              )
              .toList();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConsultando = false;
        });
      }
    }
  }

  Future<void> _actualizarEstatusProducto(
    int iddetalle,
    int nuevoIdEstatus,
  ) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}api_cambiar_estatus_producto.php',
    );
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'iddetalle': iddetalle, 'idestatus': nuevoIdEstatus}),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['status'] == 'success') {
          _snack('Estatus actualizado.', color: Colors.green);
        } else {
          throw Exception(decoded['message'] ?? 'Error al actualizar');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      _snack('Error: $e', color: Colors.red);
    }
  }

  void _mostrarDialogoDetalles(EmbarqueConsulta embarque) async {
    // Muestra un loader mientras se cargan los detalles
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    List<EmbarqueDetalleProducto> detalles = [];
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}api_embarque_detalle.php?idfolioembarque=${embarque.idfolioembarque}',
      );
      final response = await http.get(url);
      Navigator.of(context).pop(); // Cierra el loader

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final List<dynamic> data = decoded['data'];
          detalles = data
              .map((json) => EmbarqueDetalleProducto.fromJson(json))
              .toList();
        } else {
          throw Exception(decoded['error'] ?? 'Error al cargar detalles');
        }
      } else {
        throw Exception('Error de conexión: ${response.statusCode}');
      }
    } catch (e) {
      Navigator.of(
        context,
      ).pop(); // Asegúrate de cerrar el loader en caso de error
      _snack('Error al cargar detalles: $e', color: Colors.red);
      return;
    }

    // Muestra el diálogo con los detalles
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: Text('Detalle del Embarque #${embarque.idfolioembarque}'),
              content: SizedBox(
                width: double.maxFinite,
                child: _estatusList.isEmpty
                    ? const Center(
                        child: Text('Cargando configuración de estatus...'),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: detalles.length,
                        itemBuilder: (context, index) {
                          final producto = detalles[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(producto.nombreproducto),
                              subtitle: Text('Cantidad: ${producto.cantidad}'),
                              trailing: DropdownButton<int>(
                                value: producto.idestatus,
                                items: _estatusList.map((estatus) {
                                  return DropdownMenuItem<int>(
                                    value: estatus.id,
                                    child: Text(estatus.clave),
                                  );
                                }).toList(),
                                onChanged: (newId) {
                                  if (newId != null &&
                                      newId != producto.idestatus) {
                                    _actualizarEstatusProducto(
                                      producto.iddetalle,
                                      newId,
                                    ).then((_) {
                                      // Actualiza el estado localmente para reflejar el cambio en la UI
                                      setStateInDialog(() {
                                        producto.idestatus = newId;
                                      });
                                    });
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CERRAR'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generarNota(EmbarqueConsulta embarque) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar Nota de Venta'),
        content: Text(
          '¿Estás seguro de que deseas generar la nota para el embarque #${embarque.idfolioembarque}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SÍ, GENERAR'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isConsultando = true);

    try {
      // 1. Fetch the details of the embarque
      final detallesUrl = Uri.parse(
        '${ApiConfig.baseUrl}api_embarque_detalle.php?idfolioembarque=${embarque.idfolioembarque}',
      );
      final detallesResponse = await http.get(detallesUrl);
      if (detallesResponse.statusCode != 200)
        throw Exception('Error al obtener detalles del embarque.');

      final detallesDecoded = json.decode(detallesResponse.body);
      if (detallesDecoded['success'] != true)
        throw Exception(
          detallesDecoded['error'] ?? 'Error del servidor al obtener detalles.',
        );

      final List<dynamic> detallesData = detallesDecoded['data'];
      if (detallesData.isEmpty)
        throw Exception(
          'Este embarque no tiene productos para generar una nota.',
        );

      // 2. Build the payload for the nota API - USANDO EL ALMACEN ORIGINAL DEL EMBARQUE
      final payload = {
        'id_embarque': embarque.idfolioembarque,
        'id_usuario': embarque.idusuario,
        'id_cliente': embarque.idcliente,
        'id_almacen':
            embarque.idalmacen, // Se usa el idalmacen del embarque original
        'detalles': detallesData
            .map(
              (d) => {
                'idproducto': d['idproducto'],
                'idunidad': d['idunidad'],
                'cantidad': d['cantidad'],
                'precio': d['preciounitario'],
              },
            )
            .toList(),
      };

      // 3. Call the generate nota API
      final notaUrl = Uri.parse('${ApiConfig.baseUrl}api_generar_nota.php');
      final notaResponse = await http.post(
        notaUrl,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(payload),
      );

      if (mounted) {
        final notaDecoded = json.decode(notaResponse.body);
        if (notaResponse.statusCode == 201 && notaDecoded['success'] == true) {
          _snack(
            '✅ Nota #${notaDecoded['idnota']} generada correctamente.',
            color: Colors.green,
          );
          _consultarEmbarques(); // Refrescar la lista de embarques
        } else {
          throw Exception(
            notaDecoded['error'] ?? 'Error desconocido al generar la nota.',
          );
        }
      }
    } catch (e) {
      if (mounted) _snack('❌ Error: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isConsultando = false);
    }
  }

  Future<bool> _generarNotaSilenciosa(EmbarqueConsulta embarque) async {
    try {
      // 1. detalles
      final detallesUrl = Uri.parse(
        '${ApiConfig.baseUrl}api_embarque_detalle.php?idfolioembarque=${embarque.idfolioembarque}',
      );
      final detallesResponse = await http.get(detallesUrl);
      if (detallesResponse.statusCode != 200) return false;

      final detallesDecoded = json.decode(detallesResponse.body);
      if (detallesDecoded['success'] != true) return false;

      final List<dynamic> detallesData = detallesDecoded['data'];
      if (detallesData.isEmpty) return false;

      final payload = {
        'id_embarque': embarque.idfolioembarque,
        'id_usuario': embarque.idusuario,
        'id_cliente': embarque.idcliente,
        'id_almacen': embarque.idalmacen,
        'detalles': detallesData
            .map(
              (d) => {
                'idproducto': d['idproducto'],
                'idunidad': d['idunidad'],
                'cantidad': d['cantidad'],
                'precio': d['preciounitario'],
              },
            )
            .toList(),
      };

      final notaUrl = Uri.parse('${ApiConfig.baseUrl}api_generar_nota.php');
      final notaResponse = await http.post(
        notaUrl,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(payload),
      );

      if (notaResponse.statusCode == 201) {
        final notaDecoded = json.decode(notaResponse.body);
        return notaDecoded['success'] == true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _generarNotasSeleccionadas() async {
    // tomar solo los embarques activos que estén seleccionados
    final seleccionados = _embarquesConsultados
        .where(
          (e) => e.esActivo && _selectedEmbarques.contains(e.idfolioembarque),
        )
        .toList();

    if (seleccionados.isEmpty) {
      _snack('Selecciona al menos un embarque activo.', color: Colors.red);
      return;
    }

    final fechaTxt =
        "${_fechaFiltro.day.toString().padLeft(2, '0')}/${_fechaFiltro.month.toString().padLeft(2, '0')}/${_fechaFiltro.year}";
    final nombreAlmacen = _nombreAlmacenFiltro();

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Generar notas'),
          content: Text(
            'Se van a generar ${seleccionados.length} nota(s) de la fecha $fechaTxt'
            '${nombreAlmacen != null ? ' del almacén $nombreAlmacen' : ''}.\n\n¿Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CERRAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('GENERAR TODO'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    setState(() => _isConsultando = true);

    int okCount = 0;
    int failCount = 0;

    for (final e in seleccionados) {
      final ok = await _generarNotaSilenciosa(e);
      if (ok) {
        okCount++;
      } else {
        failCount++;
      }
    }

    // refrescamos la lista para que se vea actualizado
    await _consultarEmbarques(fecha: _fechaFiltro);

    setState(() => _isConsultando = false);

    _snack(
      'Generadas: $okCount. Fallaron: $failCount.',
      color: failCount == 0 ? Colors.green : Colors.orange,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EDF3),
      body: SafeArea(
        child: (_isLoading && _estatusList.isEmpty)
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(username: _username, onLogout: _logout),
                    const SizedBox(height: 8),
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF1E3A8A),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF1E3A8A),
                      tabs: const [
                        Tab(
                          text: 'CREAR',
                          icon: Icon(Icons.add_circle_outline),
                        ),
                        Tab(text: 'CONSULTAR', icon: Icon(Icons.search)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // --- Pestaña 1: Formulario de Creación ---
                          SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _CardWrap(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Wrap(
                                        spacing: 16, // Espacio horizontal
                                        runSpacing:
                                            16, // Espacio vertical cuando se envuelve
                                        children: [
                                          _buildResponsiveDropdown(
                                            constraints: constraints,
                                            label: 'Almacén',
                                            icon: Icons
                                                .store_mall_directory_outlined,
                                            value: _selectedAlmacenId,
                                            items: _almacenes
                                                .map(
                                                  (a) => DropdownMenuItem<int>(
                                                    value: a.id,
                                                    child: Text(a.nombre),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (v) => setState(
                                              () => _selectedAlmacenId = v,
                                            ),
                                          ),
                                          _buildResponsiveDropdown(
                                            constraints: constraints,
                                            label: 'Almacenista',
                                            icon: Icons.badge_outlined,
                                            value: _selectedAlmacenistaId,
                                            items: _almacenistas
                                                .map(
                                                  (a) => DropdownMenuItem<int>(
                                                    value: a.id,
                                                    child: Text(a.nombre),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (v) => setState(
                                              () => _selectedAlmacenistaId = v,
                                            ),
                                          ),

                                          _buildResponsiveDropdown(
                                            constraints: constraints,
                                            label: 'Cliente',
                                            icon: Icons.person_outline,
                                            value: _selectedClienteId,
                                            items: _clientes
                                                .map(
                                                  (c) => DropdownMenuItem<int>(
                                                    value: c.id,
                                                    child: Text(c.nombre),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (v) {
                                              setState(
                                                () => _selectedClienteId = v,
                                              );
                                              _fetchPrecio();
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Captura de productos
                                _CardWrap(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const _SectionTitle('Producto'),
                                      const SizedBox(height: 12),
                                      LayoutBuilder(
                                        builder: (context, c) {
                                          final isSmall = c.maxWidth < 500;
                                          return Wrap(
                                            spacing: 16,
                                            runSpacing: 16,
                                            alignment:
                                                WrapAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.end,
                                            children: [
                                              // Autocomplete de productos
                                              SizedBox(
                                                width: isSmall
                                                    ? double.infinity
                                                    : c.maxWidth * 0.4,
                                                child: Autocomplete<Producto>(
                                                  key: _autocompleteKey,
                                                  displayStringForOption:
                                                      (Producto option) =>
                                                          option.nombre,
                                                  optionsBuilder:
                                                      (
                                                        TextEditingValue
                                                        textEditingValue,
                                                      ) {
                                                        if (textEditingValue
                                                                .text ==
                                                            '') {
                                                          return const Iterable<
                                                            Producto
                                                          >.empty();
                                                        }
                                                        return _productos.where((
                                                          Producto option,
                                                        ) {
                                                          return option.nombre
                                                              .toLowerCase()
                                                              .contains(
                                                                textEditingValue
                                                                    .text
                                                                    .toLowerCase(),
                                                              );
                                                        });
                                                      },
                                                  onSelected: (Producto selection) {
                                                    setState(() {
                                                      _selectedProducto =
                                                          selection;
                                                      _productoAutocompleteCtrl
                                                          .text = selection
                                                          .nombre; // Mantener el texto
                                                    });
                                                    _fetchPrecio();
                                                  },
                                                  fieldViewBuilder:
                                                      (
                                                        BuildContext context,
                                                        TextEditingController
                                                        fieldController,
                                                        FocusNode
                                                        fieldFocusNode,
                                                        VoidCallback
                                                        onFieldSubmitted,
                                                      ) {
                                                        return TextField(
                                                          controller:
                                                              fieldController,
                                                          focusNode:
                                                              fieldFocusNode,
                                                          decoration: _inputDeco(
                                                            label:
                                                                'Busca un Producto',
                                                            icon: Icons
                                                                .shopping_basket_outlined,
                                                            trailing: IconButton(
                                                              icon: const Icon(
                                                                Icons.clear,
                                                                size: 20,
                                                              ),
                                                              onPressed: () {
                                                                fieldController
                                                                    .clear();
                                                                setState(() {
                                                                  _selectedProducto =
                                                                      null;
                                                                });
                                                              },
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                ),
                                              ),
                                              // Campo de cantidad
                                              SizedBox(
                                                width: isSmall
                                                    ? (c.maxWidth / 2) - 8
                                                    : c.maxWidth * 0.15,
                                                child: TextField(
                                                  controller: cantidadCtrl,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration: _inputDeco(
                                                    label: 'Cantidad',
                                                    icon: Icons
                                                        .format_list_numbered,
                                                  ),
                                                ),
                                              ),
                                              // Unidad Dropdown
                                              SizedBox(
                                                width: isSmall
                                                    ? (c.maxWidth / 2) - 8
                                                    : c.maxWidth * 0.2,
                                                child: _buildDropdown(
                                                  label: 'Unidad',
                                                  icon: Icons.straighten,
                                                  value: _selectedUnidadId,
                                                  items: _unidades
                                                      .map(
                                                        (u) =>
                                                            DropdownMenuItem<
                                                              int
                                                            >(
                                                              value: u.id,
                                                              child: Text(
                                                                u.nombre,
                                                              ),
                                                            ),
                                                      )
                                                      .toList(),
                                                  onChanged: (v) {
                                                    setState(
                                                      () =>
                                                          _selectedUnidadId = v,
                                                    );
                                                    _fetchPrecio();
                                                  },
                                                ),
                                              ),
                                              // Botón de agregar
                                              SizedBox(
                                                width: isSmall
                                                    ? double.infinity
                                                    : c.maxWidth * 0.15,
                                                child: _primaryButton(
                                                  icon:
                                                      Icons.add_circle_outline,
                                                  text: 'Agregar',
                                                  background: const Color(
                                                    0xFF1E3A8A,
                                                  ),
                                                  onPressed: _agregarFila,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Tabla de productos
                                _CardWrap(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const _SectionTitle('Detalle'),
                                      const SizedBox(height: 12),
                                      filas.isEmpty
                                          ? const Padding(
                                              padding: EdgeInsets.all(24.0),
                                              child: Center(
                                                child: Text(
                                                  'Sin productos agregados',
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: DataTable(
                                                columns: const [
                                                  DataColumn(
                                                    label: Text('cod.'),
                                                  ),
                                                  DataColumn(
                                                    label: Text('Cantidad'),
                                                  ),
                                                  DataColumn(
                                                    label: Text('Unidad'),
                                                  ),
                                                  DataColumn(
                                                    label: Text('Producto'),
                                                  ),
                                                  DataColumn(
                                                    label: Text('P/U'),
                                                  ),
                                                  DataColumn(
                                                    label: Text('Estatus'),
                                                  ),
                                                  DataColumn(
                                                    label: Text('Acciones'),
                                                  ),
                                                ],
                                                rows: [
                                                  for (
                                                    int i = 0;
                                                    i < filas.length;
                                                    i++
                                                  )
                                                    DataRow(
                                                      cells: [
                                                        DataCell(
                                                          Text(
                                                            filas[i]['cod']
                                                                as String,
                                                          ),
                                                        ),
                                                        DataCell(
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              IconButton(
                                                                icon: const Icon(
                                                                  Icons.remove,
                                                                ),
                                                                color:
                                                                    Colors.red,
                                                                iconSize: 18,
                                                                onPressed: () =>
                                                                    _cambiarCantidad(
                                                                      i,
                                                                      -1,
                                                                    ),
                                                              ),
                                                              Text(
                                                                '${filas[i]['cantidad']}',
                                                              ),
                                                              IconButton(
                                                                icon:
                                                                    const Icon(
                                                                      Icons.add,
                                                                    ),
                                                                color: Colors
                                                                    .green,
                                                                iconSize: 18,
                                                                onPressed: () =>
                                                                    _cambiarCantidad(
                                                                      i,
                                                                      1,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        DataCell(
                                                          Text(
                                                            filas[i]['unidad']
                                                                .toString(),
                                                          ),
                                                        ),
                                                        DataCell(
                                                          Text(
                                                            filas[i]['producto']
                                                                .toString(),
                                                          ),
                                                        ),
                                                        DataCell(
                                                          SizedBox(
                                                            width:
                                                                80, // Ancho fijo para el campo de precio
                                                            child: TextField(
                                                              controller:
                                                                  filas[i]['precio_controller']
                                                                      as TextEditingController,
                                                              keyboardType:
                                                                  const TextInputType.numberWithOptions(
                                                                    decimal:
                                                                        true,
                                                                  ),
                                                              decoration:
                                                                  const InputDecoration(
                                                                    border:
                                                                        InputBorder
                                                                            .none,
                                                                    prefixText:
                                                                        '\$',
                                                                  ),
                                                              onChanged: (_) =>
                                                                  setState(
                                                                    () {},
                                                                  ), // Para que el total se actualice en tiempo real
                                                            ),
                                                          ),
                                                        ),
                                                        const DataCell(
                                                          Text('EE'),
                                                        ), // Mostrar clave de estatus
                                                        DataCell(
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.delete,
                                                            ),
                                                            color: Colors.red,
                                                            onPressed: () =>
                                                                _eliminar(i),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Total
                                _CardWrap(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'TOTAL',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F766E),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          '\$${total.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Botones de acción
                                _editingEmbarqueId != null
                                    // --- BOTONES EN MODO EDICIÓN ---
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          Expanded(
                                            child: _actionBtnModern(
                                              icon: Icons.cancel_outlined,
                                              text: 'CANCELAR EDICIÓN',
                                              background: Colors.red.shade700,
                                              border: Colors.red.shade900,
                                              onPressed: _limpiarFormulario,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _actionBtnModern(
                                              icon: Icons.save_as_outlined,
                                              text: 'ACTUALIZAR',
                                              background: Colors.blue.shade700,
                                              border: Colors.blue.shade900,
                                              onPressed:
                                                  _guardarEmbarqueEnServidor,
                                            ),
                                          ),
                                        ],
                                      )
                                    // --- BOTÓN EN MODO CREACIÓN ---
                                    : Center(
                                        child: SizedBox(
                                          width:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.6,
                                          child: _actionBtnModern(
                                            icon: Icons.cloud_upload_outlined,
                                            text: 'GUARDAR',
                                            background: const Color(0xFF1E3A8A),
                                            border: const Color(0xFF1D4ED8),
                                            onPressed:
                                                _guardarEmbarqueEnServidor,
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                          // --- Pestaña 2: Consulta ---
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // --- Filtros ---
                                _buildFiltrosConsulta(),
                                const SizedBox(height: 16),
                                // --- Resultados ---
                                Expanded(
                                  child: RefreshIndicator(
                                    onRefresh:
                                        _refreshConsultaAuto, // <- deslizar hacia abajo
                                    child: _isConsultando
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : _embarquesConsultados.isEmpty
                                        ? ListView(
                                            // RefreshIndicator necesita algo que scrollee
                                            children: const [
                                              SizedBox(height: 80),
                                              Center(
                                                child: Text(
                                                  'No se encontraron embarques para la fecha seleccionada.',
                                                ),
                                              ),
                                              SizedBox(height: 300),
                                            ],
                                          )
                                        : ListView(
                                            children: [
                                              // aquí metemos tu tabla horizontal
                                              _buildTablaResultados(),
                                              const SizedBox(height: 40),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDeco({
    required String label,
    required IconData icon,
    Widget? trailing,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: trailing,
      filled: true,
      fillColor: const Color(0xFFF6F7FB),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD8DFEA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF6F7FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD8DFEA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 12,
        ), // Añadido para dar más altura
      ),
      isExpanded: true,
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildResponsiveDropdown<T>({
    required BoxConstraints constraints,
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    // En pantallas muy angostas, usa el ancho completo.
    // En pantallas más anchas, usa la mitad del ancho menos el espaciado.
    final isNarrow = constraints.maxWidth < 400;
    final itemWidth = isNarrow
        ? constraints.maxWidth
        : (constraints.maxWidth / 2) - 8;

    return SizedBox(
      width: itemWidth,
      child: _buildDropdown(
        label: label,
        icon: icon,
        value: value,
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String text,
    required Color background,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 3,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        shadowColor: Colors.black.withOpacity(0.25),
      ),
    );
  }

  Widget _actionBtnModern({
    required IconData icon,
    required String text,
    required Color background,
    required Color border,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 4,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border, width: 1.2),
        ),
        shadowColor: Colors.black.withOpacity(0.25),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets para la Pestaña de Consulta ---

  Widget _buildFiltrosConsulta() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isSmall = constraints.maxWidth < 520;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // FECHA estilo píldora
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fechaFiltro,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null && picked != _fechaFiltro) {
                  setState(() => _fechaFiltro = picked);
                }
              },
              icon: const Icon(
                Icons.calendar_today,
                size: 16,
                color: Color(0xFF1E3A8A),
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${_fechaFiltro.day.toString().padLeft(2, '0')}/${_fechaFiltro.month.toString().padLeft(2, '0')}/${_fechaFiltro.year}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more, size: 16, color: Colors.grey),
                ],
              ),
            ),
            SizedBox(
              width: isSmall ? double.infinity : 260,
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedAlmacenFiltroId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Almacén',
                        labelStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(
                          Icons.store_mall_directory_outlined,
                          size: 18,
                        ),
                        suffixIcon: _selectedAlmacenFiltroId != null
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(
                                    () => _selectedAlmacenFiltroId = null,
                                  );
                                  _consultarEmbarques();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _almacenes
                          .map(
                            (a) => DropdownMenuItem<int>(
                              value: a.id,
                              child: Text(
                                a.nombre,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedAlmacenFiltroId = v),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // botón buscar al lado
                  ElevatedButton(
                    onPressed: () => _consultarEmbarques(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Icon(Icons.search, size: 16),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _iniciarEdicion(EmbarqueConsulta embarque) async {
    // 1. Mostrar un loader y limpiar el formulario actual
    setState(() {
      _isLoading = true;
      _limpiarFormulario(); // Limpia cualquier estado anterior
    });

    try {
      // 2. Obtener los detalles (productos) del embarque
      final url = Uri.parse(
        '${ApiConfig.baseUrl}api_embarque_detalle.php?idfolioembarque=${embarque.idfolioembarque}',
      );
      final response = await http.get(url);
      if (!mounted) return;

      final decoded = json.decode(response.body);
      if (response.statusCode != 200 || decoded['success'] != true) {
        throw Exception(
          decoded['error'] ?? 'Error al cargar los productos del embarque.',
        );
      }
      final List<dynamic> detallesData = decoded['data'];

      // 3. Poblar el estado del formulario con los datos del embarque
      setState(() {
        _editingEmbarqueId = embarque.idfolioembarque;

        // Poblar cabecera
        _selectedAlmacenId = embarque.idalmacen;
        _selectedAlmacenistaId =
            embarque.idalmacenista; // Ahora sí viene en EmbarqueConsulta
        _selectedClienteId = embarque.idcliente;
        _selectedUnidadId = null; // La unidad es por producto, no de cabecera

        // Poblar la tabla de productos (filas)
        for (var detalle in detallesData) {
          // --- FIX: Usar parseo seguro en lugar de casteo directo ---
          final cantidad = num.tryParse(detalle['cantidad'].toString()) ?? 0;
          final precio =
              num.tryParse(detalle['preciounitario'].toString()) ?? 0;

          filas.add({
            'cod': _nextCodigo(),
            'cantidad': cantidad.toInt(),
            'unidad': _unidades
                .firstWhere(
                  (u) => u.id == detalle['idunidad'],
                  orElse: () => Unidad(id: 0, nombre: 'N/A'),
                )
                .nombre,
            'producto': _productos
                .firstWhere(
                  (p) => p.id == detalle['idproducto'],
                  orElse: () => Producto(id: 0, nombre: 'N/A'),
                )
                .nombre,
            'precio_controller': TextEditingController(
              text: precio.toStringAsFixed(2),
            ),
            'idproducto': detalle['idproducto'],
            'idunidad': detalle['idunidad'],
            'idestatus': detalle['idestatus'],
          });
        }

        // 4. Cambiar a la pestaña de CREAR
        _tabController.animateTo(0);
        _isLoading = false;
      });

      _snack(
        'Editando Embarque #${embarque.idfolioembarque}. Haz tus cambios y guarda.',
        color: Colors.blue,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _snack('❌ Error al iniciar edición: $e', color: Colors.red);
      }
    }
  }

  Future<void> _cancelarEmbarque(int idfolioembarque) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Cancelación'),
        content: Text(
          '¿Estás seguro de que deseas cancelar el embarque #$idfolioembarque? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'SÍ, CANCELAR',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isConsultando = true);

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}api_cancelar_embarque.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'idfolioembarque': idfolioembarque}),
      );

      if (mounted) {
        final decoded = json.decode(response.body);
        if (response.statusCode == 200 && decoded['success'] == true) {
          _snack(
            '✅ Embarque #$idfolioembarque cancelado.',
            color: Colors.orange,
          );
          _consultarEmbarques(); // Refrescar la lista
        } else {
          throw Exception(decoded['error'] ?? 'Error desconocido al cancelar.');
        }
      }
    } catch (e) {
      if (mounted) _snack('❌ Error: $e', color: Colors.red);
    } finally {
      // El refresco ya quita el estado de carga, así que no es necesario aquí.
    }
  }

  Widget _buildTablaResultados() {
    final total = _embarquesConsultados.length;
    if (total == 0) {
      return const SizedBox.shrink();
    }

    final start = _currentPage * _rowsPerPage;
    final end = (start + _rowsPerPage) > total ? total : (start + _rowsPerPage);
    final pageItems = _embarquesConsultados.sublist(start, end);

    // calcular si realmente todos los activos están seleccionados
    final todosActivos = _embarquesConsultados
        .where((e) => e.esActivo)
        .toList();
    final allSelected =
        todosActivos.isNotEmpty &&
        todosActivos.every(
          (e) => _selectedEmbarques.contains(e.idfolioembarque),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 38,
            dataRowMinHeight: 38,
            columns: [
              DataColumn(
                label: Checkbox(
                  value: allSelected,
                  onChanged: (v) {
                    setState(() {
                      _selectAll = v ?? false;
                      _selectedEmbarques.clear();
                      if (_selectAll) {
                        // seleccionar TODOS los de la fecha (no solo la página) que estén activos
                        for (final e in _embarquesConsultados) {
                          if (e.esActivo) {
                            _selectedEmbarques.add(e.idfolioembarque);
                          }
                        }
                      }
                    });
                  },
                ),
              ),
              const DataColumn(label: Text('Folio')),
              const DataColumn(label: Text('Fecha')),
              const DataColumn(label: Text('Cliente')),
              const DataColumn(label: Text('Usuario')),
              const DataColumn(label: Text('Almacenista')),
              const DataColumn(label: Text('Estado')),
              const DataColumn(label: Text('Acciones')),
            ],
            rows: pageItems.map((embarque) {
              final isChecked = _selectedEmbarques.contains(
                embarque.idfolioembarque,
              );
              return DataRow(
                cells: [
                  DataCell(
                    Checkbox(
                      value: isChecked,
                      onChanged: embarque.esActivo
                          ? (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedEmbarques.add(
                                    embarque.idfolioembarque,
                                  );
                                } else {
                                  _selectedEmbarques.remove(
                                    embarque.idfolioembarque,
                                  );
                                }
                              });
                            }
                          : null,
                    ),
                  ),
                  DataCell(Text(embarque.idfolioembarque.toString())),
                  DataCell(Text(embarque.regtimestamp.split(' ').first)),
                  DataCell(Text(embarque.nombre_cliente)),
                  DataCell(Text(embarque.nombreusuario)),
                  DataCell(Text(embarque.nombre_almacenista)),
                  DataCell(
                    Icon(
                      embarque.esActivo ? Icons.check_circle : Icons.cancel,
                      color: embarque.esActivo ? Colors.green : Colors.red,
                      size: 18,
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.receipt_long_outlined,
                            size: 18,
                          ),
                          tooltip: 'Generar Nota',
                          color: embarque.esActivo ? Colors.green : Colors.grey,
                          onPressed: embarque.esActivo
                              ? () => _generarNota(embarque)
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Editar',
                          color: embarque.esActivo ? Colors.blue : Colors.grey,
                          onPressed: embarque.esActivo
                              ? () => _iniciarEdicion(embarque)
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Cancelar',
                          color: embarque.esActivo ? Colors.red : Colors.grey,
                          onPressed: embarque.esActivo
                              ? () =>
                                    _cancelarEmbarque(embarque.idfolioembarque)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // paginador + botón generar todo
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${start + 1} - $end de $total',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _selectedEmbarques.isNotEmpty
                      ? _generarNotasSeleccionadas
                      : null,
                  icon: const Icon(Icons.playlist_add_check),
                  label: const Text('Generar todo'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0
                      ? () {
                          setState(() {
                            _currentPage--;
                          });
                        }
                      : null,
                ),
                Text(
                  '${_currentPage + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: end < total
                      ? () {
                          setState(() {
                            _currentPage++;
                          });
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// --------- Secciones visuales ---------

class _Header extends StatelessWidget {
  final String username;
  final VoidCallback onLogout;

  const _Header({required this.username, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final Color a = const Color(0xFF0D1B2A);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(shape: BoxShape.circle, color: a),
          child: const Icon(
            Icons.local_shipping_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Embarques',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'logout') {
              onLogout();
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Cerrar Sesión'),
                ],
              ),
            ),
          ],
          child: Row(
            children: [
              const CircleAvatar(radius: 18, child: Icon(Icons.person_outline)),
              const SizedBox(width: 8),
              Text(
                'Hola, $username',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardWrap extends StatelessWidget {
  final Widget child;
  const _CardWrap({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}
