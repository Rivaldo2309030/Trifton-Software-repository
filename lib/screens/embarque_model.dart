class Embarque {
  final int id;
  final int idalmacen;
  final int idalmacenista;
  final int idunidad;
  final int idcliente;
  final double total;

  Embarque({
    required this.id,
    required this.idalmacen,
    required this.idalmacenista,
    required this.idunidad,
    required this.idcliente,
    required this.total,
  });

  factory Embarque.fromJson(Map<String, dynamic> json) {
    return Embarque(
      id: int.parse(json['id']),
      idalmacen: int.parse(json['idalmacen']),
      idalmacenista: int.parse(json['idalmacenista']),
      idunidad: int.parse(json['idunidad']),
      idcliente: int.parse(json['idcliente']),
      total: double.parse(json['total']),
    );
  }
}