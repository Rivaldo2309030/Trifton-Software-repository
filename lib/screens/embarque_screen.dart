import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:distribuidora/services/database_helper.dart';

// --- Modelos de Datos Refactorizados ---

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
    return Almacen(
      id: map['id'],
      nombre: map['nombre'],
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'nombre': nombre,
    };
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
    return Unidad(
      id: map['id'],
      nombre: map['nombre'],
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }
}

class Cliente {
  final int id;
  final String nombre;
  Cliente({required this.id, required this.nombre});

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: int.tryParse(json['idcliente'].toString()) ?? 0,
      nombre: json['nombrecliente'],
    );
  }

  factory Cliente.fromDbMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'],
      nombre: map['nombre'],
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'nombre': nombre,
    };
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
    return Almacenista(
      id: map['id'],
      nombre: map['nombre'],
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'nombre': nombre,
    };
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
    return Producto(
      id: map['id'],
      nombre: map['nombre'],
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }
}


// --- Modelo para la pestaña de Consulta (Actualizado) ---
class EmbarqueConsulta {
  final int idfolioembarque;
  final String regtimestamp;
  final String nombre_cliente;
  final String nombreusuario;
  final String nombre_almacenista;
  final bool esActivo;

  EmbarqueConsulta({
    required this.idfolioembarque,
    required this.regtimestamp,
    required this.nombre_cliente,
    required this.nombreusuario,
    required this.nombre_almacenista,
    required this.esActivo,
  });

  factory EmbarqueConsulta.fromJson(Map<String, dynamic> json) {
    return EmbarqueConsulta(
      idfolioembarque: int.tryParse(json['idfolioembarque'].toString()) ?? 0,
      regtimestamp: json['regtimestamp'] ?? '',
      nombre_cliente: json['nombre_cliente'] ?? 'N/A',
      nombreusuario: json['nombreusuario'] ?? 'N/A',
      nombre_almacenista: json['nombre_almacenista'] ?? 'N/A',
      esActivo: (int.tryParse(json['estado_embarque'].toString()) ?? 0) == 1,
    );
  }
}


class EmbarqueScreen extends StatefulWidget {
  const EmbarqueScreen({super.key});

  @override
  State<EmbarqueScreen> createState() => _EmbarqueScreenState();
}

class _EmbarqueScreenState extends State<EmbarqueScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Estado para la pestaña de Consulta ---
  List<EmbarqueConsulta> _embarquesConsultados = [];
  bool _isConsultando = true;
  DateTime _fechaFiltro = DateTime.now();

  // --- Catalogos (dinamicos) ---
  List<Almacen> _almacenes = [];
  List<Unidad> _unidades = [];
  List<Producto> _productos = [];
  List<Cliente> _clientes = [];
  List<Almacenista> _almacenistas = [];
  bool _isLoading = true;

  // --- Estado de filtros/encabezado ---
  int? _selectedAlmacenId;
  int? _selectedAlmacenistaId;
  int? _selectedUnidadId;
  int? _selectedClienteId;

  final TextEditingController _productoAutocompleteCtrl = TextEditingController();

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
    _fetchCatalogos();
    _consultarEmbarques(); // Carga inicial para la pestaña de consulta

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // No hacer nada mientras la animación está en curso
      } else {
        if (_tabController.index == 1 && _embarquesConsultados.isEmpty) {
          // Si el usuario va a la pestaña de consulta y está vacía, refrescar.
          _consultarEmbarques();
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

  Future<void> _fetchCatalogos() async {
    setState(() { _isLoading = true; });
    await _loadCatalogsFromDb();
    setState(() { _isLoading = false; });
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
          _almacenes = almacenesData.map((map) => Almacen.fromDbMap(map)).toList();
          _clientes = clientesData.map((map) => Cliente.fromDbMap(map)).toList();
          _productos = productosData.map((map) => Producto.fromDbMap(map)).toList();
          _unidades = unidadesData.map((map) => Unidad.fromDbMap(map)).toList();
          _almacenistas = almacenistasData.map((map) => Almacenista.fromDbMap(map)).toList();
        });
      }
    } catch (e) {
      _snack('Error al cargar catálogos locales: $e', color: Colors.red);
    }
  }

  Future<void> _syncCatalogsFromServer() async {
    const String baseUrl = 'https://mediumslateblue-okapi-112468.hostingersite.com/APIS_RIVALDO/';
    final db = DatabaseHelper.instance;

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('${baseUrl}api_almacenes.php')),
        http.get(Uri.parse('${baseUrl}api_unidades.php')),
        http.get(Uri.parse('${baseUrl}api_productos.php')),
        http.get(Uri.parse('${baseUrl}api_clientes.php')),
        http.get(Uri.parse('${baseUrl}api_almacenistas.php')),
      ]);

      if (!mounted) return;

      // Almacenes
      if (responses[0].statusCode == 200) {
        final List<dynamic> data = json.decode(responses[0].body);
        final List<Almacen> almacenes = data.map((item) => Almacen.fromJson(item)).toList();
        await db.batchUpdateCatalog('almacenes_cat', almacenes.map((e) => e.toDbMap()).toList());
        if (mounted) setState(() => _almacenes = almacenes);
      }

      // Unidades
      if (responses[1].statusCode == 200) {
        final List<dynamic> data = json.decode(responses[1].body);
        final List<Unidad> unidades = data.map((item) => Unidad.fromJson(item)).toList();
        await db.batchUpdateCatalog('unidades_cat', unidades.map((e) => e.toDbMap()).toList());
        if (mounted) setState(() => _unidades = unidades);
      }

      // Productos
      if (responses[2].statusCode == 200) {
        final List<dynamic> data = json.decode(responses[2].body);
        final List<Producto> productos = data.map((item) => Producto.fromJson(item)).toList();
        await db.batchUpdateCatalog('productos_cat', productos.map((e) => e.toDbMap()).toList());
        if (mounted) setState(() => _productos = productos);
      }

      // Clientes
      if (responses[3].statusCode == 200) {
        final List<dynamic> data = json.decode(responses[3].body);
        final List<Cliente> clientes = data.map((item) => Cliente.fromJson(item)).toList();
        await db.batchUpdateCatalog('clientes_cat', clientes.map((e) => e.toDbMap()).toList());
        if (mounted) setState(() => _clientes = clientes);
      }

      // Almacenistas
      if (responses[4].statusCode == 200) {
        final List<dynamic> data = json.decode(responses[4].body);
        final List<Almacenista> almacenistas = data.map((item) => Almacenista.fromJson(item)).toList();
        await db.batchUpdateCatalog('almacenistas_cat', almacenistas.map((e) => e.toDbMap()).toList());
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
    if (_selectedProducto == null || _selectedClienteId == null || _selectedUnidadId == null) {
      setState(() => _precioUnitarioDinamico = null);
      return;
    }

    final db = DatabaseHelper.instance;
    final idCliente = _selectedClienteId!;
    final idProducto = _selectedProducto!.id;
    final idUnidad = _selectedUnidadId!;

    // 1. Intentar obtener el precio del caché local
    final localPrice = await db.getPrecio(idCliente, idProducto, idUnidad);

    if (localPrice != null) {
      setState(() {
        _precioUnitarioDinamico = localPrice;
      });
      return; // Precio encontrado en caché, no es necesario ir al servidor
    }

    // 2. Si no está en caché, ir al servidor
    const String baseUrl = 'https://mediumslateblue-okapi-112468.hostingersite.com/APIS_RIVALDO/';
    final url = Uri.parse('${baseUrl}api_precios.php?idcliente=$idCliente&idproducto=$idProducto&idunidad=$idUnidad');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['preciounitario'] != null) {
          final serverPrice = (data['preciounitario'] as num).toDouble();
          setState(() {
            _precioUnitarioDinamico = serverPrice;
          });
          // 3. Guardar el precio recién obtenido en el caché local
          await db.insertOrUpdatePrecio({
            'idcliente': idCliente,
            'idproducto': idProducto,
            'idunidad': idUnidad,
            'preciounitario': serverPrice,
          });
        } else {
          _snack('No se encontró un precio para esta combinación. Se usará 0.0.', color: Colors.orange);
          setState(() => _precioUnitarioDinamico = 0.0);
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } on SocketException {
      _snack('Sin conexión. Ingresa el precio manualmente.', color: Colors.orange);
      setState(() => _precioUnitarioDinamico = 0.0);
    } catch (e) {
      _snack('Error al obtener precio: $e. Se usará 0.0.', color: Colors.red);
      setState(() => _precioUnitarioDinamico = 0.0);
    }
  }

  void _snack(String msg, {Color color = Colors.black87}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  String _nextCodigo() {
    final next = filas.length + 1;
    return next.toString().padLeft(3, '0');
  }

  void _agregarFila() {
    // Validaciones de encabezado actualizadas
    if (_selectedAlmacenId == null || _selectedAlmacenistaId == null || _selectedUnidadId == null || _selectedClienteId == null) {
      _snack('Completa todos los campos del encabezado.', color: Colors.red);
      return;
    }
    
    if (_selectedProducto == null) {
      _snack('Selecciona un producto de la lista.', color: Colors.red);
      return;
    }

    if (_precioUnitarioDinamico == null) {
      _snack('No se pudo obtener un precio para este producto. Verifica la configuración.', color: Colors.red);
      return;
    }

    int cantidad = int.tryParse(cantidadCtrl.text) ?? 1;
    if (cantidad < 1) cantidad = 1;

    setState(() {
      filas.add({
        'cod': _nextCodigo(),
        'cantidad': cantidad,
        'unidad': _unidades.firstWhere((u) => u.id == _selectedUnidadId, orElse: () => Unidad(id: 0, nombre: 'N/A')).nombre,
        'producto': _selectedProducto!.nombre,
        'precio_controller': TextEditingController(text: _precioUnitarioDinamico!.toStringAsFixed(2)),
        'idproducto': _selectedProducto!.id,
        'idunidad': _selectedUnidadId, // Guardamos también el id de unidad para el guardado final
      });
      
      // Limpiar controles
      _selectedProducto = null;
      _productoAutocompleteCtrl.clear();
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

  double get total => filas.fold<double>(
        0.0,
        (sum, f) {
          final precio = double.tryParse((f['precio_controller'] as TextEditingController).text) ?? 0.0;
          return sum + (f['cantidad'] as int) * precio;
        },
      );

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
    });
  }

  Map<String, dynamic> _buildPayload() {
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
        'preciounitario': double.tryParse((fila['precio_controller'] as TextEditingController).text) ?? 0.0,
      };
    }).toList();

    return {
      'idalmacen': _selectedAlmacenId,
      'idusuario': 1, // TODO: Cambiar por el ID del usuario logueado
      'idalmacenista': _selectedAlmacenistaId,
      'idcliente': _selectedClienteId,
      'detalles': detallesPayload,
    };
  }

  Future<void> _guardarEmbarqueLocalmente({Map<String, dynamic>? payload}) async {
    final Map<String, dynamic> dataToSave = payload ?? _buildPayload();
    if (dataToSave.isEmpty) return;

    try {
      final dbHelper = DatabaseHelper.instance;
      final id = await dbHelper.insertEmbarque(dataToSave);
      _snack('✅ Embarque guardado localmente (ID: $id). Se sincronizará más tarde.', color: Colors.blueGrey);
      _limpiarFormulario();
    } catch (e) {
      _snack('❌ Error al guardar localmente: $e', color: Colors.red);
      print('Error en _guardarEmbarqueLocalmente: $e');
    }
  }

  Future<void> _guardarEmbarqueEnServidor() async {
    final Map<String, dynamic> payload = _buildPayload();
    if (payload.isEmpty) return;

    const String baseUrl = 'https://mediumslateblue-okapi-112468.hostingersite.com/APIS_RIVALDO/';
    final url = Uri.parse('${baseUrl}api_embarques.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10)); // Timeout de 10 segundos

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _snack('✅ Embarque guardado en servidor. Folio: ${data['idfolioembarque']}', color: Colors.green);
        _limpiarFormulario();
      } else {
        final errorData = json.decode(response.body);
        _snack('❌ Error del servidor: ${errorData['error'] ?? 'Desconocido'}. Intentando guardado local.', color: Colors.orange);
        await _guardarEmbarqueLocalmente(payload: payload);
      }
    } on SocketException catch (_) {
      _snack('🔌 Sin conexión. Guardando localmente...', color: Colors.orange);
      await _guardarEmbarqueLocalmente(payload: payload);
    } catch (e) {
      _snack('❌ Error inesperado: $e. Guardando localmente...', color: Colors.orange);
      print('Error en _guardarEmbarqueEnServidor: $e');
      await _guardarEmbarqueLocalmente(payload: payload);
    }
  }

  // --- Lógica para la Pestaña de Consulta (Actualizada) ---
  Future<void> _consultarEmbarques({DateTime? fecha}) async {
    if (!mounted) return;
    setState(() {
      _isConsultando = true;
    });

    try {
      final fechaAFiltrar = fecha ?? _fechaFiltro;
      final formattedDate = "${fechaAFiltrar.year}-${fechaAFiltrar.month.toString().padLeft(2, '0')}-${fechaAFiltrar.day.toString().padLeft(2, '0')}";
      
      const String baseUrl = 'https://mediumslateblue-okapi-112468.hostingersite.com/APIS_RIVALDO/';
      final url = Uri.parse('${baseUrl}api_consulta_embarques.php?fecha=$formattedDate');
      
      final response = await http.get(url);

      if (mounted) {
        if (response.statusCode == 200) {
          final Map<String, dynamic> decoded = json.decode(response.body);
          if (decoded['success'] == true) {
            final List<dynamic> data = decoded['data'];
            setState(() {
              _embarquesConsultados = data.map((json) => EmbarqueConsulta.fromJson(json)).toList();
            });
          } else {
            throw Exception(decoded['error'] ?? 'Error desconocido del servidor');
          }
        } else {
          throw Exception('Error de conexión: ${response.statusCode}');
        }
      }
    } on SocketException {
        if (mounted) {
            setState(() {
                _embarquesConsultados = [];
            });
        }
    } catch (e) {
      if (mounted) {
        _snack('Error al consultar embarques: $e', color: Colors.red);
        setState(() {
          _embarquesConsultados = []; // Limpiar en caso de error
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EDF3),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(),
                    const SizedBox(height: 8),
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF1E3A8A),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF1E3A8A),
                      tabs: const [
                        Tab(text: 'CREAR', icon: Icon(Icons.add_circle_outline)),
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
                                    builder: (context, c) {
                                      final w = c.maxWidth;
                                      final isPhone = w < 700;
                                      final isTablet = w >= 700 && w < 1100;
                                      
                                      return GridView.count(
                                        crossAxisCount: isPhone ? 2 : (isTablet ? 3 : 5),
                                        mainAxisSpacing: 16,
                                        crossAxisSpacing: 16,
                                        childAspectRatio: isPhone ? 3.2 : (isTablet ? 3.4 : 3.2),
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        children: [
                                          _buildDropdown<int>(
                                            label: 'Almacén',
                                            icon: Icons.store_mall_directory_outlined,
                                            value: _selectedAlmacenId,
                                            items: _almacenes.map((a) => DropdownMenuItem<int>(value: a.id, child: Text(a.nombre))).toList(),
                                            onChanged: (v) => setState(() => _selectedAlmacenId = v),
                                          ),
                                          _buildDropdown<int>(
                                            label: 'Almacenista',
                                            icon: Icons.badge_outlined,
                                            value: _selectedAlmacenistaId,
                                            items: _almacenistas.map((a) => DropdownMenuItem<int>(value: a.id, child: Text(a.nombre))).toList(),
                                            onChanged: (v) => setState(() => _selectedAlmacenistaId = v),
                                          ),
                                          _buildDropdown<int>(
                                            label: 'Unidad',
                                            icon: Icons.straighten,
                                            value: _selectedUnidadId,
                                            items: _unidades.map((u) => DropdownMenuItem<int>(value: u.id, child: Text(u.nombre))).toList(),
                                            onChanged: (v) {
                                              setState(() => _selectedUnidadId = v);
                                              _fetchPrecio();
                                            },
                                          ),
                                          _buildDropdown<int>(
                                            label: 'Cliente',
                                            icon: Icons.person_outline,
                                            value: _selectedClienteId,
                                            items: _clientes.map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.nombre))).toList(),
                                            onChanged: (v) {
                                              setState(() => _selectedClienteId = v);
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
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const _SectionTitle('Producto'),
                                      const SizedBox(height: 12),
                                      LayoutBuilder(builder: (context, c) {
                                        final isSmall = c.maxWidth < 500;
                                        return Wrap(
                                          spacing: 16,
                                          runSpacing: 16,
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment: WrapCrossAlignment.end,
                                          children: [
                                            // Autocomplete de productos
                                            SizedBox(
                                              width: isSmall ? double.infinity : c.maxWidth * 0.5,
                                              child: Autocomplete<Producto>(
                                                displayStringForOption: (Producto option) => option.nombre,
                                                optionsBuilder: (TextEditingValue textEditingValue) {
                                                  if (textEditingValue.text == '') {
                                                    return const Iterable<Producto>.empty();
                                                  }
                                                  return _productos.where((Producto option) {
                                                    return option.nombre.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                                  });
                                                },
                                                onSelected: (Producto selection) {
                                                  setState(() {
                                                    _selectedProducto = selection;
                                                  });
                                                  _fetchPrecio();
                                                },
                                                fieldViewBuilder: (BuildContext context, TextEditingController fieldController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                                                  // Asignar el controlador externo
                                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                                    fieldController.text = _productoAutocompleteCtrl.text;
                                                  });
                                                  return TextField(
                                                    controller: fieldController,
                                                    focusNode: fieldFocusNode,
                                                    decoration: _inputDeco(
                                                      label: 'Busca un Producto',
                                                      icon: Icons.shopping_basket_outlined,
                                                      trailing: IconButton(
                                                        icon: const Icon(Icons.clear, size: 20),
                                                        onPressed: () {
                                                          fieldController.clear();
                                                          setState(() {
                                                            _selectedProducto = null;
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
                                              width: isSmall ? double.infinity : c.maxWidth * 0.2,
                                              child: TextField(
                                                controller: cantidadCtrl,
                                                keyboardType: TextInputType.number,
                                                decoration: _inputDeco(
                                                  label: 'Cantidad',
                                                  icon: Icons.format_list_numbered,
                                                ),
                                              ),
                                            ),
                                            // Botón de agregar
                                            SizedBox(
                                              width: isSmall ? double.infinity : c.maxWidth * 0.2,
                                              child: _primaryButton(
                                                icon: Icons.add_circle_outline,
                                                text: 'Agregar',
                                                background: const Color(0xFF1E3A8A),
                                                onPressed: _agregarFila,
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Tabla de productos
                                _CardWrap(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const _SectionTitle('Detalle'),
                                      const SizedBox(height: 12),
                                      filas.isEmpty
                                          ? const Padding(
                                              padding: EdgeInsets.all(24.0),
                                              child: Center(
                                                child: Text('Sin productos agregados', style: TextStyle(color: Colors.grey)),
                                              ),
                                            )
                                          : SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: DataTable(
                                                columns: const [
                                                  DataColumn(label: Text('cod.')),
                                                  DataColumn(label: Text('Cantidad')),
                                                  DataColumn(label: Text('Unidad')),
                                                  DataColumn(label: Text('Producto')),
                                                  DataColumn(label: Text('P/U')),
                                                  DataColumn(label: Text('Acciones')),
                                                ],
                                                rows: [
                                                  for (int i = 0; i < filas.length; i++)
                                                    DataRow(
                                                      cells: [
                                                        DataCell(Text(filas[i]['cod'] as String)),
                                                        DataCell(Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            IconButton(
                                                              icon: const Icon(Icons.remove),
                                                              color: Colors.red,
                                                              iconSize: 18,
                                                              onPressed: () => _cambiarCantidad(i, -1),
                                                            ),
                                                            Text('${filas[i]['cantidad']}'),
                                                            IconButton(
                                                              icon: const Icon(Icons.add),
                                                              color: Colors.green,
                                                              iconSize: 18,
                                                              onPressed: () => _cambiarCantidad(i, 1),
                                                            ),
                                                          ],
                                                        )),
                                                        DataCell(Text(filas[i]['unidad'].toString())),
                                                        DataCell(Text(filas[i]['producto'].toString())),
                                                        DataCell(
                                                          SizedBox(
                                                            width: 80, // Ancho fijo para el campo de precio
                                                            child: TextField(
                                                              controller: filas[i]['precio_controller'] as TextEditingController,
                                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                              decoration: const InputDecoration(border: InputBorder.none, prefixText: '\$'),
                                                              onChanged: (_) => setState(() {}), // Para que el total se actualice en tiempo real
                                                            ),
                                                          ),
                                                        ),
                                                        DataCell(
                                                          IconButton(
                                                            icon: const Icon(Icons.delete),
                                                            color: Colors.red,
                                                            onPressed: () => _eliminar(i),
                                                          ),
                                                        ),
                                                      ],
                                                    )
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
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F766E),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '\$${total.toStringAsFixed(2)}',
                                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Botones de acción
                                LayoutBuilder(
                                  builder: (context, c) {
                                    return GridView.count(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 3.6,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      children: [
                                        _actionBtnModern(
                                          icon: Icons.save_outlined,
                                          text: 'GUARDAR LOCALMENTE',
                                          background: const Color(0xFF6C757D),
                                          border: const Color(0xFF495057),
                                          onPressed: _guardarEmbarqueLocalmente,
                                        ),
                                        _actionBtnModern(
                                          icon: Icons.cloud_upload_outlined,
                                          text: 'GUARDAR',
                                          background: const Color(0xFF1E3A8A),
                                          border: const Color(0xFF1D4ED8),
                                          onPressed: _guardarEmbarqueEnServidor,
                                        ),
                                        _actionBtnModern(
                                          icon: Icons.print_outlined,
                                          text: 'IMPRIMIR',
                                          background: const Color(0xFF0F766E),
                                          border: const Color(0xFF115E59),
                                          onPressed: () => _snack('Enviando a impresión (demo)', color: Colors.teal),
                                        ),
                                      ],
                                    );
                                  },
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
                                  child: _isConsultando
                                      ? const Center(child: CircularProgressIndicator())
                                      : _embarquesConsultados.isEmpty
                                          ? const Center(child: Text('No se encontraron embarques para la fecha seleccionada.'))
                                          : _buildTablaResultados(),
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
      ),
      isExpanded: true,
      items: items,
      onChanged: onChanged,
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
              style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets para la Pestaña de Consulta ---

  Widget _buildFiltrosConsulta() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  "${_fechaFiltro.day}/${_fechaFiltro.month}/${_fechaFiltro.year}",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_calendar_outlined, color: Color(0xFF1E3A8A)),
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _fechaFiltro,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null && picked != _fechaFiltro) {
                      setState(() {
                        _fechaFiltro = picked;
                      });
                    }
                  },
                ),
              ],
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.search, size: 18),
              label: const Text('BUSCAR'),
              onPressed: () => _consultarEmbarques(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTablaResultados() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Folio')),
            DataColumn(label: Text('Fecha')),
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('Usuario')),
            DataColumn(label: Text('Almacenista')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: _embarquesConsultados.map((embarque) {
            return DataRow(
              cells: [
                DataCell(Text(embarque.idfolioembarque.toString())),
                DataCell(Text(embarque.regtimestamp.split(' ').first)), // Mostrar solo la fecha
                DataCell(Text(embarque.nombre_cliente)),
                DataCell(Text(embarque.nombreusuario)),
                DataCell(Text(embarque.nombre_almacenista)),
                DataCell(
                  Icon(
                    embarque.esActivo ? Icons.check_circle : Icons.cancel,
                    color: embarque.esActivo ? Colors.green : Colors.red,
                  ),
                ),
                DataCell(Row(
                  children: [
                    IconButton(icon: const Icon(Icons.edit_outlined), color: Colors.blue, onPressed: () { /* TODO: Lógica de Editar */ }),
                    IconButton(icon: const Icon(Icons.delete_outline), color: Colors.red, onPressed: () { /* TODO: Lógica de Cancelar */ }),
                    IconButton(icon: const Icon(Icons.print_outlined), color: Colors.grey, onPressed: () { /* TODO: Lógica de Imprimir */ }),
                  ],
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// --------- Secciones visuales ---------

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Color a = const Color(0xFF0D1B2A);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: a,
          ),
          child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Embarques',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
        const CircleAvatar(
          radius: 18,
          child: Icon(Icons.person_outline),
        ),
        const SizedBox(width: 8),
        const Text('Hola Arturo', style: TextStyle(fontWeight: FontWeight.w600)),
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
    return Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
  }
}