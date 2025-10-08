import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'embarque_screen.dart'; // Reutilizamos EmbarqueConsulta

// Modelo para los productos dentro del detalle
class DetalleProducto {
  final int idDetalle;
  final int idProducto;
  final String nombreProducto;
  final String nombreUnidad;
  final double cantidad;
  final double precioUnitario;

  DetalleProducto({
    required this.idDetalle,
    required this.idProducto,
    required this.nombreProducto,
    required this.nombreUnidad,
    required this.cantidad,
    required this.precioUnitario,
  });

  factory DetalleProducto.fromJson(Map<String, dynamic> json) {
    return DetalleProducto(
      idDetalle: int.tryParse(json['iddetalle'].toString()) ?? 0,
      idProducto: int.tryParse(json['idproducto'].toString()) ?? 0,
      nombreProducto: json['nombreproducto'] ?? 'N/A',
      nombreUnidad: json['nombreunidad'] ?? 'N/A',
      cantidad: double.tryParse(json['cantidad'].toString()) ?? 0.0,
      precioUnitario: double.tryParse(json['preciounitario'].toString()) ?? 0.0,
    );
  }
}

class PedidoDetailScreen extends StatefulWidget {
  final EmbarqueConsulta embarqueHeader;

  const PedidoDetailScreen({super.key, required this.embarqueHeader});

  @override
  State<PedidoDetailScreen> createState() => _PedidoDetailScreenState();
}

class _PedidoDetailScreenState extends State<PedidoDetailScreen> {
  bool _isLoading = true;
  List<DetalleProducto> _detalles = [];

  @override
  void initState() {
    super.initState();
    _fetchDetallesEmbarque();
  }

  Future<void> _fetchDetallesEmbarque() async {
    setState(() { _isLoading = true; });
    try {
      final id = widget.embarqueHeader.idfolioembarque;
      const String baseUrl = 'https://mediumslateblue-okapi-112468.hostingersite.com/APIS_RIVALDO/';
      final url = Uri.parse('${baseUrl}api_embarque_detalle.php?id=$id');

      final response = await http.get(url);

      if (mounted) {
        if (response.statusCode == 200) {
          final Map<String, dynamic> decoded = json.decode(response.body);
          if (decoded['success'] == true) {
            final List<dynamic> data = decoded['data'];
            setState(() {
              _detalles = data.map((json) => DetalleProducto.fromJson(json)).toList();
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
          SnackBar(content: Text('Error al cargar detalles: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Procesar Entrega #${widget.embarqueHeader.idfolioembarque}'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const Divider(thickness: 2, height: 2),
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('Productos Solicitados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(child: _buildDetailsList()),
              ],
            ),
      bottomNavigationBar: _buildConfirmButton(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Cliente: ${widget.embarqueHeader.nombre_cliente}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Usuario que solicitó: ${widget.embarqueHeader.nombreusuario}'),
          Text('Fecha de Solicitud: ${widget.embarqueHeader.regtimestamp}'),
        ],
      ),
    );
  }

  Widget _buildDetailsList() {
    if (_detalles.isEmpty) {
      return const Center(child: Text('No se encontraron detalles para este embarque.'));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _detalles.length,
      itemBuilder: (context, index) {
        final producto = _detalles[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              child: Text(producto.cantidad.toStringAsFixed(0)),
            ),
            title: Text(producto.nombreProducto),
            subtitle: Text(producto.nombreUnidad),
            trailing: Text(
              '\$${producto.precioUnitario.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfirmButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Confirmar Entrega y Generar Nota'),
        onPressed: () {
          // TODO: Lógica para generar la nota y el cobro
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}