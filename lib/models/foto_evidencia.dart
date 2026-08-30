class FotoEvidencia {
  final int? id;
  final int ordenId;
  final int? checklistId;
  final String imagePath;
  final String? anotacion;
  final String? hashSha256;
  final DateTime timestampSellado;

  FotoEvidencia({
    this.id,
    required this.ordenId,
    this.checklistId,
    required this.imagePath,
    this.anotacion,
    this.hashSha256,
    required this.timestampSellado,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'orden_id': ordenId,
      'checklist_id': checklistId,
      'image_path': imagePath,
      'anotacion': anotacion,
      'hash_sha256': hashSha256,
      'timestamp_sellado': timestampSellado.toIso8601String(),
    };
  }

  factory FotoEvidencia.fromMap(Map<String, dynamic> map) {
    return FotoEvidencia(
      id: map['id'] as int?,
      ordenId: map['orden_id'] as int,
      checklistId: map['checklist_id'] as int?,
      imagePath: map['image_path'] as String,
      anotacion: map['anotacion'] as String?,
      hashSha256: map['hash_sha256'] as String?,
      timestampSellado: DateTime.parse(map['timestamp_sellado'] as String),
    );
  }
}
