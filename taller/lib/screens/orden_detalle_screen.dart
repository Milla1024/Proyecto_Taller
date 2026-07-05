import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/comentario_orden.dart';
import '../models/estado_orden.dart';
import '../models/imagen_comentario.dart';
import '../models/orden_detalle.dart';
import '../models/urgencia.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import '../services/correo_service.dart';
import '../services/print_service.dart';
import 'home_screen.dart';
import 'ordenes_screen.dart';
import 'service_order_screen.dart';
import 'user_management_screen.dart';

class OrdenDetalleScreen extends StatefulWidget {
  const OrdenDetalleScreen({
    super.key,
    required this.noOrden,
    this.currentUser,
    this.onEditarOrden,
    this.onNotificationsChanged,
  });

  final int noOrden;
  final Usuario? currentUser;
  final ValueChanged<OrdenDetalle>? onEditarOrden;
  final Future<void> Function()? onNotificationsChanged;

  @override
  State<OrdenDetalleScreen> createState() => _OrdenDetalleScreenState();
}

class _OrdenDetalleScreenState extends State<OrdenDetalleScreen> {
  late Future<OrdenDetalle?> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.obtenerOrdenCompleta(widget.noOrden);
  }

  bool get _puedeVerTotales {
    final rol = widget.currentUser?.rol;
    return rol == null || rol == 'Administrador';
  }

  String get _rol => widget.currentUser?.rol ?? '';

  void _recargar() {
    setState(() {
      _future = ApiService.instance.obtenerOrdenCompleta(widget.noOrden);
    });
  }

  void _editarOrden(OrdenDetalle detalle) {
    widget.onEditarOrden?.call(detalle);
    Navigator.of(context).pop();
  }

  Future<void> _imprimirYAceptar(OrdenDetalle detalle) async {
    await _imprimir(detalle);
    await ApiService.instance.aceptarOrden(widget.noOrden);
    await widget.onNotificationsChanged?.call();
    if (!mounted) {
      return;
    }
    _recargar();
  }

  Future<void> _completarOrden() async {
    var fechaSeleccionada = DateTime.now();
    final confirmado = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Marcar como completada'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Confirma la fecha real de salida del vehiculo del taller.',
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fechaSeleccionada,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setStateDialog(() => fechaSeleccionada = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha de salida',
                        border: OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(_formatearFecha(fechaSeleccionada)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                  ),
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(fechaSeleccionada),
                  child: const Text('Confirmar entrega'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmado == null || !mounted) {
      return;
    }

    await ApiService.instance.completarOrden(
      widget.noOrden,
      _formatearFechaIso(confirmado),
    );
    await widget.onNotificationsChanged?.call();
    if (!mounted) {
      return;
    }
    _recargar();
  }

  Future<void> _cancelarOrden() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar orden'),
        content: Text(
          'Estas seguro de cancelar la orden OT-${widget.noOrden}? '
          'Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancelar orden'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) {
      return;
    }

    await ApiService.instance.cancelarOrden(widget.noOrden);
    await widget.onNotificationsChanged?.call();
    if (!mounted) {
      return;
    }
    _recargar();
  }

  Future<void> _imprimir(OrdenDetalle detalle) async {
    await printServiceOrder(
      ServiceOrderPrintData(
        orderNumber: 'OT-${detalle.noOrden}',
        customerName: detalle.clienteNombre,
        customerAddress: detalle.clienteDireccion ?? '',
        customerPhone: detalle.clienteTelefonos.join(', '),
        customerEmail: detalle.clienteCorreos.join(', '),
        entryDate: detalle.fechaIngreso,
        deliveryDate: detalle.fechaCompromiso ?? '',
        vehicleBrand: detalle.vehiculoMarca,
        vehicleModel: detalle.vehiculoModelo,
        vehicleYear: detalle.vehiculoAnio?.toString() ?? '',
        vehicleColor: detalle.vehiculoColor ?? '',
        vehiclePlate: detalle.vehiculoPlacas,
        vehicleVin: detalle.vehiculoVin,
        mileage: detalle.kilometrajeIngreso?.toString() ?? '',
        fuelLevel: detalle.gasolina ?? '',
        failureDescription: detalle.descripcionFalla,
        accessories: {
          for (final accesorio in detalle.accesorios)
            accesorio.nombre: accesorio.presente,
        },
        assignedEmployees: [
          for (final empleado in detalle.empleados)
            '${empleado.nombre} - ${empleado.rolOrden ?? empleado.puesto}',
        ],
        requiresQuote: false,
        authorizeRepair: false,
        authorizeTestDrive: false,
        acceptsTerms: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Orden OT-${widget.noOrden}')),
      body: FutureBuilder<OrdenDetalle?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No se pudo cargar la orden: ${snapshot.error}'),
              ),
            );
          }

          final detalle = snapshot.data;
          if (detalle == null) {
            return const Center(child: Text('No se encontro la orden.'));
          }

          final urgencia = calcularUrgencia(
            estado: detalle.estado,
            fechaCompromiso: detalle.fechaCompromiso,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OrdenDetalleHeader(detalle: detalle, urgencia: urgencia),
                const SizedBox(height: 16),
                FechasSection(detalle: detalle),
                const SizedBox(height: 16),
                VehiculoDetalleSection(detalle: detalle),
                const SizedBox(height: 16),
                ClienteDetalleSection(detalle: detalle),
                const SizedBox(height: 16),
                FallaDetalleSection(detalle: detalle),
                const SizedBox(height: 16),
                AccesoriosDetalleSection(detalle: detalle),
                const SizedBox(height: 16),
                ServiciosDetalleSection(detalle: detalle),
                const SizedBox(height: 16),
                EmpleadosDetalleSection(detalle: detalle),
                if (_puedeVerTotales) ...[
                  const SizedBox(height: 16),
                  TotalesDetalleSection(detalle: detalle),
                ],
                const SizedBox(height: 16),
                ComentariosDetalleSection(
                  noOrden: detalle.noOrden,
                  currentUser: widget.currentUser,
                  tieneCorreoCliente: detalle.clienteCorreos.isNotEmpty,
                ),
                const SizedBox(height: 20),
                AccionesEstadoBar(
                  estado: EstadoOrden.fromDb(detalle.estado),
                  rol: _rol,
                  onImprimir: () => _imprimir(detalle),
                  onImprimirYAceptar: () => _imprimirYAceptar(detalle),
                  onCancelar: _cancelarOrden,
                  onCompletar: _completarOrden,
                  onEditar: () => _editarOrden(detalle),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class OrdenDetalleHeader extends StatelessWidget {
  const OrdenDetalleHeader({
    super.key,
    required this.detalle,
    required this.urgencia,
  });

  final OrdenDetalle detalle;
  final Urgencia urgencia;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'OT-${detalle.noOrden}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            EstadoChip(estado: EstadoOrden.fromDb(detalle.estado)),
            PriorityChip(
              label: etiquetaUrgencia(urgencia),
              color: colorDeUrgencia(urgencia),
            ),
          ],
        ),
      ),
    );
  }
}

class FechasSection extends StatelessWidget {
  const FechasSection({super.key, required this.detalle});

  final OrdenDetalle detalle;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Fechas',
      icon: Icons.event_outlined,
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          ProfileField(label: 'Ingreso', value: _mostrar(detalle.fechaIngreso)),
          ProfileField(
            label: 'Compromiso',
            value: _mostrar(detalle.fechaCompromiso),
          ),
          ProfileField(
            label: 'Salida real',
            value: _mostrar(detalle.fechaSalida),
          ),
        ],
      ),
    );
  }
}

class VehiculoDetalleSection extends StatelessWidget {
  const VehiculoDetalleSection({super.key, required this.detalle});

  final OrdenDetalle detalle;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Vehiculo',
      icon: Icons.directions_car_outlined,
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          ProfileField(
            label: 'Placas',
            value: _mostrar(detalle.vehiculoPlacas),
          ),
          ProfileField(
            label: 'Marca y modelo',
            value: '${detalle.vehiculoMarca} ${detalle.vehiculoModelo}',
          ),
          ProfileField(
            label: 'Año',
            value: detalle.vehiculoAnio?.toString() ?? '—',
          ),
          ProfileField(label: 'Color', value: _mostrar(detalle.vehiculoColor)),
          ProfileField(
            label: 'Kilometraje de ingreso',
            value: detalle.kilometrajeIngreso?.toString() ?? '—',
          ),
          ProfileField(label: 'Gasolina', value: _mostrar(detalle.gasolina)),
        ],
      ),
    );
  }
}

class ClienteDetalleSection extends StatelessWidget {
  const ClienteDetalleSection({super.key, required this.detalle});

  final OrdenDetalle detalle;

  @override
  Widget build(BuildContext context) {
    final telefono = detalle.clienteTelefonos.isEmpty
        ? '—'
        : detalle.clienteTelefonos.join(', ');
    final correo = detalle.clienteCorreos.isEmpty
        ? '—'
        : detalle.clienteCorreos.join(', ');
    return FormSection(
      title: 'Cliente',
      icon: Icons.person_outline,
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          ProfileField(label: 'Nombre', value: _mostrar(detalle.clienteNombre)),
          ProfileField(
            label: 'Direccion',
            value: _mostrar(detalle.clienteDireccion),
          ),
          ProfileField(label: 'Telefono', value: telefono),
          ProfileField(label: 'Correo', value: correo),
        ],
      ),
    );
  }
}

class FallaDetalleSection extends StatelessWidget {
  const FallaDetalleSection({super.key, required this.detalle});

  final OrdenDetalle detalle;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Falla y observaciones',
      icon: Icons.report_problem_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_mostrar(detalle.descripcionFalla)),
          const SizedBox(height: 12),
          const Text(
            'Observaciones',
            style: TextStyle(
              color: AppColors.slate,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(_mostrar(detalle.observaciones)),
        ],
      ),
    );
  }
}

class AccesoriosDetalleSection extends StatelessWidget {
  const AccesoriosDetalleSection({super.key, required this.detalle});

  final OrdenDetalle detalle;

  @override
  Widget build(BuildContext context) {
    final recibidos = detalle.accesorios.where((a) => a.presente).toList();
    return FormSection(
      title: 'Accesorios recibidos',
      icon: Icons.checklist_outlined,
      child: recibidos.isEmpty
          ? const Text('Sin accesorios registrados.')
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final accesorio in recibidos)
                  PriorityChip(label: accesorio.nombre, color: AppColors.teal),
              ],
            ),
    );
  }
}

class ServiciosDetalleSection extends StatelessWidget {
  const ServiciosDetalleSection({super.key, required this.detalle});

  final OrdenDetalle detalle;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Servicios realizados',
      icon: Icons.build_outlined,
      child: detalle.servicios.isEmpty
          ? const Text('Sin servicios registrados.')
          : Column(
              children: [
                for (var i = 0; i < detalle.servicios.length; i++) ...[
                  if (i > 0) const Divider(height: 20, color: AppColors.border),
                  ServicioRealizadoTile(servicio: detalle.servicios[i]),
                ],
              ],
            ),
    );
  }
}

class ServicioRealizadoTile extends StatelessWidget {
  const ServicioRealizadoTile({super.key, required this.servicio});

  final ServicioRealizado servicio;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                servicio.tipo,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (servicio.descripcion.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(servicio.descripcion),
              ],
            ],
          ),
        ),
        Text(
          'L ${servicio.total.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class EmpleadosDetalleSection extends StatelessWidget {
  const EmpleadosDetalleSection({super.key, required this.detalle});

  final OrdenDetalle detalle;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Empleados asignados',
      icon: Icons.engineering_outlined,
      child: detalle.empleados.isEmpty
          ? const Text('Sin empleados asignados.')
          : Column(
              children: [
                for (final empleado in detalle.empleados)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(empleado.nombre)),
                        Text(empleado.rolOrden ?? empleado.puesto),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class TotalesDetalleSection extends StatelessWidget {
  const TotalesDetalleSection({super.key, required this.detalle});

  final OrdenDetalle detalle;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Totales',
      icon: Icons.payments_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TotalRow(label: 'Subtotal', value: detalle.subtotal),
          _TotalRow(label: 'Impuesto', value: detalle.impuesto),
          const Divider(color: AppColors.border),
          _TotalRow(label: 'Total', value: detalle.total, destacado: true),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.destacado = false,
  });

  final String label;
  final double value;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final style = destacado
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            'L ${value.toStringAsFixed(2)}',
            style: destacado ? style?.copyWith(color: AppColors.teal) : style,
          ),
        ],
      ),
    );
  }
}

bool _puedeComentar(String rol) {
  return rol == 'Administrador' || rol == 'Mecánico';
}

class ComentariosDetalleSection extends StatefulWidget {
  const ComentariosDetalleSection({
    super.key,
    required this.noOrden,
    required this.currentUser,
    required this.tieneCorreoCliente,
  });

  final int noOrden;
  final Usuario? currentUser;
  final bool tieneCorreoCliente;

  @override
  State<ComentariosDetalleSection> createState() =>
      _ComentariosDetalleSectionState();
}

class _ComentariosDetalleSectionState
    extends State<ComentariosDetalleSection> {
  late Future<List<ComentarioOrden>> _future;
  final _controller = TextEditingController();
  final List<String> _imagenesPendientes = [];
  bool _visibleCliente = true;
  bool _guardando = false;
  bool _enviando = false;

  bool get _puede => _puedeComentar(widget.currentUser?.rol ?? '');

  @override
  void initState() {
    super.initState();
    _future = _cargar();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<ComentarioOrden>> _cargar() {
    return ApiService.instance.obtenerComentarios(widget.noOrden);
  }

  void _recargar() {
    setState(() {
      _future = _cargar();
    });
  }

  Future<void> _seleccionarImagenes() async {
    final resultado = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
    );
    if (resultado == null) {
      return;
    }
    final rutas = [
      for (final archivo in resultado.files)
        if (archivo.path != null) archivo.path!,
    ];
    if (rutas.isEmpty) {
      return;
    }
    setState(() => _imagenesPendientes.addAll(rutas));
  }

  void _quitarPendiente(int index) {
    setState(() => _imagenesPendientes.removeAt(index));
  }

  Future<void> _agregar() async {
    final texto = _controller.text.trim();
    final usuario = widget.currentUser;
    if (texto.isEmpty || usuario == null) {
      return;
    }
    setState(() => _guardando = true);
    try {
      await ApiService.instance.guardarComentario(
        noOrden: widget.noOrden,
        idEmpleado: usuario.id,
        comentario: texto,
        visibleCliente: _visibleCliente,
        rutasImagenes: _imagenesPendientes,
      );
      _controller.clear();
      if (!mounted) {
        return;
      }
      setState(() {
        _guardando = false;
        _imagenesPendientes.clear();
      });
      _recargar();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el comentario')),
      );
    }
  }

  Future<void> _enviarAlCliente() async {
    final pendientes = await ApiService.instance
        .obtenerComentariosVisiblesNoEnviados(widget.noOrden);
    if (pendientes.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay comentarios nuevos para enviar'),
        ),
      );
      return;
    }

    setState(() => _enviando = true);
    final orden = await ApiService.instance.obtenerOrdenCompleta(
      widget.noOrden,
    );
    final estado = orden == null
        ? EstadoEnvioCorreo.fallo
        : await CorreoService.instance.enviarActualizacion(orden, pendientes);
    if (estado == EstadoEnvioCorreo.exito) {
      await ApiService.instance.marcarComentariosEnviados([
        for (final comentario in pendientes) comentario.id,
      ]);
    }

    if (!mounted) {
      return;
    }
    setState(() => _enviando = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_mensajeEnvio(estado))));
    _recargar();
  }

  String _mensajeEnvio(EstadoEnvioCorreo estado) {
    switch (estado) {
      case EstadoEnvioCorreo.exito:
        return 'Comentarios enviados al cliente';
      case EstadoEnvioCorreo.excedeTamano:
        return 'Las imágenes superan el límite de tamaño del correo';
      case EstadoEnvioCorreo.fallo:
        return 'No se pudo enviar el correo al cliente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Comentarios',
      icon: Icons.forum_outlined,
      child: FutureBuilder<List<ComentarioOrden>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Text(
              'No se pudieron cargar los comentarios: ${snapshot.error}',
            );
          }

          final comentarios = snapshot.data ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (comentarios.isEmpty)
                const Text('Aún no hay comentarios.')
              else
                for (final comentario in comentarios) ...[
                  ComentarioTile(comentario: comentario),
                  const SizedBox(height: 14),
                ],
              if (_puede) ...[
                const Divider(color: AppColors.border),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Escribe un comentario...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.steel,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      onPressed: _seleccionarImagenes,
                      icon: const Icon(Icons.attach_file_outlined),
                      label: const Text('Adjuntar imagen'),
                    ),
                    for (var i = 0; i < _imagenesPendientes.length; i++)
                      _ImagenPendienteThumb(
                        ruta: _imagenesPendientes[i],
                        onQuitar: () => _quitarPendiente(i),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _visibleCliente,
                      activeColor: AppColors.teal,
                      onChanged: (value) =>
                          setState(() => _visibleCliente = value ?? true),
                    ),
                    const Text('Visible al cliente'),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                      ),
                      onPressed: _guardando ? null : _agregar,
                      icon: const Icon(Icons.add_comment_outlined),
                      label: const Text('Agregar'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.teal,
                        side: const BorderSide(color: AppColors.teal),
                      ),
                      onPressed: (!widget.tieneCorreoCliente || _enviando)
                          ? null
                          : _enviarAlCliente,
                      icon: const Icon(Icons.email_outlined),
                      label: Text(
                        widget.tieneCorreoCliente
                            ? 'Enviar al cliente'
                            : 'El cliente no tiene correo registrado',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ImagenPendienteThumb extends StatelessWidget {
  const _ImagenPendienteThumb({required this.ruta, required this.onQuitar});

  final String ruta;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(
            File(ruta),
            width: 56,
            height: 56,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onQuitar,
            child: const CircleAvatar(
              radius: 10,
              backgroundColor: AppColors.coral,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

void _mostrarImagenCompleta(BuildContext context, ImagenComentario imagen) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          InteractiveViewer(child: Image.file(File(imagen.rutaAbsoluta))),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}

class ComentarioTile extends StatelessWidget {
  const ComentarioTile({super.key, required this.comentario});

  final ComentarioOrden comentario;

  String get _iniciales {
    final nombre = (comentario.nombreEmpleado ?? '').trim();
    if (nombre.isEmpty) {
      return '?';
    }
    final partes = nombre.split(RegExp(r'\s+'));
    final buffer = StringBuffer();
    for (final parte in partes.take(2)) {
      if (parte.isNotEmpty) {
        buffer.write(parte[0]);
      }
    }
    return buffer.toString().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: AppColors.tealSoft,
          child: Text(
            _iniciales,
            style: const TextStyle(
              color: AppColors.teal,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${comentario.nombreEmpleado ?? "Empleado"} · '
                    '${comentario.rolEmpleado ?? ""}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    _formatearFechaHora(comentario.fechaHora),
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(comentario.comentario),
              const SizedBox(height: 6),
              PriorityChip(
                label: comentario.visibleCliente
                    ? 'Visible al cliente'
                    : 'Nota interna',
                color: comentario.visibleCliente
                    ? AppColors.teal
                    : AppColors.steel,
              ),
              if (comentario.imagenes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final imagen in comentario.imagenes)
                      GestureDetector(
                        onTap: () => _mostrarImagenCompleta(context, imagen),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(imagen.rutaAbsoluta),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _formatearFechaHora(String iso) {
  final fecha = DateTime.tryParse(iso);
  if (fecha == null) {
    return iso;
  }
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  final hora = fecha.hour.toString().padLeft(2, '0');
  final minuto = fecha.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year} $hora:$minuto';
}

class AccionesEstadoBar extends StatelessWidget {
  const AccionesEstadoBar({
    super.key,
    required this.estado,
    required this.rol,
    required this.onImprimir,
    required this.onImprimirYAceptar,
    required this.onCancelar,
    required this.onCompletar,
    required this.onEditar,
  });

  final EstadoOrden estado;
  final String rol;
  final VoidCallback onImprimir;
  final VoidCallback onImprimirYAceptar;
  final VoidCallback onCancelar;
  final VoidCallback onCompletar;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final botones = <Widget>[
      if (puedeAceptar(estado, rol))
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
          onPressed: onImprimirYAceptar,
          icon: const Icon(Icons.print_outlined),
          label: const Text('Imprimir y aceptar'),
        ),
      if (puedeCompletar(estado, rol))
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
          onPressed: onCompletar,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Marcar como completada'),
        ),
      if (puedeCancelar(estado, rol))
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.coral,
            side: const BorderSide(color: AppColors.coral),
          ),
          onPressed: onCancelar,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancelar orden'),
        ),
      if (puedeEditar(estado, rol))
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(backgroundColor: AppColors.panel),
          onPressed: onEditar,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar'),
        ),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(backgroundColor: AppColors.panel),
        onPressed: onImprimir,
        icon: const Icon(Icons.print_outlined),
        label: const Text('Imprimir'),
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 10, runSpacing: 10, children: botones),
            if (estado == EstadoOrden.completado) ...[
              const SizedBox(height: 10),
              const Text(
                'Completada · se conservará y luego se depurará',
                style: TextStyle(
                  color: AppColors.slate,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _mostrar(String? valor) {
  if (valor == null || valor.trim().isEmpty) {
    return '—';
  }
  return valor;
}

String _formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

String _formatearFechaIso(DateTime fecha) {
  final anio = fecha.year.toString().padLeft(4, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  final dia = fecha.day.toString().padLeft(2, '0');
  return '$anio-$mes-$dia';
}
