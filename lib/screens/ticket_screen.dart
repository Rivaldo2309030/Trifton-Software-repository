import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:distribuidora/models/nota_model.dart';
import 'package:distribuidora/screens/nota_detail_screen.dart'; // Re-using NotaDetalle model

class TicketScreen extends StatelessWidget {
  final Nota nota;
  final List<NotaDetalle> detalles;

  const TicketScreen({
    super.key,
    required this.nota,
    required this.detalles,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket de Venta'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Center(
                  child: Text(
                    'Distribuidora Triton',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const Center(child: Text('RFC: ABC123456XYZ')),
                const Center(child: Text('Calle Ficticia 123, Colonia Centro')),
                const SizedBox(height: 20),

                // Info de la Nota
                Text('Nota de Venta: #${nota.idnota}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(nota.regtimestamp))}'),
                const SizedBox(height: 10),
                Text('Cliente: ${nota.nombreCliente}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Almacén de Salida: ${nota.nombreAlmacenSalida}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                if (nota.nombreAlmacenOrigen != null && nota.nombreAlmacenOrigen != nota.nombreAlmacenSalida)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('Almacén de Origen: ${nota.nombreAlmacenOrigen}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                  ),
                const Divider(height: 20, thickness: 1),

                // Tabla de Productos Flexible
                _buildHeaderRow(),
                const Divider(),
                Column(
                  children: detalles.map((item) => _buildProductRow(item, currencyFormat)).toList(),
                ),
                const Divider(height: 20, thickness: 1),

                // Totales
                _buildTotalRow('Total:', currencyFormat.format(nota.total)),
                const SizedBox(height: 8),
                _buildTotalRow('Saldo Pendiente:', currencyFormat.format(nota.saldo), isBold: true),
                const SizedBox(height: 20),

                // Footer
                const Center(child: Text('¡Gracias por su compra!')),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // En una app real, aquí se llamaría a un plugin de impresión
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Imprimiendo ticket... (Simulación)'),
              backgroundColor: Colors.teal,
            ),
          );
        },
        label: const Text('IMPRIMIR'),
        icon: const Icon(Icons.print),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildHeaderRow() {
    return const Row(
      children: [
        SizedBox(width: 50, child: Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(child: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold))),
        SizedBox(width: 80, child: Text('P/U', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
        SizedBox(width: 90, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildProductRow(NotaDetalle item, NumberFormat currencyFormat) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 50, child: Text(item.cantidad.toString())),
          Expanded(child: Text(item.nombreProducto)),
          SizedBox(width: 80, child: Text(currencyFormat.format(item.precio), textAlign: TextAlign.right)),
          SizedBox(width: 90, child: Text(currencyFormat.format(item.total), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: 120,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
