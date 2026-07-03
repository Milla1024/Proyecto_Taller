import 'package:flutter/material.dart';

import '../models/orden_servicio.dart';
import '../models/urgencia.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class OrdenesScreen extends StatefulWidget {
  const OrdenesScreen({super.key, this.currentUser});

  final Usuario? currentUser;

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

  Future<void> _cargarOrdenes() async {
    try {
      final loaded = await ApiService.instance.listarOrdenes();
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
    copia.sort(
      (a, b) =>
          calcularUrgencia(a).index.compareTo(calcularUrgencia(b).index),
    );
    return copia;
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
            OrdenesTable(ordenes: ordenadasPorUrgencia)
          else
            OrdenesCardGrid(ordenes: ordenadasPorUrgencia),
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
  const OrdenesTable({super.key, required this.ordenes});

  final List<OrdenServicio> ordenes;

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
                    if (i > 0) const Divider(height: 1, color: AppColors.border),
                    OrdenesTableRow(orden: ordenes[i]),
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
            child: Text('TOTAL', style: _headerStyle, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class OrdenesTableRow extends StatelessWidget {
  const OrdenesTableRow({super.key, required this.orden});

  final OrdenServicio orden;

  @override
  Widget build(BuildContext context) {
    final urgencia = calcularUrgencia(orden);
    return Padding(
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
          Expanded(flex: 2, child: Text(textoEntrega(orden))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: PriorityChip(label: orden.estado, color: colorDeEstado(orden.estado)),
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
    );
  }
}

class OrdenesCardGrid extends StatelessWidget {
  const OrdenesCardGrid({super.key, required this.ordenes});

  final List<OrdenServicio> ordenes;

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
          itemBuilder: (context, index) => OrdenCard(orden: ordenes[index]),
        );
      },
    );
  }
}

class OrdenCard extends StatelessWidget {
  const OrdenCard({super.key, required this.orden});

  final OrdenServicio orden;

  @override
  Widget build(BuildContext context) {
    final urgencia = calcularUrgencia(orden);
    final terminada = orden.estado != 'En Proceso';
    return Card(
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
            Text(textoEntrega(orden)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: terminada ? 1.0 : null,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(8),
                    color: terminada
                        ? colorDeEstado(orden.estado)
                        : colorDeUrgencia(urgencia),
                    backgroundColor: AppColors.mist,
                  ),
                ),
                const SizedBox(width: 10),
                Text(orden.estado),
              ],
            ),
          ],
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

Color colorDeEstado(String estado) {
  switch (estado) {
    case 'Finalizado':
      return AppColors.teal;
    case 'Cancelado':
      return AppColors.coral;
    default:
      return AppColors.steel;
  }
}
