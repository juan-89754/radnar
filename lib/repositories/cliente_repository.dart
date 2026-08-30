import 'package:sqflite/sqflite.dart';
import '../models/cliente.dart';
import '../services/database_helper.dart';

class ClienteRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insert(Cliente cliente) async {
    final db = await _dbHelper.database;
    // Pre-validate/clean phone number
    final cleanedPhone = Cliente.cleanAndValidatePhone(cliente.telefono);
    final validatedCliente = cliente.copyWith(
      telefono: cleanedPhone,
      updatedAt: DateTime.now(),
    );
    return await db.insert('clientes', validatedCliente.toMap());
  }

  Future<int> update(Cliente cliente) async {
    final db = await _dbHelper.database;
    final cleanedPhone = Cliente.cleanAndValidatePhone(cliente.telefono);
    final validatedCliente = cliente.copyWith(
      telefono: cleanedPhone,
      updatedAt: DateTime.now(),
    );
    return await db.update(
      'clientes',
      validatedCliente.toMap(),
      where: 'id = ?',
      whereArgs: [cliente.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'clientes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Cliente?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'clientes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Cliente.fromMap(maps.first);
  }

  Future<List<Cliente>> getAll({String? search}) async {
    final db = await _dbHelper.database;
    List<Map<String, dynamic>> maps;

    if (search != null && search.trim().isNotEmpty) {
      final query = '%${search.trim()}%';
      maps = await db.query(
        'clientes',
        where: 'nombre_completo LIKE ? OR telefono LIKE ? OR email LIKE ?',
        whereArgs: [query, query, query],
        orderBy: 'created_at DESC',
      );
    } else {
      maps = await db.query(
        'clientes',
        orderBy: 'created_at DESC',
      );
    }

    return List.generate(maps.length, (i) => Cliente.fromMap(maps[i]));
  }
}
