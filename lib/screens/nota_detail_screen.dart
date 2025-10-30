import 'dart:convert';
import 'dart:io'; // Import for SocketException
import 'dart:async'; // Import for TimeoutException
import 'package:distribuidora/services/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:distribuidora/models/nota_model.dart';
import 'package:distribuidora/screens/print_preview_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Import for connectivity_plus
import 'package:distribuidora/models/offline_note_model.dart';
import 'package:distribuidora/services/database_helper.dart';


// --- Modelo para los productos dentro del detalle de la nota (ahora desde embarque_detalle) ---
class NotaDetalle {
  final int iddetalle; // ID de embarque_detalle
  final double cantidad;
  final double precio;
  final double total;
  int idestatus; // El estatus es mutable
  final String nombreProducto;
  final String nombreUnidad;

  NotaDetalle({
    required this.iddetalle,
    required this.cantidad,
    required this.precio,
    required this.total,
    required this.idestatus,
    required this.nombreProducto,
    required this.nombreUnidad,
  });

  factory NotaDetalle.fromJson(Map<String, dynamic> json) {
    return NotaDetalle(
      iddetalle: int.tryParse(json['iddetalle'].toString()) ?? 0,
      cantidad: double.tryParse(json['cantidad'].toString()) ?? 0.0,
      precio: double.tryParse(json['precio'].toString()) ?? 0.0,
      total: double.tryParse(json['total'].toString()) ?? 0.0,
      idestatus: int.tryParse(json['idestatus'].toString()) ?? 0,
      nombreProducto: json['nombreproducto'] ?? 'N/A',
      nombreUnidad: json['nombreunidad'] ?? 'N/A',
    );
  }
}

// Modelo de Almacen (copiado para ser auto-contenido)
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
}

// Modelo para la lista de Estatus
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
  late Nota _notaActual; // Para poder modificar sus datos

  // Estado para el combo de Almacén
  List<Almacen> _almacenes = [];
  int? _selectedAlmacenId;
  bool _isUpdatingAlmacen = false;

  // Estado para la lista de Estatus
  List<Estatus> _estatusList = [];

  // Formulario de Pago
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  String _tipoPago = 'Efectivo';

  // --- Nuevos estados para la impresión ---
  String _nombreVendedor = '';
  // Las variables para el último pago se obtendrán directamente de la API antes de imprimir.

  @override
  void initState() {
    super.initState();
    _notaActual = widget.nota;
    _saldoActual = widget.nota.saldo;
    _selectedAlmacenId = widget.nota.idalmacen;
    
    // _loadLastPaymentInfo(); // Eliminado
    _fetchInitialData();
  }

  // La función _loadLastPaymentInfo ha sido eliminada.

  Future<void> _fetchInitialData() async {
    setState(() { _isLoading = true; });
    // Ejecutar todas las llamadas de red concurrentemente
    await Future.wait([
      _fetchDetallesNota(),
      _fetchAlmacenes(),
      _fetchEstatusList(),
    ]);
    if (mounted) {
      setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _fetchEstatusList() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {

    }

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}api_estatus_movimiento.php')).timeout(const Duration(seconds: 15));
      if (mounted && response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final List<dynamic> data = decoded['data'];
          setState(() {
            _estatusList = data.map((json) => Estatus.fromJson(json)).toList();
          });
        }
      }
    } on SocketException {
      if (mounted) {
        // _showConnectivitySnackBar('No se pudo conectar al servidor para cargar estatus. Verifica tu conexión a internet.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar la lista de estatus: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fetchAlmacenes() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      // _showConnectivitySnackBar('No hay conexión a internet. No se pudo cargar la lista de almacenes.');
      return;
    }

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}api_almacenes.php')).timeout(const Duration(seconds: 15));
      if (mounted && response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _almacenes = data.map((item) => Almacen.fromJson(item)).toList();
        });
      }
    } on SocketException {
      if (mounted) {
        // _showConnectivitySnackBar('No se pudo conectar al servidor para cargar almacenes. Verifica tu conexión a internet.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar la lista de almacenes: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _actualizarAlmacen(int? nuevoAlmacenId) async {
    if (nuevoAlmacenId == null) return;

    setState(() {
      _isUpdatingAlmacen = true;
    });

    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      // _showConnectivitySnackBar('No hay conexión a internet. No se pudo actualizar el almacén.');
      if (mounted) {
        setState(() {
          _isUpdatingAlmacen = false;
        });
      }
      return;
    }

    try {
      final payload = {
        'idnota': widget.nota.idnota,
        'idalmacen': nuevoAlmacenId,
      };
      final url = Uri.parse('${ApiConfig.baseUrl}api_actualizar_almacen_nota.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (mounted) {
        final decoded = json.decode(response.body);
        if (response.statusCode == 200 && decoded['success'] == true) {
          setState(() {
            _selectedAlmacenId = nuevoAlmacenId;
            _hasDataChanged = true;
            // Actualizamos el objeto local de la nota para consistencia
            final nombreNuevoAlmacen = _almacenes.firstWhere((a) => a.id == nuevoAlmacenId, orElse: () => Almacen(id: 0, nombre: 'N/A')).nombre;
            _notaActual = Nota(
              idnota: _notaActual.idnota,
              total: _notaActual.total,
              saldo: _notaActual.saldo,
              regtimestamp: _notaActual.regtimestamp,
              nombreCliente: _notaActual.nombreCliente,
              idalmacen: nuevoAlmacenId,
              nombreAlmacenSalida: nombreNuevoAlmacen,
              nombreAlmacenOrigen: _notaActual.nombreAlmacenOrigen,
              montoPagadoAcumulado: _notaActual.montoPagadoAcumulado,
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Almacén actualizado.'), backgroundColor: Colors.green),
          );
        } else {
          throw Exception(decoded['error'] ?? 'Error desconocido');
        }
      }
    } on SocketException {
      if (mounted) {
        // _showConnectivitySnackBar('No se pudo conectar al servidor para actualizar el almacén. Verifica tu conexión a internet.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al actualizar el almacén: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAlmacen = false;
        });
      }
    }
  }

  Future<void> _fetchDetallesNota() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      // _showConnectivitySnackBar('No hay conexión a internet. Cargando datos locales si existen.');
      await _loadDetallesFromOffline();
      return;
    }

    try {
      final id = _notaActual.idnota;
      final url = Uri.parse('${ApiConfig.baseUrl}api_nota_detalle.php?idnota=$id');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (mounted) {
        if (response.statusCode == 200) {
          final Map<String, dynamic> decoded = json.decode(response.body);
          if (decoded['success'] == true) {
            final Map<String, dynamic> data = decoded['data'];
            final List<dynamic> detallesData = data['detalles'];
            final String vendedorNombre = data['vendedor']?['nombre'] ?? 'No asignado';

            setState(() {
              _detalles = detallesData.map((json) => NotaDetalle.fromJson(json)).toList();
              _nombreVendedor = vendedorNombre;
            });
            // Sincronizar detalles y pagos en segundo plano
            await _saveDetallesToOffline(_detalles);
            await _syncPagosForNota(id); // <-- NUEVO: Sincronizar pagos

          } else {
            throw Exception(decoded['error'] ?? 'Error desconocido del servidor');
          }
        } else {
          throw Exception('Error de conexión: ${response.statusCode}');
        }
      }
    } on SocketException {
      if (mounted) {
        // _showConnectivitySnackBar('Error de conexión. Cargando datos locales.');
        await _loadDetallesFromOffline();
      }
    } on TimeoutException {
      if (mounted) {
        // _showConnectivitySnackBar('La conexión es lenta. Cargando datos locales.');
        await _loadDetallesFromOffline();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar detalles: $e'), backgroundColor: Colors.red),
        );
        await _loadDetallesFromOffline();
      }
    }
  }

  Future<void> _syncPagosForNota(int idnota) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}api_pagos_por_nota.php?idnota=$idnota');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final List<dynamic> pagosData = decoded['data'];
          final dbHelper = DatabaseHelper.instance;
          await dbHelper.insertPagosOffline(pagosData.cast<Map<String, dynamic>>());
          print('Pagos para la nota #$idnota sincronizados localmente.');
        }
      }
    } catch (e) {
      // Falla silenciosamente. Si no se pueden sincronizar los pagos, no es un error crítico.
      print('Error al sincronizar pagos para la nota #$idnota: $e');
    }
  }

    Future<void> _saveDetallesToOffline(List<NotaDetalle> detalles) async {
      final dbHelper = DatabaseHelper.instance;
      // Clear existing details for this note before saving new ones
      await (await dbHelper.database)?.delete(
        'nota_detalle_offline',
        where: 'idnota_fk = ?',
        whereArgs: [widget.nota.idnota],
      );

      final List<Map<String, dynamic>> detallesToSave = detalles.map((d) => NotaDetalleOffline.fromNotaDetalle(d, widget.nota.idnota).toMap()).toList();
      await dbHelper.insertNotaDetallesOffline(detallesToSave);
    }

    Future<void> _loadDetallesFromOffline() async {
      final dbHelper = DatabaseHelper.instance;
      final List<Map<String, dynamic>> detallesMaps = await dbHelper.getNotaDetallesOffline(widget.nota.idnota);
      final List<NotaDetalle> loadedDetalles = [];

      for (var detalleMap in detallesMaps) {
        loadedDetalles.add(NotaDetalle(
          iddetalle: detalleMap['iddetalle'],
          cantidad: detalleMap['cantidad'],
          precio: detalleMap['precio'],
          total: detalleMap['total'],
          idestatus: detalleMap['idestatus'],
          nombreProducto: detalleMap['nombreproducto'],
          nombreUnidad: detalleMap['nombreunidad'],
        ));
      }

      if (mounted) {
        setState(() {
          _detalles = loadedDetalles;
        });
        if (loadedDetalles.isEmpty) {
          // _showConnectivitySnackBar('No hay conexión a internet y no se encontraron detalles de nota guardados localmente.');
        } else {
          // _showConnectivitySnackBar('Mostrando detalles de nota guardados localmente (sin conexión).');
        }
      }
    }

  Future<void> _registrarPago() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isPaying = true; });

    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      // _showConnectivitySnackBar('No hay conexión a internet. No se pudo registrar el pago.');
      if (mounted) setState(() { _isPaying = false; });
      return;
    }

    try {
      final montoPagado = double.parse(_montoController.text);
      final payload = {
        'idnota': widget.nota.idnota,
        'monto': montoPagado,
        'tipopago': _tipoPago,
      };

      final url = Uri.parse('${ApiConfig.baseUrl}api_registrar_pago.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (mounted) {
        final decoded = json.decode(response.body);
        if (response.statusCode == 200 && decoded['success'] == true) {
          final nuevoSaldoRecibido = (decoded['nuevo_saldo'] as num).toDouble();
          setState(() {
            _saldoActual = nuevoSaldoRecibido;
            _hasDataChanged = true;
            
            // Actualizamos el monto acumulado en el objeto de la nota para habilitar el botón de imprimir
            _notaActual = Nota(
              idnota: _notaActual.idnota,
              total: _notaActual.total,
              saldo: nuevoSaldoRecibido,
              regtimestamp: _notaActual.regtimestamp,
              nombreCliente: _notaActual.nombreCliente,
              idalmacen: _notaActual.idalmacen,
              nombreAlmacenSalida: _notaActual.nombreAlmacenSalida,
              nombreAlmacenOrigen: _notaActual.nombreAlmacenOrigen,
              montoPagadoAcumulado: _notaActual.montoPagadoAcumulado + montoPagado,
            );
          });

          // La información del último pago ya no se guarda en SharedPreferences.

          _montoController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Pago registrado. Nuevo saldo: $nuevoSaldoRecibido'), backgroundColor: Colors.green),
          );
        } else {
          throw Exception(decoded['error'] ?? 'Error desconocido al registrar el pago');
        }
      }
    } on SocketException {
      if (mounted) { 
        // _showConnectivitySnackBar('Error de conexión al registrar el pago.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al registrar el pago: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _isPaying = false; });
    }
  }



  Future<void> _handlePrint() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Obteniendo datos..."),
              ],
            ),
          ),
        );
      },
    );

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}api_ultimo_pago.php?id_nota=${_notaActual.idnota}');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (mounted) {
        Navigator.pop(context); // Cerrar el diálogo de carga
        final decoded = json.decode(response.body);

        if (response.statusCode == 200 && decoded['success'] == true) {
          double montoPagado = 0;
          String formaDePago = '';
          double saldoAnterior = 0;

          final paymentData = decoded['data'];
          if (paymentData != null) {
            montoPagado = double.tryParse(paymentData['monto'].toString()) ?? 0.0;
            formaDePago = paymentData['tipo_pago'] ?? '';
            saldoAnterior = _notaActual.saldo + montoPagado;
          }

          _navigateToPrintPreview(montoPagado: montoPagado, formaDePago: formaDePago, saldoAnterior: saldoAnterior);
        } else {
          throw Exception(decoded['message'] ?? 'No se pudo obtener la información del último pago.');
        }
      }
    } on SocketException {
        if (mounted) {
            Navigator.pop(context); // Cerrar diálogo de carga
            _printFromOffline(); // <-- FALLBACK A MODO OFFLINE
        }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar el diálogo de carga en caso de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error para imprimir: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _printFromOffline() async {
    final dbHelper = DatabaseHelper.instance;
    final localPago = await dbHelper.getLatestPagoForNota(_notaActual.idnota);

    if (localPago != null) {
      final montoPagado = localPago['monto'] as double;
      final formaDePago = localPago['tipo_pago'] as String;
      final saldoAnterior = _notaActual.saldo + montoPagado;

      _navigateToPrintPreview(montoPagado: montoPagado, formaDePago: formaDePago, saldoAnterior: saldoAnterior);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin conexión. No se encontraron datos de pago locales para esta nota.'), backgroundColor: Colors.orange),
      );
    }
  }

  void _navigateToPrintPreview({required double montoPagado, required String formaDePago, required double saldoAnterior}) {
    final args = PrintPreviewArgs(
      nota: _notaActual,
      detalles: _detalles,
      nombreVendedor: _nombreVendedor,
      montoPagado: montoPagado,
      formaDePago: formaDePago,
      saldoAnterior: saldoAnterior,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrintPreviewScreen(args: args),
      ),
    );
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.pop(context, _hasDataChanged),
            tooltip: 'Regresar',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.print_outlined),
              onPressed: (_notaActual.montoPagadoAcumulado > 0 && !_isLoading) ? _handlePrint : null,
              tooltip: _isLoading 
                  ? 'Cargando datos...' 
                  : (_notaActual.montoPagadoAcumulado > 0 
                      ? 'Imprimir Tickets' 
                      : 'No se han registrado pagos para esta nota'),
            ),
          ],
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
      ),
    );
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
              Text(_notaActual.nombreCliente, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              // ---- INICIO DEL COMBO DE ALMACÉN ----
              DropdownButtonFormField<int>(
                value: _almacenes.any((almacen) => almacen.id == _selectedAlmacenId) ? _selectedAlmacenId : null,
                items: _almacenes.map((almacen) {
                  return DropdownMenuItem<int>(
                    value: almacen.id,
                    child: Text(almacen.nombre),
                  );
                }).toList(),
                onChanged: _isUpdatingAlmacen ? null : (value) {
                  if (value != null && value != _selectedAlmacenId) {
                    _actualizarAlmacen(value);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Almacén de Salida',
                  prefixIcon: _isUpdatingAlmacen 
                      ? const SizedBox(width: 24, height: 24, child: Padding(padding: EdgeInsets.all(4.0), child: CircularProgressIndicator(strokeWidth: 3,)))
                      : const Icon(Icons.store_mall_directory),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              // ---- FIN DEL COMBO DE ALMACÉN ----
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total de la Nota:', style: TextStyle(fontSize: 16)),
                  Text(currencyFormat.format(_notaActual.total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Future<void> _cambiarEstatusProducto(int iddetalle, int nuevoIdEstatus) async {
    // Para evitar múltiples llamadas, podrías añadir un booleano de estado aquí si es necesario

    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      // _showConnectivitySnackBar('No hay conexión a internet. No se pudo cambiar el estatus del producto.');
      return;
    }

    try {
      final payload = {
        'iddetalle': iddetalle,
        'idestatus': nuevoIdEstatus,
      };
      final url = Uri.parse('${ApiConfig.baseUrl}api_cambiar_estatus_producto.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (mounted) {
        final decoded = json.decode(response.body);
        if (response.statusCode == 200 && decoded['status'] == 'success') {
          // Actualizar el estado localmente para reflejar el cambio en la UI
          setState(() {
            final producto = _detalles.firstWhere((d) => d.iddetalle == iddetalle);
            producto.idestatus = nuevoIdEstatus;
            _hasDataChanged = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Estatus actualizado. Recalculando totales...'), backgroundColor: Colors.teal),
          );
          // Llamar a la lógica de recálculo de la nota aquí
          await _recalcularNota();
        } else {
          throw Exception(decoded['message'] ?? 'Error desconocido al cambiar estatus');
        }
      }
    } on SocketException {
      if (mounted) {
        // _showConnectivitySnackBar('No se pudo conectar al servidor para cambiar el estatus del producto. Verifica tu conexión a internet.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _recalcularNota() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      // _showConnectivitySnackBar('No hay conexión a internet. No se pudo recalcular la nota.');
      return;
    }

    try {
      final payload = {'idnota': _notaActual.idnota};
      final url = Uri.parse('${ApiConfig.baseUrl}api_recalcular_nota.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (mounted) {
        final decoded = json.decode(response.body);
        if (response.statusCode == 200 && decoded['success'] == true) {
          setState(() {
            // Actualizar el estado local con los nuevos valores devueltos por la API
            _notaActual = Nota(
              idnota: _notaActual.idnota,
              total: (decoded['nuevo_total'] as num).toDouble(),
              saldo: (decoded['nuevo_saldo'] as num).toDouble(),
              regtimestamp: _notaActual.regtimestamp,
              nombreCliente: _notaActual.nombreCliente,
              idalmacen: _notaActual.idalmacen,
              nombreAlmacenSalida: _notaActual.nombreAlmacenSalida,
              nombreAlmacenOrigen: _notaActual.nombreAlmacenOrigen,
              montoPagadoAcumulado: _notaActual.montoPagadoAcumulado,
            );
            _saldoActual = (decoded['nuevo_saldo'] as num).toDouble();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Totales recalculados.'), backgroundColor: Colors.green),
          );
        } else {
          throw Exception(decoded['error'] ?? 'Error desconocido al recalcular');
        }
      }
    } on SocketException {
      if (mounted) {
        // _showConnectivitySnackBar('No se pudo conectar al servidor para recalcular la nota. Verifica tu conexión a internet.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al recalcular la nota: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildDetailsList() {
    if (_detalles.isEmpty) {
      return const Center(child: Text('No se encontraron productos para esta nota.'));
    }
    
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Cant.')),
          DataColumn(label: Text('Unidad')),
          DataColumn(label: Text('Producto')),
          DataColumn(label: Text('P/U')),
          DataColumn(label: Text('Total')),
          DataColumn(label: Text('Estatus')),
        ],
        rows: _detalles.map((producto) {
          return DataRow(
            cells: [
              DataCell(Text(producto.cantidad.toString())),
              DataCell(Text(producto.nombreUnidad)),
              DataCell(Text(producto.nombreProducto)),
              DataCell(Text(currencyFormat.format(producto.precio))),
              DataCell(Text(currencyFormat.format(producto.total))),
              DataCell(
                _estatusList.isEmpty
                  ? const Text('Cargando...')
                  : DropdownButton<int>(
                      value: producto.idestatus,
                      items: _estatusList.map((estatus) {
                        return DropdownMenuItem<int>(
                          value: estatus.id,
                          child: Text(estatus.clave),
                        );
                      }).toList(),
                      onChanged: (newId) {
                        if (newId != null && newId != producto.idestatus) {
                          _cambiarEstatusProducto(producto.iddetalle, newId);
                        }
                      },
                    ),
              ),
            ],
          );
        }).toList(),
      ),
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