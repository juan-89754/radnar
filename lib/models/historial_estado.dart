class HistorialEstado {
  final int? id;
  final int ordenId;
  final String estadoAnterior;
  final String estadoNuevo;
  final String? notasTransicion;
  final DateTime timestamp;

  HistorialEstado({
    this.id,
    required this.ordenId,
    required this.estadoAnterior,
    required this.estadoNuevo,
    this.notasTransicion,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'orden_id': ordenId,
      'estado_anterior': estadoAnterior,
      'estado_nuevo': estadoNuevo,
      'notas_transicion': notasTransicion,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory HistorialEstado.fromMap(Map<String, dynamic> map) {
    return HistorialEstado(
      id: map['id'] as int?,
      ordenId: map['orden_id'] as int,
      estadoAnterior: map['estado_anterior'] as String,
      estadoNuevo: map['estado_nuevo'] as String,
      notasTransicion: map['notas_transicion'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
