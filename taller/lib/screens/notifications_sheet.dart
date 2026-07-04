import 'package:flutter/material.dart';

import '../models/notificacion_usuario.dart';
import '../services/api_service.dart';

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({
    super.key,
    required this.idEmpleado,
    required this.onChanged,
  });

  final int idEmpleado;
  final Future<void> Function() onChanged;

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  late Future<List<NotificacionUsuario>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargar();
  }

  Future<List<NotificacionUsuario>> _cargar() {
    return ApiService.instance.listarNotificacionesUsuario(widget.idEmpleado);
  }

  Future<void> _recargar() async {
    setState(() {
      _future = _cargar();
    });
    await widget.onChanged();
  }

  Future<void> _marcarLeida(NotificacionUsuario notificacion) async {
    await ApiService.instance.marcarNotificacionLeida(notificacion.id);
    if (mounted) {
      await _recargar();
    }
  }

  Future<void> _marcarTodasLeidas() async {
    await ApiService.instance.marcarTodasNotificacionesLeidas(
      widget.idEmpleado,
    );
    if (mounted) {
      await _recargar();
    }
  }

  Future<void> _eliminar(NotificacionUsuario notificacion) async {
    await ApiService.instance.eliminarNotificacion(notificacion.id);
    if (mounted) {
      await _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Notificaciones',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _marcarTodasLeidas,
                    icon: const Icon(Icons.done_all_outlined),
                    label: const Text('Marcar leidas'),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<NotificacionUsuario>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'No se pudieron cargar las notificaciones: ${snapshot.error}',
                        ),
                      );
                    }

                    final notificaciones = snapshot.data ?? [];
                    if (notificaciones.isEmpty) {
                      return const Center(
                        child: Text('No tienes notificaciones pendientes.'),
                      );
                    }

                    return ListView.separated(
                      itemCount: notificaciones.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final notificacion = notificaciones[index];
                        return _NotificationTile(
                          notificacion: notificacion,
                          onMarkRead: notificacion.leida
                              ? null
                              : () => _marcarLeida(notificacion),
                          onDelete: () => _eliminar(notificacion),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notificacion,
    required this.onMarkRead,
    required this.onDelete,
  });

  final NotificacionUsuario notificacion;
  final VoidCallback? onMarkRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = notificacion.leida
        ? Theme.of(context).colorScheme.outline
        : Theme.of(context).colorScheme.primary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          notificacion.leida
              ? Icons.notifications_none_outlined
              : Icons.notifications_active_outlined,
          color: color,
        ),
      ),
      title: Text(
        notificacion.titulo,
        style: TextStyle(
          fontWeight: notificacion.leida ? FontWeight.w600 : FontWeight.w800,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(notificacion.mensaje),
      ),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            tooltip: 'Marcar como leida',
            onPressed: onMarkRead,
            icon: const Icon(Icons.mark_email_read_outlined),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
