import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:distribuidora/services/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:distribuidora/screens/nota_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:distribuidora/models/nota_model.dart';

// --- Modelo para el Historial de Embarques ---
class HistorialItem {
  final int idDetalle;
  final int cantidad;
  final double precioUnitario;
  final String nombreProducto;
  final String nombreUnidad;
  final String nombreCliente;
  final String fechaEmbarque;

  HistorialItem({
    required this.idDetalle,
    required this.cantidad,
    required this.precioUnitario,
    required this.nombreProducto,
    required this.nombreUnidad,
    required this.nombreCliente,
    required this.fechaEmbarque,
  });

  factory HistorialItem.fromJson(Map<String, dynamic> json) {
    return HistorialItem(
      idDetalle: int.tryParse(json['id_detalle'].toString()) ?? 0,
      cantidad: int.tryParse(json['cantidad'].toString()) ?? 0,
      precioUnitario: double.tryParse(json['precio_unitario'].toString()) ?? 0.0,
      nombreProducto: json['nombreproducto'] ?? 'N/A',
      nombreUnidad: json['nombreunidad'] ?? 'N/A',
      nombreCliente: json['nombrecliente'] ?? 'N/A',
      fechaEmbarque: json['fecha_embarque'] ?? '',
    );
  }
}

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Estado para la pestaña de Notas de Venta
  bool _isLoadingNotas = true;
  List<Nota> _notasDelDia = [];
  DateTime _fechaFiltro = DateTime.now();

  // Estado para la pestaña de Historial
  bool _isLoadingHistorial = true;
  List<HistorialItem> _historialItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchNotasDelDia();
    _fetchHistorial();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- LÓGICA PARA NOTAS DE VENTA ---
  Future<void> _fetchNotasDelDia() async {
    setState(() { _isLoadingNotas = true; });
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_fechaFiltro);
      final url = Uri.parse('${ApiConfig.baseUrl}api_consulta_notas_v2.php?fecha=$formattedDate');
      final response = await http.get(url);
      if (mounted) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final data = decoded['data'] as List;
          setState(() {
            _notasDelDia = data.map((json) => Nota.fromJson(json)).toList();
          });
        } else {
          throw Exception(decoded['error'] ?? 'Error al cargar notas');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en Notas: $e')));
      }
    } finally {
      if (mounted) setState(() { _isLoadingNotas = false; });
    }
  }

  // --- LÓGICA PARA HISTORIAL DE EMBARQUES ---
  Future<void> _fetchHistorial() async {
    setState(() { _isLoadingHistorial = true; });
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}api_historial_embarques.php');
      final response = await http.get(url);
      if (mounted) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final data = decoded['data'] as List;
          setState(() {
            _historialItems = data.map((json) => HistorialItem.fromJson(json)).toList();
          });
        } else {
          throw Exception(decoded['error'] ?? 'Error al cargar historial');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en Historial: $e')));
      }
    } finally {
      if (mounted) setState(() { _isLoadingHistorial = false; });
    }
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null) return 'Fecha desconocida';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(isoString));
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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

  // --- UI para Pestaña 1: Notas de Venta ---
  Widget _buildNotasDeVentaView() {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EDF3),
      body: Column(
        children: [
          _buildFiltersNotas(),
          Expanded(
            child: _isLoadingNotas
                ? const Center(child: CircularProgressIndicator())
                : _notasDelDia.isEmpty
                    ? const Center(child: Text('No se encontraron notas de venta para esta fecha.'))
                    : _buildNotaslist(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersNotas() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Mostrando notas para:'),
              const SizedBox(width: 16),
              Text(DateFormat('dd/MM/yyyy').format(_fechaFiltro), style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.calendar_today, color: Color(0xFF1E3A8A)),
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: _fechaFiltro, firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (picked != null && picked != _fechaFiltro) {
                    setState(() => _fechaFiltro = picked);
                    _fetchNotasDelDia();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotaslist() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: _notasDelDia.length,
      itemBuilder: (context, index) {
        final nota = _notasDelDia[index];
        final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
        final bool conSaldo = nota.saldo > 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: conSaldo ? Colors.orange.shade700 : Colors.green, foregroundColor: Colors.white, child: Text('#${nota.idnota}')),
            title: Text(nota.nombreCliente, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('''Total: ${currencyFormat.format(nota.total)} | Saldo: ${currencyFormat.format(nota.saldo)}
${_formatTimestamp(nota.regtimestamp)}'''),
            isThreeLine: true,
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              final shouldRefresh = await Navigator.push(context, MaterialPageRoute(builder: (context) => NotaDetailScreen(nota: nota)));
              if (shouldRefresh == true) _fetchNotasDelDia();
            },
          ),
        );
      },
    );
  }

  // --- UI para Pestaña 2: Historial de Embarques ---
  Widget _buildHistorialView() {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EDF3),
      body: _isLoadingHistorial
          ? const Center(child: CircularProgressIndicator())
          : _historialItems.isEmpty
              ? const Center(child: Text('No se encontraron items en el historial de embarques.'))
              : _buildHistorialList(),
    );
  }

  Widget _buildHistorialList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: _historialItems.length,
      itemBuilder: (context, index) {
        final item = _historialItems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white, child: Text(item.cantidad.toString())),
            title: Text(item.nombreProducto, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('''Cliente: ${item.nombreCliente}
            Unidad: ${item.nombreUnidad} | Fecha: ${_formatTimestamp(item.fechaEmbarque)}'''),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
