import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:distribuidora/services/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:distribuidora/models/nota_model.dart';
import 'package:distribuidora/screens/print_preview_screen.dart' as pps;

import 'package:distribuidora/models/offline_note_model.dart';
import 'package:distribuidora/services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- MODELOS DE DATOS ---

class NotaDetalle {
  final int iddetalle;
  final double cantidad;
  final double precio;
  final double total;
  int idestatus;
  final String nombreProducto;
  final String nombreUnidad;
  final String tipoProducto; // Nuevo campo

  NotaDetalle(
      {required this.iddetalle,
      required this.cantidad,
      required this.precio,
      required this.total,
      required this.idestatus,
      required this.nombreProducto,
      required this.nombreUnidad,
      this.tipoProducto = 'P'}); // Inicializar con 'P' por defecto

  factory NotaDetalle.fromJson(Map<String, dynamic> json) {
    return NotaDetalle(
      iddetalle: int.tryParse(json['iddetalle'].toString()) ?? 0,
      cantidad: double.tryParse(json['cantidad'].toString()) ?? 0.0,
      precio: double.tryParse(json['precio'].toString()) ?? 0.0,
      total: double.tryParse(json['total'].toString()) ?? 0.0,
      idestatus: int.tryParse(json['idestatus'].toString()) ?? 0,
      nombreProducto: json['nombreproducto'] ?? 'N/A',
      nombreUnidad: json['nombreunidad'] ?? 'N/A',
      tipoProducto: json['tipo_producto'] ?? 'P', // Parsear el nuevo campo
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
}

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

class Pago {
  final int idpago;
  final double monto;
  final String tipoPago;
  final String regtimestamp;

  Pago(
      {required this.idpago,
      required this.monto,
      required this.tipoPago,
      required this.regtimestamp});

  factory Pago.fromDbMap(Map<String, dynamic> map) {
    return Pago(
      idpago: map['idpago'],
      monto: map['monto'],
      tipoPago: map['tipo_pago'],
      regtimestamp: map['regtimestamp'],
    );
  }
}

class CajaItem {
  final int iddetalleEmbarque;
  final String nombreProducto;
  final double precioUnitario;
  final double saldoCajasItem;
  final double cantidadOriginal;
  final double cantidadDevuelta; // Nuevo campo

  CajaItem(
      {required this.iddetalleEmbarque,
      required this.nombreProducto,
      required this.precioUnitario,
      required this.saldoCajasItem,
      required this.cantidadOriginal,
      required this.cantidadDevuelta}); // Requerido

  factory CajaItem.fromJson(Map<String, dynamic> json) {
    return CajaItem(
      iddetalleEmbarque: json['iddetalle_embarque'],
      nombreProducto: json['nombre_producto'],
      precioUnitario: (json['precio_unitario'] as num).toDouble(),
      saldoCajasItem: (json['saldo_cajas_item'] as num).toDouble(),
      cantidadOriginal: (json['cantidad_original'] as num).toDouble(),
      cantidadDevuelta: (json['cantidad_devuelta'] as num).toDouble(), // Nuevo
    );
  }
}

// --- WIDGET PRINCIPAL ---

class NotaDetailScreen extends StatefulWidget {
  final Nota nota;
  const NotaDetailScreen({super.key, required this.nota});

  @override
  State<NotaDetailScreen> createState() => _NotaDetailScreenState();
}

class _NotaDetailScreenState extends State<NotaDetailScreen> {
  // Estado UI
  bool _isLoading = true;
  bool _isPaying = false;
  bool _hasDataChanged = false;
  bool _isUpdatingAlmacen = false;

  // Datos de la Nota
  List<NotaDetalle> _detalles = [];
  late double _saldoActual;
  late Nota _notaActual;
  String _nombreVendedor = '';

  // Catalogos
  List<Almacen> _almacenes = [];
  int? _selectedAlmacenId;
  List<Estatus> _estatusList = [];
  List<Pago> _pagos = [];

  // Formulario de Pago
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  String _tipoPago = 'Efectivo';
  bool _isCajaPayment = false;

  // Lógica de Pago con Cajas
  bool _isLoadingCajas = false;
  final Map<int, TextEditingController> _cajaControllers = {};
  List<CajaItem> _cajasPendientes = [];

  @override
  void initState() {
    super.initState();
    _notaActual = widget.nota;
    _saldoActual = widget.nota.saldo;
    _selectedAlmacenId = widget.nota.idalmacen;
    _montoController.text = _saldoActual.toStringAsFixed(2);
    _fetchInitialData();
  }

  @override
  void dispose() {
    _montoController.dispose();
    _cajaControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  // --- LÓGICA DE CARGA DE DATOS ---

  Future<void> _fetchInitialData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    await _loadDetallesFromOffline();
    await _loadPagos();
    await _fetchNetworkData(); // await para asegurar que los datos de red se carguen antes de finalizar la carga
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchNetworkData() async {
    if (!(await _tieneInternet())) {
      return;
    }
    await Future.wait([
      _fetchDetallesNota(),
      _fetchAlmacenes(),
      _fetchEstatusList(),
    ]);
  }

  Future<bool> _tieneInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _fetchDetallesNota() async {
    try {
      final id = _notaActual.idnota;
      final url = Uri.parse('${ApiConfig.baseUrl}api_nota_detalle.php?idnota=$id');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (mounted && response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final data = decoded['data'];
          setState(() {
            _detalles = (data['detalles'] as List)
                .map((json) => NotaDetalle.fromJson(json))
                .toList();
            _nombreVendedor = data['vendedor']?['nombre'] ?? 'No asignado';

            // --- INICIO DE LA CORRECCIÓN ---
            // Detecta el tipo de nota y ajusta el estado del formulario de pago automáticamente
            if (_detalles.isNotEmpty) {
              final noteType = _detalles.first.tipoProducto;
              if (noteType == 'C') {
                _tipoPago = 'Caja';
                _isCajaPayment = true;
              } else {
                _tipoPago = 'Efectivo';
                _isCajaPayment = false;
              }
            }
            // --- FIN DE LA CORRECCIÓN ---
          });

          // Si es de cajas, carga el balance de cajas inmediatamente
          if (_isCajaPayment) {
            await _fetchCajaBalance();
          }

          await _saveDetallesToOffline(_detalles);
          await _syncPagosForNota(id);
        } else {
          throw Exception(decoded['error']);
        }
      }
    } catch (e) {
      if (mounted) {
        await _loadDetallesFromOffline();
      }
    }
  }

  Future<void> _fetchAlmacenes() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}api_almacenes.php'))
          .timeout(const Duration(seconds: 15));
      if (mounted && response.statusCode == 200) {
        setState(() {
          _almacenes = (json.decode(response.body) as List)
              .map((item) => Almacen.fromJson(item))
              .toList();
        });
      }
    } catch (e) {
      /* Ignorar error */
    }
  }

  Future<void> _fetchEstatusList() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}api_estatus_movimiento.php'))
          .timeout(const Duration(seconds: 15));
      if (mounted && response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          setState(() {
            _estatusList = (decoded['data'] as List)
                .map((json) => Estatus.fromJson(json))
                .toList();
          });
        }
      }
    } catch (e) {
      /* Ignorar error */
    }
  }

  Future<void> _syncPagosForNota(int idnota) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}api_pagos_por_nota.php?idnota=$idnota');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          await DatabaseHelper.instance
              .insertPagosOffline(decoded['data']);
          await _loadPagos();
        }
      }
    } catch (e) {
      /* Falla silenciosamente */
    }
  }

  Future<void> _loadPagos() async {
    final pagosMaps =
        await DatabaseHelper.instance.getPagosForNota(widget.nota.idnota);
    if (mounted) {
      setState(() => _pagos = pagosMaps.map((map) => Pago.fromDbMap(map)).toList());
    }
  }

  Future<void> _saveDetallesToOffline(List<NotaDetalle> detalles) async {
    final db = await DatabaseHelper.instance.database;
    if (db != null) {
      await db.delete('nota_detalle_offline',
          where: 'idnota_fk = ?', whereArgs: [widget.nota.idnota]);
    }
    final detallesToSave = detalles
        .map((d) =>
            NotaDetalleOffline.fromNotaDetalle(d, widget.nota.idnota).toMap())
        .toList();
    await DatabaseHelper.instance.insertNotaDetallesOffline(detallesToSave);
  }

    Future<void> _loadDetallesFromOffline() async {

      final detallesMaps = await DatabaseHelper.instance

          .getNotaDetallesOffline(widget.nota.idnota);

      if (mounted) {

        setState(() {

                    _detalles = detallesMaps

                        .map((d) => NotaDetalle(

                            iddetalle: d['iddetalle'], cantidad: d['cantidad'], precio: d['precio'],

                            total: d['total'], idestatus: d['idestatus'], nombreProducto: d['nombreproducto'],

                            nombreUnidad: d['nombreunidad'], tipoProducto: d['tipo_producto']))

                        .toList();

        });

      }

    }

  

        Future<void> _actualizarAlmacen(int? nuevoAlmacenId) async {

  

          if (nuevoAlmacenId == null) {

  

            return;

  

          }

  

    

  

        if(mounted) setState(() { _isUpdatingAlmacen = true; });

  

        

  

        final isOnline = await _tieneInternet();

  

        if (!isOnline) {

  

          if (mounted) {

  

            ScaffoldMessenger.of(context).showSnackBar(

  

              const SnackBar(content: Text('No hay conexión a internet. No se pudo actualizar el almacén.'), backgroundColor: Colors.orange),

  

            );

  

            setState(() { _isUpdatingAlmacen = false; });

  

          }

  

          return;

  

        }

  

    

  

        try {

  

          final payload = {'idnota': widget.nota.idnota, 'idalmacen': nuevoAlmacenId};

  

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

  

                final nombreNuevoAlmacen = _almacenes.firstWhere((a) => a.id == nuevoAlmacenId, orElse: () => Almacen(id: 0, nombre: 'N/A')).nombre;

  

                _notaActual = Nota(

  

                  idnota: _notaActual.idnota, idcliente: _notaActual.idcliente, total: _notaActual.total,

  

                  saldo: _notaActual.saldo, regtimestamp: _notaActual.regtimestamp,

  

                  nombreCliente: _notaActual.nombreCliente, idalmacen: nuevoAlmacenId,

  

                                    nombreAlmacenSalida: nombreNuevoAlmacen, nombreAlmacenOrigen: _notaActual.nombreAlmacenOrigen,

  

                                    montoPagadoAcumulado: _notaActual.montoPagadoAcumulado, nombreVendedor: _notaActual.nombreVendedor,

  

                                    tipoProducto: _notaActual.tipoProducto, // <-- CORRECCIÓN

  

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

  

            ScaffoldMessenger.of(context).showSnackBar(

  

              const SnackBar(content: Text('No se pudo conectar al servidor. Verifica tu conexión a internet.'), backgroundColor: Colors.orange),

  

            );

  

          }

  

        } catch (e) {

  

          if (mounted) {

  

            ScaffoldMessenger.of(context).showSnackBar(

  

              SnackBar(content: Text('❌ Error al actualizar el almacén: $e'), backgroundColor: Colors.red),

  

            );

  

          }

  

        } finally {

  

          if (mounted) setState(() => _isUpdatingAlmacen = false);

  

        }

  

      }

  

    

  

      Future<void> _cambiarEstatusProducto(int iddetalle, int nuevoIdEstatus) async {

  

        final isOnline = await _tieneInternet();

  

        if (!isOnline) {

  

          if (mounted) {

  

            ScaffoldMessenger.of(context).showSnackBar(

  

              const SnackBar(content: Text('No hay conexión a internet. No se pudo cambiar el estatus del producto.'), backgroundColor: Colors.orange),

  

            );

  

          }

  

          return;

  

        }

  

    

  

        try {

  

          final payload = {'iddetalle': iddetalle, 'idestatus': nuevoIdEstatus};

  

          final url = Uri.parse('${ApiConfig.baseUrl}api_cambiar_estatus_producto.php');

  

          final response = await http.post(

  

            url,

  

            headers: {'Content-Type': 'application/json; charset=UTF-8'},

  

            body: jsonEncode(payload),

  

          ).timeout(const Duration(seconds: 15));

  

    

  

          if (mounted) {

  

            final decoded = json.decode(response.body);

  

            if (response.statusCode == 200 && decoded['status'] == 'success') {

  

              setState(() {

  

                _detalles.firstWhere((d) => d.iddetalle == iddetalle).idestatus = nuevoIdEstatus;

  

                _hasDataChanged = true;

  

              });

  

              ScaffoldMessenger.of(context).showSnackBar(

  

                const SnackBar(content: Text('✅ Estatus actualizado. Recalculando totales...'), backgroundColor: Colors.teal),

  

              );

  

              await _recalcularNota();

  

            } else {

  

              throw Exception(decoded['message'] ?? 'Error desconocido');

  

            }

  

          }

  

        } on SocketException {

  

          if (mounted) {

  

            ScaffoldMessenger.of(context).showSnackBar(

  

              const SnackBar(content: Text('No se pudo conectar al servidor. Verifica tu conexión a internet.'), backgroundColor: Colors.orange),

  

            );

  

          }

  

        } catch (e) {

  

          if (mounted) {

  

            ScaffoldMessenger.of(context).showSnackBar(

  

              SnackBar(content: Text('❌ Error al cambiar estatus: $e'), backgroundColor: Colors.red),

  

            );

  

          }

  

        }

  

      }

  

    

  

      Future<void> _recalcularNota() async {

  

        final isOnline = await _tieneInternet();

  

        if (!isOnline) {

  

          if (mounted) {

  

            ScaffoldMessenger.of(context).showSnackBar(

  

              const SnackBar(content: Text('No hay conexión a internet. No se pudo recalcular la nota.'), backgroundColor: Colors.orange),

  

            );

  

          }

  

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

  

                _notaActual = Nota(

  

                  idnota: _notaActual.idnota, idcliente: _notaActual.idcliente,

  

                  total: (decoded['nuevo_total'] as num).toDouble(),

  

                  saldo: (decoded['nuevo_saldo'] as num).toDouble(),

  

                  regtimestamp: _notaActual.regtimestamp,

  

                  nombreCliente: _notaActual.nombreCliente, idalmacen: _notaActual.idalmacen,

  

                                    nombreAlmacenSalida: _notaActual.nombreAlmacenSalida,

  

                                    nombreAlmacenOrigen: _notaActual.nombreAlmacenOrigen,

  

                                    montoPagadoAcumulado: _notaActual.montoPagadoAcumulado,

  

                                    nombreVendedor: _notaActual.nombreVendedor,

  

                                    tipoProducto: _notaActual.tipoProducto, // <-- CORRECCIÓN

  

                                  );

  

                                  _saldoActual = (decoded['nuevo_saldo'] as num).toDouble();

  

                                });

  

                                ScaffoldMessenger.of(context).showSnackBar(

  

                const SnackBar(content: Text('✅ Totales recalculados.'), backgroundColor: Colors.green),

  

              );

  

            } else {

  

              throw Exception(decoded['error'] ?? 'Error desconocido');

  

            }

  

          }

  

        } on SocketException {

  

          if (mounted) {

  

            ScaffoldMessenger.of(context).showSnackBar(

  

              const SnackBar(content: Text('No se pudo conectar al servidor. Verifica tu conexión a internet.'), backgroundColor: Colors.orange),

  

            );

  

          }

  

        } catch (e) {

  

          if (mounted) {

  

            ScaffoldMessenger.of(context).showSnackBar(

  

              SnackBar(content: Text('❌ Error al recalcular nota: $e'), backgroundColor: Colors.red),

  

            );

  

          }

  

        }

  

      }

  

    

  

      // --- LÓGICA DE ACCIONES ---

  Future<void> _registrarPago() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isPaying = true);

    try {
      if (_isCajaPayment) {
        await _registrarPagoCajas();
      } else {
        await _registrarPagoMonetario();
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  Future<void> _registrarPagoMonetario() async {
    final montoPagado = double.parse(_montoController.text);
    final isOffline = !(await _tieneInternet());

    if (isOffline) {
      final dbHelper = DatabaseHelper.instance;
      final prefs = await SharedPreferences.getInstance();
      final idUsuario = prefs.getInt('idusuario');
      if (idUsuario == null) throw Exception('ID de usuario no encontrado.');

      await dbHelper.insertPagoParaSincronizar({
        'idnota': widget.nota.idnota, 'monto': montoPagado, 'tipo_pago': _tipoPago,
        'regtimestamp': DateTime.now().toIso8601String(), 'id_usuario': idUsuario, 'synced': 0
      });

      final nuevoSaldo = _saldoActual - montoPagado;
      await dbHelper.updateNotaSaldo(widget.nota.idnota, nuevoSaldo, _notaActual.montoPagadoAcumulado + montoPagado);

      if (mounted) {
        setState(() {
          _saldoActual = nuevoSaldo;
          _hasDataChanged = true;
          _montoController.text = _saldoActual.toStringAsFixed(2);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Pago guardado localmente.'), backgroundColor: Colors.blue));
      }
    } else {
      final payload = {'idnota': widget.nota.idnota, 'monto': montoPagado, 'tipopago': _tipoPago};
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}api_registrar_pago.php'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(payload)
      ).timeout(const Duration(seconds: 15));

      if (mounted) {
        final decoded = json.decode(response.body);
        if (response.statusCode == 200 && decoded['success'] == true) {
          final nuevoSaldoRecibido = (decoded['nuevo_saldo'] as num).toDouble();
          final nuevoAcumulado = (decoded['monto_pagado_acumulado'] as num).toDouble();
          setState(() {
            _saldoActual = nuevoSaldoRecibido;
            _notaActual = _notaActual.copyWith(
              saldo: nuevoSaldoRecibido,
              montoPagadoAcumulado: nuevoAcumulado,
            );
            _hasDataChanged = true;
            _montoController.text = _saldoActual.toStringAsFixed(2);
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Pago registrado. Nuevo saldo: $nuevoSaldoRecibido'), backgroundColor: Colors.green));
        } else {
          throw Exception(decoded['error'] ?? 'Error desconocido');
        }
      }
    }
    await _syncPagosForNota(widget.nota.idnota);
  }

  Future<void> _registrarPagoCajas() async {
    bool hasError = false;
    int itemsProcessed = 0;
    double? nuevoSaldoFinal;
    double? nuevoAcumuladoFinal;

    setState(() => _isPaying = true);

    for (var entry in _cajaControllers.entries) {
      final iddetalle = entry.key;
      final controller = entry.value;
      if (controller.text.isEmpty) continue;

      final cantidad = int.tryParse(controller.text);
      if (cantidad != null && cantidad > 0) {
        itemsProcessed++;
        try {
          final payload = {
            'idnota': widget.nota.idnota, 'monto': cantidad, 'tipopago': 'Caja', 'iddetalle_embarque': iddetalle,
          };
          final response = await http.post(
            Uri.parse('${ApiConfig.baseUrl}api_registrar_pago.php'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'}, body: jsonEncode(payload)
          ).timeout(const Duration(seconds: 20));

          final decoded = json.decode(response.body);
          if (response.statusCode != 200 || decoded['success'] != true) {
            throw Exception(decoded['error'] ?? 'Error en API para item $iddetalle');
          } else {
            // Guardar el último saldo y acumulado devuelto por la API
            nuevoSaldoFinal = (decoded['nuevo_saldo'] as num).toDouble();
            nuevoAcumuladoFinal = (decoded['monto_pagado_acumulado'] as num).toDouble();
          }
        } catch (e) {
          hasError = true;
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
          break;
        }
      }
    }

    if (mounted) {
      if (!hasError && itemsProcessed > 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Devolución de cajas registrada.'), backgroundColor: Colors.green));
        setState(() {
          if (nuevoSaldoFinal != null) {
            _saldoActual = nuevoSaldoFinal;
          }
          if (nuevoSaldoFinal != null && nuevoAcumuladoFinal != null) {
            _notaActual = _notaActual.copyWith(
              saldo: nuevoSaldoFinal,
              montoPagadoAcumulado: nuevoAcumuladoFinal,
            );
          }
          _hasDataChanged = true;
        });
        await _fetchCajaBalance();
        await _syncPagosForNota(widget.nota.idnota);
        
      } else if (!hasError && itemsProcessed == 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se ingresó cantidad para ninguna caja.'), backgroundColor: Colors.orange));
      }
      setState(() => _isPaying = false);
    }
  }

  Future<void> _handlePrint() async {
    // Si el saldo es 0, estamos re-imprimiendo el último recibo.
    if (_saldoActual <= 0) {
      await _reimprimirUltimoRecibo();
    } else {
      // Si hay saldo, estamos pre-visualizando un pago nuevo.
      await _previsualizarPagoActual();
    }
  }

  Future<void> _previsualizarPagoActual() async {
    // Usa el estado actual de la UI para la previsualización
    final formaDePago = _tipoPago;
    
    if (formaDePago == 'Caja') {
      double totalCreditoMonetario = 0.0;
      final cajasDevueltas = _cajaControllers.entries.map((entry) {
        final itemInfo = _cajasPendientes.firstWhere((c) => c.iddetalleEmbarque == entry.key);
        final cantidad = double.tryParse(entry.value.text) ?? 0.0;
        totalCreditoMonetario += cantidad * itemInfo.precioUnitario;
        return cantidad;
      }).fold(0.0, (sum, val) => sum + val);

      final totalCajasOriginales = _cajasPendientes.fold(0.0, (sum, item) => sum + item.cantidadOriginal);
      final saldoCajasActual = _cajasPendientes.fold(0.0, (sum, item) => sum + item.saldoCajasItem);

      _navigateToPrintPreview(
        montoPagado: totalCreditoMonetario, // <--- VALOR MONETARIO CALCULADO
        formaDePago: formaDePago,
        saldoAnterior: 0,
        cajasEntregadas: cajasDevueltas,
        cajasOriginales: totalCajasOriginales,
        cajasSaldoAnterior: saldoCajasActual,
        cajasSaldoActual: saldoCajasActual - cajasDevueltas,
        isCajaPrint: true, // Es un pago de Caja
      );

    } else {
      // Para pagos monetarios
      final montoPagado = double.tryParse(_montoController.text) ?? 0.0;
      final saldoAnterior = _saldoActual;
      _navigateToPrintPreview(
        montoPagado: montoPagado,
        formaDePago: formaDePago,
        saldoAnterior: saldoAnterior,
        isCajaPrint: false, // No es un pago de Caja
      );
    }
  }

  Future<void> _reimprimirUltimoRecibo() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(width: 20), Text("Obteniendo datos...")]),
        ),
      ),
    );

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}api_ultimo_pago.php?id_nota=${_notaActual.idnota}');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      Navigator.pop(context); // Cerrar diálogo de carga

      final decoded = json.decode(response.body);

      if (response.statusCode == 200 && decoded['success'] == true) {
        final paymentData = decoded['data'];
        if (paymentData == null) throw Exception('No se encontró el último pago.');

        final formaDePago = paymentData['tipo_pago'] ?? '';
        final cantidadPagada = double.tryParse(paymentData['monto'].toString()) ?? 0.0;

                if (formaDePago == 'Caja') {
                  await _fetchCajaBalance(); // Get latest box balance for price info
                  if (mounted) {
                    final idDetalleEmbarque = paymentData['iddetalle_embarque'];
                    final itemInfo = _cajasPendientes.firstWhere((c) => c.iddetalleEmbarque == idDetalleEmbarque, orElse: () => throw Exception('Detalle de caja no encontrado para el último pago.'));
                    final creditoMonetario = cantidadPagada * itemInfo.precioUnitario;
        
                    final totalCajasOriginales = _cajasPendientes.fold(0.0, (sum, item) => sum + item.cantidadOriginal);
                    final totalCajasActual = _cajasPendientes.fold(0.0, (sum, item) => sum + item.saldoCajasItem);
                    // Suma el total devuelto de todos los items para obtener el acumulado real
                    final totalCajasDevueltas = _cajasPendientes.fold(0.0, (sum, item) => sum + item.cantidadDevuelta);
        
                    _navigateToPrintPreview(
                      montoPagado: creditoMonetario, // <--- VALOR MONETARIO CALCULADO
                      formaDePago: formaDePago,
                      saldoAnterior: 0,
                      cajasEntregadas: totalCajasDevueltas,
                      cajasSaldoAnterior: totalCajasActual + cantidadPagada, 
                      cajasSaldoActual: totalCajasActual,
                      cajasOriginales: totalCajasOriginales,
                      isCajaPrint: true,
                    );
                  }        } else {
          // El saldo actual es 0, el saldo anterior era el monto del último pago.
          final saldoAnterior = _notaActual.saldo + cantidadPagada;
          _navigateToPrintPreview(
            montoPagado: cantidadPagada,
            formaDePago: formaDePago,
            saldoAnterior: saldoAnterior,
            isCajaPrint: false, // No es un pago de Caja
          );
        }
      } else {
        throw Exception(decoded['message'] ?? 'No se pudo obtener la info del último pago.');
      }
    } on SocketException {
      if (!mounted) return;
      Navigator.pop(context);
      _printFromOffline();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error para imprimir: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _printFromOffline() async {
    final dbHelper = DatabaseHelper.instance;
    final localPago = await dbHelper.getLatestPagoForNotaIncludingPending(_notaActual.idnota);

    if (!mounted || localPago == null) return;

    final montoPagado = localPago['monto'] as double;
    final formaDePago = localPago['tipo_pago'] as String;

    if (formaDePago == 'Caja') {
      _navigateToPrintPreview(
        montoPagado: 0, formaDePago: formaDePago, saldoAnterior: 0,
        cajasEntregadas: montoPagado,
        cajasSaldoAnterior: null, cajasSaldoActual: null,
        isCajaPrint: true, // Es un pago de Caja
      );
    } else {
      final saldoAnterior = _notaActual.saldo + montoPagado;
      _navigateToPrintPreview(montoPagado: montoPagado, formaDePago: formaDePago, saldoAnterior: saldoAnterior, isCajaPrint: false); // No es un pago de Caja
    }
  }
  
  void _navigateToPrintPreview({
    required double montoPagado,
    required String formaDePago,
    required double saldoAnterior,
    double? cajasEntregadas,
    double? cajasSaldoAnterior,
    double? cajasSaldoActual,
    double? cajasOriginales,
    required bool isCajaPrint, // Nuevo parámetro
  }) {
    final args = pps.PrintPreviewArgs(
      nota: _notaActual, detalles: _detalles, nombreVendedor: _nombreVendedor,
      montoPagado: montoPagado, formaDePago: formaDePago, saldoAnterior: saldoAnterior,
      isDeliveryNote: false, cajasEntregadas: cajasEntregadas,
      cajasSaldoAnterior: cajasSaldoAnterior, cajasSaldoActual: cajasSaldoActual,
      cajasOriginales: cajasOriginales,
      isCajaPrint: isCajaPrint, // Pasar el nuevo parámetro
    );
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => pps.PrintPreviewScreen(args: args)));
  }

  void _navigateToPrintPreviewNotaSurtido() {
    final bool isCajaNote = _notaActual.tipoProducto.trim().toUpperCase() == 'C';
    final args = pps.PrintPreviewArgs(
      nota: _notaActual,
      detalles: _detalles,
      nombreVendedor: _nombreVendedor,
      montoPagado: 0,
      formaDePago: '',
      saldoAnterior: 0,
      isDeliveryNote: true, // This flag now means "Only the delivery note, not the receipt"
      isCajaPrint: isCajaNote, // This flag tells the ticket WHICH delivery note to render
    );
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => pps.PrintPreviewScreen(args: args)));
  }

  Future<void> _fetchCajaBalance() async {
    if (mounted) setState(() => _isLoadingCajas = true);
    _cajaControllers.forEach((_, c) => c.dispose());
    _cajaControllers.clear();
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}api_calculo_saldo_cajas.php?idnota=${_notaActual.idnota}');
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (mounted) {
        final decoded = json.decode(response.body);
        if (response.statusCode == 200 && decoded['success'] == true) {
          setState(() {
            _cajasPendientes = (decoded['data'] as List).map((item) => CajaItem.fromJson(item)).toList();
            for (var item in _cajasPendientes) {
              _cajaControllers[item.iddetalleEmbarque] = TextEditingController();
            }
          });
        } else {
          throw Exception(decoded['error']);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al obtener saldo de cajas: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoadingCajas = false);
    }
  }

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if(didPop) return;
        Navigator.pop(context, _hasDataChanged);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Detalle de Nota #${widget.nota.idnota}'),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => Navigator.pop(context, _hasDataChanged)),
          actions: [
            IconButton(
              icon: const Icon(Icons.local_shipping_outlined),
              onPressed: !_isLoading ? _navigateToPrintPreviewNotaSurtido : null,
              tooltip: 'Imprimir Nota de Surtido',
            ),
            IconButton(
              icon: const Icon(Icons.receipt_long),
              onPressed: !_isLoading ? _handlePrint : null,
              tooltip: 'Imprimir Recibo de Pago',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchInitialData,
                child: ListView(
                  children: [
                    _buildHeader(),
                    const Divider(thickness: 1, height: 1),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('Productos en la Nota', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    _buildDetailsList(),
                    if (_saldoActual > 0 || _cajasPendientes.any((c) => c.saldoCajasItem > 0)) _buildPaymentForm(),
                    _buildPaymentHistory(),
                  ],
                ),
              ),
      ),
    );
  }

  // --- WIDGETS DE UI ---
  
  Widget _buildHeader() {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    
    // Determinar si es nota de Cajas
    final bool isCaja = _notaActual.tipoProducto == 'C';
    final String totalLabel = isCaja ? 'Total de Unidades:' : 'Total de la Nota:';
    final String saldoLabel = isCaja ? 'Unidades Pendientes:' : 'Saldo Pendiente:';
    
    String totalValue;
    String saldoValue;

    if (isCaja) {
      // Para cajas, usamos los campos específicos de inventario
      totalValue = _notaActual.totalCajas.toStringAsFixed(0);
      
      // Si tenemos el desglose de cajas pendientes cargado, lo usamos para mayor precisión en tiempo real
      if (_cajasPendientes.isNotEmpty) {
        final double saldoCalculado = _cajasPendientes.fold(0, (sum, item) => sum + item.saldoCajasItem);
        saldoValue = saldoCalculado.toStringAsFixed(0);
      } else {
        // Si no, usamos el valor que vino en la nota (que podría no estar actualizado si no se ha recargado)
        saldoValue = _notaActual.saldoCajas.toStringAsFixed(0);
      }
    } else {
      // Para monetario, usamos los campos estándar
      totalValue = currencyFormat.format(_notaActual.total);
      saldoValue = currencyFormat.format(_saldoActual);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_notaActual.nombreCliente, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('ID Cliente: ${_notaActual.idcliente}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _almacenes.any((almacen) => almacen.id == _selectedAlmacenId) ? _selectedAlmacenId : null,
                items: _almacenes.map((almacen) {
                  return DropdownMenuItem<int>(value: almacen.id, child: Text(almacen.nombre));
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(totalLabel, style: const TextStyle(fontSize: 16)),
                  Text(totalValue, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(saldoLabel, style: TextStyle(fontSize: 16, color: Colors.orange.shade800)),
                  Text(saldoValue, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsList() {
    if (_detalles.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No se encontraron productos para esta nota.')));
    
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final bool isCaja = _detalles.isNotEmpty && _detalles.first.tipoProducto == 'C';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Cant.')),
          const DataColumn(label: Text('Unidad')),
          const DataColumn(label: Text('Producto')),
          if (!isCaja) const DataColumn(label: Text('P/U')),
          if (!isCaja) const DataColumn(label: Text('Total')),
          const DataColumn(label: Text('Estatus')), // Added Estatus column back
        ],
        rows: _detalles.map((producto) {
          final String puStr = isCaja 
              ? producto.precio.toStringAsFixed(0) 
              : currencyFormat.format(producto.precio);
          final String totalStr = isCaja 
              ? producto.total.toStringAsFixed(0) 
              : currencyFormat.format(producto.total);

          return DataRow(
            cells: [
              DataCell(Text(producto.cantidad.toString())),
              DataCell(Text(producto.nombreUnidad)),
              DataCell(Text(producto.nombreProducto)),
              if (!isCaja) DataCell(Text(puStr)),
              if (!isCaja) DataCell(Text(totalStr)),
              DataCell(
                _estatusList.isEmpty
                  ? const Text('Cargando...')
                  : DropdownButton<int>(
                      value: producto.idestatus,
                      items: _estatusList.map((estatus) {
                        return DropdownMenuItem<int>(value: estatus.id, child: Text(estatus.clave));
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
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Registrar Pago', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  // Determina el tipo de nota ( 'P' o 'C' )
                  final noteType = _detalles.isNotEmpty ? _detalles.first.tipoProducto : 'P';
                  // Genera la lista de opciones de pago dinámicamente
                  final paymentOptions = (noteType == 'C') ? ['Caja'] : ['Efectivo', 'Transferencia'];

                  // Asegura que el valor seleccionado sea válido para las opciones disponibles
                  final currentValue = paymentOptions.contains(_tipoPago) ? _tipoPago : paymentOptions.first;
                  
                  // Si el estado interno no coincide, lo actualizamos en el siguiente frame
                  if (_tipoPago != currentValue) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                           _tipoPago = currentValue;
                           _isCajaPayment = currentValue == 'Caja';
                        });
                      }
                    });
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: currentValue,
                    decoration: const InputDecoration(labelText: 'Tipo de Pago', border: OutlineInputBorder()),
                    items: paymentOptions.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                    onChanged: (newValue) {
                      if (newValue == null) return;
                      setState(() {
                        _tipoPago = newValue;
                        _isCajaPayment = newValue == 'Caja';
                        if (_isCajaPayment) {
                          _fetchCajaBalance();
                        } else {
                          _montoController.text = _saldoActual.toStringAsFixed(2);
                        }
                      });
                    },
                  );
                }
              ),
              const SizedBox(height: 16),
              if (_isCajaPayment) _buildCajasPaymentForm() else _buildMonetaryPaymentForm(),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isPaying ? null : _registrarPago,
                icon: _isPaying ? const SizedBox.shrink() : const Icon(Icons.check_circle),
                label: _isPaying ? const CircularProgressIndicator(color: Colors.white) : const Text('Registrar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white,
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
  
  Widget _buildMonetaryPaymentForm() {
    return TextFormField(
      controller: _montoController,
      decoration: const InputDecoration(labelText: 'Monto a Pagar', prefixIcon: Icon(Icons.attach_money), border: OutlineInputBorder()),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Por favor, ingrese un valor';
        final monto = double.tryParse(value);
        if (monto == null) return 'Ingrese un número válido';
        if (monto <= 0) return 'El valor debe ser mayor a cero';
        if (monto > _saldoActual) return 'El monto no puede ser mayor al saldo pendiente';
        return null;
      },
    );
  }

  Widget _buildCajasPaymentForm() {
    if (_isLoadingCajas) return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
    if (_cajasPendientes.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No hay cajas pendientes de devolución para esta nota.')));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Detalle de Cajas a Devolver:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _cajasPendientes.length,
          itemBuilder: (context, index) {
            final item = _cajasPendientes[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(flex: 4, child: Text(item.nombreProducto, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Text('Pend: ${item.saldoCajasItem.toStringAsFixed(0)}'),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cajaControllers[item.iddetalleEmbarque],
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Cant.', border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        final cant = int.tryParse(value);
                        if (cant == null) return 'Inválido';
                        if (cant < 0) return 'Negativo';
                        if (cant > item.saldoCajasItem) return 'Excede';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPaymentHistory() {
    if (_pagos.isEmpty) return const SizedBox.shrink();
    
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final DateFormat dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Historial de Pagos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._pagos.map((pago) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateFormat.format(DateTime.parse(pago.regtimestamp)), style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  Text(
                    '${pago.tipoPago}: ${pago.tipoPago == 'Caja' ? pago.monto.toStringAsFixed(0) : currencyFormat.format(pago.monto)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}