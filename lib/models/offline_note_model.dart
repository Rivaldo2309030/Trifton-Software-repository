import 'package:distribuidora/models/nota_model.dart'; // Import Nota model for conversion

class NotaOffline {
  final int idnota;
  final double total;
  final double saldo;
  final String regtimestamp;
  final String nombreCliente;
  final int idalmacen;
  final String nombreAlmacenSalida;
  final String? nombreAlmacenOrigen;
  final double montoPagadoAcumulado;
  final String? nombreVendedor;

  NotaOffline({
    required this.idnota,
    required this.total,
    required this.saldo,
    required this.regtimestamp,
    required this.nombreCliente,
    required this.idalmacen,
    required this.nombreAlmacenSalida,
    this.nombreAlmacenOrigen,
    required this.montoPagadoAcumulado,
    this.nombreVendedor,
  });

  // Convert from Nota (server model) to NotaOffline (local model)
  factory NotaOffline.fromNota(Nota nota) {
    return NotaOffline(
      idnota: nota.idnota,
      total: nota.total,
      saldo: nota.saldo,
      regtimestamp: nota.regtimestamp,
      nombreCliente: nota.nombreCliente,
      idalmacen: nota.idalmacen,
      nombreAlmacenSalida: nota.nombreAlmacenSalida,
      nombreAlmacenOrigen: nota.nombreAlmacenOrigen,
      montoPagadoAcumulado: nota.montoPagadoAcumulado,
      nombreVendedor: nota.nombreVendedor,
    );
  }

  // Convert from SQLite Map to NotaOffline
  factory NotaOffline.fromMap(Map<String, dynamic> map) {
    return NotaOffline(
      idnota: map['idnota'] as int,
      total: map['total'] as double,
      saldo: map['saldo'] as double,
      regtimestamp: map['regtimestamp'] as String,
      nombreCliente: map['nombre_cliente'] as String,
      idalmacen: map['idalmacen'] as int,
      nombreAlmacenSalida: map['nombre_almacen_salida'] as String,
      nombreAlmacenOrigen: map['nombre_almacen_origen'] as String?,
      montoPagadoAcumulado: map['monto_pagado_acumulado'] as double,
      nombreVendedor: map['nombre_vendedor'] as String?,
    );
  }

  // Convert NotaOffline to SQLite Map
  Map<String, dynamic> toMap() {
    return {
      'idnota': idnota,
      'total': total,
      'saldo': saldo,
      'regtimestamp': regtimestamp,
      'nombre_cliente': nombreCliente,
      'idalmacen': idalmacen,
      'nombre_almacen_salida': nombreAlmacenSalida,
      'nombre_almacen_origen': nombreAlmacenOrigen,
      'monto_pagado_acumulado': montoPagadoAcumulado,
      'nombre_vendedor': nombreVendedor,
    };
  }
}

class NotaDetalleOffline {
  final int iddetalle; // This will be auto-incremented in SQLite, but we need it for server sync
  final int idnotaFk;
  final double cantidad;
  final double precio;
  final double total;
  final int idestatus;
  final String nombreProducto;
  final String nombreUnidad;

  NotaDetalleOffline({
    required this.iddetalle,
    required this.idnotaFk,
    required this.cantidad,
    required this.precio,
    required this.total,
    required this.idestatus,
    required this.nombreProducto,
    required this.nombreUnidad,
  });

  // Convert from NotaDetalle (server model) to NotaDetalleOffline (local model)
  factory NotaDetalleOffline.fromNotaDetalle(dynamic detalle, int idnotaFk) {
    return NotaDetalleOffline(
      iddetalle: detalle.iddetalle, // Assuming iddetalle is available in the server model
      idnotaFk: idnotaFk,
      cantidad: detalle.cantidad,
      precio: detalle.precio,
      total: detalle.total,
      idestatus: detalle.idestatus,
      nombreProducto: detalle.nombreProducto,
      nombreUnidad: detalle.nombreUnidad,
    );
  }

  // Convert from SQLite Map to NotaDetalleOffline
  factory NotaDetalleOffline.fromMap(Map<String, dynamic> map) {
    return NotaDetalleOffline(
      iddetalle: map['iddetalle'] as int,
      idnotaFk: map['idnota_fk'] as int,
      cantidad: map['cantidad'] as double,
      precio: map['precio'] as double,
      total: map['total'] as double,
      idestatus: map['idestatus'] as int,
      nombreProducto: map['nombreproducto'] as String,
      nombreUnidad: map['nombreunidad'] as String,
    );
  }

  // Convert NotaDetalleOffline to SQLite Map
  Map<String, dynamic> toMap() {
    return {
      // 'iddetalle': iddetalle, // iddetalle is auto-incremented, so don't include for insert
      'idnota_fk': idnotaFk,
      'cantidad': cantidad,
      'precio': precio,
      'total': total,
      'idestatus': idestatus,
      'nombreproducto': nombreProducto,
      'nombreunidad': nombreUnidad,
    };
  }
}
