import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  final bool isDeliveryNote; // Nuevo: indica si es una nota de surtido

  PrintPreviewArgs({
    required this.nota,
    required this.detalles,
    required this.nombreVendedor,
    required this.montoPagado,
    required this.formaDePago,
    required this.saldoAnterior,
    this.isDeliveryNote = false, // Valor por defecto
  });
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
  late Future<Empresa> _empresaFuture;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _empresaFuture = _fetchEmpresa();
  }

  Future<Empresa> _fetchEmpresa() async {
    final dbHelper = DatabaseHelper.instance;
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}api_datos_empresa.php'));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final empresaData = decoded['data'];
          // Guardar en la base de datos local para uso offline
          await dbHelper.saveEmpresaInfo(empresaData);
          return Empresa.fromJson(empresaData);
        }
      }
      // Si la API falla pero no es una excepción de red, intentar cargar desde local
      final localData = await dbHelper.getEmpresaInfo();
      if (localData != null) {
        return Empresa.fromJson(localData);
      }
    } catch (e) {
      // Si hay una excepción (ej. sin red), intentar cargar desde local
      final localData = await dbHelper.getEmpresaInfo();
      if (localData != null) {
        return Empresa.fromJson(localData);
      }
    }
    // Si todo falla, devolver datos por defecto
    return Empresa(); 
  }

  Future<void> _savePdfToDownloads() async {
    setState(() => _isPrinting = true);

    try {
      final doc = pw.Document();
      final empresa = await _empresaFuture;

      const pageFormat = PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm);

      if (widget.args.isDeliveryNote) {
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => NotaVentaPdf(args: widget.args, empresa: empresa)));
      } else {
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => NotaVentaPdf(args: widget.args, empresa: empresa)));
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => NotaVentaPdf(args: widget.args, empresa: empresa)));
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => ReciboPagoPdf(args: widget.args, empresa: empresa)));
      }

      // Sanitize the client name for the filename
      final sanitizedClientName = widget.args.nota.nombreCliente.replaceAll(RegExp(r'[^a-zA-Z0-9 ._-]'), '').trim();
      final String filename = '${widget.args.nota.idnota}-${sanitizedClientName}.pdf';

      // Get the downloads directory
      final Directory? downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception("No se pudo encontrar el directorio de descargas.");
      }
      
      final String path = '${downloadsDir.path}/$filename';

      // Save the file
      final file = File(path);
      await file.writeAsBytes(await doc.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Guardado en Descargas: $filename'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al guardar el PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _printDocument() async {
    setState(() => _isPrinting = true);
    try {
      final doc = pw.Document();
      final empresa = await _empresaFuture;
      const pageFormat = PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm);

      if (widget.args.isDeliveryNote) {
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => NotaVentaPdf(args: widget.args, empresa: empresa)));
      } else {
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => NotaVentaPdf(args: widget.args, empresa: empresa)));
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => NotaVentaPdf(args: widget.args, empresa: empresa)));
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => ReciboPagoPdf(args: widget.args, empresa: empresa)));
      }

      final sanitizedClientName = widget.args.nota.nombreCliente.replaceAll(RegExp(r'[^a-zA-Z0-9 ._-]'), '').trim();
      final String filename = '${widget.args.nota.idnota}-${sanitizedClientName}.pdf';

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: filename,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Documento enviado a la impresora.'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al imprimir: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _isPrinting = true);
    try {
      final doc = pw.Document();
      final empresa = await _empresaFuture;

      const pageFormat = PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm);

      if (widget.args.isDeliveryNote) {
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => NotaVentaPdf(args: widget.args, empresa: empresa)));
      } else {
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => NotaVentaPdf(args: widget.args, empresa: empresa)));
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => NotaVentaPdf(args: widget.args, empresa: empresa)));
        doc.addPage(pw.Page(pageFormat: pageFormat, build: (pw.Context context) => ReciboPagoPdf(args: widget.args, empresa: empresa)));
      }

      final sanitizedClientName = widget.args.nota.nombreCliente.replaceAll(RegExp(r'[^a-zA-Z0-9 ._-]'), '').trim();
      final String filename = '${widget.args.nota.idnota}-${sanitizedClientName}.pdf';

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: filename,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al compartir PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
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
      body: FutureBuilder<Empresa>(
        future: _empresaFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final empresa = snapshot.data ?? Empresa();

          return Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: widget.args.isDeliveryNote
                      ? [
                          _buildTicketPage(NotaVentaTicket(args: widget.args, empresa: empresa)),
                        ]
                      : [
                          _buildTicketPage(NotaVentaTicket(args: widget.args, empresa: empresa)),
                          _buildTicketPage(NotaVentaTicket(args: widget.args, empresa: empresa)),
                          _buildTicketPage(ReciboPagoTicket(args: widget.args, empresa: empresa)),
                        ],                ),
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
                icon: _isPrinting
                    ? const SizedBox.shrink()
                    : Icon(isMobile ? Icons.share : Icons.save_alt),
                label: _isPrinting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isMobile ? 'Compartir' : 'Guardar PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printDocument,
                icon: _isPrinting ? const SizedBox.shrink() : const Icon(Icons.print_rounded),
                label: _isPrinting
                    ? const SizedBox.shrink()
                    : const Text('Imprimir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketPage(Widget ticket) {
    // Un ancho de ~210-220px es una buena aproximación para 58mm
    const double thermalWidth = 210;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          elevation: 4,
          child: Container(
            padding: const EdgeInsets.all(8.0), // Reducir padding para más espacio
            width: thermalWidth, 
            color: Colors.white,
            child: ticket,
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    final int pageCount = widget.args.isDeliveryNote ? 1 : 3;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botón de Anterior
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: _currentPage > 0
                ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
          ),
          // Indicadores de puntos
          ...List.generate(pageCount, (index) {
            return Container(
              width: 8.0,
              height: 8.0,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index ? const Color(0xFF1E3A8A) : Colors.grey,
              ),
            );
          }),
          // Botón de Siguiente
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: _currentPage < pageCount - 1
                ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
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

  const NotaVentaTicket({super.key, required this.args, required this.empresa});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final dateFormat = DateFormat('dd/MM/yy HH:mm');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Center(child: Text(empresa.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
          Center(child: Text(empresa.direccion, style: const TextStyle(fontSize: 8), textAlign: TextAlign.center)),
          Center(child: Text('Tel: $empresa.telefono', style: const TextStyle(fontSize: 8))),
          const Divider(height: 10, thickness: 0.5),
          Text('Nota: #${args.nota.idnota}', style: const TextStyle(fontSize: 8)),
          Text('Fecha: ${dateFormat.format(DateTime.parse(args.nota.regtimestamp))}', style: const TextStyle(fontSize: 8)),
          Text('Vendedor: ${args.nombreVendedor}', style: const TextStyle(fontSize: 8)),
          const Divider(height: 10, thickness: 0.5),

          // Cuerpo
          const Row(
            children: [
              Expanded(flex: 1, child: Text('Cant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8))),
              Expanded(flex: 5, child: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8))),
              Expanded(flex: 2, child: Text('Importe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8), textAlign: TextAlign.right)),
            ],
          ),
          const Divider(thickness: 1, color: Colors.black),
          ...args.detalles.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: Text(item.cantidad.toStringAsFixed(0), style: const TextStyle(fontSize: 8))),
                Expanded(flex: 5, child: Text(item.nombreProducto, style: const TextStyle(fontSize: 8))),
                Expanded(flex: 2, child: Text(currencyFormat.format(item.total), style: const TextStyle(fontSize: 8), textAlign: TextAlign.right)),
              ],
            ),
          )),
          const Divider(thickness: 1, color: Colors.black),

          // Pie
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('TOTAL: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(currencyFormat.format(args.nota.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Center(child: Text(empresa.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
          Center(child: Text(empresa.direccion, style: const TextStyle(fontSize: 8), textAlign: TextAlign.center)),
          Center(child: Text('Tel: $empresa.telefono', style: const TextStyle(fontSize: 8))),
          const Divider(height: 10, thickness: 0.5),
          const Center(child: Text('RECIBO DE PAGO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9))),
          const Divider(height: 10, thickness: 0.5),
          Text('Nota: #${args.nota.idnota}', style: const TextStyle(fontSize: 8)),
          Text('Fecha: ${dateFormat.format(DateTime.parse(args.nota.regtimestamp))}', style: const TextStyle(fontSize: 8)),
          const Divider(height: 10, thickness: 0.5),

          // Cuerpo
          _buildInfoRow('Forma de pago:', args.formaDePago),
          const SizedBox(height: 4),
          _buildInfoRow('Saldo Anterior:', currencyFormat.format(args.saldoAnterior)),
          const SizedBox(height: 4),
          _buildInfoRow('Cantidad Pagada:', currencyFormat.format(args.montoPagado), isBold: true),
          const SizedBox(height: 4),
          _buildInfoRow('Saldo:', currencyFormat.format(args.saldoAnterior - args.montoPagado)),
          const Divider(height: 20, thickness: 0.5),

          // Pie
          const Text('Recibí pago:', style: TextStyle(fontSize: 8)),
          const SizedBox(height: 20),
          const Text('________________________'),
          const Text('Firma del Vendedor', style: TextStyle(fontSize: 8)),
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
          style: TextStyle(
            fontSize: 9,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// --- Widgets de Plantillas de PDF (para la impresión) ---

class NotaVentaPdf extends pw.StatelessWidget {
  final PrintPreviewArgs args;
  final Empresa empresa;

  NotaVentaPdf({required this.args, required this.empresa});

  @override
  pw.Widget build(pw.Context context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final dateFormat = DateFormat('dd/MM/yy HH:mm');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(child: pw.Text(empresa.nombre, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
        pw.Center(child: pw.Text(empresa.direccion, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
        pw.Center(child: pw.Text('Tel: $empresa.telefono', style: const pw.TextStyle(fontSize: 8))),
        pw.Divider(height: 10, thickness: 0.5),
        pw.Text('Nota: #${args.nota.idnota}', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Fecha: ${dateFormat.format(DateTime.parse(args.nota.regtimestamp))}', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Vendedor: ${args.nombreVendedor}', style: const pw.TextStyle(fontSize: 8)),
        pw.Divider(height: 10, thickness: 0.5),

        // -- Encabezado de productos --
        pw.Row(
          children: [
            pw.Expanded(flex: 1, child: pw.Text('Cant', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
            pw.Expanded(flex: 5, child: pw.Text('Producto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
            pw.Expanded(flex: 2, child: pw.Text('Importe', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.right)),
          ],
        ),
        pw.Divider(thickness: 0.5, color: PdfColors.black),

        // -- Lista de productos --
        ...args.detalles.map((item) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 1, child: pw.Text(item.cantidad.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 8))),
              pw.Expanded(flex: 5, child: pw.Text(item.nombreProducto, style: const pw.TextStyle(fontSize: 8))),
              pw.Expanded(flex: 2, child: pw.Text(currencyFormat.format(item.total), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
            ],
          ),
        )),
        pw.Divider(thickness: 0.5, color: PdfColors.black),

        // -- Totales --
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('TOTAL: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text(currencyFormat.format(args.nota.total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
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

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(child: pw.Text(empresa.nombre, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
        pw.Center(child: pw.Text(empresa.direccion, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
        pw.Center(child: pw.Text('Tel: ${empresa.telefono}', style: const pw.TextStyle(fontSize: 8))),
        pw.Divider(height: 10, thickness: 0.5),
        pw.Center(child: pw.Text('RECIBO DE PAGO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
        pw.Divider(height: 10, thickness: 0.5),
        pw.Text('Nota: #${args.nota.idnota}', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Fecha: ${dateFormat.format(DateTime.parse(args.nota.regtimestamp))}', style: const pw.TextStyle(fontSize: 8)),
        pw.Divider(height: 10, thickness: 0.5),
        _buildInfoRow('Forma de pago:', args.formaDePago),
        pw.SizedBox(height: 4),
        _buildInfoRow('Saldo Anterior:', currencyFormat.format(args.saldoAnterior)),
        pw.SizedBox(height: 4),
        _buildInfoRow('Cantidad Pagada:', currencyFormat.format(args.montoPagado), isBold: true),
        pw.SizedBox(height: 4),
        _buildInfoRow('Saldo:', currencyFormat.format(args.saldoAnterior - args.montoPagado)),
        pw.Divider(height: 20, thickness: 0.5),
        pw.Text('Recibí pago:', style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 20),
        pw.Text('________________________'),
        pw.Text('Firma del Vendedor', style: const pw.TextStyle(fontSize: 8)),
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