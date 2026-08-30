import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('radnar_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    // Enable Foreign Key support
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    // Table Clientes
    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre_completo TEXT NOT NULL,
        telefono TEXT UNIQUE NOT NULL,
        email TEXT,
        direccion TEXT,
        notas TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Table Equipos
    await db.execute('''
      CREATE TABLE equipos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER NOT NULL,
        tipo TEXT NOT NULL,
        marca TEXT NOT NULL,
        modelo TEXT NOT NULL,
        numero_serie TEXT,
        pin_cifrado TEXT,
        procesador TEXT,
        ram TEXT,
        almacenamiento TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE
      )
    ''');

    // Table Tecnicos
    await db.execute('''
      CREATE TABLE tecnicos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre_completo TEXT NOT NULL,
        telefono TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // Table Ordenes
    await db.execute('''
      CREATE TABLE ordenes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        codigo_orden TEXT UNIQUE NOT NULL,
        cliente_id INTEGER NOT NULL,
        equipo_id INTEGER NOT NULL,
        tecnico_id INTEGER,
        estado TEXT NOT NULL DEFAULT 'ingresado',
        motivo_ingreso TEXT NOT NULL,
        accesorios_incluidos TEXT,
        fecha_ingreso TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE RESTRICT,
        FOREIGN KEY (equipo_id) REFERENCES equipos (id) ON DELETE RESTRICT,
        FOREIGN KEY (tecnico_id) REFERENCES tecnicos (id) ON DELETE SET NULL
      )
    ''');

    // Table Checklist Recepcion
    await db.execute('''
      CREATE TABLE checklist_recepcion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orden_id INTEGER UNIQUE NOT NULL,
        datos_inspeccion TEXT NOT NULL,
        hash_sha256 TEXT NOT NULL,
        timestamp_sellado TEXT NOT NULL,
        FOREIGN KEY (orden_id) REFERENCES ordenes (id) ON DELETE CASCADE
      )
    ''');

    // Table Bitacoras Tecnicas
    await db.execute('''
      CREATE TABLE bitacoras_tecnicas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orden_id INTEGER NOT NULL,
        autor_texto TEXT NOT NULL DEFAULT 'Técnico',
        contenido TEXT NOT NULL,
        es_privado INTEGER NOT NULL DEFAULT 1,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (orden_id) REFERENCES ordenes (id) ON DELETE CASCADE
      )
    ''');

    // Table Historial Estados
    await db.execute('''
      CREATE TABLE historial_estados (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orden_id INTEGER NOT NULL,
        estado_anterior TEXT NOT NULL,
        estado_nuevo TEXT NOT NULL,
        notas_transicion TEXT,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (orden_id) REFERENCES ordenes (id) ON DELETE CASCADE
      )
    ''');

    // Table Cotizaciones
    await db.execute('''
      CREATE TABLE cotizaciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orden_id INTEGER NOT NULL,
        titulo TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'borrador',
        notas_cliente TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (orden_id) REFERENCES ordenes (id) ON DELETE CASCADE
      )
    ''');

    // Table Lineas Cotizacion
    await db.execute('''
      CREATE TABLE lineas_cotizacion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cotizacion_id INTEGER NOT NULL,
        tipo TEXT NOT NULL DEFAULT 'repuesto',
        opcion TEXT NOT NULL DEFAULT 'opcion_a',
        descripcion TEXT NOT NULL,
        costo_proveedor REAL NOT NULL DEFAULT 0.0,
        margen_porcentaje REAL NOT NULL DEFAULT 30.0,
        precio_cliente REAL NOT NULL DEFAULT 0.0,
        cantidad INTEGER NOT NULL DEFAULT 1,
        aprobada_por_cliente INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (cotizacion_id) REFERENCES cotizaciones (id) ON DELETE CASCADE
      )
    ''');

    // Table Fotos Evidencia
    await db.execute('''
      CREATE TABLE fotos_evidencia (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orden_id INTEGER NOT NULL,
        checklist_id INTEGER,
        image_path TEXT NOT NULL,
        anotacion TEXT,
        hash_sha256 TEXT,
        timestamp_sellado TEXT NOT NULL,
        FOREIGN KEY (orden_id) REFERENCES ordenes (id) ON DELETE CASCADE,
        FOREIGN KEY (checklist_id) REFERENCES checklist_recepcion (id) ON DELETE SET NULL
      )
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
