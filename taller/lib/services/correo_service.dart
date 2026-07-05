import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../models/comentario_orden.dart';
import '../models/orden_detalle.dart';

/// Limite de tamano total de adjuntos por correo. Con la compresion aplicada
/// al guardar las imagenes (Tarea 2 de comentarios) esto casi nunca deberia
/// alcanzarse, pero debe existir un tope explicito.
const int kLimiteAdjuntosBytes = 18 * 1024 * 1024;

enum EstadoEnvioCorreo { exito, fallo, excedeTamano }

/// Colores de referencia: mismos valores hex que AppColors
/// (lib/screens/home_screen.dart), reescritos aqui porque los correos
/// requieren CSS inline y este servicio no depende de widgets de Flutter.
class _ColoresCorreo {
  static const teal = '#0F766E';
  static const ink = '#202A33';
  static const slate = '#5B6875';
  static const mist = '#F3F5F6';
  static const border = '#D6DDE3';
  static const panel = '#FFFFFF';
}

class _ContenidoNotificacion {
  const _ContenidoNotificacion({required this.asunto, required this.cuerpo});

  final String asunto;
  final String cuerpo;
}

class CorreoService {
  CorreoService._();

  static final CorreoService instance = CorreoService._();

  String get _smtpHost => dotenv.env['SMTP_HOST'] ?? '';
  int get _smtpPort => int.tryParse(dotenv.env['SMTP_PORT'] ?? '') ?? 587;
  String get _smtpUsuario => dotenv.env['SMTP_USUARIO'] ?? '';
  String get _smtpPassword => dotenv.env['SMTP_PASSWORD'] ?? '';
  String get _nombreRemitente => dotenv.env['SMTP_NOMBRE_REMITENTE'] ?? 'Taller';
  String get _tallerNombre => dotenv.env['TALLER_NOMBRE'] ?? 'Taller';
  String get _tallerTelefono => dotenv.env['TALLER_TELEFONO'] ?? '';
  String get _tallerHorario => dotenv.env['TALLER_HORARIO'] ?? '';

  SmtpServer _smtpServer() {
    return SmtpServer(
      _smtpHost,
      port: _smtpPort,
      username: _smtpUsuario,
      password: _smtpPassword,
      ssl: _smtpPort == 465,
    );
  }

  /// Correo con los datos de la orden y los comentarios visibles al cliente,
  /// con las imagenes de esos comentarios como adjuntos. No lanza
  /// excepciones: cualquier fallo se atrapa y se devuelve EstadoEnvioCorreo.
  Future<EstadoEnvioCorreo> enviarActualizacion(
    OrdenDetalle orden,
    List<ComentarioOrden> comentarios,
  ) async {
    if (orden.clienteCorreos.isEmpty) {
      return EstadoEnvioCorreo.fallo;
    }

    final comentariosVisibles = comentarios
        .where((comentario) => comentario.visibleCliente)
        .toList();

    final archivosAdjuntos = <File>[];
    var tamanoTotalBytes = 0;
    for (final comentario in comentariosVisibles) {
      for (final imagen in comentario.imagenes) {
        final archivo = File(imagen.rutaAbsoluta);
        if (archivo.existsSync()) {
          tamanoTotalBytes += archivo.lengthSync();
          archivosAdjuntos.add(archivo);
        }
      }
    }

    if (tamanoTotalBytes > kLimiteAdjuntosBytes) {
      return EstadoEnvioCorreo.excedeTamano;
    }

    try {
      final mensaje = Message()
        ..from = Address(_smtpUsuario, _nombreRemitente)
        ..recipients.addAll(orden.clienteCorreos)
        ..subject = 'Actualización de su orden #${orden.noOrden}'
        ..html = _htmlActualizacion(orden, comentariosVisibles)
        ..attachments = [
          for (final archivo in archivosAdjuntos) FileAttachment(archivo),
        ];
      await send(mensaje, _smtpServer());
      return EstadoEnvioCorreo.exito;
    } catch (_) {
      return EstadoEnvioCorreo.fallo;
    }
  }

  /// Correo corto y generico segun la transicion de estado. Si la orden no
  /// tiene correo o la transicion no tiene texto definido, no envia nada.
  Future<bool> enviarNotificacionEstado(
    OrdenDetalle orden,
    String estadoNuevo,
  ) async {
    if (orden.clienteCorreos.isEmpty) {
      return false;
    }

    final contenido = _contenidoNotificacion(orden, estadoNuevo);
    if (contenido == null) {
      return false;
    }

    try {
      final mensaje = Message()
        ..from = Address(_smtpUsuario, _nombreRemitente)
        ..recipients.addAll(orden.clienteCorreos)
        ..subject = contenido.asunto
        ..html = _htmlNotificacion(contenido.cuerpo);
      await send(mensaje, _smtpServer());
      return true;
    } catch (_) {
      return false;
    }
  }

  _ContenidoNotificacion? _contenidoNotificacion(
    OrdenDetalle orden,
    String estadoNuevo,
  ) {
    final vehiculo = '${orden.vehiculoMarca} ${orden.vehiculoModelo}';
    switch (estadoNuevo) {
      case 'En progreso':
        return _ContenidoNotificacion(
          asunto: 'Su orden #${orden.noOrden} está en proceso',
          cuerpo:
              'Estimado/a ${orden.clienteNombre}, su vehículo $vehiculo ha '
              'sido recibido y el trabajo ha comenzado. Le avisaremos cuando '
              'esté listo. Gracias por confiar en $_tallerNombre.',
        );
      case 'Completado':
        return _ContenidoNotificacion(
          asunto: 'Su orden #${orden.noOrden} está lista',
          cuerpo:
              'Estimado/a ${orden.clienteNombre}, el trabajo en su vehículo '
              '$vehiculo ha finalizado y está listo para entrega. Puede '
              'pasar a recogerlo en $_tallerHorario. Gracias por confiar en '
              '$_tallerNombre.',
        );
      // Cancelado: texto preparado, sin activar por defecto. Para
      // habilitarlo basta con descomentar este caso.
      // case 'Cancelado':
      //   return _ContenidoNotificacion(
      //     asunto: 'Su orden #${orden.noOrden} fue cancelada',
      //     cuerpo:
      //         'Estimado/a ${orden.clienteNombre}, su orden de servicio '
      //         'para el vehículo $vehiculo ha sido cancelada. Cualquier '
      //         'consulta, comuníquese al $_tallerTelefono. Gracias por '
      //         'confiar en $_tallerNombre.',
      //   );
      default:
        return null;
    }
  }

  String _htmlEncabezado() {
    return '''
      <tr>
        <td style="background-color:${_ColoresCorreo.teal};padding:20px 24px;border-radius:8px 8px 0 0;">
          <h1 style="margin:0;color:#FFFFFF;font-family:Arial,Helvetica,sans-serif;font-size:20px;">
            $_tallerNombre
          </h1>
        </td>
      </tr>
    ''';
  }

  String _htmlPie() {
    return '''
      <tr>
        <td style="padding:16px 24px;border-top:1px solid ${_ColoresCorreo.border};">
          <p style="margin:0;color:${_ColoresCorreo.slate};font-family:Arial,Helvetica,sans-serif;font-size:12px;">
            $_tallerNombre &middot; $_tallerTelefono &middot; $_tallerHorario
          </p>
        </td>
      </tr>
    ''';
  }

  String _htmlDato(String etiqueta, String valor) {
    return '''
      <tr>
        <td style="padding:4px 0;color:${_ColoresCorreo.slate};font-family:Arial,Helvetica,sans-serif;font-size:13px;font-weight:bold;width:140px;">
          $etiqueta
        </td>
        <td style="padding:4px 0;color:${_ColoresCorreo.ink};font-family:Arial,Helvetica,sans-serif;font-size:13px;">
          $valor
        </td>
      </tr>
    ''';
  }

  String _htmlComentario(ComentarioOrden comentario) {
    final autor = comentario.nombreEmpleado ?? 'Taller';
    return '''
      <div style="padding:12px 16px;margin-bottom:10px;background-color:${_ColoresCorreo.mist};border-radius:6px;">
        <p style="margin:0 0 4px 0;color:${_ColoresCorreo.ink};font-family:Arial,Helvetica,sans-serif;font-size:13px;font-weight:bold;">
          $autor &middot; <span style="color:${_ColoresCorreo.slate};font-weight:normal;">${comentario.fechaHora}</span>
        </p>
        <p style="margin:0;color:${_ColoresCorreo.ink};font-family:Arial,Helvetica,sans-serif;font-size:13px;">
          ${comentario.comentario}
        </p>
      </div>
    ''';
  }

  String _htmlActualizacion(
    OrdenDetalle orden,
    List<ComentarioOrden> comentariosVisibles,
  ) {
    final comentariosHtml = comentariosVisibles.isEmpty
        ? '<p style="color:${_ColoresCorreo.slate};font-family:Arial,Helvetica,sans-serif;font-size:13px;">Sin comentarios nuevos.</p>'
        : comentariosVisibles.map(_htmlComentario).join();

    return '''
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:${_ColoresCorreo.mist};padding:24px 0;">
        <tr>
          <td align="center">
            <table role="presentation" width="560" cellpadding="0" cellspacing="0" style="background-color:${_ColoresCorreo.panel};border-radius:8px;overflow:hidden;">
              ${_htmlEncabezado()}
              <tr>
                <td style="padding:20px 24px;">
                  <h2 style="margin:0 0 12px 0;color:${_ColoresCorreo.ink};font-family:Arial,Helvetica,sans-serif;font-size:16px;">
                    Actualización de su orden #${orden.noOrden}
                  </h2>
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:16px;">
                    ${_htmlDato('Cliente:', orden.clienteNombre)}
                    ${_htmlDato('Vehículo:', '${orden.vehiculoMarca} ${orden.vehiculoModelo}')}
                    ${_htmlDato('No. de orden:', 'OT-${orden.noOrden}')}
                    ${_htmlDato('Estado actual:', orden.estado)}
                  </table>
                  <h3 style="margin:0 0 8px 0;color:${_ColoresCorreo.ink};font-family:Arial,Helvetica,sans-serif;font-size:14px;">
                    Comentarios
                  </h3>
                  $comentariosHtml
                </td>
              </tr>
              ${_htmlPie()}
            </table>
          </td>
        </tr>
      </table>
    ''';
  }

  String _htmlNotificacion(String cuerpo) {
    return '''
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:${_ColoresCorreo.mist};padding:24px 0;">
        <tr>
          <td align="center">
            <table role="presentation" width="560" cellpadding="0" cellspacing="0" style="background-color:${_ColoresCorreo.panel};border-radius:8px;overflow:hidden;">
              ${_htmlEncabezado()}
              <tr>
                <td style="padding:20px 24px;">
                  <p style="margin:0;color:${_ColoresCorreo.ink};font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.5;">
                    $cuerpo
                  </p>
                </td>
              </tr>
              ${_htmlPie()}
            </table>
          </td>
        </tr>
      </table>
    ''';
  }
}
