class NotificacionUsuario {
  const NotificacionUsuario({
    required this.id,
    required this.idEmpleado,
    required this.noOrden,
    required this.titulo,
    required this.mensaje,
    this.estadoAnterior,
    required this.estadoNuevo,
    required this.leida,
    required this.fechaCreacion,
  });

  final int id;
  final int idEmpleado;
  final int noOrden;
  final String titulo;
  final String mensaje;
  final String? estadoAnterior;
  final String estadoNuevo;
  final bool leida;
  final String fechaCreacion;

  factory NotificacionUsuario.fromMap(Map<String, Object?> map) {
    return NotificacionUsuario(
      id: map['id'] as int,
      idEmpleado: map['id_empleado'] as int,
      noOrden: map['no_orden'] as int,
      titulo: map['titulo'] as String? ?? '',
      mensaje: map['mensaje'] as String? ?? '',
      estadoAnterior: map['estado_anterior'] as String?,
      estadoNuevo: map['estado_nuevo'] as String? ?? '',
      leida: (map['leida'] as int? ?? 0) == 1,
      fechaCreacion: map['fecha_creacion'] as String? ?? '',
    );
  }
}
