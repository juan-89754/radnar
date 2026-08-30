import 'package:sqflite/sqflite.dart';
import '../models/tecnico.dart';
import '../services/database_helper.dart';

class TecnicoRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insert(Tecnico tecnico) async {
    final db = await _dbHelper.database;
    return await db.insert('tecnicos', tecnico.toMap());
  }

  Future<int> update(Tecnico tecnico) async {
    final db = await _dbHelper.database;
    return await db.update(
      'tecnicos',
      tecnico.toMap(),
      where: 'id = ?',
      whereArgs: [tecnico.id],
    );
  }

  Future<List<Tecnico>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query('tecnicos', orderBy: 'nombre_completo ASC');
    return List.generate(maps.length, (i) => Tecnico.fromMap(maps[i]));
  }

  Future<List<Tecnico>> getActivos() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'tecnicos',
      where: 'activo = 1',
      orderBy: 'nombre_completo ASC',
    );
    return List.generate(maps.length, (i) => Tecnico.fromMap(maps[i]));
  }

  Future<Tecnico?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'tecnicos',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Tecnico.fromMap(maps.first);
  }
}
