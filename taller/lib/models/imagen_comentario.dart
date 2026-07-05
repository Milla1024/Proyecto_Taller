import 'package:path/path.dart' as p;

class ImagenComentario {
  const ImagenComentario({
    required this.id,
    required this.idComentario,
    required this.ruta,
    required this.fechaHora,
    required this.dirBase,
  });

  final int id;
  final int idComentario;
  final String ruta;
  final String fechaHora;

  /// Directorio base (donde vive liteTaller.db) usado para resolver [ruta],
  /// que se guarda relativa en la base para no romperse si esa carpeta se
  /// mueve. Se pasa al construir el objeto porque no es un dato de la fila.
  final String dirBase;

  String get rutaAbsoluta => p.join(dirBase, ruta);

  factory ImagenComentario.fromMap(
    Map<String, Object?> map, {
    required String dirBase,
  }) {
    return ImagenComentario(
      id: map['id'] as int,
      idComentario: map['id_comentario'] as int,
      ruta: map['ruta'] as String? ?? '',
      fechaHora: map['fecha_hora'] as String? ?? '',
      dirBase: dirBase,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'id_comentario': idComentario,
      'ruta': ruta,
      'fecha_hora': fechaHora,
    };
  }
}
