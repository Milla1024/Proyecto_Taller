class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.rol,
    required this.activo,
    required this.telefono,
    this.contrasena,
  });

  final int id;
  final String nombre;
  final String rol;
  final bool activo;
  final String telefono;
  final String? contrasena;

  Usuario copyWith({
    int? id,
    String? nombre,
    String? rol,
    bool? activo,
    String? telefono,
    String? contrasena,
  }) {
    return Usuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      rol: rol ?? this.rol,
      activo: activo ?? this.activo,
      telefono: telefono ?? this.telefono,
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
      telefono: map['telefono'] as String? ?? '',
    );
  }

  Map<String, Object?> toMap() {
    return {
      'nombre': nombre,
      'puesto': rol,
      'activo': activo ? 1 : 0,
      'telefono': telefono,
      if (contrasena != null && contrasena!.isNotEmpty)
        'contrasena': contrasena,
    };
  }
}
