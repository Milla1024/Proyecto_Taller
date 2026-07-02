import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/usuario.dart';

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  Database? _database;

  Future<Database> get _db async {
    final database = _database;
    if (database != null) {
      return database;
    }

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final path = await _resolveDatabasePath();
    final opened = await databaseFactory.openDatabase(path);
    await _prepareDatabase(opened);
    _database = opened;
    return opened;
  }

  Future<String> _resolveDatabasePath() async {
    final current = Directory.current.path;
    final candidates = [
      p.join(current, 'liteTaller.db'),
      p.join(p.dirname(current), 'liteTaller.db'),
      p.join(p.dirname(Platform.resolvedExecutable), 'liteTaller.db'),
    ];

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    final databasesPath = await databaseFactory.getDatabasesPath();
    await Directory(databasesPath).create(recursive: true);
    return p.join(databasesPath, 'liteTaller.db');
  }

  Future<void> _prepareDatabase(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS empleado (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        puesto TEXT NOT NULL,
        telefono TEXT,
        "contrase\u00f1a" TEXT NOT NULL,
        activo INTEGER DEFAULT 1,
        numero_empleado TEXT
      )
    ''');

    final columns = await db.rawQuery('PRAGMA table_info(empleado)');
    final columnNames = columns.map((column) => column['name'] as String).toSet();
    Future<void> addColumn(String name, String definition) async {
      if (!columnNames.contains(name)) {
        await db.execute('ALTER TABLE empleado ADD COLUMN $definition');
      }
    }

    await addColumn('activo', 'activo INTEGER DEFAULT 1');
    await addColumn('numero_empleado', 'numero_empleado TEXT');

    await db.execute('''
      UPDATE empleado
      SET numero_empleado = printf('EMP-%03d', id)
      WHERE numero_empleado IS NULL OR numero_empleado = ''
    ''');

    final countRows = await db.rawQuery('SELECT COUNT(*) AS total FROM empleado');
    final count = countRows.first['total'] as int;
    if (count == 0) {
      await db.insert('empleado', {
        'nombre': 'Administrador',
        'puesto': 'Administrador',
        'telefono': '',
        'contrase\u00f1a': 'admin123',
        'activo': 1,
        'numero_empleado': 'EMP-001',
      });
    }
  }

  Future<List<Usuario>> listarUsuarios() async {
    final db = await _db;
    final rows = await db.query('empleado', orderBy: 'id DESC');
    return rows.map(Usuario.fromMap).toList();
  }

  Future<Usuario?> obtenerUsuario(int id) async {
    final db = await _db;
    final rows = await db.query(
      'empleado',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Usuario.fromMap(rows.first);
  }

  Future<Usuario?> iniciarSesion(String nombre, String contrasena) async {
    final db = await _db;
    final rows = await db.query(
      'empleado',
      where: 'lower(nombre) = lower(?) AND "contrase\u00f1a" = ? AND activo = 1',
      whereArgs: [nombre.trim(), contrasena],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Usuario.fromMap(rows.first);
  }

  Future<Usuario> crearUsuario(Usuario usuario) async {
    final db = await _db;
    final id = await db.insert('empleado', _toEmpleadoMap(usuario));
    final numeroEmpleado = usuario.numeroEmpleado.trim().isEmpty
        ? 'EMP-${id.toString().padLeft(3, '0')}'
        : usuario.numeroEmpleado.trim();
    await db.update(
      'empleado',
      {'numero_empleado': numeroEmpleado},
      where: 'id = ?',
      whereArgs: [id],
    );
    return usuario.copyWith(id: id, numeroEmpleado: numeroEmpleado);
  }

  Future<void> actualizarUsuario(Usuario usuario) async {
    final db = await _db;
    await db.update(
      'empleado',
      _toEmpleadoMap(usuario, includePassword: usuario.contrasena != null),
      where: 'id = ?',
      whereArgs: [usuario.id],
    );
  }

  Future<void> eliminarUsuario(int id) async {
    final db = await _db;
    await db.delete('empleado', where: 'id = ?', whereArgs: [id]);
  }

  Map<String, Object?> _toEmpleadoMap(
    Usuario usuario, {
    bool includePassword = true,
  }) {
    return {
      'nombre': usuario.nombre.trim(),
      'puesto': usuario.rol,
      'telefono': '',
      'activo': usuario.activo ? 1 : 0,
      'numero_empleado': usuario.numeroEmpleado.trim(),
      if (includePassword)
        'contrase\u00f1a': usuario.contrasena?.trim().isNotEmpty == true
            ? usuario.contrasena!.trim()
            : '123456',
    };
  }
}
