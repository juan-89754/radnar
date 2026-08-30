import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class BackupHelper {
  /// Exports the current SQLite database to the Application Documents folder in a 'Backups' subdirectory.
  /// Returns the path of the generated backup file.
  static Future<String> exportBackup() async {
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'radnar_offline.db'));

    if (!await dbFile.exists()) {
      throw Exception('No existe una base de datos activa para respaldar.');
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final backupFolder = Directory(join(appDocDir.path, 'Backups'));
    if (!await backupFolder.exists()) {
      await backupFolder.create(recursive: true);
    }

    // Format filename with current timestamp
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final backupFile = File(join(backupFolder.path, 'radnar_backup_$timestamp.db'));

    await dbFile.copy(backupFile.path);
    return backupFile.path;
  }

  /// Lists all backup files (.db) available in the backups directory.
  static Future<List<File>> listBackups() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final backupFolder = Directory(join(appDocDir.path, 'Backups'));
    if (!await backupFolder.exists()) {
      return [];
    }

    final List<File> files = [];
    final entities = await backupFolder.list().toList();
    for (var entity in entities) {
      if (entity is File && entity.path.endsWith('.db')) {
        files.add(entity);
      }
    }
    // Sort newest backups first
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// Restores a backup from the given path by copying it over the active database file.
  static Future<void> importBackup(String backupPath) async {
    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      throw Exception('El archivo de respaldo seleccionado no existe.');
    }

    // 1. Close current connection to release lock
    await DatabaseHelper.instance.close();

    // 2. Overwrite the active DB file
    final dbPath = await getDatabasesPath();
    final activeDbPath = join(dbPath, 'radnar_offline.db');

    await backupFile.copy(activeDbPath);

    // 3. Force re-opening database in DatabaseHelper (next query will trigger get database)
    // sqflite automatically handles lazy initialization on next call since the static helper field is set to null.
  }
}
