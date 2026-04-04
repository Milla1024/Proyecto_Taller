DROP TABLE IF EXISTS Trabaja;
DROP TABLE IF EXISTS Servicio;
DROP TABLE IF EXISTS Orden_Accesorios;
DROP TABLE IF EXISTS Cliente_Telefono;
DROP TABLE IF EXISTS Cliente_Correo;
DROP TABLE IF EXISTS Orden;
DROP TABLE IF EXISTS Vehiculo;
DROP TABLE IF EXISTS Empleado;
DROP TABLE IF EXISTS Cliente;

create table Cliente(
	id INT primary key,
    nombre varchar(100),
    direccion varchar(100)
);

CREATE TABLE Cliente_Telefono (
    id_cliente INT,
    telefono VARCHAR(20),
    PRIMARY KEY (id_cliente, telefono),
    FOREIGN KEY (id_cliente) REFERENCES Cliente(id)
);

CREATE TABLE Cliente_Correo (
    id_cliente INT,
    correo VARCHAR(100),
    PRIMARY KEY (id_cliente, correo),
    FOREIGN KEY (id_cliente) REFERENCES Cliente(id)
);

CREATE TABLE Vehiculo (
    vin VARCHAR(50) PRIMARY KEY,
    marca VARCHAR(50),
    modelo VARCHAR(50),
    color VARCHAR(30),
    kilometraje INT,
    anio INT,
    placas VARCHAR(20),
    id_cliente INT,
    FOREIGN KEY (id_cliente) REFERENCES Cliente(id)
);

CREATE TABLE Orden (
    no_orden INT PRIMARY KEY,
    descripcion TEXT,
    fecha_ingreso DATE,
    fecha_salida DATE,
    vin VARCHAR(50),
    FOREIGN KEY (vin) REFERENCES Vehiculo(vin)
);

CREATE TABLE Orden_Accesorios (
    no_orden INT,
    accesorio VARCHAR(100),
    PRIMARY KEY (no_orden, accesorio),
    FOREIGN KEY (no_orden) REFERENCES Orden(no_orden)
);

CREATE TABLE Empleado (
    id INT PRIMARY KEY,
    nombre VARCHAR(100)
);

CREATE TABLE Trabaja (
    id_empleado INT,
    no_orden INT,
    PRIMARY KEY (id_empleado, no_orden),
    FOREIGN KEY (id_empleado) REFERENCES Empleado(id),
    FOREIGN KEY (no_orden) REFERENCES Orden(no_orden)
);

CREATE TABLE Servicio (
    vin VARCHAR(50),
    no_orden INT,
    tipo VARCHAR(50),
    PRIMARY KEY (vin, no_orden),
    FOREIGN KEY (vin) REFERENCES Vehiculo(vin),
    FOREIGN KEY (no_orden) REFERENCES Orden(no_orden)
);