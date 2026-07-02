import '../models/usuario.dart';

class ApiService {
  Future<List<Usuario>> listarUsuarios() async {
    return const [];
  }

  Future<Usuario?> obtenerUsuario(int id) async {
    return null;
  }

  Future<void> crearUsuario(Usuario usuario) async {}

  Future<void> actualizarUsuario(Usuario usuario) async {}

  Future<void> eliminarUsuario(int id) async {}
}
