import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/comentario_orden.dart';
import '../models/cotizacion.dart';
import '../models/imagen_comentario.dart';
import '../models/orden_detalle.dart';
import '../models/orden_servicio.dart';
import '../models/notificacion_usuario.dart';
import '../models/usuario.dart';
import 'correo_service.dart';

const int _kAnchoMaximoImagenComentario = 1600;
const int _kCalidadJpegComentario = 80;

/// Activar SOLO cuando el modulo de facturas persista la transaccion antes
/// de perder acceso a la orden de origen. Mientras este en false,
/// purgarOrdenesCompletadas() queda cableada pero es un no-op.
const bool kPurgaOrdenesActiva = false;

class DashboardStats {
  const DashboardStats({
    required this.ordenesActivas,
    required this.ordenesHoy,
    required this.porEntregar,
    required this.urgentes,
    required this.facturadoMes,
    required this.facturasMes,
    required this.alertasPendientes,
    required this.enRevision,
    required this.enProgreso,
    required this.completadasHoy,
    required this.canceladasMes,
    required this.serviciosMes,
    required this.ordenesRecientes,
    required this.avisos,
  });

  final int ordenesActivas;
  final int ordenesHoy;
  final int porEntregar;
  final int urgentes;
  final double facturadoMes;
  final int facturasMes;
  final int alertasPendientes;
  final int enRevision;
  final int enProgreso;
  final int completadasHoy;
  final int canceladasMes;
  final List<DashboardServiceStat> serviciosMes;
  final List<DashboardOrderItem> ordenesRecientes;
  final List<DashboardReminderItem> avisos;
}

class DashboardServiceStat {
  const DashboardServiceStat({
    required this.tipo,
    required this.cantidad,
    required this.porcentaje,
  });

  final String tipo;
  final int cantidad;
  final int porcentaje;
}

class DashboardOrderItem {
  const DashboardOrderItem({
    required this.noOrden,
    required this.vehiculo,
    required this.descripcion,
    required this.estado,
    required this.fechaIngreso,
    this.fechaCompromiso,
  });

  final int noOrden;
  final String vehiculo;
  final String descripcion;
  final String estado;
  final String fechaIngreso;
  final String? fechaCompromiso;
}

class DashboardReminderItem {
  const DashboardReminderItem({
    required this.titulo,
    required this.subtitulo,
    required this.tipo,
  });

  final String titulo;
  final String subtitulo;
  final DashboardReminderType tipo;
}

enum DashboardReminderType { danger, warning, info }

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
    await _prepareEmpleadoTable(db);
    await _prepareServiceOrderTables(db);
    await _prepareFacturaTables(db);
    await _prepareCotizacionTables(db);
    await _prepareNotificacionUsuarioTable(db);
    await _prepareComentarioOrdenTable(db);
    await _prepareComentarioImagenTable(db);
    await _purgarOrdenesCompletadas(db);
  }

  Future<void> _prepareEmpleadoTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS empleado (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        puesto TEXT NOT NULL,
        telefono TEXT,
        contrasena TEXT NOT NULL,
        activo INTEGER DEFAULT 1
      )
    ''');

    final columns = await db.rawQuery('PRAGMA table_info(empleado)');
    final columnNames = columns
        .map((column) => column['name'] as String)
        .toSet();

    final needsRebuild =
        !columnNames.contains('contrasena') ||
        !columnNames.contains('telefono') ||
        !columnNames.contains('activo') ||
        columnNames.contains('numero_empleado');

    if (needsRebuild) {
      await _rebuildEmpleadoTable(db, columnNames);
      return;
    }

    Future<void> addColumn(String name, String definition) async {
      if (!columnNames.contains(name)) {
        await db.execute('ALTER TABLE empleado ADD COLUMN $definition');
      }
    }

    await addColumn('telefono', 'telefono TEXT');
    await addColumn('activo', 'activo INTEGER DEFAULT 1');

    final countRows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM empleado',
    );
    final count = countRows.first['total'] as int;
    if (count == 0) {
      await db.insert('empleado', {
        'nombre': 'Prueba',
        'puesto': 'Administrador',
        'telefono': '94079604',
        'contrasena': 'admin123',
        'activo': 1,
      });
    }
  }

  Future<void> _rebuildEmpleadoTable(
    Database db,
    Set<String> columnNames,
  ) async {
    const legacyPasswordColumn = 'contrase\u00f1a';

    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction((txn) async {
        await txn.execute('''
          CREATE TABLE empleado_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            puesto TEXT NOT NULL,
            telefono TEXT,
            contrasena TEXT NOT NULL,
            activo INTEGER DEFAULT 1
          )
        ''');

        final selectParts = <String>[
          columnNames.contains('id') ? 'id' : 'NULL AS id',
          columnNames.contains('nombre') ? 'nombre' : "'' AS nombre",
          columnNames.contains('puesto') ? 'puesto' : "'Ayudante' AS puesto",
          if (columnNames.contains('telefono'))
            'telefono'
          else if (columnNames.contains('numero_empleado'))
            'numero_empleado AS telefono'
          else
            "'' AS telefono",
          if (columnNames.contains('contrasena'))
            'contrasena'
          else if (columnNames.contains(legacyPasswordColumn))
            '"$legacyPasswordColumn" AS contrasena'
          else
            "'123456' AS contrasena",
          columnNames.contains('activo') ? 'activo' : '1 AS activo',
        ];

        await txn.execute('''
          INSERT INTO empleado_new (
            id,
            nombre,
            puesto,
            telefono,
            contrasena,
            activo
          )
          SELECT ${selectParts.join(', ')}
          FROM empleado
        ''');

        await txn.execute('DROP TABLE empleado');
        await txn.execute('ALTER TABLE empleado_new RENAME TO empleado');
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }

    final countRows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM empleado',
    );
    final count = countRows.first['total'] as int;
    if (count == 0) {
      await db.insert('empleado', {
        'nombre': 'Prueba',
        'puesto': 'Administrador',
        'telefono': '94079604',
        'contrasena': 'admin123',
        'activo': 1,
      });
    }
  }

  Future<void> _prepareServiceOrderTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cliente (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        direccion TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cliente_telefono (
        id_cliente INTEGER NOT NULL,
        telefono TEXT NOT NULL,
        PRIMARY KEY (id_cliente, telefono),
        FOREIGN KEY (id_cliente) REFERENCES cliente(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cliente_correo (
        id_cliente INTEGER NOT NULL,
        correo TEXT NOT NULL,
        PRIMARY KEY (id_cliente, correo),
        FOREIGN KEY (id_cliente) REFERENCES cliente(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS vehiculo (
        vin TEXT PRIMARY KEY,
        marca TEXT NOT NULL,
        modelo TEXT NOT NULL,
        color TEXT,
        kilometraje INTEGER DEFAULT 0,
        anio INTEGER,
        placas TEXT,
        id_cliente INTEGER NOT NULL,
        FOREIGN KEY (id_cliente) REFERENCES cliente(id)
          ON DELETE CASCADE
      )
    ''');

    await _prepareOrdenServicioTable(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS orden_accesorios (
        no_orden INTEGER NOT NULL,
        accesorio TEXT NOT NULL,
        presente INTEGER DEFAULT 1,
        PRIMARY KEY (no_orden, accesorio),
        FOREIGN KEY (no_orden) REFERENCES orden_servicio(no_orden)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS trabaja (
        id_empleado INTEGER NOT NULL,
        no_orden INTEGER NOT NULL,
        rol TEXT,
        PRIMARY KEY (id_empleado, no_orden),
        FOREIGN KEY (id_empleado) REFERENCES empleado(id)
          ON DELETE CASCADE,
        FOREIGN KEY (no_orden) REFERENCES orden_servicio(no_orden)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS servicio (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        no_orden INTEGER NOT NULL,
        tipo TEXT NOT NULL,
        descripcion TEXT,
        costo_mano_obra REAL DEFAULT 0,
        costo_repuestos REAL DEFAULT 0,
        total REAL DEFAULT 0,
        FOREIGN KEY (no_orden) REFERENCES orden_servicio(no_orden)
          ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _prepareOrdenServicioTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS orden_servicio (
        no_orden INTEGER PRIMARY KEY AUTOINCREMENT,
        descripcion_falla TEXT NOT NULL,
        fecha_ingreso TEXT NOT NULL,
        fecha_compromiso TEXT,
        fecha_salida TEXT,
        estado TEXT NOT NULL CHECK(estado IN ('En revisión', 'En progreso', 'Completado', 'Cancelado')) DEFAULT 'En revisión',
        kilometraje_ingreso INTEGER,
        gasolina TEXT,
        observaciones TEXT,
        subtotal REAL DEFAULT 0,
        impuesto REAL DEFAULT 0,
        total REAL DEFAULT 0,
        vin TEXT NOT NULL,
        FOREIGN KEY (vin) REFERENCES vehiculo(vin)
          ON DELETE CASCADE
      )
    ''');

    final ordenColumns = await db.rawQuery('PRAGMA table_info(orden_servicio)');
    final ordenColumnNames = ordenColumns
        .map((column) => column['name'] as String)
        .toSet();
    Future<void> addOrdenColumn(String name, String definition) async {
      if (!ordenColumnNames.contains(name)) {
        await db.execute('ALTER TABLE orden_servicio ADD COLUMN $definition');
      }
    }

    await addOrdenColumn('fecha_compromiso', 'fecha_compromiso TEXT');

    await _rebuildOrdenServicioEstadoIfNeeded(db);
  }

  Future<void> _prepareNotificacionUsuarioTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notificacion_usuario (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_empleado INTEGER NOT NULL,
        no_orden INTEGER NOT NULL,
        titulo TEXT NOT NULL,
        mensaje TEXT NOT NULL,
        estado_anterior TEXT,
        estado_nuevo TEXT NOT NULL,
        leida INTEGER DEFAULT 0,
        fecha_creacion TEXT NOT NULL,
        FOREIGN KEY (id_empleado) REFERENCES empleado(id)
          ON DELETE CASCADE,
        FOREIGN KEY (no_orden) REFERENCES orden_servicio(no_orden)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_notificacion_usuario_empleado_leida
      ON notificacion_usuario(id_empleado, leida, fecha_creacion)
    ''');
  }

  /// La apertura de la base no usa el mecanismo de version/onUpgrade de
  /// sqflite (ver openDatabase en _db): todas las tablas se crean de forma
  /// idempotente aqui mismo, asi que las instalaciones existentes ganan esta
  /// tabla la proxima vez que abran la app, sin perder datos.
  Future<void> _prepareComentarioOrdenTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS comentario_orden (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        no_orden INTEGER NOT NULL,
        id_empleado INTEGER NOT NULL,
        comentario TEXT NOT NULL,
        fecha_hora TEXT NOT NULL,
        visible_cliente INTEGER NOT NULL DEFAULT 1,
        enviado INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (no_orden) REFERENCES orden_servicio(no_orden)
          ON DELETE CASCADE,
        FOREIGN KEY (id_empleado) REFERENCES empleado(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_comentario_orden_no_orden
      ON comentario_orden(no_orden, fecha_hora)
    ''');
  }

  /// Mismo patron idempotente que _prepareComentarioOrdenTable: no hay
  /// version/onUpgrade de sqflite en este proyecto, asi que las
  /// instalaciones existentes ganan esta tabla en su proxima apertura.
  Future<void> _prepareComentarioImagenTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS comentario_imagen (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_comentario INTEGER NOT NULL,
        ruta TEXT NOT NULL,
        fecha_hora TEXT NOT NULL,
        FOREIGN KEY (id_comentario) REFERENCES comentario_orden(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_comentario_imagen_id_comentario
      ON comentario_imagen(id_comentario)
    ''');
  }

  Future<void> _prepareFacturaTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS factura (
        no_factura INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_nombre TEXT NOT NULL,
        cliente_documento TEXT,
        cliente_telefono TEXT,
        cliente_direccion TEXT,
        fecha TEXT NOT NULL,
        fecha_iso TEXT,
        subtotal REAL DEFAULT 0,
        descuento_porcentaje REAL DEFAULT 0,
        descuento REAL DEFAULT 0,
        impuesto_porcentaje REAL DEFAULT 0,
        impuesto REAL DEFAULT 0,
        total REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS factura_linea (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        no_factura INTEGER NOT NULL,
        producto TEXT NOT NULL,
        cantidad REAL NOT NULL,
        precio_unitario REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (no_factura) REFERENCES factura(no_factura)
          ON DELETE CASCADE
      )
    ''');

    final facturaColumns = await db.rawQuery('PRAGMA table_info(factura)');
    final facturaColumnNames = facturaColumns
        .map((column) => column['name'] as String)
        .toSet();
    if (!facturaColumnNames.contains('descuento_porcentaje')) {
      await db.execute(
        'ALTER TABLE factura ADD COLUMN descuento_porcentaje REAL DEFAULT 0',
      );
    }
    if (!facturaColumnNames.contains('impuesto_porcentaje')) {
      await db.execute(
        'ALTER TABLE factura ADD COLUMN impuesto_porcentaje REAL DEFAULT 0',
      );
    }
    if (!facturaColumnNames.contains('fecha_iso')) {
      await db.execute('ALTER TABLE factura ADD COLUMN fecha_iso TEXT');
    }

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_factura_fecha_iso
      ON factura(fecha_iso)
    ''');
  }

  Future<void> _prepareCotizacionTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cotizacion (
        no_cotizacion INTEGER PRIMARY KEY AUTOINCREMENT,
        proveedor_empresa TEXT NOT NULL,
        proveedor_rtn TEXT,
        proveedor_telefono TEXT,
        proveedor_correo TEXT,
        proveedor_direccion TEXT,
        proveedor_atiende TEXT,
        cliente_nombre TEXT NOT NULL,
        cliente_atencion TEXT,
        vehiculo TEXT,
        placa TEXT,
        vin TEXT,
        kilometraje TEXT,
        fecha_emision TEXT NOT NULL,
        fecha_iso TEXT,
        subtotal REAL DEFAULT 0,
        impuesto_porcentaje REAL DEFAULT 0,
        impuesto REAL DEFAULT 0,
        total REAL DEFAULT 0,
        terminos TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cotizacion_linea (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        no_cotizacion INTEGER NOT NULL,
        cantidad REAL NOT NULL,
        descripcion TEXT NOT NULL,
        precio_unitario REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (no_cotizacion) REFERENCES cotizacion(no_cotizacion)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cotizacion_cliente_nombre
      ON cotizacion(cliente_nombre)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cotizacion_fecha_iso
      ON cotizacion(fecha_iso)
    ''');
  }

  /// SQLite no permite ALTER de un CHECK existente: si la tabla todavia tiene
  /// el CHECK viejo ('En Proceso', 'Finalizado', 'Cancelado'), la reconstruye
  /// con el CHECK nuevo, mapeando los valores de estado y preservando el
  /// resto de columnas.
  Future<void> _rebuildOrdenServicioEstadoIfNeeded(Database db) async {
    final schemaRows = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'orden_servicio'",
    );
    final schemaSql = schemaRows.isEmpty
        ? ''
        : (schemaRows.first['sql'] as String? ?? '');
    final tieneCheckViejo = schemaSql.contains('En Proceso');
    if (!tieneCheckViejo) {
      return;
    }

    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction((txn) async {
        await txn.execute('''
          CREATE TABLE orden_servicio_new (
            no_orden INTEGER PRIMARY KEY AUTOINCREMENT,
            descripcion_falla TEXT NOT NULL,
            fecha_ingreso TEXT NOT NULL,
            fecha_compromiso TEXT,
            fecha_salida TEXT,
            estado TEXT NOT NULL CHECK(estado IN ('En revisión', 'En progreso', 'Completado', 'Cancelado')) DEFAULT 'En revisión',
            kilometraje_ingreso INTEGER,
            gasolina TEXT,
            observaciones TEXT,
            subtotal REAL DEFAULT 0,
            impuesto REAL DEFAULT 0,
            total REAL DEFAULT 0,
            vin TEXT NOT NULL,
            FOREIGN KEY (vin) REFERENCES vehiculo(vin)
              ON DELETE CASCADE
          )
        ''');

        await txn.execute('''
          INSERT INTO orden_servicio_new (
            no_orden, descripcion_falla, fecha_ingreso, fecha_compromiso,
            fecha_salida, estado, kilometraje_ingreso, gasolina,
            observaciones, subtotal, impuesto, total, vin
          )
          SELECT
            no_orden, descripcion_falla, fecha_ingreso, fecha_compromiso,
            fecha_salida,
            CASE estado
              WHEN 'En Proceso' THEN 'En progreso'
              WHEN 'Finalizado' THEN 'Completado'
              WHEN 'Cancelado' THEN 'Cancelado'
              ELSE 'En revisión'
            END,
            kilometraje_ingreso, gasolina, observaciones, subtotal, impuesto,
            total, vin
          FROM orden_servicio
        ''');

        await txn.execute('DROP TABLE orden_servicio');
        await txn.execute(
          'ALTER TABLE orden_servicio_new RENAME TO orden_servicio',
        );
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
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
      where: 'lower(nombre) = lower(?) AND contrasena = ? AND activo = 1',
      whereArgs: [nombre.trim(), contrasena],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Usuario.fromMap(rows.first);
  }

  Future<int> obtenerSiguienteNoOrden() async {
    final db = await _db;
    final maxRows = await db.rawQuery(
      'SELECT COALESCE(MAX(no_orden), 0) AS max_id FROM orden_servicio',
    );
    final maxId = maxRows.first['max_id'] as int;

    var sequenceId = 0;
    try {
      final sequenceRows = await db.rawQuery(
        "SELECT seq FROM sqlite_sequence WHERE name = 'orden_servicio'",
      );
      if (sequenceRows.isNotEmpty) {
        sequenceId = sequenceRows.first['seq'] as int;
      }
    } catch (_) {
      sequenceId = 0;
    }

    return (maxId > sequenceId ? maxId : sequenceId) + 1;
  }

  Future<int> obtenerSiguienteNoFactura() async {
    final db = await _db;
    final maxRows = await db.rawQuery(
      'SELECT COALESCE(MAX(no_factura), 0) AS max_id FROM factura',
    );
    final maxId = maxRows.first['max_id'] as int;

    var sequenceId = 0;
    try {
      final sequenceRows = await db.rawQuery(
        "SELECT seq FROM sqlite_sequence WHERE name = 'factura'",
      );
      if (sequenceRows.isNotEmpty) {
        sequenceId = sequenceRows.first['seq'] as int;
      }
    } catch (_) {
      sequenceId = 0;
    }

    return (maxId > sequenceId ? maxId : sequenceId) + 1;
  }

  Future<int> obtenerSiguienteNoCotizacion() async {
    final db = await _db;
    final maxRows = await db.rawQuery(
      'SELECT COALESCE(MAX(no_cotizacion), 0) AS max_id FROM cotizacion',
    );
    final maxId = maxRows.first['max_id'] as int;

    var sequenceId = 0;
    try {
      final sequenceRows = await db.rawQuery(
        "SELECT seq FROM sqlite_sequence WHERE name = 'cotizacion'",
      );
      if (sequenceRows.isNotEmpty) {
        sequenceId = sequenceRows.first['seq'] as int;
      }
    } catch (_) {
      sequenceId = 0;
    }

    return (maxId > sequenceId ? maxId : sequenceId) + 1;
  }

  Future<Usuario> crearUsuario(Usuario usuario) async {
    final db = await _db;
    final id = await db.insert('empleado', _toEmpleadoMap(usuario));
    return usuario.copyWith(id: id);
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

  Future<int> guardarFactura({
    required String clienteNombre,
    required String clienteDocumento,
    required String clienteTelefono,
    required String clienteDireccion,
    required String fecha,
    required String fechaIso,
    required double subtotal,
    required double descuentoPorcentaje,
    required double descuento,
    required double impuestoPorcentaje,
    required double impuesto,
    required double total,
    required List<Map<String, Object?>> lineas,
  }) async {
    final db = await _db;
    return db.transaction<int>((txn) async {
      final facturaId = await txn.insert('factura', {
        'cliente_nombre': clienteNombre.trim(),
        'cliente_documento': clienteDocumento.trim(),
        'cliente_telefono': clienteTelefono.trim(),
        'cliente_direccion': clienteDireccion.trim(),
        'fecha': fecha.trim(),
        'fecha_iso': fechaIso.trim(),
        'subtotal': subtotal,
        'descuento_porcentaje': descuentoPorcentaje,
        'descuento': descuento,
        'impuesto_porcentaje': impuestoPorcentaje,
        'impuesto': impuesto,
        'total': total,
      });

      for (final linea in lineas) {
        await txn.insert('factura_linea', {
          'no_factura': facturaId,
          'producto': linea['producto'],
          'cantidad': linea['cantidad'],
          'precio_unitario': linea['precio_unitario'],
          'total': linea['total'],
        });
      }

      return facturaId;
    });
  }

  Future<List<Map<String, Object?>>> listarFacturas({
    String? desdeIso,
    String? hastaIso,
  }) async {
    final db = await _db;
    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    if (desdeIso != null && desdeIso.trim().isNotEmpty) {
      whereParts.add('fecha_iso >= ?');
      whereArgs.add(desdeIso.trim());
    }
    if (hastaIso != null && hastaIso.trim().isNotEmpty) {
      whereParts.add('fecha_iso <= ?');
      whereArgs.add(hastaIso.trim());
    }

    return db.query(
      'factura',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'COALESCE(fecha_iso, fecha) DESC, no_factura DESC',
    );
  }

  Future<int> guardarCotizacion({
    required String proveedorEmpresa,
    required String proveedorRtn,
    required String proveedorTelefono,
    required String proveedorCorreo,
    required String proveedorDireccion,
    required String proveedorAtiende,
    required String clienteNombre,
    required String clienteAtencion,
    required String vehiculo,
    required String placa,
    required String vin,
    required String kilometraje,
    required String fechaEmision,
    required String fechaIso,
    required double subtotal,
    required double impuestoPorcentaje,
    required double impuesto,
    required double total,
    required String terminos,
    required List<Map<String, Object?>> lineas,
  }) async {
    final db = await _db;
    return db.transaction<int>((txn) async {
      final cotizacionId = await txn.insert('cotizacion', {
        'proveedor_empresa': proveedorEmpresa.trim(),
        'proveedor_rtn': proveedorRtn.trim(),
        'proveedor_telefono': proveedorTelefono.trim(),
        'proveedor_correo': proveedorCorreo.trim(),
        'proveedor_direccion': proveedorDireccion.trim(),
        'proveedor_atiende': proveedorAtiende.trim(),
        'cliente_nombre': clienteNombre.trim(),
        'cliente_atencion': clienteAtencion.trim(),
        'vehiculo': vehiculo.trim(),
        'placa': placa.trim(),
        'vin': vin.trim(),
        'kilometraje': kilometraje.trim(),
        'fecha_emision': fechaEmision.trim(),
        'fecha_iso': fechaIso.trim(),
        'subtotal': subtotal,
        'impuesto_porcentaje': impuestoPorcentaje,
        'impuesto': impuesto,
        'total': total,
        'terminos': terminos.trim(),
      });

      for (final linea in lineas) {
        await txn.insert('cotizacion_linea', {
          'no_cotizacion': cotizacionId,
          'cantidad': linea['cantidad'],
          'descripcion': linea['descripcion'],
          'precio_unitario': linea['precio_unitario'],
          'total': linea['total'],
        });
      }

      return cotizacionId;
    });
  }

  Future<List<CotizacionResumen>> listarCotizaciones({
    String? clienteNombre,
  }) async {
    final db = await _db;
    final filtro = clienteNombre?.trim();
    final rows = await db.query(
      'cotizacion',
      where: filtro == null || filtro.isEmpty
          ? null
          : 'cliente_nombre LIKE ? COLLATE NOCASE',
      whereArgs: filtro == null || filtro.isEmpty ? null : ['%$filtro%'],
      orderBy: 'COALESCE(fecha_iso, fecha_emision) DESC, no_cotizacion DESC',
    );
    return rows.map(CotizacionResumen.fromMap).toList();
  }

  Future<CotizacionDetalle?> obtenerCotizacionCompleta(
    int noCotizacion,
  ) async {
    final db = await _db;
    final cotizacionRows = await db.query(
      'cotizacion',
      where: 'no_cotizacion = ?',
      whereArgs: [noCotizacion],
      limit: 1,
    );
    if (cotizacionRows.isEmpty) {
      return null;
    }

    final lineas = await db.query(
      'cotizacion_linea',
      where: 'no_cotizacion = ?',
      whereArgs: [noCotizacion],
      orderBy: 'id ASC',
    );
    return CotizacionDetalle.fromMap(cotizacionRows.first, lineas);
  }

  Future<DashboardStats> obtenerDashboardStats({int? idEmpleado}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month);
    final nextMonthStart = DateTime(now.year, now.month + 1);
    final monthEnd = nextMonthStart.subtract(const Duration(days: 1));
    final todayText = _formatDisplayDate(today);
    final todayIso = _formatIsoDate(today);

    final ordenes = await listarOrdenes(idEmpleado: idEmpleado);
    final activas = ordenes
        .where((orden) => _estadosActivos.contains(orden.estado))
        .toList();
    final enRevision = ordenes
        .where((orden) => orden.estado == 'En revisión')
        .length;
    final enProgreso = ordenes
        .where((orden) => orden.estado == 'En progreso')
        .length;
    final completadasHoy = ordenes.where((orden) {
      return orden.estado == 'Completado' &&
          (orden.fechaSalida == todayIso || orden.fechaSalida == todayText);
    }).length;
    final canceladasMes = ordenes.where((orden) {
      final fecha = _parseStoredDate(orden.fechaSalida) ??
          _parseStoredDate(orden.fechaIngreso);
      return orden.estado == 'Cancelado' && _isInRange(fecha, monthStart, monthEnd);
    }).length;
    final ordenesHoy = ordenes.where((orden) {
      final fecha = _parseStoredDate(orden.fechaIngreso);
      return fecha != null && _isSameDay(fecha, today);
    }).length;
    final porEntregar = ordenes
        .where((orden) => orden.estado == 'Completado')
        .length;
    final urgentes = activas.where((orden) {
      final fecha = _parseStoredDate(orden.fechaCompromiso);
      return fecha != null && !fecha.isAfter(today);
    }).length;
    final alertasPendientes = urgentes;

    final facturasMes = await listarFacturas(
      desdeIso: _formatIsoDate(monthStart),
      hastaIso: _formatIsoDate(monthEnd),
    );
    final totalFacturadoMes = facturasMes.fold<double>(
      0,
      (total, factura) => total + ((factura['total'] as num?)?.toDouble() ?? 0),
    );

    final serviciosMes = await _obtenerServiciosDashboard(
      monthStart: monthStart,
      idEmpleado: idEmpleado,
    );

    final recientes = ordenes.take(5).map((orden) {
      return DashboardOrderItem(
        noOrden: orden.noOrden,
        vehiculo: '${orden.vehiculoMarca} ${orden.vehiculoModelo}'.trim(),
        descripcion: orden.descripcionFalla,
        estado: orden.estado,
        fechaIngreso: orden.fechaIngreso,
        fechaCompromiso: orden.fechaCompromiso,
      );
    }).toList();

    return DashboardStats(
      ordenesActivas: activas.length,
      ordenesHoy: ordenesHoy,
      porEntregar: porEntregar,
      urgentes: urgentes,
      facturadoMes: totalFacturadoMes,
      facturasMes: facturasMes.length,
      alertasPendientes: alertasPendientes,
      enRevision: enRevision,
      enProgreso: enProgreso,
      completadasHoy: completadasHoy,
      canceladasMes: canceladasMes,
      serviciosMes: serviciosMes,
      ordenesRecientes: recientes,
      avisos: _buildDashboardAvisos(activas, today),
    );
  }

  Future<List<DashboardServiceStat>> _obtenerServiciosDashboard({
    required DateTime monthStart,
    int? idEmpleado,
  }) async {
    final db = await _db;
    final args = <Object?>[
      _formatDisplayDate(monthStart).substring(3, 5),
      monthStart.year.toString(),
    ];
    final employeeFilter = idEmpleado == null
        ? ''
        : '''
          AND EXISTS (
            SELECT 1 FROM trabaja t
            WHERE t.no_orden = os.no_orden AND t.id_empleado = ?
          )
        ''';
    if (idEmpleado != null) {
      args.add(idEmpleado);
    }

    final rows = await db.rawQuery('''
      SELECT s.tipo, COUNT(*) AS cantidad
      FROM servicio s
      JOIN orden_servicio os ON os.no_orden = s.no_orden
      WHERE substr(os.fecha_ingreso, 4, 2) = ?
        AND substr(os.fecha_ingreso, 7, 4) = ?
        $employeeFilter
      GROUP BY s.tipo
      ORDER BY cantidad DESC, s.tipo ASC
      LIMIT 5
    ''', args);

    final total = rows.fold<int>(
      0,
      (sum, row) => sum + ((row['cantidad'] as num?)?.toInt() ?? 0),
    );
    if (total == 0) {
      return const [];
    }

    return [
      for (final row in rows)
        DashboardServiceStat(
          tipo: row['tipo'] as String? ?? 'Sin tipo',
          cantidad: (row['cantidad'] as num?)?.toInt() ?? 0,
          porcentaje:
              ((((row['cantidad'] as num?)?.toDouble() ?? 0) / total) * 100)
                  .round(),
        ),
    ];
  }

  /// Si [idEmpleado] se especifica, solo devuelve las ordenes donde ese
  /// empleado esta asignado (tabla trabaja). Sin filtro, devuelve todas
  /// (uso de Administrador).
  Future<List<OrdenServicio>> listarOrdenes({int? idEmpleado}) async {
    final db = await _db;
    final filtro = idEmpleado != null
        ? '''
      WHERE EXISTS (
        SELECT 1 FROM trabaja t
        WHERE t.no_orden = os.no_orden AND t.id_empleado = ?
      )
    '''
        : '';
    final rows = await db.rawQuery('''
      SELECT
        os.no_orden,
        os.descripcion_falla,
        os.fecha_ingreso,
        os.fecha_compromiso,
        os.fecha_salida,
        os.estado,
        os.total,
        v.marca,
        v.modelo,
        v.placas,
        c.nombre AS cliente_nombre
      FROM orden_servicio os
      JOIN vehiculo v ON v.vin = os.vin
      JOIN cliente c ON c.id = v.id_cliente
      $filtro
      ORDER BY os.no_orden DESC
    ''', idEmpleado != null ? [idEmpleado] : []);
    return rows.map(OrdenServicio.fromMap).toList();
  }

  Future<OrdenDetalle?> obtenerOrdenCompleta(int noOrden) async {
    final db = await _db;
    final ordenRows = await db.rawQuery(
      '''
      SELECT
        os.no_orden,
        os.descripcion_falla,
        os.observaciones,
        os.fecha_ingreso,
        os.fecha_compromiso,
        os.fecha_salida,
        os.estado,
        os.kilometraje_ingreso,
        os.gasolina,
        os.subtotal,
        os.impuesto,
        os.total,
        v.vin,
        v.marca,
        v.modelo,
        v.color,
        v.anio,
        v.placas,
        c.id AS cliente_id,
        c.nombre AS cliente_nombre,
        c.direccion AS cliente_direccion
      FROM orden_servicio os
      JOIN vehiculo v ON v.vin = os.vin
      JOIN cliente c ON c.id = v.id_cliente
      WHERE os.no_orden = ?
      LIMIT 1
    ''',
      [noOrden],
    );

    if (ordenRows.isEmpty) {
      return null;
    }

    final ordenRow = ordenRows.first;
    final clienteId = ordenRow['cliente_id'] as int;

    final telefonos = await db.query(
      'cliente_telefono',
      where: 'id_cliente = ?',
      whereArgs: [clienteId],
    );
    final correos = await db.query(
      'cliente_correo',
      where: 'id_cliente = ?',
      whereArgs: [clienteId],
    );
    final servicios = await db.query(
      'servicio',
      where: 'no_orden = ?',
      whereArgs: [noOrden],
    );
    final accesorios = await db.query(
      'orden_accesorios',
      where: 'no_orden = ?',
      whereArgs: [noOrden],
    );
    final empleados = await db.rawQuery(
      '''
      SELECT e.id AS id_empleado, e.nombre, e.puesto, t.rol
      FROM trabaja t
      JOIN empleado e ON e.id = t.id_empleado
      WHERE t.no_orden = ?
    ''',
      [noOrden],
    );

    return OrdenDetalle.build(
      orden: ordenRow,
      telefonos: telefonos,
      correos: correos,
      servicios: servicios,
      accesorios: accesorios,
      empleados: empleados,
    );
  }

  Future<void> aceptarOrden(int noOrden) async {
    final db = await _db;
    var cambioAplicado = false;
    await db.transaction((txn) async {
      final updated = await txn.update(
        'orden_servicio',
        {'estado': 'En progreso'},
        where: 'no_orden = ? AND estado = ?',
        whereArgs: [noOrden, 'En revisión'],
      );
      if (updated > 0) {
        cambioAplicado = true;
        await _registrarCambioEstadoOrden(
          txn,
          noOrden: noOrden,
          estadoAnterior: 'En revisión',
          estadoNuevo: 'En progreso',
        );
      }
    });
    if (cambioAplicado) {
      await _notificarCambioEstadoPorCorreo(noOrden, 'En progreso');
    }
  }

  Future<void> cancelarOrden(int noOrden) async {
    final db = await _db;
    await db.transaction((txn) async {
      final updated = await txn.update(
        'orden_servicio',
        {'estado': 'Cancelado'},
        where: 'no_orden = ? AND estado = ?',
        whereArgs: [noOrden, 'En revisión'],
      );
      if (updated > 0) {
        await _registrarCambioEstadoOrden(
          txn,
          noOrden: noOrden,
          estadoAnterior: 'En revisión',
          estadoNuevo: 'Cancelado',
        );
      }
    });
  }

  /// [fechaSalidaIso] debe ir en formato yyyy-MM-dd: esta fecha tambien
  /// arranca el reloj de retencion para purgarOrdenesCompletadas().
  Future<void> completarOrden(int noOrden, String fechaSalidaIso) async {
    final db = await _db;
    var cambioAplicado = false;
    await db.transaction((txn) async {
      final updated = await txn.update(
        'orden_servicio',
        {'estado': 'Completado', 'fecha_salida': fechaSalidaIso},
        where: 'no_orden = ? AND estado = ?',
        whereArgs: [noOrden, 'En progreso'],
      );
      if (updated > 0) {
        cambioAplicado = true;
        await _registrarCambioEstadoOrden(
          txn,
          noOrden: noOrden,
          estadoAnterior: 'En progreso',
          estadoNuevo: 'Completado',
        );
      }
    });
    if (cambioAplicado) {
      await _notificarCambioEstadoPorCorreo(noOrden, 'Completado');
    }
  }

  /// Envia la notificacion de cambio de estado por correo. Se llama despues
  /// de que la transicion ya quedo persistida: un fallo aqui (SMTP caido,
  /// sin correo del cliente, etc.) solo se registra en consola y jamas
  /// revierte ni bloquea la transicion de estado.
  Future<void> _notificarCambioEstadoPorCorreo(
    int noOrden,
    String estadoNuevo,
  ) async {
    try {
      final orden = await obtenerOrdenCompleta(noOrden);
      if (orden == null) {
        return;
      }
      await CorreoService.instance.enviarNotificacionEstado(
        orden,
        estadoNuevo,
      );
    } catch (error) {
      // ignore: avoid_print
      print('No se pudo enviar la notificacion de estado de OT-$noOrden: $error');
    }
  }

  Future<void> _registrarCambioEstadoOrden(
    Transaction txn, {
    required int noOrden,
    required String estadoAnterior,
    required String estadoNuevo,
  }) async {
    final empleados = await txn.query(
      'trabaja',
      columns: ['id_empleado'],
      where: 'no_orden = ?',
      whereArgs: [noOrden],
    );
    if (empleados.isEmpty) {
      return;
    }

    final fechaCreacion = DateTime.now().toIso8601String();
    final titulo = 'Cambio de estado en OT-$noOrden';
    final mensaje =
        'La orden OT-$noOrden cambio de $estadoAnterior a $estadoNuevo.';
    for (final empleado in empleados) {
      await txn.insert('notificacion_usuario', {
        'id_empleado': empleado['id_empleado'],
        'no_orden': noOrden,
        'titulo': titulo,
        'mensaje': mensaje,
        'estado_anterior': estadoAnterior,
        'estado_nuevo': estadoNuevo,
        'leida': 0,
        'fecha_creacion': fechaCreacion,
      });
    }
  }

  Future<List<NotificacionUsuario>> listarNotificacionesUsuario(
    int idEmpleado,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'notificacion_usuario',
      where: 'id_empleado = ?',
      whereArgs: [idEmpleado],
      orderBy: 'datetime(fecha_creacion) DESC, id DESC',
    );
    return rows.map(NotificacionUsuario.fromMap).toList();
  }

  Future<int> contarNotificacionesNoLeidas(int idEmpleado) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM notificacion_usuario
      WHERE id_empleado = ? AND leida = 0
    ''',
      [idEmpleado],
    );
    return rows.first['total'] as int? ?? 0;
  }

  Future<void> marcarNotificacionLeida(int idNotificacion) async {
    final db = await _db;
    await db.update(
      'notificacion_usuario',
      {'leida': 1},
      where: 'id = ?',
      whereArgs: [idNotificacion],
    );
  }

  Future<void> marcarTodasNotificacionesLeidas(int idEmpleado) async {
    final db = await _db;
    await db.update(
      'notificacion_usuario',
      {'leida': 1},
      where: 'id_empleado = ?',
      whereArgs: [idEmpleado],
    );
  }

  Future<void> eliminarNotificacion(int idNotificacion) async {
    final db = await _db;
    await db.delete(
      'notificacion_usuario',
      where: 'id = ?',
      whereArgs: [idNotificacion],
    );
  }

  Future<void> _purgarOrdenesCompletadas(Database db) async {
    if (!kPurgaOrdenesActiva) {
      return;
    }
    await db.rawDelete('''
      DELETE FROM orden_servicio
      WHERE estado = 'Completado'
        AND fecha_salida IS NOT NULL
        AND date(fecha_salida) <= date('now', '-2 months')
    ''');
  }

  Future<void> purgarOrdenesCompletadas() async {
    final db = await _db;
    await _purgarOrdenesCompletadas(db);
  }

  Future<int> guardarOrdenServicio({
    required int noOrden,
    required String clienteNombre,
    required String clienteDireccion,
    required String clienteTelefono,
    required String clienteCorreo,
    required String vehiculoVin,
    required String vehiculoMarca,
    required String vehiculoModelo,
    required String vehiculoColor,
    required int? vehiculoAnio,
    required String vehiculoPlacas,
    required String descripcionFalla,
    required String fechaIngreso,
    required String fechaCompromiso,
    required String fechaSalida,
    required int? kilometrajeIngreso,
    required String gasolina,
    required Map<String, bool> accesorios,
    required Map<int, String> empleadosAsignados,
  }) async {
    final db = await _db;
    return db.transaction<int>((txn) async {
      final clienteId = await txn.insert('cliente', {
        'nombre': clienteNombre.trim(),
        'direccion': clienteDireccion.trim(),
      });

      final telefono = clienteTelefono.trim();
      if (telefono.isNotEmpty) {
        await txn.insert('cliente_telefono', {
          'id_cliente': clienteId,
          'telefono': telefono,
        });
      }

      final correo = clienteCorreo.trim();
      if (correo.isNotEmpty) {
        await txn.insert('cliente_correo', {
          'id_cliente': clienteId,
          'correo': correo,
        });
      }

      final vin = vehiculoVin.trim();
      final vehiculoMap = {
        'vin': vin,
        'marca': vehiculoMarca.trim(),
        'modelo': vehiculoModelo.trim(),
        'color': vehiculoColor.trim(),
        'kilometraje': kilometrajeIngreso ?? 0,
        'anio': vehiculoAnio,
        'placas': vehiculoPlacas.trim(),
        'id_cliente': clienteId,
      };
      final updatedVehicles = await txn.update(
        'vehiculo',
        vehiculoMap,
        where: 'vin = ?',
        whereArgs: [vin],
      );
      if (updatedVehicles == 0) {
        await txn.insert('vehiculo', vehiculoMap);
      }

      final orderId = await txn.insert('orden_servicio', {
        'no_orden': noOrden,
        'descripcion_falla': descripcionFalla.trim(),
        'fecha_ingreso': fechaIngreso.trim(),
        'fecha_compromiso': fechaCompromiso.trim().isEmpty
            ? null
            : fechaCompromiso.trim(),
        'fecha_salida': fechaSalida.trim().isEmpty ? null : fechaSalida.trim(),
        'estado': 'En revisión',
        'kilometraje_ingreso': kilometrajeIngreso,
        'gasolina': gasolina,
        'observaciones': '',
        'vin': vin,
      });

      for (final entry in accesorios.entries) {
        await txn.insert('orden_accesorios', {
          'no_orden': orderId,
          'accesorio': entry.key,
          'presente': entry.value ? 1 : 0,
        });
      }

      for (final entry in empleadosAsignados.entries) {
        await txn.insert('trabaja', {
          'id_empleado': entry.key,
          'no_orden': orderId,
          'rol': entry.value,
        });
      }

      return orderId;
    });
  }

  /// Actualiza una orden existente (modo edicion): SOLO toca los campos de
  /// ingreso. Nunca cambia no_orden, vin, estado, fecha_salida ni total,
  /// esos los maneja la maquina de estados / las transiciones.
  ///
  /// No requiere apagar foreign_keys: no se dropea ninguna tabla, solo se
  /// reemplazan filas hijas (cliente_telefono/correo, orden_accesorios,
  /// trabaja) cuyos padres (cliente, orden_servicio) nunca se borran.
  Future<void> actualizarOrdenServicio({
    required int noOrden,
    required String clienteNombre,
    required String clienteDireccion,
    required String clienteTelefono,
    required String clienteCorreo,
    required String vehiculoMarca,
    required String vehiculoModelo,
    required String vehiculoColor,
    required int? vehiculoAnio,
    required String vehiculoPlacas,
    required String descripcionFalla,
    required String fechaIngreso,
    required String fechaCompromiso,
    required int? kilometrajeIngreso,
    required String gasolina,
    required String observaciones,
    required Map<String, bool> accesorios,
    required Map<int, String> empleadosAsignados,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final ordenRows = await txn.query(
        'orden_servicio',
        columns: ['vin'],
        where: 'no_orden = ?',
        whereArgs: [noOrden],
        limit: 1,
      );
      if (ordenRows.isEmpty) {
        throw StateError('No se encontro la orden $noOrden');
      }
      final vin = ordenRows.first['vin'] as String;

      final vehiculoRows = await txn.query(
        'vehiculo',
        columns: ['id_cliente'],
        where: 'vin = ?',
        whereArgs: [vin],
        limit: 1,
      );
      if (vehiculoRows.isEmpty) {
        throw StateError('No se encontro el vehiculo $vin');
      }
      final clienteId = vehiculoRows.first['id_cliente'] as int;

      await txn.update(
        'cliente',
        {'nombre': clienteNombre.trim(), 'direccion': clienteDireccion.trim()},
        where: 'id = ?',
        whereArgs: [clienteId],
      );

      await txn.delete(
        'cliente_telefono',
        where: 'id_cliente = ?',
        whereArgs: [clienteId],
      );
      final telefono = clienteTelefono.trim();
      if (telefono.isNotEmpty) {
        await txn.insert('cliente_telefono', {
          'id_cliente': clienteId,
          'telefono': telefono,
        });
      }

      await txn.delete(
        'cliente_correo',
        where: 'id_cliente = ?',
        whereArgs: [clienteId],
      );
      final correo = clienteCorreo.trim();
      if (correo.isNotEmpty) {
        await txn.insert('cliente_correo', {
          'id_cliente': clienteId,
          'correo': correo,
        });
      }

      await txn.update(
        'vehiculo',
        {
          'marca': vehiculoMarca.trim(),
          'modelo': vehiculoModelo.trim(),
          'color': vehiculoColor.trim(),
          'anio': vehiculoAnio,
          'placas': vehiculoPlacas.trim(),
          'kilometraje': kilometrajeIngreso ?? 0,
        },
        where: 'vin = ?',
        whereArgs: [vin],
      );

      await txn.update(
        'orden_servicio',
        {
          'descripcion_falla': descripcionFalla.trim(),
          'fecha_ingreso': fechaIngreso.trim(),
          'fecha_compromiso': fechaCompromiso.trim().isEmpty
              ? null
              : fechaCompromiso.trim(),
          'kilometraje_ingreso': kilometrajeIngreso,
          'gasolina': gasolina,
          'observaciones': observaciones,
        },
        where: 'no_orden = ?',
        whereArgs: [noOrden],
      );

      await txn.delete(
        'orden_accesorios',
        where: 'no_orden = ?',
        whereArgs: [noOrden],
      );
      for (final entry in accesorios.entries) {
        await txn.insert('orden_accesorios', {
          'no_orden': noOrden,
          'accesorio': entry.key,
          'presente': entry.value ? 1 : 0,
        });
      }

      await txn.delete('trabaja', where: 'no_orden = ?', whereArgs: [noOrden]);
      for (final entry in empleadosAsignados.entries) {
        await txn.insert('trabaja', {
          'id_empleado': entry.key,
          'no_orden': noOrden,
          'rol': entry.value,
        });
      }
    });
  }

  static final Random _randomImagenComentario = Random();

  /// Carpeta destino para las imagenes de una orden, junto al archivo de la
  /// base de datos (no dentro de la base): `<dir_base>/comentarios_img/<no_orden>`.
  String _directorioImagenesComentario(String dirBase, int noOrden) {
    return p.join(dirBase, 'comentarios_img', noOrden.toString());
  }

  /// Copia [rutaOrigen] a [directorioDestino] comprimida como JPEG (ancho
  /// maximo _kAnchoMaximoImagenComentario, calidad _kCalidadJpegComentario)
  /// y devuelve la ruta RELATIVA a [dirBase] para guardar en la base.
  Future<String> _copiarYComprimirImagenComentario({
    required String rutaOrigen,
    required String directorioDestino,
    required String dirBase,
    required int noOrden,
  }) async {
    final bytesOriginales = await File(rutaOrigen).readAsBytes();
    final imagenDecodificada = img.decodeImage(bytesOriginales);
    if (imagenDecodificada == null) {
      throw FormatException('No se pudo leer la imagen: $rutaOrigen');
    }

    final imagenFinal = imagenDecodificada.width > _kAnchoMaximoImagenComentario
        ? img.copyResize(
            imagenDecodificada,
            width: _kAnchoMaximoImagenComentario,
          )
        : imagenDecodificada;
    final bytesJpg = img.encodeJpg(imagenFinal, quality: _kCalidadJpegComentario);

    final nombreUnico =
        '${DateTime.now().millisecondsSinceEpoch}_'
        '${_randomImagenComentario.nextInt(999999).toString().padLeft(6, '0')}'
        '.jpg';
    await Directory(directorioDestino).create(recursive: true);
    await File(p.join(directorioDestino, nombreUnico)).writeAsBytes(bytesJpg);

    return p.join('comentarios_img', noOrden.toString(), nombreUnico);
  }

  Future<int> guardarComentario({
    required int noOrden,
    required int idEmpleado,
    required String comentario,
    required bool visibleCliente,
    List<String> rutasImagenes = const [],
  }) async {
    final db = await _db;
    final dirBase = p.dirname(db.path);
    final directorioDestino = _directorioImagenesComentario(dirBase, noOrden);

    final rutasRelativasGuardadas = <String>[];
    try {
      for (final rutaOrigen in rutasImagenes) {
        final rutaRelativa = await _copiarYComprimirImagenComentario(
          rutaOrigen: rutaOrigen,
          directorioDestino: directorioDestino,
          dirBase: dirBase,
          noOrden: noOrden,
        );
        rutasRelativasGuardadas.add(rutaRelativa);
      }

      return await db.transaction<int>((txn) async {
        final fechaHora = DateTime.now().toIso8601String();
        final idComentario = await txn.insert('comentario_orden', {
          'no_orden': noOrden,
          'id_empleado': idEmpleado,
          'comentario': comentario.trim(),
          'fecha_hora': fechaHora,
          'visible_cliente': visibleCliente ? 1 : 0,
          'enviado': 0,
        });

        for (final rutaRelativa in rutasRelativasGuardadas) {
          await txn.insert('comentario_imagen', {
            'id_comentario': idComentario,
            'ruta': rutaRelativa,
            'fecha_hora': fechaHora,
          });
        }

        return idComentario;
      });
    } catch (error) {
      for (final rutaRelativa in rutasRelativasGuardadas) {
        final archivo = File(p.join(dirBase, rutaRelativa));
        if (archivo.existsSync()) {
          archivo.deleteSync();
        }
      }
      rethrow;
    }
  }

  Future<Map<int, List<ImagenComentario>>> _obtenerImagenesPorComentario(
    Database db,
    List<int> idsComentario,
    String dirBase,
  ) async {
    if (idsComentario.isEmpty) {
      return {};
    }
    final placeholders = List.filled(idsComentario.length, '?').join(', ');
    final rows = await db.query(
      'comentario_imagen',
      where: 'id_comentario IN ($placeholders)',
      whereArgs: idsComentario,
      orderBy: 'datetime(fecha_hora) ASC, id ASC',
    );

    final resultado = <int, List<ImagenComentario>>{};
    for (final row in rows) {
      final imagen = ImagenComentario.fromMap(row, dirBase: dirBase);
      resultado.putIfAbsent(imagen.idComentario, () => []).add(imagen);
    }
    return resultado;
  }

  Future<List<ComentarioOrden>> obtenerComentarios(int noOrden) async {
    final db = await _db;
    final dirBase = p.dirname(db.path);
    final rows = await db.rawQuery(
      '''
      SELECT
        c.id,
        c.no_orden,
        c.id_empleado,
        c.comentario,
        c.fecha_hora,
        c.visible_cliente,
        c.enviado,
        e.nombre AS nombre_empleado,
        e.puesto AS rol_empleado
      FROM comentario_orden c
      JOIN empleado e ON e.id = c.id_empleado
      WHERE c.no_orden = ?
      ORDER BY datetime(c.fecha_hora) ASC, c.id ASC
    ''',
      [noOrden],
    );
    final imagenesPorComentario = await _obtenerImagenesPorComentario(
      db,
      [for (final row in rows) row['id'] as int],
      dirBase,
    );
    return [
      for (final row in rows)
        ComentarioOrden.fromMap(
          row,
          imagenes: imagenesPorComentario[row['id'] as int] ?? const [],
        ),
    ];
  }

  Future<List<ComentarioOrden>> obtenerComentariosVisiblesNoEnviados(
    int noOrden,
  ) async {
    final db = await _db;
    final dirBase = p.dirname(db.path);
    final rows = await db.rawQuery(
      '''
      SELECT
        c.id,
        c.no_orden,
        c.id_empleado,
        c.comentario,
        c.fecha_hora,
        c.visible_cliente,
        c.enviado,
        e.nombre AS nombre_empleado,
        e.puesto AS rol_empleado
      FROM comentario_orden c
      JOIN empleado e ON e.id = c.id_empleado
      WHERE c.no_orden = ? AND c.visible_cliente = 1 AND c.enviado = 0
      ORDER BY datetime(c.fecha_hora) ASC, c.id ASC
    ''',
      [noOrden],
    );
    final imagenesPorComentario = await _obtenerImagenesPorComentario(
      db,
      [for (final row in rows) row['id'] as int],
      dirBase,
    );
    return [
      for (final row in rows)
        ComentarioOrden.fromMap(
          row,
          imagenes: imagenesPorComentario[row['id'] as int] ?? const [],
        ),
    ];
  }

  Future<void> marcarComentariosEnviados(List<int> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final db = await _db;
    await db.transaction((txn) async {
      final placeholders = List.filled(ids.length, '?').join(', ');
      await txn.update(
        'comentario_orden',
        {'enviado': 1},
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    });
  }

  Map<String, Object?> _toEmpleadoMap(
    Usuario usuario, {
    bool includePassword = true,
  }) {
    return {
      'nombre': usuario.nombre.trim(),
      'puesto': usuario.rol,
      'telefono': usuario.telefono.trim(),
      'activo': usuario.activo ? 1 : 0,
      if (includePassword)
        'contrasena': usuario.contrasena?.trim().isNotEmpty == true
            ? usuario.contrasena!.trim()
            : '123456',
    };
  }
}

const _estadosActivos = {'En revisión', 'En progreso'};

List<DashboardReminderItem> _buildDashboardAvisos(
  List<OrdenServicio> activas,
  DateTime today,
) {
  final avisos = <DashboardReminderItem>[];
  for (final orden in activas) {
    final compromiso = _parseStoredDate(orden.fechaCompromiso);
    if (compromiso == null) {
      continue;
    }
    final vehiculo = '${orden.vehiculoMarca} ${orden.vehiculoModelo}'.trim();
    if (compromiso.isBefore(today)) {
      avisos.add(
        DashboardReminderItem(
          titulo: 'OT-${orden.noOrden} vencida',
          subtitulo: '$vehiculo debia entregarse el ${orden.fechaCompromiso}',
          tipo: DashboardReminderType.danger,
        ),
      );
    } else if (_isSameDay(compromiso, today)) {
      avisos.add(
        DashboardReminderItem(
          titulo: 'OT-${orden.noOrden} vence hoy',
          subtitulo: '$vehiculo esta en estado ${orden.estado}',
          tipo: DashboardReminderType.warning,
        ),
      );
    }
  }

  if (avisos.isEmpty) {
    return const [
      DashboardReminderItem(
        titulo: 'Sin entregas vencidas',
        subtitulo: 'Las ordenes activas estan dentro de su fecha compromiso.',
        tipo: DashboardReminderType.info,
      ),
    ];
  }
  return avisos.take(4).toList();
}

DateTime? _parseStoredDate(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  final isoParts = text.split('-');
  if (isoParts.length == 3) {
    final year = int.tryParse(isoParts[0]);
    final month = int.tryParse(isoParts[1]);
    final day = int.tryParse(isoParts[2]);
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }

  final displayParts = text.split('/');
  if (displayParts.length == 3) {
    final day = int.tryParse(displayParts[0]);
    final month = int.tryParse(displayParts[1]);
    final year = int.tryParse(displayParts[2]);
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }

  return DateTime.tryParse(text);
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _isInRange(DateTime? value, DateTime start, DateTime end) {
  if (value == null) {
    return false;
  }
  return !value.isBefore(start) && !value.isAfter(end);
}

String _formatDisplayDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _formatIsoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
