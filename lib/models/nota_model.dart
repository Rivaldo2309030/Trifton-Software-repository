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
    );
  }
}
