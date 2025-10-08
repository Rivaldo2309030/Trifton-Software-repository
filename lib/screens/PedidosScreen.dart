import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'embarque_screen.dart'; // Reutilizamos el modelo de EmbarqueConsulta

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key, pedidos}); // el parámetro pedidos ya no se usa

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  bool _isLoading = true;
  List<EmbarqueConsulta> _embarquesPendientes = [];
  DateTime _fechaFiltro = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchEmbarquesPendientes();
  }

  Future<void> _fetchEmbarquesPendientes() async {
    setState(() { _isLoading = true; });

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_fechaFiltro);
      const String baseUrl = 'https://mediumslateblue-okapi-112468.hostingersite.com/APIS_RIVALDO/';
      final url = Uri.parse('${baseUrl}api_consulta_embarques.php?fecha=$formattedDate');
      
      final response = await http.get(url);

      if (mounted) {
        if (response.statusCode == 200) {
          final Map<String, dynamic> decoded = json.decode(response.body);
          if (decoded['success'] == true) {
            final List<dynamic> data = decoded['data'];
            setState(() {
              _embarquesPendientes = data.map((json) => EmbarqueConsulta.fromJson(json)).toList();
            });
          } else {
            throw Exception(decoded['error'] ?? 'Error desconocido del servidor');
          }
        } else {
          throw Exception('Error de conexión: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar embarques: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null) return 'Fecha desconocida';
    try {
      final DateTime date = DateTime.parse(isoString);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EDF3),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _embarquesPendientes.isEmpty
                    ? const Center(child: Text('No se encontraron solicitudes de embarque para esta fecha.'))
                    : _buildEmbarquesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Mostrando solicitudes para:', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 16),
              Text(
                DateFormat('dd/MM/yyyy').format(_fechaFiltro),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today, color: Color(0xFF1E3A8A)),
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
                    _fetchEmbarquesPendientes();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmbarquesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _embarquesPendientes.length,
      itemBuilder: (context, index) {
        final embarque = _embarquesPendientes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(child: Text(embarque.idfolioembarque.toString())),
            title: Text('Cliente: ${embarque.nombre_cliente}'),
            subtitle: Text('Usuario: ${embarque.nombreusuario}\nFecha: ${_formatTimestamp(embarque.regtimestamp)}'),
            isThreeLine: true,
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Navegar a la pantalla de detalle del pedido para procesar la entrega y el cobro.
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Procesando embarque #${embarque.idfolioembarque}')),
              );
            },
          ),
        );
      },
    );
  }
}