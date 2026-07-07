PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS trabaja;
DROP TABLE IF EXISTS notificacion_usuario;
DROP TABLE IF EXISTS cotizacion_linea;
DROP TABLE IF EXISTS cotizacion;
DROP TABLE IF EXISTS factura_linea;
DROP TABLE IF EXISTS factura;
DROP TABLE IF EXISTS servicio;
DROP TABLE IF EXISTS orden_accesorios;
DROP TABLE IF EXISTS cliente_telefono;
DROP TABLE IF EXISTS cliente_correo;
DROP TABLE IF EXISTS orden_servicio;
DROP TABLE IF EXISTS vehiculo;
DROP TABLE IF EXISTS empleado;
DROP TABLE IF EXISTS cliente;

CREATE TABLE cliente (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL,
    direccion TEXT
);

CREATE TABLE cliente_telefono (
    id_cliente INTEGER NOT NULL,
    telefono TEXT NOT NULL,
    PRIMARY KEY (id_cliente, telefono),
    FOREIGN KEY (id_cliente) REFERENCES cliente(id)
        ON DELETE CASCADE
);

CREATE TABLE cliente_correo (
    id_cliente INTEGER NOT NULL,
    correo TEXT NOT NULL,
    PRIMARY KEY (id_cliente, correo),
    FOREIGN KEY (id_cliente) REFERENCES cliente(id)
        ON DELETE CASCADE
);

CREATE TABLE vehiculo (
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
);

CREATE TABLE empleado (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL,
    puesto TEXT NOT NULL,
    telefono TEXT,
    contrasena TEXT NOT NULL,
    activo INTEGER DEFAULT 1
);

CREATE TABLE orden_servicio (
    no_orden INTEGER PRIMARY KEY AUTOINCREMENT,
    descripcion_falla TEXT NOT NULL,
    fecha_ingreso TEXT NOT NULL,
    fecha_salida TEXT,
    estado TEXT NOT NULL CHECK(estado IN ('En Proceso', 'Finalizado', 'Cancelado')) DEFAULT 'En Proceso',
    kilometraje_ingreso INTEGER,
    gasolina TEXT,
    observaciones TEXT,
    subtotal REAL DEFAULT 0,
    impuesto REAL DEFAULT 0,
    total REAL DEFAULT 0,
    vin TEXT NOT NULL,
    FOREIGN KEY (vin) REFERENCES vehiculo(vin)
        ON DELETE CASCADE
);

CREATE TABLE orden_accesorios (
    no_orden INTEGER NOT NULL,
    accesorio TEXT NOT NULL,
    presente INTEGER DEFAULT 1,
    PRIMARY KEY (no_orden, accesorio),
    FOREIGN KEY (no_orden) REFERENCES orden_servicio(no_orden)
        ON DELETE CASCADE
);

CREATE TABLE trabaja (
    id_empleado INTEGER NOT NULL,
    no_orden INTEGER NOT NULL,
    rol TEXT,
    PRIMARY KEY (id_empleado, no_orden),
    FOREIGN KEY (id_empleado) REFERENCES empleado(id)
        ON DELETE CASCADE,
    FOREIGN KEY (no_orden) REFERENCES orden_servicio(no_orden)
        ON DELETE CASCADE
);

CREATE TABLE servicio (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    no_orden INTEGER NOT NULL,
    tipo TEXT NOT NULL,
    descripcion TEXT,
    costo_mano_obra REAL DEFAULT 0,
    costo_repuestos REAL DEFAULT 0,
    total REAL DEFAULT 0,
    FOREIGN KEY (no_orden) REFERENCES orden_servicio(no_orden)
        ON DELETE CASCADE
);

CREATE TABLE factura (
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
);

CREATE TABLE factura_linea (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    no_factura INTEGER NOT NULL,
    producto TEXT NOT NULL,
    cantidad REAL NOT NULL,
    precio_unitario REAL NOT NULL,
    total REAL NOT NULL,
    FOREIGN KEY (no_factura) REFERENCES factura(no_factura)
        ON DELETE CASCADE
);

CREATE INDEX idx_factura_fecha_iso
ON factura(fecha_iso);

CREATE TABLE cotizacion (
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
);

CREATE TABLE cotizacion_linea (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    no_cotizacion INTEGER NOT NULL,
    cantidad REAL NOT NULL,
    descripcion TEXT NOT NULL,
    precio_unitario REAL NOT NULL,
    total REAL NOT NULL,
    FOREIGN KEY (no_cotizacion) REFERENCES cotizacion(no_cotizacion)
        ON DELETE CASCADE
);

CREATE INDEX idx_cotizacion_cliente_nombre
ON cotizacion(cliente_nombre);

CREATE INDEX idx_cotizacion_fecha_iso
ON cotizacion(fecha_iso);

CREATE TABLE notificacion_usuario (
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
);

CREATE INDEX idx_notificacion_usuario_empleado_leida
ON notificacion_usuario(id_empleado, leida, fecha_creacion);
