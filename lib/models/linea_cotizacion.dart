class LineaCotizacion {
  final int? id;
  final int cotizacionId;
  final String tipo; // mano_obra, repuesto, equipo_completo
  final String opcion; // opcion_a, opcion_b
  final String descripcion;
  final double costoProveedor;
  final double margenPorcentaje;
  final double precioCliente;
  final int cantidad;
  final bool aprobadaPorCliente;
  final DateTime createdAt;

  static const Map<String, String> nombresTipos = {
    'mano_obra': 'Mano de Obra / Servicio Técnico',
    'repuesto': 'Repuesto / Componente',
    'equipo_completo': 'Equipo Completo / Periférico',
  };

  static const Map<String, String> nombresOpciones = {
    'opcion_a': 'Opción A (Principal / Recomendada)',
    'opcion_b': 'Opción B (Alternativa / Económica)',
  };

  LineaCotizacion({
    this.id,
    required this.cotizacionId,
    this.tipo = 'repuesto',
    this.opcion = 'opcion_a',
    required this.descripcion,
    this.costoProveedor = 0.0,
    this.margenPorcentaje = 30.0,
    required this.precioCliente,
    this.cantidad = 1,
    this.aprobadaPorCliente = true,
    required this.createdAt,
  });

  double get subtotalCliente => precioCliente * cantidad;

  static double autoCalculatePrecioCliente(double costo, double margen) {
    if (costo > 0.0) {
      double factor = 1.0 + (margen / 100.0);
      return double.parse((costo * factor).toStringAsFixed(2));
    }
    return 0.0;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cotizacion_id': cotizacionId,
      'tipo': tipo,
      'opcion': opcion,
      'descripcion': descripcion,
      'costo_proveedor': costoProveedor,
      'margen_porcentaje': margenPorcentaje,
      'precio_cliente': precioCliente,
      'cantidad': cantidad,
      'aprobada_por_cliente': aprobadaPorCliente ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LineaCotizacion.fromMap(Map<String, dynamic> map) {
    return LineaCotizacion(
      id: map['id'] as int?,
      cotizacionId: map['cotizacion_id'] as int,
      tipo: map['tipo'] as String,
      opcion: map['opcion'] as String,
      descripcion: map['descripcion'] as String,
      costoProveedor: (map['costo_proveedor'] as num).toDouble(),
      margenPorcentaje: (map['margen_porcentaje'] as num).toDouble(),
      precioCliente: (map['precio_cliente'] as num).toDouble(),
      cantidad: map['cantidad'] as int,
      aprobadaPorCliente: (map['aprobada_por_cliente'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  LineaCotizacion copyWith({
    int? id,
    int? cotizacionId,
    String? tipo,
    String? opcion,
    String? descripcion,
    double? costoProveedor,
    double? margenPorcentaje,
    double? precioCliente,
    int? cantidad,
    bool? aprobadaPorCliente,
    DateTime? createdAt,
  }) {
    return LineaCotizacion(
      id: id ?? this.id,
      cotizacionId: cotizacionId ?? this.cotizacionId,
      tipo: tipo ?? this.tipo,
      opcion: opcion ?? this.opcion,
      descripcion: descripcion ?? this.descripcion,
      costoProveedor: costoProveedor ?? this.costoProveedor,
      margenPorcentaje: margenPorcentaje ?? this.margenPorcentaje,
      precioCliente: precioCliente ?? this.precioCliente,
      cantidad: cantidad ?? this.cantidad,
      aprobadaPorCliente: aprobadaPorCliente ?? this.aprobadaPorCliente,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
