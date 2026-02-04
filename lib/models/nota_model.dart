class Nota {
  final int idnota;
  final int idcliente; // Añadido para la lógica offline
  final double total;
  final double saldo;
  final String regtimestamp;
  final String nombreCliente;
  final int idalmacen; // ID del almacén de salida
  final String nombreAlmacenSalida;
  final String? nombreAlmacenOrigen;
  final double montoPagadoAcumulado;
  final String? nombreVendedor;
  final String? lastPaymentType;
  final String tipoProducto; // Nuevo campo
  final double totalCajas;
  final double saldoCajas;
  final double cajasDevueltas;

  Nota({
    required this.idnota,
    required this.idcliente,
    required this.total,
    required this.saldo,
    required this.regtimestamp,
    required this.nombreCliente,
    required this.idalmacen,
    required this.nombreAlmacenSalida,
    this.nombreAlmacenOrigen,
    required this.montoPagadoAcumulado,
    this.nombreVendedor,
    this.lastPaymentType,
    required this.tipoProducto, // Requerido
    this.totalCajas = 0.0,
    this.saldoCajas = 0.0,
    this.cajasDevueltas = 0.0,
  });

  factory Nota.fromJson(Map<String, dynamic> json) {
    return Nota(
      idnota: int.tryParse(json['idnota'].toString()) ?? 0,
      idcliente: int.tryParse(json['idcliente'].toString()) ?? 0,
      total: double.tryParse(json['total'].toString()) ?? 0.0,
      saldo: double.tryParse(json['saldo'].toString()) ?? 0.0,
      regtimestamp: json['regtimestamp'] ?? '',
      nombreCliente: json['nombre_cliente'] ?? 'N/A',
      idalmacen: int.tryParse(json['idalmacen'].toString()) ?? 0,
      nombreAlmacenSalida: json['nombre_almacen_salida'] ?? 'N/A',
      nombreAlmacenOrigen: json['nombre_almacen_origen'],
      montoPagadoAcumulado: double.tryParse(json['monto_pagado_acumulado'].toString()) ?? 0.0,
      nombreVendedor: json['nombre_vendedor'],
      lastPaymentType: json['last_payment_type'],
      tipoProducto: json['tipo_producto'] ?? 'P',
      totalCajas: double.tryParse(json['total_cajas']?.toString() ?? '0') ?? 0.0,
      saldoCajas: double.tryParse(json['saldo_cajas']?.toString() ?? '0') ?? 0.0,
      cajasDevueltas: double.tryParse(json['cajas_devueltas']?.toString() ?? '0') ?? 0.0,
    );
  }

  // Nuevo factory para crear desde el mapa de la base de datos local
  factory Nota.fromMap(Map<String, dynamic> map) {
    return Nota(
      idnota: map['idnota'],
      idcliente: map['idcliente'],
      total: map['total'],
      saldo: map['saldo'],
      regtimestamp: map['regtimestamp'],
      nombreCliente: map['nombre_cliente'],
      idalmacen: map['idalmacen'],
      nombreAlmacenSalida: map['nombre_almacen_salida'],
      nombreAlmacenOrigen: map['nombre_almacen_origen'],
      montoPagadoAcumulado: map['monto_pagado_acumulado'] ?? 0.0,
      nombreVendedor: map['nombre_vendedor'],
      lastPaymentType: map['last_payment_type'],
      tipoProducto: map['tipo_producto'] ?? 'P',
      // En modo offline estos valores podrían no estar calculados, por ahora default 0
      totalCajas: 0.0, 
      saldoCajas: 0.0,
      cajasDevueltas: 0.0,
    );
  }

  Nota copyWith({
    int? idnota,
    int? idcliente,
    double? total,
    double? saldo,
    String? regtimestamp,
    String? nombreCliente,
    int? idalmacen,
    String? nombreAlmacenSalida,
    String? nombreAlmacenOrigen,
    double? montoPagadoAcumulado,
    String? nombreVendedor,
    String? lastPaymentType,
    String? tipoProducto, // Nuevo
    double? totalCajas,
    double? saldoCajas,
    double? cajasDevueltas,
  }) {
    return Nota(
      idnota: idnota ?? this.idnota,
      idcliente: idcliente ?? this.idcliente,
      total: total ?? this.total,
      saldo: saldo ?? this.saldo,
      regtimestamp: regtimestamp ?? this.regtimestamp,
      nombreCliente: nombreCliente ?? this.nombreCliente,
      idalmacen: idalmacen ?? this.idalmacen,
      nombreAlmacenSalida: nombreAlmacenSalida ?? this.nombreAlmacenSalida,
      nombreAlmacenOrigen: nombreAlmacenOrigen ?? this.nombreAlmacenOrigen,
      montoPagadoAcumulado: montoPagadoAcumulado ?? this.montoPagadoAcumulado,
      nombreVendedor: nombreVendedor ?? this.nombreVendedor,
      lastPaymentType: lastPaymentType ?? this.lastPaymentType,
      tipoProducto: tipoProducto ?? this.tipoProducto,
      totalCajas: totalCajas ?? this.totalCajas,
      saldoCajas: saldoCajas ?? this.saldoCajas,
      cajasDevueltas: cajasDevueltas ?? this.cajasDevueltas,
    );
  }
}
