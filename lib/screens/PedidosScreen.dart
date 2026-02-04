import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Para InternetAddress
import 'package:connectivity_plus/connectivity_plus.dart'; // Para Connectivity
import 'package:distribuidora/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:distribuidora/screens/nota_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:distribuidora/models/nota_model.dart';
import 'package:distribuidora/services/database_helper.dart';
import 'package:distribuidora/services/api_config.dart'; // Para ApiConfig
import 'package:http/http.dart' as http;

// --- Modelo para la lista completa de clientes (para autocompletado) ---
class Cliente {
  final int id;
  final String nombre;

  Cliente({required this.id, required this.nombre});

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: int.tryParse(map['idcliente'].toString()) ?? 0,
      nombre: map['nombrecliente'] ?? 'N/A',
    );
  }
}

// --- Modelo para la nueva vista de Clientes con Saldo ---
class ClienteConSaldo {
  final int id;
  final String nombre;

  ClienteConSaldo({required this.id, required this.nombre});

  factory ClienteConSaldo.fromMap(Map<String, dynamic> map) {
    return ClienteConSaldo(
      id: int.tryParse(map['idcliente'].toString()) ?? 0,
      nombre: map['nombrecliente'] ?? map['nombre_cliente'] ?? 'N/A',
    );
  }
}

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  PedidosScreenState createState() => PedidosScreenState();
}

class PedidosScreenState extends State<PedidosScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _historialTabController; // Sub-pestañas para el historial
  final dbHelper = DatabaseHelper.instance;

  // --- Estado para la lista completa de clientes ---
  List<Cliente> _allClients = [];

  // --- Estado para la pestaña de Notas de Venta (PRODUCTOS) ---
  bool _isLoadingNotas = true;
  List<Nota> _notas = [];
  List<ClienteConSaldo> _clientesConSaldo = [];
  List<ClienteConSaldo> _clientesCajas = []; // <<< Nueva lista para Cajas
  ClienteConSaldo? _selectedClient;
  DateTime? _selectedDateNotas;
  final TextEditingController _clientSearchControllerNotas = TextEditingController();
  // Resumen PRODUCTOS
  double _saldoAnteriorProductos = 0.0;
  double _pedidoHoyProductos = 0.0;
  double _totalCreditoProductos = 0.0;

  // --- Estado para la pestaña de Historial (CAJAS) ---
  bool _isLoadingHistorial = true;
  List<Nota> _todasLasNotas = [];
  Cliente? _selectedClientHistorial;
  DateTime? _selectedDateHistorial;
  final TextEditingController _clientSearchControllerHistorial = TextEditingController();
  // Resumen CAJAS
  double _cajasPendientes = 0.0;
  double _cajasEnEntregasHoy = 0.0;
  double _totalCajasEntregadas = 0.0;

  // --- Estado para la pestaña de HISTORIAL GENERAL ---
  bool _isLoadingHistorialGeneral = true;
  List<Nota> _notasHistorialGeneral = [];
  Cliente? _selectedClientHistorialGeneral;
  DateTime? _selectedDateHistorialGeneral;
  final TextEditingController _clientSearchControllerHistorialGeneral = TextEditingController();


  // --- Lógica Online/Offline ---
  Future<bool> _tieneInternet() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  void refreshAllData() {
    _refreshData();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _historialTabController = TabController(length: 2, vsync: this); // Sub-pestañas
    _fetchAllClients(); // Cargar la lista de todos los clientes
    _refreshData(); // Carga inicial
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _refreshData();
      }
    });
  }

  Future<void> _fetchAllClients() async {
    try {
      final isOnline = await _tieneInternet();
      if (!isOnline) return;

      final url = '${ApiConfig.baseUrl}api_clientes.php';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final List<dynamic> clientData = json.decode(response.body);
        if (mounted) {
          setState(() {
            _allClients = clientData.map((data) => Cliente.fromMap(data)).toList();
          });
        }
      } else {
        throw Exception('Error del servidor al cargar clientes: ${response.statusCode}');
      }
    } catch (e) {
      // No mostrar snackbar para esta carga en segundo plano, es para el autocompletado
      // print("Error al cargar la lista completa de clientes: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _historialTabController.dispose();
    _clientSearchControllerNotas.dispose();
    _clientSearchControllerHistorial.dispose();
    _clientSearchControllerHistorialGeneral.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final isOnline = await _tieneInternet();
    if (_tabController.index == 0) {
      isOnline ? _loadDataNotasFromServer() : _loadDataNotasFromDB();
    } else if (_tabController.index == 1) {
      isOnline ? _loadDataCajasFromServer() : _loadDataCajasFromDB();
    } else { // index == 2
      isOnline ? _loadDataHistorialFromServer() : _loadDataHistorialFromDB();
    }
  }

  // --- LÓGICA DE CARGA DE DATOS ---

  // -- Pestaña 1: Notas de Venta (PRODUCTOS) --
  Future<void> _loadDataNotasFromServer() async {
    if (mounted) setState(() => _isLoadingNotas = true);
    try {
      String url;
      String tipoProductoFilter = 'P'; // Siempre filtrar por 'P' para esta pestaña

      if (_selectedClient == null) {
        // Modo: Cargar clientes con saldo Y RESUMENES
        final clientNameFilter = _clientSearchControllerNotas.text.trim();
        
        var queryParams = <String, String>{
          'tipo_producto': tipoProductoFilter, // Añadir filtro de tipo_producto
        };
        if (_selectedDateNotas != null) {
          queryParams['fecha'] = DateFormat('yyyy-MM-dd').format(_selectedDateNotas!);
        }
        if (clientNameFilter.isNotEmpty) {
          queryParams['nombre_cliente'] = clientNameFilter;
        }
        
        url = '${ApiConfig.baseUrl}api_consulta_notas_v2.php?${Uri(queryParameters: queryParams).query}';
      } else {
        // Modo: Cargar notas de un cliente específico
        var queryParams = <String, String>{
          'idcliente': _selectedClient!.id.toString(),
          'tipo_producto': tipoProductoFilter, // Añadir filtro de tipo_producto
        };
        if (_selectedDateNotas != null) {
          queryParams['fecha'] = DateFormat('yyyy-MM-dd').format(_selectedDateNotas!);
        }
        url = '${ApiConfig.baseUrl}api_consulta_notas_v2.php?${Uri(queryParameters: queryParams).query}';
      }

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final responseData = decoded['response'];
          if (mounted) {
            setState(() {
              if (responseData['type'] == 'clientes') {
                _clientesConSaldo = (responseData['data'] as List).map((map) => ClienteConSaldo.fromMap(map)).toList();
                _notas = [];
                // Actualizar los resúmenes de PRODUCTOS
                if (responseData['resumen'] != null) {
                  _saldoAnteriorProductos = (responseData['resumen']['saldo_anterior'] as num?)?.toDouble() ?? 0.0;
                  _pedidoHoyProductos = (responseData['resumen']['pedido_hoy'] as num?)?.toDouble() ?? 0.0;
                  _totalCreditoProductos = (responseData['resumen']['total_credito'] as num?)?.toDouble() ?? 0.0;
                }
              } else { // 'notas'
                _notas = (responseData['data'] as List).map((map) => Nota.fromJson(map)).toList();
                _clientesConSaldo = [];
                
                // Intentar leer resumen si viene en la respuesta, si no, poner en cero
                if (responseData['resumen'] != null) {
                  _saldoAnteriorProductos = (responseData['resumen']['saldo_anterior'] as num?)?.toDouble() ?? 0.0;
                  _pedidoHoyProductos = (responseData['resumen']['pedido_hoy'] as num?)?.toDouble() ?? 0.0;
                  _totalCreditoProductos = (responseData['resumen']['total_credito'] as num?)?.toDouble() ?? 0.0;
                } else {
                  // Solo limpiar si no hay datos de resumen explícitos
                  _saldoAnteriorProductos = 0.0;
                  _pedidoHoyProductos = 0.0;
                  _totalCreditoProductos = 0.0;
                }
              }
            });
          }
        } else {
          throw Exception(decoded['error'] ?? 'Error desconocido de la API');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar notas: $e. Mostrando datos locales.'), backgroundColor: Colors.orange));
        _loadDataNotasFromDB(); // Fallback a datos locales
      }
    } finally {
      if (mounted) setState(() => _isLoadingNotas = false);
    }
  }

  Future<void> _loadDataNotasFromDB() async {
    if (mounted) setState(() => _isLoadingNotas = true);
    try {
      if (_selectedClient == null) {
        final clientMaps = await dbHelper.getClientesConSaldo();
        var clients = clientMaps.map((map) => ClienteConSaldo.fromMap(map)).toList();
        final clientNameFilter = _clientSearchControllerNotas.text.trim().toLowerCase();
        if (clientNameFilter.isNotEmpty) {
          clients = clients.where((c) => c.nombre.toLowerCase().contains(clientNameFilter)).toList();
        }
        if (mounted) setState(() { _clientesConSaldo = clients; _notas = []; });
      } else {
        final notaMaps = await dbHelper.getNotasForCliente(_selectedClient!.id);
        var notas = notaMaps.map((map) => Nota.fromMap(map)).toList();
        if (_selectedDateNotas != null) {
          notas = notas.where((n) => DateFormat('yyyy-MM-dd').format(DateTime.parse(n.regtimestamp)) == DateFormat('yyyy-MM-dd').format(_selectedDateNotas!)).toList();
        }
        if (mounted) setState(() { _notas = notas; _clientesConSaldo = []; });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al leer base de datos: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoadingNotas = false);
    }
  }

  // -- Pestaña 2: CAJAS --
  Future<void> _loadDataCajasFromServer() async {
    if (mounted) setState(() => _isLoadingHistorial = true);
    try {
      String url;
      String tipoProductoFilter = 'C'; 

      if (_selectedClientHistorial == null) {
        // Modo: Cargar clientes con saldo (de Cajas) Y RESUMENES
        final clientNameFilter = _clientSearchControllerHistorial.text.trim();
        
        var queryParams = <String, String>{
          'tipo_producto': tipoProductoFilter,
        };
        if (_selectedDateHistorial != null) {
          queryParams['fecha'] = DateFormat('yyyy-MM-dd').format(_selectedDateHistorial!);
        }
        if (clientNameFilter.isNotEmpty) {
          queryParams['nombre_cliente'] = clientNameFilter;
        }
        
        url = '${ApiConfig.baseUrl}api_consulta_notas_v2.php?${Uri(queryParameters: queryParams).query}';
      } else {
        // Modo: Cargar notas de un cliente específico
        var queryParams = <String, String>{
          'idcliente': _selectedClientHistorial!.id.toString(),
          'tipo_producto': tipoProductoFilter,
        };
        if (_selectedDateHistorial != null) {
          queryParams['fecha'] = DateFormat('yyyy-MM-dd').format(_selectedDateHistorial!);
        }
        url = '${ApiConfig.baseUrl}api_consulta_notas_v2.php?${Uri(queryParameters: queryParams).query}';
      }

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final responseData = decoded['response'];
          if (mounted) {
            setState(() {
              if (responseData['type'] == 'clientes') {
                _clientesCajas = (responseData['data'] as List).map((map) => ClienteConSaldo.fromMap(map)).toList();
                _todasLasNotas = [];
                
                // Resumen Cajas
                 if (responseData['resumen'] != null) {
                  _cajasPendientes = (responseData['resumen']['cajas_pendientes'] as num?)?.toDouble() ?? 0.0;
                  _cajasEnEntregasHoy = (responseData['resumen']['cajas_en_entregas_hoy'] as num?)?.toDouble() ?? 0.0;
                  _totalCajasEntregadas = (responseData['resumen']['total_cajas_entregadas'] as num?)?.toDouble() ?? 0.0;
                }
              } else { // 'notas'
                _todasLasNotas = (responseData['data'] as List).map((map) => Nota.fromJson(map)).toList();
                
                // Resumen Cajas
                 if (responseData['resumen'] != null) {
                  _cajasPendientes = (responseData['resumen']['cajas_pendientes'] as num?)?.toDouble() ?? 0.0;
                  _cajasEnEntregasHoy = (responseData['resumen']['cajas_en_entregas_hoy'] as num?)?.toDouble() ?? 0.0;
                  _totalCajasEntregadas = (responseData['resumen']['total_cajas_entregadas'] as num?)?.toDouble() ?? 0.0;
                }
              }
            });
          }
        } else {
          throw Exception(decoded['error'] ?? 'Error desconocido de la API');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar historial: $e. Mostrando datos locales.'), backgroundColor: Colors.orange));
        _loadDataCajasFromDB(); 
      }
    } finally {
      if (mounted) setState(() => _isLoadingHistorial = false);
    }
  }

  Future<void> _loadDataCajasFromDB() async {
    if (mounted) setState(() => _isLoadingHistorial = true);
    try {
      final notaMaps = await dbHelper.getNotasOffline(tipoProducto: 'C');
      var notas = notaMaps.map((map) => Nota.fromMap(map)).toList();

      if (_selectedClientHistorial == null) {
        // Modo: Lista de Clientes (Offline)
        final uniqueClients = <int, ClienteConSaldo>{};
        for (var n in notas) {
           // Solo agregar si tiene saldo o es relevante. 
           // Asumimos que si está en getNotasOffline('C') es relevante.
           if (!uniqueClients.containsKey(n.idcliente)) {
             uniqueClients[n.idcliente] = ClienteConSaldo(id: n.idcliente, nombre: n.nombreCliente);
           }
        }
        var clients = uniqueClients.values.toList();
        
        final clientNameFilter = _clientSearchControllerHistorial.text.trim().toLowerCase();
        if (clientNameFilter.isNotEmpty) {
          clients = clients.where((c) => c.nombre.toLowerCase().contains(clientNameFilter)).toList();
        }
        
        clients.sort((a, b) => a.nombre.compareTo(b.nombre));

        if (mounted) {
          setState(() {
            _clientesCajas = clients;
            _todasLasNotas = [];
            _cajasPendientes = 0.0;
            _cajasEnEntregasHoy = 0.0;
            _totalCajasEntregadas = 0.0;
          });
        }
      } else {
        // Modo: Notas de un Cliente (Offline)
        notas = notas.where((n) => n.idcliente == _selectedClientHistorial!.id).toList();

        if (_selectedDateHistorial != null) {
          notas = notas.where((n) => DateFormat('yyyy-MM-dd').format(DateTime.parse(n.regtimestamp)) == DateFormat('yyyy-MM-dd').format(_selectedDateHistorial!)).toList();
        }
        
        if (mounted) setState(() => _todasLasNotas = notas);
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al leer historial de la base de datos: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoadingHistorial = false);
    }
  }

  Future<void> _loadDataHistorialFromDB() async {
    if (mounted) setState(() => _isLoadingHistorialGeneral = true);
    try {
      final notaMaps = await dbHelper.getNotasOffline(); // Sin filtro de tipo_producto
      var notas = notaMaps.map((map) => Nota.fromMap(map)).toList();
      final clientNameFilter = _clientSearchControllerHistorialGeneral.text.trim().toLowerCase();
      if (clientNameFilter.isNotEmpty) {
        notas = notas.where((n) => n.nombreCliente.toLowerCase().contains(clientNameFilter)).toList();
      }
      if (_selectedDateHistorialGeneral != null) {
        notas = notas.where((n) => DateFormat('yyyy-MM-dd').format(DateTime.parse(n.regtimestamp)) == DateFormat('yyyy-MM-dd').format(_selectedDateHistorialGeneral!)).toList();
      }
      if (mounted) setState(() => _notasHistorialGeneral = notas);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al leer historial de la base de datos: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoadingHistorialGeneral = false);
    }
  }

  // --- Widgets de UI (sin cambios) ---
  InputDecoration _inputDeco({ required String label, required IconData icon, Widget? trailing }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: trailing,
      filled: true,
      fillColor: const Color(0xFFF6F7FB),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD8DFEA))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildFilterWidgets({
    required DateTime? selectedDate,
    required Function(DateTime?) onDateSelected,
    required TextEditingController clientSearchController,
    required VoidCallback onSearchPressed,
    required Iterable<Cliente> clientOptions,
    required Function(Cliente) onClientSelected,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Autocomplete<Cliente>(
              displayStringForOption: (Cliente option) => option.nombre,
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<Cliente>.empty();
                }
                return clientOptions.where((Cliente option) {
                  return option.nombre.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: onClientSelected,
              fieldViewBuilder: (BuildContext context, TextEditingController fieldController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                return TextFormField(
                  controller: fieldController,
                  focusNode: fieldFocusNode,
                  decoration: _inputDeco(
                    label: 'Buscar Cliente',
                    icon: Icons.person_search,
                    trailing: IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        fieldController.clear();
                        clientSearchController.clear();
                        onSearchPressed();
                      },
                    ),
                  ),
                  onFieldSubmitted: (_) => onSearchPressed(),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (picked != null) onDateSelected(picked);
                    },
                    child: InputDecorator(
                      decoration: _inputDeco(
                        label: 'Fecha',
                        icon: Icons.calendar_today,
                        trailing: selectedDate != null ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () => onDateSelected(null),
                        ) : null,
                      ),
                      child: Text(
                        selectedDate != null ? DateFormat('dd/MM/yyyy').format(selectedDate) : 'Todas las fechas',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('BUSCAR'),
                  onPressed: onSearchPressed,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null) return 'Fecha desconocida';
    try { return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(isoString)); } catch (e) { return isoString; }
  }

  String _formatNotaSubtitle(Nota nota, NumberFormat currencyFormat) {
    String subtitle = '';

    if (nota.tipoProducto == 'C') {
      // Formato para Cajas (Inventario)
      subtitle += 'Total Cajas: ${nota.totalCajas.toStringAsFixed(0)} | Pendientes: ${nota.saldoCajas.toStringAsFixed(0)} | Devueltas: ${nota.cajasDevueltas.toStringAsFixed(0)}';
    } else {
      // Formato Monetario Estándar
      subtitle += 'Total: ${currencyFormat.format(nota.total)} | Saldo: ${currencyFormat.format(nota.saldo)} | Pagado: ${currencyFormat.format(nota.montoPagadoAcumulado)}';
    }

    // Línea 2: Información específica del último pago
    if (nota.lastPaymentType != null) {
      if (nota.lastPaymentType == 'Caja') {
        subtitle += '\nÚltimo Movimiento: Devolución de Caja'; 
      } else {
        subtitle += '\nÚltimo Pago: ${nota.lastPaymentType}';
      }
    } else {
      subtitle += '\nSin movimientos registrados';
    }

    // Línea 3: Fecha de registro
    subtitle += '\n${_formatTimestamp(nota.regtimestamp)}';

    return subtitle;
  }

  // --- Widgets de Resumen ---
  Widget _buildResumenProductos() {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Resumen de Crédito (Productos)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(),
              _buildResumenRow('Saldo Anterior:', currencyFormat.format(_saldoAnteriorProductos)),
              _buildResumenRow('Pedido de Hoy:', currencyFormat.format(_pedidoHoyProductos)),
              const Divider(),
              _buildResumenRow('Total Crédito:', currencyFormat.format(_totalCreditoProductos), isTotal: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumenCajas() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Resumen de Cajas (Envases)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(),
              _buildResumenRow('Cajas Pendientes por Devolver:', _cajasPendientes.toStringAsFixed(0)),
              _buildResumenRow('Cajas en Entregas (Hoy):', _cajasEnEntregasHoy.toStringAsFixed(0)),
              const Divider(),
              _buildResumenRow('Total de Cajas Entregadas:', _totalCajasEntregadas.toStringAsFixed(0), isTotal: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumenRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: isTotal ? 18 : 15, fontWeight: isTotal ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const OfflineBanner(),
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.payment), SizedBox(width: 8), Text('PRODUCTOS')])),
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.local_shipping_outlined), SizedBox(width: 8), Text('CAJAS')])),
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history), SizedBox(width: 8), Text('HISTORIAL')])),
            ],
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.blueGrey,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3.0,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildNotasDeVentaView(),
              _buildHistorialView(), // Este es ahora Cajas
              _buildHistorialGeneralView(), // Nuevo historial general
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotasDeVentaView() {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EDF3),
      body: RefreshIndicator(
        onRefresh: () => _refreshData(),
        child: Column(
          children: [
            _buildFilterWidgets(
              selectedDate: _selectedDateNotas,
              onDateSelected: (date) { setState(() => _selectedDateNotas = date); }, // Solo actualizar estado
              clientSearchController: _clientSearchControllerNotas,
              onSearchPressed: () {
                // Al presionar buscar, ejecutamos la consulta con los filtros actuales
                _refreshData();
              },
              clientOptions: _allClients,
              onClientSelected: (Cliente cliente) {
                // Asignar el texto para que el usuario vea a quién seleccionó
                _clientSearchControllerNotas.text = cliente.nombre;
                setState(() {
                  _selectedClient = ClienteConSaldo(id: cliente.id, nombre: cliente.nombre);
                });
                // No refrescamos aquí, esperamos al botón BUSCAR
              },
            ),
            // Mostrar resumen solo si hay Cliente Y (No hay fecha O hubo movimiento ese día)
            if (_selectedClient != null && (_selectedDateNotas == null || _pedidoHoyProductos > 0)) _buildResumenProductos(),
            if (_selectedClient != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Card(
                  elevation: 2,
                  child: ListTile(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E3A8A)),
                      onPressed: () {
                        setState(() { _selectedClient = null; });
                        _refreshData();
                      },
                    ),
                    title: Text('Notas de: ${_selectedClient!.nombre}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16), overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
            Expanded(
              child: _isLoadingNotas
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedClient == null
                      ? _buildClientList()
                      : _notas.isEmpty
                          ? const Center(child: Text('Este cliente no tiene notas pendientes.'))
                          : _buildNotaslist(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientList() {
    if (_clientesConSaldo.isEmpty) {
      return const Center(child: Text('No hay clientes con notas pendientes de pago.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _clientesConSaldo.length,
      itemBuilder: (context, index) {
        final cliente = _clientesConSaldo[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFF1E3A8A), foregroundColor: Colors.white, child: Icon(Icons.person_outline)),
            title: Text(cliente.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.blueGrey),
            onTap: () { setState(() => _selectedClient = cliente); _refreshData(); },
          ),
        );
      },
    );
  }

  Widget _buildNotaslist() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: _notas.length,
      itemBuilder: (context, index) {
        final nota = _notas[index];
        final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
        final bool conSaldo = nota.saldo > 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: conSaldo ? Colors.orange.shade700 : Colors.green, foregroundColor: Colors.white, child: Text('#${nota.idnota}')),
            title: Text(nota.nombreCliente, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_formatNotaSubtitle(nota, currencyFormat)),
            isThreeLine: true,
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              final shouldRefresh = await Navigator.push(context, MaterialPageRoute(builder: (context) => NotaDetailScreen(nota: nota)));
              if (shouldRefresh == true) _refreshData();
            },
          ),
        );
      },
    );
  }

  Widget _buildHistorialView() {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EDF3),
      body: RefreshIndicator(
        onRefresh: () => _refreshData(), // Esto llamará a la lógica de refresh para la pestaña actual
        child: Column(
          children: [
            // Autocomplete para el historial
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Autocomplete<Cliente>(
                      displayStringForOption: (Cliente option) => option.nombre,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') return const Iterable<Cliente>.empty();
                        return _allClients.where((Cliente option) {
                          return option.nombre.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (Cliente cliente) {
                        _clientSearchControllerHistorial.text = cliente.nombre; // Mantener texto
                        setState(() => _selectedClientHistorial = cliente);
                        // Esperar al botón BUSCAR
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                         if (controller.text != _clientSearchControllerHistorial.text) {
                           controller.text = _clientSearchControllerHistorial.text;
                         }
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: _inputDeco(
                            label: 'Buscar Cliente en Cajas',
                            icon: Icons.person_search,
                            trailing: IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                controller.clear();
                                _clientSearchControllerHistorial.clear();
                                setState(() => _selectedClientHistorial = null);
                                _refreshData();
                              },
                            ),
                          ),
                          onFieldSubmitted: (_) => _refreshData(),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDateHistorial ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                              setState(() => _selectedDateHistorial = picked);
                            },
                            child: InputDecorator(
                              decoration: _inputDeco(
                                label: 'Fecha',
                                icon: Icons.calendar_today,
                                trailing: _selectedDateHistorial != null ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () { setState(() => _selectedDateHistorial = null); _refreshData(); },
                                ) : null,
                              ),
                              child: Text(
                                _selectedDateHistorial != null ? DateFormat('dd/MM/yyyy').format(_selectedDateHistorial!) : 'Todas las fechas',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('BUSCAR'),
                          onPressed: () {
                             _refreshData();
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Mostrar resumen solo si hay Cliente Y (No hay fecha O hubo movimiento de cajas ese día)
            if (_selectedClientHistorial != null && (_selectedDateHistorial == null || _cajasEnEntregasHoy > 0)) _buildResumenCajas(),
            if (_selectedClientHistorial != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Card(
                  elevation: 2,
                  child: ListTile(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E3A8A)),
                      onPressed: () {
                        setState(() => _selectedClientHistorial = null);
                        _refreshData();
                      },
                    ),
                    title: Text('Historial de Cajas de: ${_selectedClientHistorial!.nombre}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16), overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
            Expanded(
              child: _isLoadingHistorial
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedClientHistorial == null
                      ? _buildClientListCajas()
                      : _todasLasNotas.isEmpty
                          ? const Center(child: Text('No se encontraron notas de cajas.'))
                          : _buildHistorialList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientListCajas() {
    if (_clientesCajas.isEmpty) {
      return const Center(child: Text('No hay clientes con movimientos de cajas.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _clientesCajas.length,
      itemBuilder: (context, index) {
        final cliente = _clientesCajas[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFF1E3A8A), foregroundColor: Colors.white, child: Icon(Icons.inventory_2_outlined)),
            title: Text(cliente.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.blueGrey),
            onTap: () { 
              // Convertir ClienteConSaldo a Cliente (que es lo que espera _selectedClientHistorial)
              setState(() => _selectedClientHistorial = Cliente(id: cliente.id, nombre: cliente.nombre)); 
              _refreshData(); 
            },
          ),
        );
      },
    );
  }

  Widget _buildHistorialList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: _todasLasNotas.length,
      itemBuilder: (context, index) {
        final nota = _todasLasNotas[index];
        final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
        final bool conSaldo = nota.saldo > 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: conSaldo ? Colors.orange.shade700 : Colors.green, foregroundColor: Colors.white, child: Text('#${nota.idnota}')),
            title: Text(nota.nombreCliente, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_formatNotaSubtitle(nota, currencyFormat)),
            isThreeLine: true,
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => NotaDetailScreen(nota: nota)));
              _refreshData();
            },
          ),
        );
      },
    );
  }

  // --- NUEVAS FUNCIONES PARA HISTORIAL GENERAL ---

  Future<void> _loadDataHistorialFromServer() async {
    if (mounted) setState(() => _isLoadingHistorialGeneral = true);
    try {
      var queryParams = <String, String>{}; // Sin filtro de tipo_producto

      if (_selectedClientHistorialGeneral != null) {
        queryParams['idcliente'] = _selectedClientHistorialGeneral!.id.toString();
      } else {
        final clientNameFilter = _clientSearchControllerHistorialGeneral.text.trim();
        if (clientNameFilter.isNotEmpty) {
          queryParams['nombre_cliente'] = clientNameFilter;
        }
      }

      if (_selectedDateHistorialGeneral != null) {
        queryParams['fecha'] = DateFormat('yyyy-MM-dd').format(_selectedDateHistorialGeneral!);
      }

      final urlNotas = '${ApiConfig.baseUrl}api_todas_las_notas.php?${Uri(queryParameters: queryParams).query}';
      
      final responseNotas = await http.get(Uri.parse(urlNotas)).timeout(const Duration(seconds: 20));
      if (responseNotas.statusCode == 200) {
        final decodedNotas = json.decode(responseNotas.body);
        if (decodedNotas['success'] == true) {
          if (mounted) {
            setState(() {
              _notasHistorialGeneral = (decodedNotas['data'] as List).map((map) => Nota.fromJson(map)).toList();
            });
          }
        } else {
          throw Exception(decodedNotas['error'] ?? 'Error desconocido de la API');
        }
      } else {
        throw Exception('Error ${responseNotas.statusCode}: ${responseNotas.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar historial: $e.'), backgroundColor: Colors.orange));
      }
    } finally {
      if (mounted) setState(() => _isLoadingHistorialGeneral = false);
    }
  }

  Widget _buildHistorialGeneralView() {
    // Reutilizamos la misma lista que la pestaña de cajas, pero con los datos del historial general
    return Scaffold(
      backgroundColor: const Color(0xFFE9EDF3),
      body: RefreshIndicator(
        onRefresh: () => _refreshData(),
        child: Column(
          children: [
            // Filtros (se podrían simplificar o mantener si se quiere filtrar en ambas subpestañas a la vez)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Autocomplete<Cliente>(
                      displayStringForOption: (Cliente option) => option.nombre,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') return const Iterable<Cliente>.empty();
                        return _allClients.where((Cliente option) {
                          return option.nombre.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (Cliente cliente) {
                        _clientSearchControllerHistorialGeneral.clear();
                        setState(() => _selectedClientHistorialGeneral = cliente);
                        _refreshData();
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                         if (controller.text != _clientSearchControllerHistorialGeneral.text) {
                           controller.text = _clientSearchControllerHistorialGeneral.text;
                         }
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: _inputDeco(
                            label: 'Buscar Cliente en Historial',
                            icon: Icons.person_search,
                            trailing: IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                controller.clear();
                                _clientSearchControllerHistorialGeneral.clear();
                                setState(() => _selectedClientHistorialGeneral = null);
                                _refreshData();
                              },
                            ),
                          ),
                          onFieldSubmitted: (_) => _refreshData(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // --- INICIO DE SUB-PESTAÑAS ---
            TabBar(
              controller: _historialTabController,
              tabs: const [
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.payments_outlined), SizedBox(width: 8), Text('Monetario')])),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.local_shipping_outlined), SizedBox(width: 8), Text('Cajas')])),
              ],
               labelColor: Theme.of(context).primaryColor,
               unselectedLabelColor: Colors.blueGrey,
            ),

            Expanded(
              child: _isLoadingHistorialGeneral
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _historialTabController,
                      children: [
                        // Contenido de la sub-pestaña Monetario
                        _buildHistoryListFor(
                          _notasHistorialGeneral.where((n) => n.tipoProducto == 'P').toList()
                        ),
                        // Contenido de la sub-pestaña Cajas
                        _buildHistoryListFor(
                          _notasHistorialGeneral.where((n) => n.tipoProducto == 'C').toList()
                        ),
                      ],
                    ),
            ),
            // --- FIN DE SUB-PESTAÑAS ---
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryListFor(List<Nota> notas) {
    if (notas.isEmpty) {
      return const Center(child: Text('No se encontraron notas en esta categoría.'));
    }
     return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: notas.length,
      itemBuilder: (context, index) {
        final nota = notas[index];
        final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
        final bool conSaldo = nota.saldo > 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: conSaldo ? Colors.orange.shade700 : Colors.green, foregroundColor: Colors.white, child: Text('#${nota.idnota}')),
            title: Text(nota.nombreCliente, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_formatNotaSubtitle(nota, currencyFormat)),
            isThreeLine: true,
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => NotaDetailScreen(nota: nota)));
              _refreshData();
            },
          ),
        );
      },
    );
  }
}
