import '../services/encryption_helper.dart';

class Equipo {
  final int? id;
  final int clienteId;
  final String tipo;
  final String marca;
  final String modelo;
  final String? numeroSerie;
  final String? pinCifrado;
  final String? procesador;
  final String? ram;
  final String? almacenamiento;
  final DateTime createdAt;
  final DateTime updatedAt;

  Equipo({
    this.id,
    required this.clienteId,
    required this.tipo,
    required this.marca,
    required this.modelo,
    this.numeroSerie,
    this.pinCifrado,
    this.procesador,
    this.ram,
    this.almacenamiento,
    required this.createdAt,
    required this.updatedAt,
  });

  // Getter to easily read decrypted PIN
  String get pinPlano {
    return pinCifrado != null ? EncryptionHelper.decrypt(pinCifrado!) : '';
  }

  // Helper factory to create a new Equipo with plain PIN
  factory Equipo.create({
    int? id,
    required int clienteId,
    required String tipo,
    required String marca,
    required String modelo,
    String? numeroSerie,
    String? pinPlano,
    String? procesador,
    String? ram,
    String? almacenamiento,
  }) {
    final now = DateTime.now();
    return Equipo(
      id: id,
      clienteId: clienteId,
      tipo: tipo,
      marca: marca,
      modelo: modelo,
      numeroSerie: numeroSerie,
      pinCifrado: pinPlano != null && pinPlano.isNotEmpty
          ? EncryptionHelper.encrypt(pinPlano)
          : null,
      procesador: procesador,
      ram: ram,
      almacenamiento: almacenamiento,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cliente_id': clienteId,
      'tipo': tipo,
      'marca': marca,
      'modelo': modelo,
      'numero_serie': numeroSerie,
      'pin_cifrado': pinCifrado,
      'procesador': procesador,
      'ram': ram,
      'almacenamiento': almacenamiento,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Equipo.fromMap(Map<String, dynamic> map) {
    return Equipo(
      id: map['id'] as int?,
      clienteId: map['cliente_id'] as int,
      tipo: map['tipo'] as String,
      marca: map['marca'] as String,
      modelo: map['modelo'] as String,
      numeroSerie: map['numero_serie'] as String?,
      pinCifrado: map['pin_cifrado'] as String?,
      procesador: map['procesador'] as String?,
      ram: map['ram'] as String?,
      almacenamiento: map['almacenamiento'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Equipo copyWith({
    int? id,
    int? clienteId,
    String? tipo,
    String? marca,
    String? modelo,
    String? numeroSerie,
    String? pinCifrado,
    String? procesador,
    String? ram,
    String? almacenamiento,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Equipo(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      tipo: tipo ?? this.tipo,
      marca: marca ?? this.marca,
      modelo: modelo ?? this.modelo,
      numeroSerie: numeroSerie ?? this.numeroSerie,
      pinCifrado: pinCifrado ?? this.pinCifrado,
      procesador: procesador ?? this.procesador,
      ram: ram ?? this.ram,
      almacenamiento: almacenamiento ?? this.almacenamiento,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
