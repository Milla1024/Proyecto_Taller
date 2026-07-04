import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/orden_detalle.dart';
import '../models/orden_servicio.dart';
import '../models/usuario.dart';

/// Activar SOLO cuando el modulo de facturas persista la transaccion antes
/// de perder acceso a la orden de origen. Mientras este en false,
/// purgarOrdenesCompletadas() queda cableada pero es un no-op.
const bool kPurgaOrdenesActiva = false;

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
    final rows = await db.rawQuery(
      '''
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
    ''',
      idEmpleado != null ? [idEmpleado] : [],
    );
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
    await db.update(
      'orden_servicio',
      {'estado': 'En progreso'},
      where: 'no_orden = ? AND estado = ?',
      whereArgs: [noOrden, 'En revisión'],
    );
  }

  Future<void> cancelarOrden(int noOrden) async {
    final db = await _db;
    await db.update(
      'orden_servicio',
      {'estado': 'Cancelado'},
      where: 'no_orden = ? AND estado = ?',
      whereArgs: [noOrden, 'En revisión'],
    );
  }

  /// [fechaSalidaIso] debe ir en formato yyyy-MM-dd: esta fecha tambien
  /// arranca el reloj de retencion para purgarOrdenesCompletadas().
  Future<void> completarOrden(int noOrden, String fechaSalidaIso) async {
    final db = await _db;
    await db.update(
      'orden_servicio',
      {'estado': 'Completado', 'fecha_salida': fechaSalidaIso},
      where: 'no_orden = ? AND estado = ?',
      whereArgs: [noOrden, 'En progreso'],
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

      await txn.delete(
        'trabaja',
        where: 'no_orden = ?',
        whereArgs: [noOrden],
      );
      for (final entry in empleadosAsignados.entries) {
        await txn.insert('trabaja', {
          'id_empleado': entry.key,
          'no_orden': noOrden,
          'rol': entry.value,
        });
      }
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
