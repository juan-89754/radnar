class BitacoraTecnica {
  final int? id;
  final int ordenId;
  final String autorTexto;
  final String contenido;
  final bool esPrivado;
  final DateTime timestamp;

  BitacoraTecnica({
    this.id,
    required this.ordenId,
    this.autorTexto = 'Técnico',
    required this.contenido,
    this.esPrivado = true,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'orden_id': ordenId,
      'autor_texto': autorTexto,
      'contenido': contenido,
      'es_privado': esPrivado ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory BitacoraTecnica.fromMap(Map<String, dynamic> map) {
    return BitacoraTecnica(
      id: map['id'] as int?,
      ordenId: map['orden_id'] as int,
      autorTexto: map['autor_texto'] as String,
      contenido: map['contenido'] as String,
      esPrivado: (map['es_privado'] as int) == 1,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
