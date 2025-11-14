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

class PedidosScreenState extends State<PedidosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final dbHelper = DatabaseHelper.instance;

  // --- Estado para la pestaña de Notas de Venta ---
  bool _isLoadingNotas = true;
  List<Nota> _notas = [];
  List<ClienteConSaldo> _clientesConSaldo = [];
  ClienteConSaldo? _selectedClient;
  DateTime _selectedDateNotas = DateTime.now();
  final TextEditingController _clientSearchControllerNotas = TextEditingController();

  // --- Estado para la pestaña de Historial ---
  bool _isLoadingHistorial = true;
  List<Nota> _todasLasNotas = [];
  DateTime _selectedDateHistorial = DateTime.now();
  final TextEditingController _clientSearchControllerHistorial = TextEditingController();

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
    _tabController = TabController(length: 2, vsync: this);
    _refreshData(); // Carga inicial
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _refreshData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clientSearchControllerNotas.dispose();
    _clientSearchControllerHistorial.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final isOnline = await _tieneInternet();
    if (_tabController.index == 0) {
      isOnline ? _loadDataNotasFromServer() : _loadDataNotasFromDB();
    } else {
      isOnline ? _loadHistorialFromServer() : _loadHistorialFromDB();
    }
  }

  // --- LÓGICA DE CARGA DE DATOS ---

  // -- Pestaña 1: Notas de Venta --
  Future<void> _loadDataNotasFromServer() async {
    if (mounted) setState(() => _isLoadingNotas = true);
    try {
      String url;
      if (_selectedClient == null) {
        // Modo: Cargar clientes con saldo
        final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDateNotas);
        final clientNameFilter = _clientSearchControllerNotas.text.trim();
        url = '${ApiConfig.baseUrl}api_consulta_notas_v2.php?fecha=$formattedDate&nombre_cliente=$clientNameFilter';
      } else {
        // Modo: Cargar notas de un cliente
        final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDateNotas);
        url = '${ApiConfig.baseUrl}api_consulta_notas_v2.php?idcliente=${_selectedClient!.id}&fecha=$formattedDate';
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
              } else { // 'notas'
                _notas = (responseData['data'] as List).map((map) => Nota.fromJson(map)).toList();
                _clientesConSaldo = [];
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
        notas = notas.where((n) => DateFormat('yyyy-MM-dd').format(DateTime.parse(n.regtimestamp)) == DateFormat('yyyy-MM-dd').format(_selectedDateNotas)).toList();
        if (mounted) setState(() { _notas = notas; _clientesConSaldo = []; });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al leer base de datos: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoadingNotas = false);
    }
  }

  // -- Pestaña 2: Historial --
  Future<void> _loadHistorialFromServer() async {
    if (mounted) setState(() => _isLoadingHistorial = true);
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDateHistorial);
      final clientNameFilter = _clientSearchControllerHistorial.text.trim();
      final url = '${ApiConfig.baseUrl}api_todas_las_notas.php?fecha=$formattedDate&nombre_cliente=$clientNameFilter';
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          if (mounted) {
            setState(() {
              _todasLasNotas = (decoded['data'] as List).map((map) => Nota.fromJson(map)).toList();
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
        _loadHistorialFromDB(); // Fallback a datos locales
      }
    } finally {
      if (mounted) setState(() => _isLoadingHistorial = false);
    }
  }

  Future<void> _loadHistorialFromDB() async {
    if (mounted) setState(() => _isLoadingHistorial = true);
    try {
      final notaMaps = await dbHelper.getNotasOffline();
      var notas = notaMaps.map((map) => Nota.fromMap(map)).toList();
      final clientNameFilter = _clientSearchControllerHistorial.text.trim().toLowerCase();
      if (clientNameFilter.isNotEmpty) {
        notas = notas.where((n) => n.nombreCliente.toLowerCase().contains(clientNameFilter)).toList();
      }
      notas = notas.where((n) => DateFormat('yyyy-MM-dd').format(DateTime.parse(n.regtimestamp)) == DateFormat('yyyy-MM-dd').format(_selectedDateHistorial)).toList();
      if (mounted) setState(() => _todasLasNotas = notas);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al leer historial de la base de datos: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoadingHistorial = false);
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

  Widget _buildFilterWidgets({ required DateTime selectedDate, required Function(DateTime) onDateSelected, required TextEditingController clientSearchController, required VoidCallback onSearchPressed }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: clientSearchController,
              decoration: _inputDeco(
                label: 'Buscar Cliente',
                icon: Icons.person_search,
                trailing: IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () { clientSearchController.clear(); onSearchPressed(); },
                ),
              ),
              onFieldSubmitted: (_) => onSearchPressed(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (picked != null && picked != selectedDate) onDateSelected(picked);
                    },
                    child: InputDecorator(
                      decoration: _inputDeco(label: 'Seleccionar Fecha', icon: Icons.calendar_today),
                      child: Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: const TextStyle(fontSize: 16)),
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
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.payment), SizedBox(width: 8), Text('Notas de Venta')])),
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history), SizedBox(width: 8), Text('Historial')])),
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
              _buildHistorialView(),
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
              onDateSelected: (date) { setState(() => _selectedDateNotas = date); _refreshData(); },
              clientSearchController: _clientSearchControllerNotas,
              onSearchPressed: _refreshData,
            ),
            if (_selectedClient != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Card(
                  elevation: 2,
                  child: ListTile(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E3A8A)),
                      onPressed: () { setState(() => _selectedClient = null); _refreshData(); },
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
            subtitle: Text('''Total: ${currencyFormat.format(nota.total)} | Saldo: ${currencyFormat.format(nota.saldo)} | Pagado: ${currencyFormat.format(nota.montoPagadoAcumulado)}
${_formatTimestamp(nota.regtimestamp)}'''),
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
        onRefresh: () => _refreshData(),
        child: Column(
          children: [
            _buildFilterWidgets(
              selectedDate: _selectedDateHistorial,
              onDateSelected: (date) { setState(() => _selectedDateHistorial = date); _refreshData(); },
              clientSearchController: _clientSearchControllerHistorial,
              onSearchPressed: _refreshData,
            ),
            Expanded(
              child: _isLoadingHistorial
                  ? const Center(child: CircularProgressIndicator())
                  : _todasLasNotas.isEmpty
                      ? const Center(child: Text('No se encontraron notas en el historial.'))
                      : _buildHistorialList(),
            ),
          ],
        ),
      ),
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
            subtitle: Text('''Total: ${currencyFormat.format(nota.total)} | Saldo: ${currencyFormat.format(nota.saldo)} | Pagado: ${currencyFormat.format(nota.montoPagadoAcumulado)}
${_formatTimestamp(nota.regtimestamp)}'''),
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
