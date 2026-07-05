import 'imagen_comentario.dart';

class ComentarioOrden {
  const ComentarioOrden({
    required this.id,
    required this.noOrden,
    required this.idEmpleado,
    required this.comentario,
    required this.fechaHora,
    required this.visibleCliente,
    required this.enviado,
    this.nombreEmpleado,
    this.rolEmpleado,
    this.imagenes = const [],
  });

  final int id;
  final int noOrden;
  final int idEmpleado;
  final String comentario;
  final String fechaHora;
  final bool visibleCliente;
  final bool enviado;
  final String? nombreEmpleado;
  final String? rolEmpleado;
  final List<ImagenComentario> imagenes;

  factory ComentarioOrden.fromMap(
    Map<String, Object?> map, {
    List<ImagenComentario> imagenes = const [],
  }) {
    return ComentarioOrden(
      id: map['id'] as int,
      noOrden: map['no_orden'] as int,
      idEmpleado: map['id_empleado'] as int,
      comentario: map['comentario'] as String? ?? '',
      fechaHora: map['fecha_hora'] as String? ?? '',
      visibleCliente: (map['visible_cliente'] as int? ?? 1) == 1,
      enviado: (map['enviado'] as int? ?? 0) == 1,
      nombreEmpleado: map['nombre_empleado'] as String?,
      rolEmpleado: map['rol_empleado'] as String?,
      imagenes: imagenes,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'no_orden': noOrden,
      'id_empleado': idEmpleado,
      'comentario': comentario,
      'fecha_hora': fechaHora,
      'visible_cliente': visibleCliente ? 1 : 0,
      'enviado': enviado ? 1 : 0,
    };
  }
}
