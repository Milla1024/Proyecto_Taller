class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.rol,
    required this.activo,
    required this.numeroEmpleado,
    this.contrasena,
  });

  final int id;
  final String nombre;
  final String rol;
  final bool activo;
  final String numeroEmpleado;
  final String? contrasena;

  Usuario copyWith({
    int? id,
    String? nombre,
    String? rol,
    bool? activo,
    String? numeroEmpleado,
    String? contrasena,
  }) {
    return Usuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      rol: rol ?? this.rol,
      activo: activo ?? this.activo,
      numeroEmpleado: numeroEmpleado ?? this.numeroEmpleado,
      contrasena: contrasena ?? this.contrasena,
    );
  }

  factory Usuario.fromMap(Map<String, Object?> map) {
    final id = map['id'] as int;
    return Usuario(
      id: id,
      nombre: map['nombre'] as String,
      rol: map['puesto'] as String? ?? map['rol'] as String? ?? '',
      activo: (map['activo'] as int? ?? 1) == 1,
      numeroEmpleado: map['numero_empleado'] as String? ??
          'EMP-${id.toString().padLeft(3, '0')}',
    );
  }

  Map<String, Object?> toMap() {
    return {
      'nombre': nombre,
      'puesto': rol,
      'activo': activo ? 1 : 0,
      'numero_empleado': numeroEmpleado,
      if (contrasena != null && contrasena!.isNotEmpty)
        'contrase\u00f1a': contrasena,
    };
  }
}
