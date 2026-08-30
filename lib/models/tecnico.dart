class Tecnico {
  final int? id;
  final String nombreCompleto;
  final String? telefono;
  final bool activo;
  final DateTime createdAt;

  Tecnico({
    this.id,
    required this.nombreCompleto,
    this.telefono,
    this.activo = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre_completo': nombreCompleto,
      'telefono': telefono,
      'activo': activo ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Tecnico.fromMap(Map<String, dynamic> map) {
    return Tecnico(
      id: map['id'] as int?,
      nombreCompleto: map['nombre_completo'] as String,
      telefono: map['telefono'] as String?,
      activo: (map['activo'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Tecnico copyWith({
    int? id,
    String? nombreCompleto,
    String? telefono,
    bool? activo,
    DateTime? createdAt,
  }) {
    return Tecnico(
      id: id ?? this.id,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      telefono: telefono ?? this.telefono,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
