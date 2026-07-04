import 'package:flutter/material.dart';

import '../models/orden_detalle.dart';
import '../models/usuario.dart';
import '../widgets/custom_button.dart';
import 'ordenes_screen.dart';
import 'service_order_screen.dart';
import 'user_management_screen.dart';

class AppColors {
  static const ink = Color(0xFF202A33);
  static const slate = Color(0xFF5B6875);
  static const mist = Color(0xFFF3F5F6);
  static const panel = Color(0xFFFFFFFF);
  static const steel = Color(0xFF334155);
  static const softGray = Color(0xFFE9EEF2);
  static const teal = Color(0xFF0F766E);
  static const tealSoft = Color(0xFFE6F1F0);
  static const amber = Color(0xFFB7791F);
  static const amberSoft = Color(0xFFF5EBDD);
  static const coral = Color(0xFFB42318);
  static const coralSoft = Color(0xFFF4E4E1);
  static const border = Color(0xFFD6DDE3);
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.currentUser});

  final Usuario? currentUser;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selectedIndex = 0;
  int ordenesRefreshToken = 0;
  OrdenDetalle? ordenEnEdicion;

  bool get _isAdmin => widget.currentUser?.rol == 'Administrador';

  void _editarOrden(OrdenDetalle detalle) {
    setState(() {
      ordenEnEdicion = detalle;
      selectedIndex = 2;
    });
  }

  void _cerrarEdicionOrden() {
    setState(() {
      ordenEnEdicion = null;
      ordenesRefreshToken++;
      selectedIndex = 1;
    });
  }

  static const destinations = [
    _Destination('Inicio', Icons.dashboard_outlined),
    _Destination('Ordenes', Icons.assignment_outlined),
    _Destination('Orden servicio', Icons.fact_check_outlined),
    _Destination('Clientes', Icons.qr_code_2_outlined),
    _Destination('Facturas', Icons.receipt_long_outlined),
    _Destination('Usuarios', Icons.manage_accounts_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final visibleDestinations = _isAdmin
        ? destinations
        : destinations
              .where((destination) => destination.label != 'Usuarios')
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taller Central'),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: () {},
            icon: const Badge(
              label: Text('3'),
              child: Icon(Icons.notifications_none_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false);
            },
            icon: const Icon(Icons.logout_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (value) {
                setState(() => selectedIndex = value);
              },
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.panel,
              selectedIconTheme: const IconThemeData(color: AppColors.teal),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.teal,
                fontWeight: FontWeight.w700,
              ),
              destinations: [
                for (final destination in visibleDestinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    label: Text(destination.label),
                  ),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: selectedIndex,
              children: [
                DashboardView(
                  onCreateOrder: () => setState(() => selectedIndex = 2),
                  onOpenUsuarios: () => setState(() => selectedIndex = 5),
                  showUsuarios: _isAdmin,
                ),
                OrdenesScreen(
                  currentUser: widget.currentUser,
                  refreshToken: ordenesRefreshToken,
                  onEditarOrden: _editarOrden,
                ),
                ServiceOrderScreen(
                  currentUser: widget.currentUser,
                  ordenExistente: ordenEnEdicion,
                  onOrderSaved: () {
                    setState(() {
                      ordenesRefreshToken++;
                      selectedIndex = 0;
                    });
                  },
                  onOrderUpdated: _cerrarEdicionOrden,
                ),
                const ModulePlaceholder(
                  icon: Icons.qr_code_2_outlined,
                  title: 'Vista del cliente',
                  description:
                      'Seguimiento publico con codigo QR o link para consultar el estado del vehiculo.',
                ),
                const ModulePlaceholder(
                  icon: Icons.receipt_long_outlined,
                  title: 'Facturacion',
                  description:
                      'Historial de facturas, filtros, impresion y exportacion a Excel.',
                ),
                const UserManagementScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (value) {
                setState(() => selectedIndex = value);
              },
              destinations: [
                for (final destination in visibleDestinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    label: destination.label,
                  ),
              ],
            ),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.onCreateOrder,
    required this.onOpenUsuarios,
    required this.showUsuarios,
  });

  final VoidCallback onCreateOrder;
  final VoidCallback onOpenUsuarios;
  final bool showUsuarios;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeaderSection(onCreateOrder: onCreateOrder),
          const SizedBox(height: 20),
          const SummaryGrid(),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 980;
              if (!isWide) {
                return const Column(
                  children: [
                    ActiveOrdersPanel(),
                    SizedBox(height: 20),
                    StatsPanel(),
                    SizedBox(height: 20),
                    ReminderPanel(),
                  ],
                );
              }

              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: ActiveOrdersPanel()),
                  SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        StatsPanel(),
                        SizedBox(height: 20),
                        ReminderPanel(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          ModuleGrid(
            onOpenServiceOrder: onCreateOrder,
            onOpenUsuarios: onOpenUsuarios,
            showUsuarios: showUsuarios,
          ),
        ],
      ),
    );
  }
}

class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key, required this.onCreateOrder});

  final VoidCallback onCreateOrder;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Panel principal',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Gestion operativa para mantenimiento, ordenes, entregas, servicios y facturacion del taller.',
              ),
            ],
          ),
        ),
        CustomButton(
          label: 'Nueva orden',
          icon: Icons.add_circle_outline,
          onPressed: onCreateOrder,
        ),
      ],
    );
  }
}

class SummaryGrid extends StatelessWidget {
  const SummaryGrid({super.key});

  static const items = [
    SummaryItem(
      'Ordenes activas',
      '18',
      '+4 hoy',
      Icons.build_circle_outlined,
      AppColors.teal,
      AppColors.softGray,
    ),
    SummaryItem(
      'Vehiculos por entregar',
      '6',
      '3 urgentes',
      Icons.local_shipping_outlined,
      AppColors.steel,
      AppColors.softGray,
    ),
    SummaryItem(
      'Facturado este mes',
      'L 82,450',
      '+12%',
      Icons.payments_outlined,
      AppColors.steel,
      AppColors.softGray,
    ),
    SummaryItem(
      'Alertas pendientes',
      '3',
      'Revisar ahora',
      Icons.warning_amber_outlined,
      AppColors.coral,
      AppColors.coralSoft,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 640
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 152,
          ),
          itemBuilder: (context, index) => SummaryCard(item: items[index]),
        );
      },
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.item});

  final SummaryItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: item.softColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(item.icon, color: item.color),
                  ),
                ),
                const Spacer(),
                Text(
                  item.helper,
                  style: TextStyle(
                    color: item.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(item.value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(item.title),
          ],
        ),
      ),
    );
  }
}

class ActiveOrdersPanel extends StatelessWidget {
  const ActiveOrdersPanel({super.key});

  static const orders = [
    OrderItem(
      'OT-1042',
      'Toyota Hilux',
      'Cambio de clutch',
      'Alta',
      0.78,
      AppColors.coral,
    ),
    OrderItem(
      'OT-1041',
      'Honda Civic',
      'Mantenimiento general',
      'Media',
      0.46,
      AppColors.amber,
    ),
    OrderItem(
      'OT-1039',
      'Nissan Frontier',
      'Diagnostico electrico',
      'Media',
      0.32,
      AppColors.amber,
    ),
    OrderItem(
      'OT-1037',
      'Hyundai Tucson',
      'Revision de frenos',
      'Baja',
      0.88,
      AppColors.teal,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SectionSurface(
      title: 'Ordenes activas',
      actionLabel: 'Ver todas',
      icon: Icons.tune_outlined,
      child: Column(
        children: [for (final order in orders) OrderRow(order: order)],
      ),
    );
  }
}

class OrderRow extends StatelessWidget {
  const OrderRow({super.key, required this.order});

  final OrderItem order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.mist,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.directions_car_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.vehicle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('${order.code} - ${order.service}'),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: order.progress,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.teal,
                  backgroundColor: AppColors.mist,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PriorityChip(label: order.priority, color: order.color),
        ],
      ),
    );
  }
}

class StatsPanel extends StatelessWidget {
  const StatsPanel({super.key});

  static const stats = [
    StatItem('Mecanica general', 42, AppColors.teal),
    StatItem('Frenos', 28, AppColors.teal),
    StatItem('Diagnostico', 18, AppColors.teal),
    StatItem('Electricidad', 12, AppColors.teal),
  ];

  @override
  Widget build(BuildContext context) {
    return SectionSurface(
      title: 'Trabajos realizados',
      actionLabel: 'Estadisticas',
      icon: Icons.bar_chart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Distribucion del mes actual'),
          const SizedBox(height: 16),
          for (final stat in stats) StatBar(stat: stat),
        ],
      ),
    );
  }
}

class StatBar extends StatelessWidget {
  const StatBar({super.key, required this.stat});

  final StatItem stat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stat.label,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('${stat.value}%'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: stat.value / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: stat.color,
            backgroundColor: AppColors.mist,
          ),
        ],
      ),
    );
  }
}

class ReminderPanel extends StatelessWidget {
  const ReminderPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionSurface(
      title: 'Entregas y avisos',
      actionLabel: 'Recordatorios',
      icon: Icons.schedule_outlined,
      child: Column(
        children: const [
          ReminderTile(
            title: 'Honda Civic listo para entrega',
            subtitle: 'Cliente avisado por correo - 2:30 PM',
            color: AppColors.steel,
          ),
          ReminderTile(
            title: 'Toyota Hilux requiere autorizacion',
            subtitle: 'Pendiente aprobacion de repuesto',
            color: AppColors.coral,
          ),
          ReminderTile(
            title: 'Nissan Frontier vence manana',
            subtitle: 'Prioridad media, avance 32%',
            color: AppColors.amber,
          ),
        ],
      ),
    );
  }
}

class ReminderTile extends StatelessWidget {
  const ReminderTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 46,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ModuleGrid extends StatelessWidget {
  const ModuleGrid({
    super.key,
    required this.onOpenServiceOrder,
    required this.onOpenUsuarios,
    required this.showUsuarios,
  });

  final VoidCallback onOpenServiceOrder;
  final VoidCallback onOpenUsuarios;
  final bool showUsuarios;

  static const modules = [
    ModuleItem(
      'Mantenimientos',
      'Guardar detalle tecnico del vehiculo',
      Icons.car_repair_outlined,
      AppColors.steel,
    ),
    ModuleItem(
      'Usuarios',
      'CRUD para administradores y vista por rol',
      Icons.manage_accounts_outlined,
      AppColors.steel,
    ),
    ModuleItem(
      'Estado inicial',
      'Recepcion y condicion del vehiculo',
      Icons.fact_check_outlined,
      AppColors.steel,
    ),
    ModuleItem(
      'Cliente QR',
      'Link de seguimiento y envio por correo',
      Icons.qr_code_2_outlined,
      AppColors.steel,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final visibleModules = showUsuarios
        ? modules
        : modules.where((module) => module.title != 'Usuarios').toList();

    return SectionSurface(
      title: 'Modulos del sistema',
      actionLabel: 'Configurar',
      icon: Icons.apps_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900
              ? 4
              : constraints.maxWidth >= 560
              ? 2
              : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleModules.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 176,
            ),
            itemBuilder: (context, index) => ModuleCard(
              module: visibleModules[index],
              onTap: () {
                switch (visibleModules[index].title) {
                  case 'Estado inicial':
                    onOpenServiceOrder();
                    break;
                  case 'Usuarios':
                    onOpenUsuarios();
                    break;
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class ModuleCard extends StatelessWidget {
  const ModuleCard({super.key, required this.module, required this.onTap});

  final ModuleItem module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(module.icon, color: module.color, size: 30),
              const Spacer(),
              Text(
                module.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(module.description),
            ],
          ),
        ),
      ),
    );
  }
}

class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54, color: AppColors.steel),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(description, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionSurface extends StatelessWidget {
  const SectionSurface({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.icon,
    required this.child,
  });

  final String title;
  final String actionLabel;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.steel),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(onPressed: () {}, child: Text(actionLabel)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class PriorityChip extends StatelessWidget {
  const PriorityChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon);

  final String label;
  final IconData icon;
}

class SummaryItem {
  const SummaryItem(
    this.title,
    this.value,
    this.helper,
    this.icon,
    this.color,
    this.softColor,
  );

  final String title;
  final String value;
  final String helper;
  final IconData icon;
  final Color color;
  final Color softColor;
}

class OrderItem {
  const OrderItem(
    this.code,
    this.vehicle,
    this.service,
    this.priority,
    this.progress,
    this.color,
  );

  final String code;
  final String vehicle;
  final String service;
  final String priority;
  final double progress;
  final Color color;
}

class StatItem {
  const StatItem(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}

class ModuleItem {
  const ModuleItem(this.title, this.description, this.icon, this.color);

  final String title;
  final String description;
  final IconData icon;
  final Color color;
}
