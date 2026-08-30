import 'package:sqflite/sqflite.dart';
import '../models/orden.dart';
import '../models/checklist_recepcion.dart';
import '../models/bitacora_tecnica.dart';
import '../models/historial_estado.dart';
import '../models/foto_evidencia.dart';
import '../services/database_helper.dart';

class OrdenRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Generates the code like ORD-YYYY-NNN
  Future<String> _generateCodigoOrden(Transaction txn) async {
    final year = DateTime.now().year;
    final prefix = 'ORD-$year-';

    // Find the last order created in this year
    final maps = await txn.rawQuery(
      "SELECT codigo_orden FROM ordenes WHERE codigo_orden LIKE '$prefix%' ORDER BY id DESC LIMIT 1"
    );

    int nextNum = 1;
    if (maps.isNotEmpty) {
      final lastCode = maps.first['codigo_orden'] as String;
      final parts = lastCode.split('-');
      if (parts.isNotEmpty) {
        final lastNumStr = parts.last;
        final lastNum = int.tryParse(lastNumStr);
        if (lastNum != null) {
          nextNum = lastNum + 1;
        }
      }
    }

    final paddedNum = nextNum.toString().padLeft(3, '0');
    return '$prefix$paddedNum';
  }

  Future<int> insert(Orden orden) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      final code = await _generateCodigoOrden(txn);
      final now = DateTime.now();
      final toSave = orden.copyWith(
        codigoOrden: code,
        fechaIngreso: now,
        updatedAt: now,
      );

      return await txn.insert('ordenes', toSave.toMap());
    });
  }

  Future<int> update(Orden orden) async {
    final db = await _dbHelper.database;

    // Business Rule Check: Cannot change customer if order is locked
    final oldOrden = await getById(orden.id!);
    if (oldOrden != null) {
      if (oldOrden.isLocked && oldOrden.clienteId != orden.clienteId) {
        throw Exception(
          'No se permite cambiar el cliente asociado a la orden una vez que pasa a estado "En reparación" o posterior.'
        );
      }
    }

    final toSave = orden.copyWith(
      updatedAt: DateTime.now(),
    );

    int count = await db.update(
      'ordenes',
      toSave.toMap(),
      where: 'id = ?',
      whereArgs: [orden.id],
    );

    // If state changed, add state history automatically
    if (oldOrden != null && oldOrden.estado != orden.estado) {
      await addHistorial(HistorialEstado(
        ordenId: orden.id!,
        estadoAnterior: oldOrden.estado,
        estadoNuevo: orden.estado,
        notasTransicion: 'Estado actualizado automáticamente',
        timestamp: DateTime.now(),
      ));
    }

    return count;
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'ordenes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Orden?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'ordenes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Orden.fromMap(maps.first);
  }

  Future<List<Orden>> getAll({String? search}) async {
    final db = await _dbHelper.database;
    List<Map<String, dynamic>> maps;

    if (search != null && search.trim().isNotEmpty) {
      // Find orders matching the order code or search criteria.
      // Since it links to client/device, we can also search inside client names by joining.
      final query = '%${search.trim()}%';
      maps = await db.rawQuery('''
        SELECT o.* FROM ordenes o
        INNER JOIN clientes c ON o.cliente_id = c.id
        INNER JOIN equipos e ON o.equipo_id = e.id
        WHERE o.codigo_orden LIKE ? 
           OR c.nombre_completo LIKE ? 
           OR e.marca LIKE ? 
           OR e.modelo LIKE ?
        ORDER BY o.fecha_ingreso DESC
      ''', [query, query, query, query]);
    } else {
      maps = await db.query('ordenes', orderBy: 'fecha_ingreso DESC');
    }

    return List.generate(maps.length, (i) => Orden.fromMap(maps[i]));
  }

  // --- Checklist Recepcion Operations ---
  
  Future<ChecklistRecepcion?> getChecklist(int ordenId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'checklist_recepcion',
      where: 'orden_id = ?',
      whereArgs: [ordenId],
    );
    if (maps.isEmpty) return null;
    return ChecklistRecepcion.fromMap(maps.first);
  }

  Future<int> saveChecklist(ChecklistRecepcion checklist) async {
    final db = await _dbHelper.database;

    // Enforce business rules
    final orden = await getById(checklist.ordenId);
    if (orden == null) {
      throw Exception('Orden no encontrada para el checklist.');
    }

    if (orden.isLocked) {
      throw Exception(
        'El checklist de recepción está bloqueado y no puede editarse una vez que la orden pasa a "En reparación" o posterior.'
      );
    }

    final existing = await getChecklist(checklist.ordenId);
    if (existing != null) {
      // Checklist is immutable after creation
      throw Exception('El checklist de recepción es inmutable tras su creación y no puede modificarse.');
    }

    return await db.insert('checklist_recepcion', checklist.toMap());
  }

  // --- Bitacora Tecnica Operations ---

  Future<List<BitacoraTecnica>> getBitacora(int ordenId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'bitacoras_tecnicas',
      where: 'orden_id = ?',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => BitacoraTecnica.fromMap(maps[i]));
  }

  Future<int> addBitacora(BitacoraTecnica note) async {
    final db = await _dbHelper.database;
    return await db.insert('bitacoras_tecnicas', note.toMap());
  }

  // --- Historial Estados Operations ---

  Future<List<HistorialEstado>> getHistorial(int ordenId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'historial_estados',
      where: 'orden_id = ?',
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) => HistorialEstado.fromMap(maps[i]));
  }

  Future<int> addHistorial(HistorialEstado history) async {
    final db = await _dbHelper.database;
    return await db.insert('historial_estados', history.toMap());
  }

  // --- Foto Evidencia Operations ---

  Future<List<FotoEvidencia>> getFotos(int ordenId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'fotos_evidencia',
      where: 'orden_id = ?',
      orderBy: 'timestamp_sellado ASC',
    );
    return List.generate(maps.length, (i) => FotoEvidencia.fromMap(maps[i]));
  }

  Future<int> addFoto(FotoEvidencia foto) async {
    final db = await _dbHelper.database;

    // Rule: Max 10 photos
    final existing = await getFotos(foto.ordenId);
    if (existing.length >= 10) {
      throw Exception('No se permiten más de 10 fotos por orden de recepción.');
    }

    return await db.insert('fotos_evidencia', foto.toMap());
  }
}
