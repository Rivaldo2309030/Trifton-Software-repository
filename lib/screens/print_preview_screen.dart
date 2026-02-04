import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';

import 'package:distribuidora/models/nota_model.dart';
import 'package:distribuidora/screens/nota_detail_screen.dart';
import 'package:distribuidora/services/api_config.dart';
import 'package:distribuidora/services/database_helper.dart';

// --- Modelos y Argumentos ---

class Empresa {
  final String nombre;
  final String direccion;
  final String telefono;

  Empresa({this.nombre = 'N/A', this.direccion = 'N/A', this.telefono = 'N/A'});

  factory Empresa.fromJson(Map<String, dynamic> json) {
    return Empresa(
      nombre: json['nombre'] ?? 'N/A',
      direccion: json['direccion'] ?? 'N/A',
      telefono: json['telefono'] ?? 'N/A',
    );
  }
}

class PrintPreviewArgs {
  final Nota nota;
  final List<NotaDetalle> detalles;
  final String nombreVendedor;
  final double montoPagado;
  final String formaDePago;
  final double saldoAnterior;
  final bool isDeliveryNote;

  // Nuevos campos para pago con Cajas
  final double? cajasEntregadas;
  final double? cajasSaldoAnterior;
  final double? cajasSaldoActual;
  final double? cajasOriginales;
  final Uint8List? logoData;
  final bool isCajaPrint; // Nuevo campo

  PrintPreviewArgs({
    required this.nota,
    required this.detalles,
    required this.nombreVendedor,
    required this.montoPagado,
    required this.formaDePago,
    required this.saldoAnterior,
    this.isDeliveryNote = false,
    this.cajasEntregadas,
    this.cajasSaldoAnterior,
    this.cajasSaldoActual,
    this.cajasOriginales,
    this.logoData,
    this.isCajaPrint = false, // Valor por defecto
  });

  PrintPreviewArgs copyWith({
    Nota? nota,
    List<NotaDetalle>? detalles,
    String? nombreVendedor,
    double? montoPagado,
    String? formaDePago,
    double? saldoAnterior,
    bool? isDeliveryNote,
    double? cajasEntregadas,
    double? cajasSaldoAnterior,
    double? cajasSaldoActual,
    double? cajasOriginales,
    Uint8List? logoData,
    bool? isCajaPrint, // Nuevo campo
  }) {
    return PrintPreviewArgs(
      nota: nota ?? this.nota,
      detalles: detalles ?? this.detalles,
      nombreVendedor: nombreVendedor ?? this.nombreVendedor,
      montoPagado: montoPagado ?? this.montoPagado,
      formaDePago: formaDePago ?? this.formaDePago,
      saldoAnterior: saldoAnterior ?? this.saldoAnterior,
      isDeliveryNote: isDeliveryNote ?? this.isDeliveryNote,
      cajasEntregadas: cajasEntregadas ?? this.cajasEntregadas,
      cajasSaldoAnterior: cajasSaldoAnterior ?? this.cajasSaldoAnterior,
      cajasSaldoActual: cajasSaldoActual ?? this.cajasSaldoActual,
      cajasOriginales: cajasOriginales ?? this.cajasOriginales,
      logoData: logoData ?? this.logoData,
      isCajaPrint: isCajaPrint ?? this.isCajaPrint, // Nuevo campo
    );
  }
}

// --- Pantalla Principal ---

class PrintPreviewScreen extends StatefulWidget {
  final PrintPreviewArgs args;

  const PrintPreviewScreen({super.key, required this.args});

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late Future<void> _initialDataFuture;
  Empresa _empresa = Empresa();
  Uint8List? _logoBytes;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _initialDataFuture = _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Cargar la empresa
    final dbHelper = DatabaseHelper.instance;
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}api_datos_empresa.php'));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final empresaData = decoded['data'];
          await dbHelper.saveEmpresaInfo(empresaData);
          _empresa = Empresa.fromJson(empresaData);
        } else {
          final localData = await dbHelper.getEmpresaInfo();
          if (localData != null) _empresa = Empresa.fromJson(localData);
        }
      } else {
        final localData = await dbHelper.getEmpresaInfo();
        if (localData != null) _empresa = Empresa.fromJson(localData);
      }
    } catch (e) {
      final localData = await dbHelper.getEmpresaInfo();
      if (localData != null) _empresa = Empresa.fromJson(localData);
    }

    // Cargar el logo
    try {
      final ByteData logoData = await rootBundle.load('lib/imagenes jeje/Cruz_BananaLogo.jpg');
      _logoBytes = logoData.buffer.asUint8List();
    } catch (e) {
      // Manejar el error si el logo no se encuentra, _logoBytes se quedará como null
    }
  }


  Future<void> _generateDocument(Function(pw.Document) onDocGenerated) async {
    setState(() => _isPrinting = true);
    try {
      final doc = pw.Document();
      const pageFormat = PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm);

      // Usar los datos ya cargados del estado
      final pdfArgs = widget.args.copyWith(logoData: _logoBytes);

      // Lógica de generación de páginas para el PDF
      if (widget.args.isDeliveryNote) {
        // Si es solo la nota de entrega, genera una sola página, respetando si es de cajas o no.
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => NotaVentaPdf(args: pdfArgs, empresa: _empresa, isCajaPrint: widget.args.isCajaPrint)));
      } else if (widget.args.isCajaPrint) {
        // Si es un PAGO de cajas, genera la nota de entrega y el recibo.
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => NotaVentaPdf(args: pdfArgs, empresa: _empresa, isCajaPrint: true))); // Ticket de entrega/devolución de cajas
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => ReciboPagoPdf(args: pdfArgs, empresa: _empresa))); // Recibo de la transacción de cajas
      } else {
        // Si es un PAGO monetario, genera los 3 tickets.
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => NotaVentaPdf(args: pdfArgs, empresa: _empresa, isCajaPrint: false))); // Original
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => NotaVentaPdf(args: pdfArgs, empresa: _empresa, isCajaPrint: false))); // Copia
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => ReciboPagoPdf(args: pdfArgs, empresa: _empresa))); // Recibo
      }
      
      await onDocGenerated(doc);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al generar el documento: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _savePdfToDownloads() async {
    await _generateDocument((doc) async {
      final sanitizedClientName = widget.args.nota.nombreCliente.replaceAll(RegExp(r'[^a-zA-Z0-9 ._-]'), '').trim();
      final String filename = '${widget.args.nota.idnota}-$sanitizedClientName.pdf';
      
      final Directory? downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) throw Exception("No se pudo encontrar el directorio de descargas.");
      
      final String path = '${downloadsDir.path}/$filename';
      final file = File(path);
      await file.writeAsBytes(await doc.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Guardado en Descargas: $filename'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _printDocument() async {
    await _generateDocument((doc) async {
      final sanitizedClientName = widget.args.nota.nombreCliente.replaceAll(RegExp(r'[^a-zA-Z0-9 ._-]'), '').trim();
      final String filename = '${widget.args.nota.idnota}-$sanitizedClientName.pdf';
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Documento enviado a la impresora.'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _sharePdf() async {
    await _generateDocument((doc) async {
      final sanitizedClientName = widget.args.nota.nombreCliente.replaceAll(RegExp(r'[^a-zA-Z0-9 ._-]'), '').trim();
      final String filename = '${widget.args.nota.idnota}-$sanitizedClientName.pdf';
      await Printing.sharePdf(bytes: await doc.save(), filename: filename);
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Platform.isAndroid || Platform.isIOS;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista Previa de Impresión'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<void>(
        future: _initialDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar datos: ${snapshot.error}'));
          }

          // Usar los datos ya cargados del estado
          final previewArgs = widget.args.copyWith(logoData: _logoBytes);

          return Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  children: widget.args.isDeliveryNote
                      ? [_buildTicketPage(NotaVentaTicket(args: previewArgs, empresa: _empresa, isCajaPrint: widget.args.isCajaPrint))] // Solo la nota de surtido
                      : widget.args.isCajaPrint
                          ? [ // Pago de Cajas: Nota de entrega + Recibo
                              _buildTicketPage(NotaVentaTicket(args: previewArgs, empresa: _empresa, isCajaPrint: true)),
                              _buildTicketPage(ReciboPagoTicket(args: previewArgs, empresa: _empresa)),
                            ]
                          : [ // Pago Monetario: Original + Copia + Recibo
                              _buildTicketPage(NotaVentaTicket(args: previewArgs, empresa: _empresa, isCajaPrint: false)),
                              _buildTicketPage(NotaVentaTicket(args: previewArgs, empresa: _empresa, isCajaPrint: false)),
                              _buildTicketPage(ReciboPagoTicket(args: previewArgs, empresa: _empresa)),
                            ],
                ),
              ),
              _buildPageIndicator(),
            ],
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : (isMobile ? _sharePdf : _savePdfToDownloads),
                icon: _isPrinting ? const SizedBox.shrink() : Icon(isMobile ? Icons.share : Icons.save_alt),
                label: _isPrinting ? const CircularProgressIndicator(color: Colors.white) : Text(isMobile ? 'Compartir' : 'Guardar PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700], foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printDocument,
                icon: _isPrinting ? const SizedBox.shrink() : const Icon(Icons.print_rounded),
                label: _isPrinting ? const SizedBox.shrink() : const Text('Imprimir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketPage(Widget ticket) {
    const double thermalWidth = 210;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          elevation: 4,
          child: Container(
            padding: const EdgeInsets.all(8.0),
            width: thermalWidth, 
            color: Colors.white,
            child: ticket,
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    final int pageCount;
    if (widget.args.isDeliveryNote) {
      pageCount = 1;
    } else if (widget.args.isCajaPrint) {
      pageCount = 2;
    } else {
      pageCount = 3;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: _currentPage > 0 ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut) : null,
          ),
          ...List.generate(pageCount, (index) {
            return Container(
              width: 8.0, height: 8.0,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(shape: BoxShape.circle, color: _currentPage == index ? const Color(0xFF1E3A8A) : Colors.grey),
            );
          }),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: _currentPage < pageCount - 1 ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut) : null,
          ),
        ],
      ),
    );
  }
}

// --- Widgets de Plantillas de Ticket ---

class NotaVentaTicket extends StatelessWidget {
  final PrintPreviewArgs args;
  final Empresa empresa;
  final bool isCajaPrint;

  const NotaVentaTicket({super.key, required this.args, required this.empresa, required this.isCajaPrint});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final dateFormat = DateFormat('dd/MM/yy HH:mm');
    final detallesFiltrados = args.detalles.where((d) => d.tipoProducto.trim().toUpperCase() == (isCajaPrint ? 'C' : 'P')).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (args.logoData != null)
            Image.memory(args.logoData!, width: 40, height: 40),
          Center(child: Text(empresa.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
          Center(child: Text(empresa.direccion, style: const TextStyle(fontSize: 8), textAlign: TextAlign.center)),
          if (empresa.telefono.isNotEmpty && empresa.telefono != 'N/A')
            Center(child: Text('Tel: ${empresa.telefono}', style: const TextStyle(fontSize: 8))),
          const Divider(height: 10, thickness: 0.5),
          Center(child: Text(isCajaPrint ? 'CAJAS ENTREGADAS' : 'NOTA DE VENTA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9))),
          const Divider(height: 10, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nota: #${args.nota.idnota}', style: const TextStyle(fontSize: 8)),
                  const SizedBox(height: 1),
                  Text('Fecha: ${dateFormat.format(DateTime.parse(args.nota.regtimestamp))}', style: const TextStyle(fontSize: 8)),
                  const SizedBox(height: 1),
                  Text('Vendedor: ${args.nombreVendedor}', style: const TextStyle(fontSize: 8)),
                ],
              ),
            ],
          ),
          const Divider(height: 10, thickness: 0.5),
          Text('Cliente: ${args.nota.nombreCliente}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 8)),
          Text('ID: ${args.nota.idcliente}', style: const TextStyle(fontSize: 8)),
          const Divider(height: 10, thickness: 0.5),
          Row(
                      children: [
                        Expanded(flex: 2, child: Text('Cant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8))),
                        Expanded(flex: 5, child: Text(isCajaPrint ? 'Envase' : 'Producto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8))),
                        if (!isCajaPrint) Expanded(flex: 3, child: Text('P/U', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8), textAlign: TextAlign.right)),
                        if (!isCajaPrint) Expanded(flex: 3, child: Text('Importe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8), textAlign: TextAlign.right)),
                      ],
                    ),
                    const Divider(thickness: 1, color: Colors.black),
                    ...detallesFiltrados.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: Text(item.cantidad.toStringAsFixed(0), style: const TextStyle(fontSize: 8))),
                          Expanded(flex: 5, child: Text(item.nombreProducto, style: const TextStyle(fontSize: 8))),
                          if (!isCajaPrint) Expanded(flex: 3, child: Text(currencyFormat.format(item.precio), style: const TextStyle(fontSize: 8), textAlign: TextAlign.right)),
                          if (!isCajaPrint) Expanded(flex: 3, child: Text(currencyFormat.format(item.total), style: const TextStyle(fontSize: 8), textAlign: TextAlign.right)),
                        ],
                      ),
                    )),
                    const Divider(thickness: 1, color: Colors.black),
          
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(isCajaPrint ? 'TOTAL CAJAS: ' : 'TOTAL: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(isCajaPrint ? args.nota.total.toStringAsFixed(0) : currencyFormat.format(args.nota.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
          const SizedBox(height: 20),
          const Text('Recibí producto:', style: TextStyle(fontSize: 8)),
          const SizedBox(height: 20),
          const Text('________________________'),
          const Text('Nombre y Firma', style: TextStyle(fontSize: 8)),
        ],
      ),
    );
  }
}

class ReciboPagoTicket extends StatelessWidget {
  final PrintPreviewArgs args;
  final Empresa empresa;

  const ReciboPagoTicket({super.key, required this.args, required this.empresa});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final dateFormat = DateFormat('dd/MM/yy HH:mm');
    final bool isCaja = args.isCajaPrint; // Usar el nuevo flag

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (args.logoData != null)
            Image.memory(args.logoData!, width: 40, height: 40),
          Center(child: Text(empresa.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
          Center(child: Text(empresa.direccion, style: const TextStyle(fontSize: 8), textAlign: TextAlign.center)),
          if (empresa.telefono.isNotEmpty && empresa.telefono != 'N/A')
            Center(child: Text('Tel: ${empresa.telefono}', style: const TextStyle(fontSize: 8))),
          const Divider(height: 10, thickness: 0.5),
          Center(child: Text(isCaja ? 'DEVOLUCIÓN DE CAJAS' : 'RECIBO DE PAGO', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9))),
          const Divider(height: 10, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nota: #${args.nota.idnota}', style: const TextStyle(fontSize: 8)),
                  const SizedBox(height: 1),
                  Text('Fecha: ${dateFormat.format(DateTime.parse(args.nota.regtimestamp))}', style: const TextStyle(fontSize: 8)),
                  const SizedBox(height: 1),
                  Text('Vendedor: ${args.nombreVendedor}', style: const TextStyle(fontSize: 8)),
                ],
              ),
            ],
          ),
          const Divider(height: 10, thickness: 0.5),
          Text('Cliente: ${args.nota.nombreCliente}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 8)),
          Text('ID: ${args.nota.idcliente}', style: const TextStyle(fontSize: 8)),
          const Divider(height: 10, thickness: 0.5),
          _buildInfoRow(isCaja ? 'Forma de Devolución:' : 'Forma de pago:', args.formaDePago),
          const SizedBox(height: 4),
          if (isCaja) ...[
            _buildInfoRow(
              'Cajas que falta devolver:', // Saldo Anterior
              (args.cajasSaldoAnterior ?? 0).toStringAsFixed(0)
            ),
            const SizedBox(height: 4),
            _buildInfoRow(
              'Cajas devueltas:', // Cantidad Pagada
              (args.cajasEntregadas ?? 0).toStringAsFixed(0),
              isBold: true
            ),
            const SizedBox(height: 4),
            _buildInfoRow(
              'Cajas que le quedan por devolver:', // Saldo Actual
              (args.cajasSaldoActual ?? 0).toStringAsFixed(0)
            ),
          ] else ...[
            _buildInfoRow(
              'Saldo Anterior:',
              currencyFormat.format(args.saldoAnterior)
            ),
            const SizedBox(height: 4),
            _buildInfoRow(
              'Cantidad Pagada:',
              currencyFormat.format(args.montoPagado),
              isBold: true
            ),
            const SizedBox(height: 4),
            _buildInfoRow(
              'Saldo:',
              currencyFormat.format(args.nota.saldo)
            ),
          ],
          const Divider(height: 20, thickness: 0.5),
          const Text('Recibí:', style: TextStyle(fontSize: 8)),
          const SizedBox(height: 20),
          const Text('________________________'),
          Text(isCaja ? 'Firma del Cliente' : 'Firma del Vendedor', style: const TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 9)),
        Text(
          value,
          style: TextStyle(fontSize: 9, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
        ),
      ],
    );
  }
}

// --- Widgets de Plantillas de PDF (para la impresión) ---

class NotaVentaPdf extends pw.StatelessWidget {
  final PrintPreviewArgs args;
  final Empresa empresa;
  final bool isCajaPrint;

  NotaVentaPdf({required this.args, required this.empresa, required this.isCajaPrint});

  @override
  pw.Widget build(pw.Context context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final dateFormat = DateFormat('dd/MM/yy HH:mm');
    final detallesFiltrados = args.detalles.where((d) => d.tipoProducto.trim().toUpperCase() == (isCajaPrint ? 'C' : 'P')).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (args.logoData != null)
          pw.Image(pw.MemoryImage(args.logoData!), width: 40, height: 40),
        pw.Center(child: pw.Text(empresa.nombre, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
        pw.Center(child: pw.Text(empresa.direccion, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
        if (empresa.telefono.isNotEmpty && empresa.telefono != 'N/A')
          pw.Center(child: pw.Text('Tel: ${empresa.telefono}', style: const pw.TextStyle(fontSize: 8))),
        pw.Divider(height: 10, thickness: 0.5),
        pw.Center(child: pw.Text(isCajaPrint ? 'CAJAS ENTREGADAS' : 'NOTA DE VENTA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
        pw.Divider(height: 10, thickness: 0.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Nota: #${args.nota.idnota}', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 1),
                pw.Text('Fecha: ${dateFormat.format(DateTime.parse(args.nota.regtimestamp))}', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 1),
                pw.Text('Vendedor: ${args.nombreVendedor}', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ],
        ),
        pw.Divider(height: 10, thickness: 0.5),
        pw.Text('Cliente: ${args.nota.nombreCliente}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
        pw.Text('ID: ${args.nota.idcliente}', style: const pw.TextStyle(fontSize: 8)),
        pw.Divider(height: 10, thickness: 0.5),
        pw.Row(
          children: [
            pw.Expanded(flex: 2, child: pw.Text('Cant', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
            pw.Expanded(flex: 5, child: pw.Text(isCajaPrint ? 'Envase' : 'Producto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
            if (!isCajaPrint) pw.Expanded(flex: 3, child: pw.Text('P/U', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.right)),
            if (!isCajaPrint) pw.Expanded(flex: 3, child: pw.Text('Importe', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.right)),
          ],
        ),
        pw.Divider(thickness: 0.5, color: PdfColors.black),
        ...detallesFiltrados.map((item) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 2, child: pw.Text(item.cantidad.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 8))),
              pw.Expanded(flex: 5, child: pw.Text(item.nombreProducto, style: const pw.TextStyle(fontSize: 8))),
              if (!isCajaPrint) pw.Expanded(flex: 3, child: pw.Text(currencyFormat.format(item.precio), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
              if (!isCajaPrint) pw.Expanded(flex: 3, child: pw.Text(currencyFormat.format(item.total), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
            ],
          ),
        )),
        pw.Divider(thickness: 0.5, color: PdfColors.black),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(isCajaPrint ? 'TOTAL CAJAS: ' : 'TOTAL: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text(isCajaPrint ? args.nota.total.toStringAsFixed(0) : currencyFormat.format(args.nota.total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text('Recibí producto:', style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 20),
        pw.Text('________________________'),
        pw.Text('Nombre y Firma', style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }
}

class ReciboPagoPdf extends pw.StatelessWidget {
  final PrintPreviewArgs args;
  final Empresa empresa;

  ReciboPagoPdf({required this.args, required this.empresa});

  @override
  pw.Widget build(pw.Context context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final dateFormat = DateFormat('dd/MM/yy HH:mm');
    final bool isCaja = args.isCajaPrint;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (args.logoData != null)
          pw.Image(pw.MemoryImage(args.logoData!), width: 40, height: 40),
        pw.Center(child: pw.Text(empresa.nombre, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
        pw.Center(child: pw.Text(empresa.direccion, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
        if (empresa.telefono.isNotEmpty && empresa.telefono != 'N/A')
          pw.Center(child: pw.Text('Tel: ${empresa.telefono}', style: const pw.TextStyle(fontSize: 8))),
        pw.Divider(height: 10, thickness: 0.5),
        pw.Center(child: pw.Text(isCaja ? 'DEVOLUCIÓN DE CAJAS' : 'RECIBO DE PAGO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
        pw.Divider(height: 10, thickness: 0.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Nota: #${args.nota.idnota}', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 1),
                pw.Text('Fecha: ${dateFormat.format(DateTime.parse(args.nota.regtimestamp))}', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 1),
                pw.Text('Vendedor: ${args.nombreVendedor}', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ],
        ),
        pw.Divider(height: 10, thickness: 0.5),
        pw.Text('Cliente: ${args.nota.nombreCliente}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
        pw.Text('ID: ${args.nota.idcliente}', style: const pw.TextStyle(fontSize: 8)),
        pw.Divider(height: 10, thickness: 0.5),
        _buildInfoRow(isCaja ? 'Forma de Devolución:' : 'Forma de pago:', args.formaDePago),
        pw.SizedBox(height: 4),
        if (isCaja) ...[
          _buildInfoRow(
            'Cajas que falta devolver:', // Saldo Anterior
            (args.cajasSaldoAnterior ?? 0).toStringAsFixed(0)
          ),
          pw.SizedBox(height: 4),
          _buildInfoRow(
            'Cajas devueltas:', // Cantidad Pagada
            (args.cajasEntregadas ?? 0).toStringAsFixed(0),
            isBold: true
          ),
          pw.SizedBox(height: 4),
          _buildInfoRow(
            'Cajas que le quedan por devolver:', // Saldo Actual
            (args.cajasSaldoActual ?? 0).toStringAsFixed(0)
          ),
        ] else ...[
          _buildInfoRow(
            'Saldo Anterior:',
            currencyFormat.format(args.saldoAnterior)
          ),
          pw.SizedBox(height: 4),
          _buildInfoRow(
            'Cantidad Pagada:',
            currencyFormat.format(args.montoPagado),
            isBold: true
          ),
          pw.SizedBox(height: 4),
          _buildInfoRow(
            'Saldo:',
            currencyFormat.format(args.nota.saldo)
          ),
        ],
        pw.Divider(height: 20, thickness: 0.5),
        pw.Text('Recibí:', style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 20),
        pw.Text('________________________'),
        pw.Text(isCaja ? 'Firma del Cliente' : 'Firma del Vendedor', style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  pw.Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

