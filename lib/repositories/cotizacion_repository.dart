import 'package:sqflite/sqflite.dart';
import '../models/cotizacion.dart';
import '../models/linea_cotizacion.dart';
import '../services/database_helper.dart';

class CotizacionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insert(Cotizacion cotizacion) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final toSave = cotizacion.copyWith(
      createdAt: now,
      updatedAt: now,
    );
    return await db.insert('cotizaciones', toSave.toMap());
  }

  Future<int> update(Cotizacion cotizacion) async {
    final db = await _dbHelper.database;
    final toSave = cotizacion.copyWith(
      updatedAt: DateTime.now(),
    );
    return await db.update(
      'cotizaciones',
      toSave.toMap(),
      where: 'id = ?',
      whereArgs: [cotizacion.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'cotizaciones',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Cotizacion?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'cotizaciones',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Cotizacion.fromMap(maps.first);
  }

  Future<Cotizacion?> getByOrdenId(int ordenId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'cotizaciones',
      where: 'orden_id = ?',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Cotizacion.fromMap(maps.first);
  }

  // --- LineaCotizacion Operations ---

  Future<List<LineaCotizacion>> getLineas(int cotizacionId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'lineas_cotizacion',
      where: 'cotizacion_id = ?',
      orderBy: 'created_at ASC',
    );
    return List.generate(maps.length, (i) => LineaCotizacion.fromMap(maps[i]));
  }

  Future<int> insertLinea(LineaCotizacion linea) async {
    final db = await _dbHelper.database;

    // Automatic client pricing calculation if not specified
    double calculatedPrecio = linea.precioCliente;
    if (linea.costoProveedor > 0 && (linea.precioCliente == 0 || linea.precioCliente == null)) {
      calculatedPrecio = LineaCotizacion.autoCalculatePrecioCliente(
        linea.costoProveedor,
        linea.margenPorcentaje,
      );
    }

    final toSave = linea.copyWith(
      precioCliente: calculatedPrecio,
      createdAt: DateTime.now(),
    );

    return await db.insert('lineas_cotizacion', toSave.toMap());
  }

  Future<int> updateLinea(LineaCotizacion linea) async {
    final db = await _dbHelper.database;

    // Recalculate customer price if changed
    double calculatedPrecio = linea.precioCliente;
    final existing = await db.query('lineas_cotizacion', where: 'id = ?', whereArgs: [linea.id]);
    if (existing.isNotEmpty) {
      final old = LineaCotizacion.fromMap(existing.first);
      if (old.costoProveedor != linea.costoProveedor || old.margenPorcentaje != linea.margenPorcentaje) {
        calculatedPrecio = LineaCotizacion.autoCalculatePrecioCliente(
          linea.costoProveedor,
          linea.margenPorcentaje,
        );
      }
    }

    final toSave = linea.copyWith(
      precioCliente: calculatedPrecio,
    );

    return await db.update(
      'lineas_cotizacion',
      toSave.toMap(),
      where: 'id = ?',
      whereArgs: [linea.id],
    );
  }

  Future<int> deleteLinea(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'lineas_cotizacion',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
