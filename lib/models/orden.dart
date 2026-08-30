class Orden {
  final int? id;
  final String codigoOrden;
  final int clienteId;
  final int equipoId;
  final int? tecnicoId;
  final String estado;
  final String motivoIngreso;
  final String? accesoriosIncluidos;
  final DateTime fechaIngreso;
  final DateTime updatedAt;

  static const List<String> estadosBloqueados = [
    'en_reparacion',
    'en_pruebas',
    'listo_entrega',
    'entregado_cobrado'
  ];

  static const Map<String, String> nombresEstados = {
    'ingresado': '1. Ingresado',
    'en_diagnostico': '2. En diagnóstico',
    'cotizado': '3. Cotizado / Esperando aprobación',
    'aprobado': '4. Aprobado / Repuestos pedidos',
    'en_reparacion': '5. En reparación',
    'en_pruebas': '6. En pruebas (stress test)',
    'listo_entrega': '7. Listo para entrega',
    'entregado_cobrado': '8. Entregado y cobrado',
  };

  Orden({
    this.id,
    required this.codigoOrden,
    required this.clienteId,
    required this.equipoId,
    this.tecnicoId,
    this.estado = 'ingresado',
    required this.motivoIngreso,
    this.accesoriosIncluidos,
    required this.fechaIngreso,
    required this.updatedAt,
  });

  bool get isLocked => estadosBloqueados.contains(estado);

  String get estadoDisplay => nombresEstados[estado] ?? estado;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'codigo_orden': codigoOrden,
      'cliente_id': clienteId,
      'equipo_id': equipoId,
      'tecnico_id': tecnicoId,
      'estado': estado,
      'motivo_ingreso': motivoIngreso,
      'accesorios_incluidos': accesoriosIncluidos,
      'fecha_ingreso': fechaIngreso.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Orden.fromMap(Map<String, dynamic> map) {
    return Orden(
      id: map['id'] as int?,
      codigoOrden: map['codigo_orden'] as String,
      clienteId: map['cliente_id'] as int,
      equipoId: map['equipo_id'] as int,
      tecnicoId: map['tecnico_id'] as int?,
      estado: map['estado'] as String,
      motivoIngreso: map['motivo_ingreso'] as String,
      accesoriosIncluidos: map['accesorios_incluidos'] as String?,
      fechaIngreso: DateTime.parse(map['fecha_ingreso'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Orden copyWith({
    int? id,
    String? codigoOrden,
    int? clienteId,
    int? equipoId,
    int? tecnicoId,
    String? estado,
    String? motivoIngreso,
    String? accesoriosIncluidos,
    DateTime? fechaIngreso,
    DateTime? updatedAt,
  }) {
    return Orden(
      id: id ?? this.id,
      codigoOrden: codigoOrden ?? this.codigoOrden,
      clienteId: clienteId ?? this.clienteId,
      equipoId: equipoId ?? this.equipoId,
      tecnicoId: tecnicoId ?? this.tecnicoId,
      estado: estado ?? this.estado,
      motivoIngreso: motivoIngreso ?? this.motivoIngreso,
      accesoriosIncluidos: accesoriosIncluidos ?? this.accesoriosIncluidos,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
