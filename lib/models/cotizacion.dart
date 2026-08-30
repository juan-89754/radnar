class Cotizacion {
  final int? id;
  final int ordenId;
  final String titulo;
  final String estado;
  final String? notasCliente;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const Map<String, String> nombresEstados = {
    'borrador': 'Borrador',
    'enviada': 'Enviada al Cliente',
    'aprobada': 'Aprobada por el Cliente',
    'rechazada': 'Rechazada por el Cliente',
  };

  Cotizacion({
    this.id,
    required this.ordenId,
    this.titulo = 'Cotización de Diagnóstico y Reparación',
    this.estado = 'borrador',
    this.notasCliente,
    required this.createdAt,
    required this.updatedAt,
  });

  String get estadoDisplay => nombresEstados[estado] ?? estado;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'orden_id': ordenId,
      'titulo': titulo,
      'estado': estado,
      'notas_cliente': notasCliente,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Cotizacion.fromMap(Map<String, dynamic> map) {
    return Cotizacion(
      id: map['id'] as int?,
      ordenId: map['orden_id'] as int,
      titulo: map['titulo'] as String,
      estado: map['estado'] as String,
      notasCliente: map['notas_cliente'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Cotizacion copyWith({
    int? id,
    int? ordenId,
    String? titulo,
    String? estado,
    String? notasCliente,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Cotizacion(
      id: id ?? this.id,
      ordenId: ordenId ?? this.ordenId,
      titulo: titulo ?? this.titulo,
      estado: estado ?? this.estado,
      notasCliente: notasCliente ?? this.notasCliente,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
