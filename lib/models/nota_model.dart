class Nota {
  final int idnota;
  final double total;
  final double saldo;
  final String regtimestamp;
  final String nombreCliente;

  Nota({
    required this.idnota,
    required this.total,
    required this.saldo,
    required this.regtimestamp,
    required this.nombreCliente,
  });

  factory Nota.fromJson(Map<String, dynamic> json) {
    return Nota(
      idnota: int.tryParse(json['idnota'].toString()) ?? 0,
      total: double.tryParse(json['total'].toString()) ?? 0.0,
      saldo: double.tryParse(json['saldo'].toString()) ?? 0.0,
      regtimestamp: json['regtimestamp'] ?? '',
      nombreCliente: json['nombre_cliente'] ?? 'N/A',
    );
  }
}
