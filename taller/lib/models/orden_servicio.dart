class OrdenServicio {
  const OrdenServicio({
    required this.noOrden,
    required this.descripcionFalla,
    required this.fechaIngreso,
    this.fechaCompromiso,
    this.fechaSalida,
    required this.estado,
    required this.total,
    required this.vehiculoMarca,
    required this.vehiculoModelo,
    required this.vehiculoPlacas,
    required this.clienteNombre,
  });

  final int noOrden;
  final String descripcionFalla;
  final String fechaIngreso;
  final String? fechaCompromiso;
  final String? fechaSalida;
  final String estado;
  final double total;
  final String vehiculoMarca;
  final String vehiculoModelo;
  final String vehiculoPlacas;
  final String clienteNombre;

  factory OrdenServicio.fromMap(Map<String, Object?> map) {
    return OrdenServicio(
      noOrden: map['no_orden'] as int,
      descripcionFalla: map['descripcion_falla'] as String? ?? '',
      fechaIngreso: map['fecha_ingreso'] as String? ?? '',
      fechaCompromiso: map['fecha_compromiso'] as String?,
      fechaSalida: map['fecha_salida'] as String?,
      estado: map['estado'] as String? ?? 'En Proceso',
      total: (map['total'] as num?)?.toDouble() ?? 0,
      vehiculoMarca: map['marca'] as String? ?? '',
      vehiculoModelo: map['modelo'] as String? ?? '',
      vehiculoPlacas: map['placas'] as String? ?? '',
      clienteNombre: map['cliente_nombre'] as String? ?? '',
    );
  }
}
