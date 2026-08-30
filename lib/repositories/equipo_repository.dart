import 'package:sqflite/sqflite.dart';
import '../models/equipo.dart';
import '../services/database_helper.dart';

class EquipoRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insert(Equipo equipo) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final toSave = equipo.copyWith(
      createdAt: now,
      updatedAt: now,
    );
    return await db.insert('equipos', toSave.toMap());
  }

  Future<int> update(Equipo equipo) async {
    final db = await _dbHelper.database;
    final toSave = equipo.copyWith(
      updatedAt: DateTime.now(),
    );
    return await db.update(
      'equipos',
      toSave.toMap(),
      where: 'id = ?',
      whereArgs: [equipo.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'equipos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Equipo?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'equipos',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Equipo.fromMap(maps.first);
  }

  Future<List<Equipo>> getByClienteId(int clienteId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'equipos',
      where: 'cliente_id = ?',
      whereArgs: [clienteId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Equipo.fromMap(maps[i]));
  }

  Future<List<Equipo>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query('equipos', orderBy: 'created_at DESC');
    return List.generate(maps.length, (i) => Equipo.fromMap(maps[i]));
  }
}
