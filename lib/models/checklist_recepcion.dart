import 'dart:convert';
import 'package:crypto/crypto.dart';

class ChecklistRecepcion {
  final int? id;
  final int ordenId;
  final Map<String, dynamic> datosInspeccion;
  final String hashSha256;
  final DateTime timestampSellado;

  ChecklistRecepcion({
    this.id,
    required this.ordenId,
    required this.datosInspeccion,
    required this.hashSha256,
    required this.timestampSellado,
  });

  // Calculates a deterministic SHA-256 hash matching the Django logic
  static String calculateHash({
    required String codigoOrden,
    required DateTime timestamp,
    required Map<String, dynamic> datos,
  }) {
    // Sort keys alphabetically
    final sortedKeys = datos.keys.toList()..sort();
    final Map<String, dynamic> sortedMap = {
      for (var key in sortedKeys) key: datos[key]
    };

    final jsonDump = json.encode(sortedMap);
    final tsStr = timestamp.toIso8601String();
    final rawPayload = '$codigoOrden:$tsStr:$jsonDump';

    final bytes = utf8.encode(rawPayload);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Factory to create a checklist and automatically seal it with a hash
  factory ChecklistRecepcion.seal({
    int? id,
    required int ordenId,
    required String codigoOrden,
    required Map<String, dynamic> datosInspeccion,
  }) {
    final now = DateTime.now();
    final hash = calculateHash(
      codigoOrden: codigoOrden,
      timestamp: now,
      datos: datosInspeccion,
    );
    return ChecklistRecepcion(
      id: id,
      ordenId: ordenId,
      datosInspeccion: datosInspeccion,
      hashSha256: hash,
      timestampSellado: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'orden_id': ordenId,
      'datos_inspeccion': json.encode(datosInspeccion),
      'hash_sha256': hashSha256,
      'timestamp_sellado': timestampSellado.toIso8601String(),
    };
  }

  factory ChecklistRecepcion.fromMap(Map<String, dynamic> map) {
    return ChecklistRecepcion(
      id: map['id'] as int?,
      ordenId: map['orden_id'] as int,
      datosInspeccion: json.decode(map['datos_inspeccion'] as String) as Map<String, dynamic>,
      hashSha256: map['hash_sha256'] as String,
      timestampSellado: DateTime.parse(map['timestamp_sellado'] as String),
    );
  }
}
