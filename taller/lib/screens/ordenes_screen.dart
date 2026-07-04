import 'package:flutter/material.dart';

import '../models/estado_orden.dart';
import '../models/orden_detalle.dart';
import '../models/orden_servicio.dart';
import '../models/urgencia.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'orden_detalle_screen.dart';

class OrdenesScreen extends StatefulWidget {
  const OrdenesScreen({
    super.key,
    this.currentUser,
    this.refreshToken = 0,
    this.onEditarOrden,
    this.onNotificationsChanged,
  });

  final Usuario? currentUser;
  final int refreshToken;
  final ValueChanged<OrdenDetalle>? onEditarOrden;
  final Future<void> Function()? onNotificationsChanged;

  @override
  State<OrdenesScreen> createState() => _OrdenesScreenState();
}

class _OrdenesScreenState extends State<OrdenesScreen> {
  final List<OrdenServicio> ordenes = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarOrdenes();
  }

  @override
  void didUpdateWidget(covariant OrdenesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.currentUser?.id != widget.currentUser?.id) {
      _cargarOrdenes();
    }
  }

  Future<void> _cargarOrdenes() async {
    try {
      final loaded = await ApiService.instance.listarOrdenes(
        idEmpleado: esVistaTabla ? null : widget.currentUser!.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        ordenes
          ..clear()
          ..addAll(loaded);
        isLoading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        isLoading = false;
        errorMessage = 'No se pudo cargar la base local: $error';
      });
    }
  }

  List<OrdenServicio> get ordenadasPorUrgencia {
    final copia = [...ordenes];
    copia.sort((a, b) => _urgenciaDe(a).index.compareTo(_urgenciaDe(b).index));
    return copia;
  }

  Future<void> _abrirDetalle(int noOrden) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrdenDetalleScreen(
          noOrden: noOrden,
          currentUser: widget.currentUser,
          onEditarOrden: widget.onEditarOrden,
          onNotificationsChanged: widget.onNotificationsChanged,
        ),
      ),
    );
    await _cargarOrdenes();
  }

  bool get esVistaTabla {
    final rol = widget.currentUser?.rol;
    return rol == null || rol == 'Administrador';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OrdenesHeader(),
          const SizedBox(height: 20),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (errorMessage != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(errorMessage!),
              ),
            )
          else if (ordenes.isEmpty)
            const OrdenesEmptyState()
          else if (esVistaTabla)
            OrdenesTable(ordenes: ordenadasPorUrgencia, onTap: _abrirDetalle)
          else
            OrdenesCardGrid(
              ordenes: ordenadasPorUrgencia,
              onTap: _abrirDetalle,
            ),
        ],
      ),
    );
  }
}

class OrdenesHeader extends StatelessWidget {
  const OrdenesHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ordenes', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Seguimiento de ordenes activas, priorizadas por urgencia de entrega.',
        ),
      ],
    );
  }
}

class OrdenesEmptyState extends StatelessWidget {
  const OrdenesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('No hay ordenes registradas todavia.')),
      ),
    );
  }
}

class OrdenesTable extends StatelessWidget {
  const OrdenesTable({super.key, required this.ordenes, required this.onTap});

  final List<OrdenServicio> ordenes;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth < 860
              ? 860.0
              : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  const OrdenesTableHeaderRow(),
                  for (var i = 0; i < ordenes.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppColors.border),
                    OrdenesTableRow(
                      orden: ordenes[i],
                      onTap: () => onTap(ordenes[i].noOrden),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class OrdenesTableHeaderRow extends StatelessWidget {
  const OrdenesTableHeaderRow({super.key});

  static const _headerStyle = TextStyle(
    color: AppColors.slate,
    fontWeight: FontWeight.w800,
    fontSize: 12,
    letterSpacing: 0.4,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.mist,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: const Row(
        children: [
          SizedBox(width: 10),
          SizedBox(width: 12),
          Expanded(flex: 2, child: Text('NO. ORDEN', style: _headerStyle)),
          Expanded(flex: 4, child: Text('VEHICULO', style: _headerStyle)),
          Expanded(flex: 3, child: Text('CLIENTE', style: _headerStyle)),
          Expanded(flex: 2, child: Text('ENTREGA', style: _headerStyle)),
          Expanded(flex: 2, child: Text('ESTADO', style: _headerStyle)),
          SizedBox(
            width: 100,
            child: Text(
              'TOTAL',
              style: _headerStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class OrdenesTableRow extends StatelessWidget {
  const OrdenesTableRow({super.key, required this.orden, required this.onTap});

  final OrdenServicio orden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urgencia = _urgenciaDe(orden);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            UrgenciaDot(urgencia: urgencia),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Text(
                'OT-${orden.noOrden}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                '${orden.vehiculoMarca} ${orden.vehiculoModelo} - ${orden.vehiculoPlacas}',
              ),
            ),
            Expanded(flex: 3, child: Text(orden.clienteNombre)),
            Expanded(flex: 2, child: Text(_textoEntregaDe(orden))),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: EstadoChip(estado: EstadoOrden.fromDb(orden.estado)),
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                'L ${orden.total.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrdenesCardGrid extends StatelessWidget {
  const OrdenesCardGrid({
    super.key,
    required this.ordenes,
    required this.onTap,
  });

  final List<OrdenServicio> ordenes;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ordenes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 220,
          ),
          itemBuilder: (context, index) => OrdenCard(
            orden: ordenes[index],
            onTap: () => onTap(ordenes[index].noOrden),
          ),
        );
      },
    );
  }
}

class OrdenCard extends StatelessWidget {
  const OrdenCard({super.key, required this.orden, required this.onTap});

  final OrdenServicio orden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urgencia = _urgenciaDe(orden);
    final estadoOrden = EstadoOrden.fromDb(orden.estado);
    final terminada = esEstadoTerminal(estadoOrden);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'OT-${orden.noOrden}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  PriorityChip(
                    label: etiquetaUrgencia(urgencia),
                    color: colorDeUrgencia(urgencia),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${orden.vehiculoMarca} ${orden.vehiculoModelo}'),
              const SizedBox(height: 4),
              Text(
                orden.vehiculoPlacas,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  orden.descripcionFalla,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(_textoEntregaDe(orden)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: terminada ? 1.0 : null,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(8),
                      color: terminada
                          ? colorDeTextoEstado(estadoOrden)
                          : colorDeUrgencia(urgencia),
                      backgroundColor: AppColors.mist,
                    ),
                  ),
                  const SizedBox(width: 10),
                  EstadoChip(estado: estadoOrden),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UrgenciaDot extends StatelessWidget {
  const UrgenciaDot({super.key, required this.urgencia});

  final Urgencia urgencia;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: colorDeUrgencia(urgencia),
        shape: BoxShape.circle,
      ),
    );
  }
}

class EstadoChip extends StatelessWidget {
  const EstadoChip({super.key, required this.estado});

  final EstadoOrden estado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorDeFondoEstado(estado),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        estado.label,
        style: TextStyle(
          color: colorDeTextoEstado(estado),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Urgencia _urgenciaDe(OrdenServicio orden) {
  return calcularUrgencia(
    estado: orden.estado,
    fechaCompromiso: orden.fechaCompromiso,
  );
}

String _textoEntregaDe(OrdenServicio orden) {
  return textoEntrega(
    estado: orden.estado,
    fechaCompromiso: orden.fechaCompromiso,
  );
}
