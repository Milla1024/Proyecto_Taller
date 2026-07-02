class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    required this.activo,
    required this.numeroEmpleado,
  });

  final int id;
  final String nombre;
  final String correo;
  final String rol;
  final bool activo;
  final String numeroEmpleado;

  Usuario copyWith({
    int? id,
    String? nombre,
    String? correo,
    String? rol,
    bool? activo,
    String? numeroEmpleado,
  }) {
    return Usuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      rol: rol ?? this.rol,
      activo: activo ?? this.activo,
      numeroEmpleado: numeroEmpleado ?? this.numeroEmpleado,
    );
  }

  factory Usuario.fromMap(Map<String, Object?> map) {
    return Usuario(
      id: map['id'] as int,
      nombre: map['nombre'] as String,
      correo: map['correo'] as String,
      rol: map['rol'] as String,
      activo: (map['activo'] as int) == 1,
      numeroEmpleado: map['numero_empleado'] as String,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'correo': correo,
      'rol': rol,
      'activo': activo ? 1 : 0,
      'numero_empleado': numeroEmpleado,
    };
  }
}
