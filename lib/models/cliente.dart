class Cliente {
  final int? id;
  final String nombreCompleto;
  final String telefono;
  final String? email;
  final String? direccion;
  final String? notas;
  final DateTime createdAt;
  final DateTime updatedAt;

  Cliente({
    this.id,
    required this.nombreCompleto,
    required this.telefono,
    this.email,
    this.direccion,
    this.notas,
    required this.createdAt,
    required this.updatedAt,
  });

  // Validates phone format and cleans it
  static String cleanAndValidatePhone(String input) {
    String clean = input.trim().replaceAll(' ', '').replaceAll('-', '');
    if (clean.length == 10 && clean.startsWith('3')) {
      clean = '+57$clean';
    }
    final RegExp e164Regex = RegExp(r'^\+[1-9]\d{6,14}$');
    if (!e164Regex.hasMatch(clean)) {
      throw FormatException(
          'Teléfono no es válido en formato internacional E.164 (ej. +573206672858).');
    }
    return clean;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre_completo': nombreCompleto,
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
      'notas': notas,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'] as int?,
      nombreCompleto: map['nombre_completo'] as String,
      telefono: map['telefono'] as String,
      email: map['email'] as String?,
      direccion: map['direccion'] as String?,
      notas: map['notas'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Cliente copyWith({
    int? id,
    String? nombreCompleto,
    String? telefono,
    String? email,
    String? direccion,
    String? notas,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      direccion: direccion ?? this.direccion,
      notas: notas ?? this.notas,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
