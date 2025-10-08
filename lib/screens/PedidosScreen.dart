import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'embarque_screen.dart'; // Reutilizamos el modelo de Cliente

// Modelo para representar un item del historial de ventas
class VentaHistorial {
  final int idDetalle;
  final double cantidad;
  final double precioUnitario;
  final String timestamp;
  final String nombreProducto;
  final String nombreUnidad;
  final String nombreCliente;

  VentaHistorial({
    required this.idDetalle,
    required this.cantidad,
    required this.precioUnitario,
    required this.timestamp,
    required this.nombreProducto,
    required this.nombreUnidad,
    required this.nombreCliente,
  });

  factory VentaHistorial.fromJson(Map<String, dynamic> json) {
    return VentaHistorial(
      idDetalle: int.tryParse(json['iddetalle'].toString()) ?? 0,
      cantidad: double.tryParse(json['cantidad'].toString()) ?? 0.0,
      precioUnitario: double.tryParse(json['preciounitario'].toString()) ?? 0.0,
      timestamp: json['regtimestamp'] ?? '',
      nombreProducto: json['nombreproducto'] ?? 'N/A',
      nombreUnidad: json['nombreunidad'] ?? 'N/A',
      nombreCliente: json['nombrecliente'] ?? 'N/A',
    );
  }
}

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key, pedidos});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  bool _isLoading = false;
  List<VentaHistorial> _ventas = [];
  List<Cliente> _clientes = []; // Para el filtro

  // Controladores de filtros
  int? _selectedClientId;
  final TextEditingController _productoSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchClientes();
    _fetchVentas(); // Carga inicial sin filtros
  }

  @override
  void dispose() {
    _productoSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchClientes() async {
    // Reutilizamos la API de clientes que ya existe
    const String url = 'https://mediumslateblue-okapi-112468.hostingersite.com/APIS_RIVALDO/api_clientes.php';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _clientes = data.map((json) => Cliente.fromJson(json)).toList();
          });
        }
      }
    } catch (e) {
      // Manejar error silenciosamente, el filtro simplemente no mostrará opciones
      print("Error cargando clientes para filtro: $e");
    }
  }

  Future<void> _fetchVentas() async {
    setState(() { _isLoading = true; });

    try {
      String url = 'https://mediumslateblue-okapi-112468.hostingersite.com/APIS_RIVALDO/api_consulta_pedidos.php';
      final Map<String, String> queryParams = {};

      if (_selectedClientId != null) {
        queryParams['idcliente'] = _selectedClientId.toString();
      }
      if (_productoSearchCtrl.text.isNotEmpty) {
        queryParams['producto'] = _productoSearchCtrl.text;
      }

      if (queryParams.isNotEmpty) {
        final uri = Uri.parse(url).replace(queryParameters: queryParams);
        url = uri.toString();
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final List<dynamic> data = decoded['data'];
          if (mounted) {
            setState(() {
              _ventas = data.map((json) => VentaHistorial.fromJson(json)).toList();
            });
          }
        } else {
          throw Exception(decoded['error'] ?? 'Error desconocido del servidor');
        }
      } else {
        throw Exception('Error de conexión: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar el historial: $e'), backgroundColor: Colors.red),
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
      backgroundColor: const Color(0xFFE9EDF3),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFilters(),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _ventas.isEmpty
                      ? const Center(child: Text('No se encontraron registros con esos filtros.'))
                      : _buildVentasList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Filtro de Clientes
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int>(
                value: _selectedClientId,
                decoration: const InputDecoration(labelText: 'Cliente', border: OutlineInputBorder()),
                items: _clientes.map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.nombre))).toList(),
                onChanged: (v) => setState(() => _selectedClientId = v),
              ),
            ),
            const SizedBox(width: 16),
            // Filtro de Producto
            Expanded(
              flex: 2,
              child: TextField(
                controller: _productoSearchCtrl,
                decoration: const InputDecoration(labelText: 'Buscar por Producto', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 16),
            // Botones
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar'),
                    onPressed: _fetchVentas,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    child: const Text('Limpiar'),
                    onPressed: () {
                      setState(() {
                        _selectedClientId = null;
                        _productoSearchCtrl.clear();
                      });
                      _fetchVentas();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVentasList() {
    return ListView.builder(
      itemCount: _ventas.length,
      itemBuilder: (context, index) {
        final venta = _ventas[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(child: Text(venta.cantidad.toStringAsFixed(0))),
            title: Text(venta.nombreProducto),
            subtitle: Text('Cliente: ${venta.nombreCliente} \nUnidad: ${venta.nombreUnidad}'),
            trailing: Text(
              '\$${(venta.cantidad * venta.precioUnitario).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
            ),
          ),
        );
      },
    );
  }
}