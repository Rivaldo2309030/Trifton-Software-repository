import 'dart:convert';
import 'package:distribuidora/services/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:distribuidora/models/nota_model.dart';
import 'package:distribuidora/screens/PedidosScreen.dart';

// --- Modelo para los productos dentro del detalle de la nota ---
class NotaDetalle {
  final int id;
  final int cantidad;
  final double precio;
  final double total;
  final String nombreProducto;
  final String nombreUnidad;

  NotaDetalle({
    required this.id,
    required this.cantidad,
    required this.precio,
    required this.total,
    required this.nombreProducto,
    required this.nombreUnidad,
  });

  factory NotaDetalle.fromJson(Map<String, dynamic> json) {
    return NotaDetalle(
      id: int.tryParse(json['id'].toString()) ?? 0,
      cantidad: int.tryParse(json['cantidad'].toString()) ?? 0,
      precio: double.tryParse(json['precio'].toString()) ?? 0.0,
      total: double.tryParse(json['total'].toString()) ?? 0.0,
      nombreProducto: json['nombreproducto'] ?? 'N/A',
      nombreUnidad: json['nombreunidad'] ?? 'N/A',
    );
  }
}

class NotaDetailScreen extends StatefulWidget {
  final Nota nota;

  const NotaDetailScreen({super.key, required this.nota});

  @override
  State<NotaDetailScreen> createState() => _NotaDetailScreenState();
}

class _NotaDetailScreenState extends State<NotaDetailScreen> {
  // Estado de la UI
  bool _isLoading = true;
  bool _isPaying = false;
  bool _hasDataChanged = false; // Flag para notificar a la pantalla anterior

  // Datos
  List<NotaDetalle> _detalles = [];
  late double _saldoActual;

  // Formulario de Pago
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  String _tipoPago = 'Efectivo';

  @override
  void initState() {
    super.initState();
    _saldoActual = widget.nota.saldo;
    _fetchDetallesNota();
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetallesNota() async {
    setState(() { _isLoading = true; });
    try {
      final id = widget.nota.idnota;
      final url = Uri.parse('${ApiConfig.baseUrl}api_nota_detalle.php?idnota=$id');
      final response = await http.get(url);

      if (mounted) {
        if (response.statusCode == 200) {
          final Map<String, dynamic> decoded = json.decode(response.body);
          if (decoded['success'] == true) {
            final List<dynamic> data = decoded['data'];
            setState(() {
              _detalles = data.map((json) => NotaDetalle.fromJson(json)).toList();
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
          SnackBar(content: Text('Error al cargar detalles de la nota: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _registrarPago() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isPaying = true; });

    try {
      final payload = {
        'idnota': widget.nota.idnota,
        'monto': double.parse(_montoController.text),
        'tipopago': _tipoPago,
      };

      final url = Uri.parse('${ApiConfig.baseUrl}api_registrar_pago.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(payload),
      );

      if (mounted) {
        final decoded = json.decode(response.body);
        if (response.statusCode == 200 && decoded['success'] == true) {
          final nuevoSaldoRecibido = (decoded['nuevo_saldo'] as num).toDouble();
          setState(() {
            _saldoActual = nuevoSaldoRecibido;
            _hasDataChanged = true; // Marcamos que los datos cambiaron
          });
          _montoController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Pago registrado. Nuevo saldo: $nuevoSaldoRecibido'), backgroundColor: Colors.green),
          );
        } else {
          throw Exception(decoded['error'] ?? 'Error desconocido al registrar el pago');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al registrar el pago: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isPaying = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasDataChanged);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
        title: Text('Detalle de Nota #${widget.nota.idnota}'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const Divider(thickness: 1, height: 1),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Text('Productos en la Nota', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(child: _buildDetailsList()),
                if (_saldoActual > 0) _buildPaymentForm(),
              ],
            ),
    ));
  }

  Widget _buildHeader() {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.nota.nombreCliente, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total de la Nota:', style: TextStyle(fontSize: 16)),
                  Text(currencyFormat.format(widget.nota.total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Saldo Pendiente:', style: TextStyle(fontSize: 16, color: Colors.orange.shade800)),
                  Text(currencyFormat.format(_saldoActual), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsList() {
    if (_detalles.isEmpty) {
      return const Center(child: Text('No se encontraron productos para esta nota.'));
    }
    
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _detalles.length,
      itemBuilder: (context, index) {
        final producto = _detalles[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              child: Text(producto.cantidad.toString()),
            ),
            title: Text(producto.nombreProducto),
            subtitle: Text(producto.nombreUnidad),
            trailing: Text(currencyFormat.format(producto.total)),
          ),
        );
      },
    );
  }

  Widget _buildPaymentForm() {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Registrar un Pago', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _montoController,
                decoration: const InputDecoration(
                  labelText: 'Monto a Pagar',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingrese un monto';
                  }
                  final monto = double.tryParse(value);
                  if (monto == null) {
                    return 'Ingrese un número válido';
                  }
                  if (monto <= 0) {
                    return 'El monto debe ser mayor a cero';
                  }
                  if (monto > _saldoActual) {
                    return 'El monto no puede ser mayor al saldo pendiente';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _tipoPago,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Pago',
                  border: OutlineInputBorder(),
                ),
                items: ['Efectivo', 'Transferencia'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _tipoPago = newValue!;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isPaying ? null : _registrarPago,
                icon: _isPaying ? const SizedBox.shrink() : const Icon(Icons.check_circle),
                label: _isPaying 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Registrar Pago'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}