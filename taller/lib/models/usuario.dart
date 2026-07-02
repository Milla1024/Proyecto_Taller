class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    required this.activo,
  });

  final int id;
  final String nombre;
  final String correo;
  final String rol;
  final bool activo;

  Usuario copyWith({
    int? id,
    String? nombre,
    String? correo,
    String? rol,
    bool? activo,
  }) {
    return Usuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      rol: rol ?? this.rol,
      activo: activo ?? this.activo,
    );
  }

  factory Usuario.fromMap(Map<String, Object?> map) {
    return Usuario(
      id: map['id'] as int,
      nombre: map['nombre'] as String,
      correo: map['correo'] as String,
      rol: map['rol'] as String,
      activo: (map['activo'] as int) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'correo': correo,
      'rol': rol,
      'activo': activo ? 1 : 0,
    };
  }
}
