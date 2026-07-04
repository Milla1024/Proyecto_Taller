class ServicioRealizado {
  const ServicioRealizado({
    required this.id,
    required this.tipo,
    required this.descripcion,
    required this.costoManoObra,
    required this.costoRepuestos,
    required this.total,
  });

  final int id;
  final String tipo;
  final String descripcion;
  final double costoManoObra;
  final double costoRepuestos;
  final double total;

  factory ServicioRealizado.fromMap(Map<String, Object?> map) {
    return ServicioRealizado(
      id: map['id'] as int,
      tipo: map['tipo'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      costoManoObra: (map['costo_mano_obra'] as num?)?.toDouble() ?? 0,
      costoRepuestos: (map['costo_repuestos'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AccesorioOrden {
  const AccesorioOrden({required this.nombre, required this.presente});

  final String nombre;
  final bool presente;

  factory AccesorioOrden.fromMap(Map<String, Object?> map) {
    return AccesorioOrden(
      nombre: map['accesorio'] as String? ?? '',
      presente: (map['presente'] as int? ?? 0) == 1,
    );
  }
}

class EmpleadoAsignado {
  const EmpleadoAsignado({
    required this.id,
    required this.nombre,
    required this.puesto,
    this.rolOrden,
  });

  final int id;
  final String nombre;
  final String puesto;
  final String? rolOrden;

  factory EmpleadoAsignado.fromMap(Map<String, Object?> map) {
    return EmpleadoAsignado(
      id: map['id_empleado'] as int,
      nombre: map['nombre'] as String? ?? '',
      puesto: map['puesto'] as String? ?? '',
      rolOrden: map['rol'] as String?,
    );
  }
}

class OrdenDetalle {
  const OrdenDetalle({
    required this.noOrden,
    required this.descripcionFalla,
    this.observaciones,
    required this.fechaIngreso,
    this.fechaCompromiso,
    this.fechaSalida,
    required this.estado,
    this.kilometrajeIngreso,
    this.gasolina,
    required this.subtotal,
    required this.impuesto,
    required this.total,
    required this.vehiculoVin,
    required this.vehiculoMarca,
    required this.vehiculoModelo,
    this.vehiculoColor,
    this.vehiculoAnio,
    required this.vehiculoPlacas,
    required this.clienteNombre,
    this.clienteDireccion,
    required this.clienteTelefonos,
    required this.clienteCorreos,
    required this.servicios,
    required this.accesorios,
    required this.empleados,
  });

  final int noOrden;
  final String descripcionFalla;
  final String? observaciones;
  final String fechaIngreso;
  final String? fechaCompromiso;
  final String? fechaSalida;
  final String estado;
  final int? kilometrajeIngreso;
  final String? gasolina;
  final double subtotal;
  final double impuesto;
  final double total;
  final String vehiculoVin;
  final String vehiculoMarca;
  final String vehiculoModelo;
  final String? vehiculoColor;
  final int? vehiculoAnio;
  final String vehiculoPlacas;
  final String clienteNombre;
  final String? clienteDireccion;
  final List<String> clienteTelefonos;
  final List<String> clienteCorreos;
  final List<ServicioRealizado> servicios;
  final List<AccesorioOrden> accesorios;
  final List<EmpleadoAsignado> empleados;

  factory OrdenDetalle.build({
    required Map<String, Object?> orden,
    required List<Map<String, Object?>> telefonos,
    required List<Map<String, Object?>> correos,
    required List<Map<String, Object?>> servicios,
    required List<Map<String, Object?>> accesorios,
    required List<Map<String, Object?>> empleados,
  }) {
    return OrdenDetalle(
      noOrden: orden['no_orden'] as int,
      descripcionFalla: orden['descripcion_falla'] as String? ?? '',
      observaciones: orden['observaciones'] as String?,
      fechaIngreso: orden['fecha_ingreso'] as String? ?? '',
      fechaCompromiso: orden['fecha_compromiso'] as String?,
      fechaSalida: orden['fecha_salida'] as String?,
      estado: orden['estado'] as String? ?? 'En revisión',
      kilometrajeIngreso: orden['kilometraje_ingreso'] as int?,
      gasolina: orden['gasolina'] as String?,
      subtotal: (orden['subtotal'] as num?)?.toDouble() ?? 0,
      impuesto: (orden['impuesto'] as num?)?.toDouble() ?? 0,
      total: (orden['total'] as num?)?.toDouble() ?? 0,
      vehiculoVin: orden['vin'] as String? ?? '',
      vehiculoMarca: orden['marca'] as String? ?? '',
      vehiculoModelo: orden['modelo'] as String? ?? '',
      vehiculoColor: orden['color'] as String?,
      vehiculoAnio: orden['anio'] as int?,
      vehiculoPlacas: orden['placas'] as String? ?? '',
      clienteNombre: orden['cliente_nombre'] as String? ?? '',
      clienteDireccion: orden['cliente_direccion'] as String?,
      clienteTelefonos: [
        for (final row in telefonos) row['telefono'] as String,
      ],
      clienteCorreos: [for (final row in correos) row['correo'] as String],
      servicios: servicios.map(ServicioRealizado.fromMap).toList(),
      accesorios: accesorios.map(AccesorioOrden.fromMap).toList(),
      empleados: empleados.map(EmpleadoAsignado.fromMap).toList(),
    );
  }
}
