import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/orden_detalle.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import '../services/print_service.dart';
import '../widgets/custom_button.dart';
import 'cotizaciones_screen.dart';
import 'notifications_sheet.dart';
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
  int serviceOrderRefreshToken = 0;
  int usuariosRefreshToken = 0;
  int notificacionesNoLeidas = 0;
  OrdenDetalle? ordenEnEdicion;

  bool get _isAdmin => widget.currentUser?.rol == 'Administrador';

  @override
  void initState() {
    super.initState();
    _cargarConteoNotificaciones();
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser?.id != widget.currentUser?.id) {
      _cargarConteoNotificaciones();
    }
  }

  Future<void> _cargarConteoNotificaciones() async {
    final idEmpleado = widget.currentUser?.id;
    if (idEmpleado == null) {
      setState(() => notificacionesNoLeidas = 0);
      return;
    }

    final count = await ApiService.instance.contarNotificacionesNoLeidas(
      idEmpleado,
    );
    if (!mounted) {
      return;
    }
    setState(() => notificacionesNoLeidas = count);
  }

  Future<void> _abrirNotificaciones() async {
    final idEmpleado = widget.currentUser?.id;
    if (idEmpleado == null) {
      return;
    }

    await _cargarConteoNotificaciones();
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => NotificationsSheet(
        idEmpleado: idEmpleado,
        onChanged: _cargarConteoNotificaciones,
      ),
    );
    await _cargarConteoNotificaciones();
  }

  void _seleccionarVentana(int value) {
    setState(() {
      selectedIndex = value;
      ordenesRefreshToken++;
      serviceOrderRefreshToken++;
      usuariosRefreshToken++;
    });
    _cargarConteoNotificaciones();
  }

  void _editarOrden(OrdenDetalle detalle) {
    setState(() {
      ordenEnEdicion = detalle;
      selectedIndex = 2;
      serviceOrderRefreshToken++;
    });
  }

  void _cerrarEdicionOrden() {
    setState(() {
      ordenEnEdicion = null;
      ordenesRefreshToken++;
      serviceOrderRefreshToken++;
      selectedIndex = 1;
    });
  }

  static const destinations = [
    _Destination('Inicio', Icons.dashboard_outlined),
    _Destination('Ordenes', Icons.assignment_outlined),
    _Destination('Orden servicio', Icons.fact_check_outlined),
    _Destination('Cotizaciones', Icons.request_quote_outlined),
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
        title: const Text('Taller PitStop'),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: _abrirNotificaciones,
            icon: Badge(
              isLabelVisible: notificacionesNoLeidas > 0,
              label: Text('$notificacionesNoLeidas'),
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
              onDestinationSelected: _seleccionarVentana,
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
                _ShellPage(
                  active: selectedIndex == 0,
                  child: DashboardView(
                    onCreateOrder: () => _seleccionarVentana(2),
                    idEmpleado: _isAdmin ? null : widget.currentUser?.id,
                  ),
                ),
                _ShellPage(
                  active: selectedIndex == 1,
                  child: OrdenesScreen(
                    currentUser: widget.currentUser,
                    refreshToken: ordenesRefreshToken,
                    onEditarOrden: _editarOrden,
                    onNotificationsChanged: _cargarConteoNotificaciones,
                  ),
                ),
                _ShellPage(
                  active: selectedIndex == 2,
                  child: ServiceOrderScreen(
                    currentUser: widget.currentUser,
                    refreshToken: serviceOrderRefreshToken,
                    ordenExistente: ordenEnEdicion,
                    onOrderSaved: () {
                      setState(() {
                        ordenesRefreshToken++;
                        serviceOrderRefreshToken++;
                        selectedIndex = 0;
                      });
                    },
                    onOrderUpdated: _cerrarEdicionOrden,
                  ),
                ),
                _ShellPage(
                  active: selectedIndex == 3,
                  child: const CotizacionesScreen(),
                ),
                _ShellPage(
                  active: selectedIndex == 4,
                  child: const InvoiceScreen(),
                ),
                _ShellPage(
                  active: selectedIndex == 5,
                  child: UserManagementScreen(
                    refreshToken: usuariosRefreshToken,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: _seleccionarVentana,
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

class _ShellPage extends StatelessWidget {
  const _ShellPage({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: active,
      child: ExcludeFocus(
        excluding: !active,
        child: ExcludeSemantics(excluding: !active, child: child),
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.onCreateOrder,
    this.idEmpleado,
  });

  final VoidCallback onCreateOrder;
  final int? idEmpleado;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardStats>(
      future: ApiService.instance.obtenerDashboardStats(idEmpleado: idEmpleado),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeaderSection(onCreateOrder: onCreateOrder),
              const SizedBox(height: 20),
              if (snapshot.hasError)
                EmptyPanelText('No se pudieron cargar las estadisticas.')
              else if (stats == null)
                const DashboardLoading()
              else ...[
                SummaryGrid(stats: stats),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 980;
                    if (!isWide) {
                      return Column(
                        children: [
                          ActiveOrdersPanel(orders: stats.ordenesRecientes),
                          const SizedBox(height: 20),
                          StatsPanel(stats: stats.serviciosMes),
                          const SizedBox(height: 20),
                          ReminderPanel(avisos: stats.avisos),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: ActiveOrdersPanel(
                            orders: stats.ordenesRecientes,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              StatsPanel(stats: stats.serviciosMes),
                              const SizedBox(height: 20),
                              ReminderPanel(avisos: stats.avisos),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class DashboardLoading extends StatelessWidget {
  const DashboardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 260,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key, required this.onCreateOrder});

  final VoidCallback onCreateOrder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final textBlock = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
        );

        final button = CustomButton(
          label: 'Nueva orden',
          icon: Icons.add_circle_outline,
          onPressed: onCreateOrder,
        );

        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              textBlock,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: button),
            ],
          );
        }

        return SizedBox(
          height: 128,
          child: Stack(
            children: [
              Positioned(left: 0, right: 260, bottom: 24, child: textBlock),
              Positioned(right: 0, bottom: 12, child: button),
            ],
          ),
        );
      },
    );
  }
}

class SummaryGrid extends StatelessWidget {
  const SummaryGrid({super.key, required this.stats});

  final DashboardStats stats;

  List<SummaryItem> get items => [
    SummaryItem(
      'Ordenes activas',
      '${stats.ordenesActivas}',
      '+${stats.ordenesHoy} hoy',
      Icons.build_circle_outlined,
      AppColors.teal,
      AppColors.softGray,
    ),
    SummaryItem(
      'Vehiculos por entregar',
      '${stats.porEntregar}',
      '${stats.urgentes} urgentes',
      Icons.local_shipping_outlined,
      AppColors.steel,
      AppColors.softGray,
    ),
    SummaryItem(
      'Facturado este mes',
      _formatCurrency(stats.facturadoMes),
      '${stats.facturasMes} facturas',
      Icons.payments_outlined,
      AppColors.steel,
      AppColors.softGray,
    ),
    SummaryItem(
      'Alertas pendientes',
      '${stats.alertasPendientes}',
      stats.alertasPendientes == 0 ? 'Al dia' : 'Revisar ahora',
      Icons.warning_amber_outlined,
      stats.alertasPendientes == 0 ? AppColors.teal : AppColors.coral,
      stats.alertasPendientes == 0 ? AppColors.tealSoft : AppColors.coralSoft,
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
  const ActiveOrdersPanel({super.key, required this.orders});

  final List<DashboardOrderItem> orders;

  @override
  Widget build(BuildContext context) {
    return SectionSurface(
      title: 'Ultimas ordenes',
      actionLabel: 'Ver todas',
      icon: Icons.tune_outlined,
      child: orders.isEmpty
          ? const EmptyPanelText('Todavia no hay ordenes registradas.')
          : Column(
              children: [for (final order in orders) OrderRow(order: order)],
            ),
    );
  }
}

class OrderRow extends StatelessWidget {
  const OrderRow({super.key, required this.order});

  final DashboardOrderItem order;

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
                  order.vehiculo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('OT-${order.noOrden} - ${order.descripcion}'),
                const SizedBox(height: 10),
                Text(
                  'Ingreso: ${order.fechaIngreso}'
                  '${order.fechaCompromiso == null || order.fechaCompromiso!.isEmpty ? '' : ' - Compromiso: ${order.fechaCompromiso}'}',
                  style: const TextStyle(color: AppColors.slate),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PriorityChip(
            label: order.estado,
            color: _statusColor(order.estado),
          ),
        ],
      ),
    );
  }
}

class StatsPanel extends StatelessWidget {
  const StatsPanel({super.key, required this.stats});

  final List<DashboardServiceStat> stats;

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
          if (stats.isEmpty)
            const EmptyPanelText('Aun no hay servicios registrados este mes.')
          else
            for (final stat in stats) StatBar(stat: stat),
        ],
      ),
    );
  }
}

class StatBar extends StatelessWidget {
  const StatBar({super.key, required this.stat});

  final DashboardServiceStat stat;

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
                  stat.tipo,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('${stat.porcentaje}%'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: stat.porcentaje / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: AppColors.teal,
            backgroundColor: AppColors.mist,
          ),
        ],
      ),
    );
  }
}

class ReminderPanel extends StatelessWidget {
  const ReminderPanel({super.key, required this.avisos});

  final List<DashboardReminderItem> avisos;

  @override
  Widget build(BuildContext context) {
    return SectionSurface(
      title: 'Entregas y avisos',
      actionLabel: 'Recordatorios',
      icon: Icons.schedule_outlined,
      child: Column(
        children: [
          for (final aviso in avisos)
            ReminderTile(
              title: aviso.titulo,
              subtitle: aviso.subtitulo,
              color: _reminderColor(aviso.tipo),
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

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen>
    with SingleTickerProviderStateMixin {
  final formKey = GlobalKey<FormState>();
  late final TabController invoiceTabController;
  final nameController = TextEditingController();
  final documentController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final invoiceController = TextEditingController();
  final dateController = TextEditingController();
  final discountController = TextEditingController(text: '0');
  final taxController = TextEditingController(text: '0');
  final fromDateController = TextEditingController();
  final toDateController = TextEditingController();
  final List<_InvoiceLineController> lines = [];
  List<Map<String, Object?>> invoiceHistory = [];
  bool historyLoading = true;

  @override
  void initState() {
    super.initState();
    invoiceTabController = TabController(length: 2, vsync: this);
    invoiceTabController.addListener(() {
      if (!invoiceTabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    dateController.text = _currentDateText();
    _loadNextInvoiceNumber();
    _loadInvoiceHistory();
    discountController.addListener(_recalculate);
    taxController.addListener(_recalculate);
  }

  @override
  void dispose() {
    invoiceTabController.dispose();
    nameController.dispose();
    documentController.dispose();
    addressController.dispose();
    phoneController.dispose();
    invoiceController.dispose();
    dateController.dispose();
    discountController.dispose();
    taxController.dispose();
    fromDateController.dispose();
    toDateController.dispose();
    for (final line in lines) {
      line.dispose();
    }
    super.dispose();
  }

  double get subtotal => lines.fold(0, (sum, line) => sum + line.total);

  double get discountPercent {
    final value = _parseMoney(discountController.text);
    return value.clamp(0, 100).toDouble();
  }

  double get discountAmount => subtotal * (discountPercent / 100);

  double get taxableAmount => subtotal - discountAmount;

  double get taxPercent {
    final value = _parseMoney(taxController.text);
    return value.clamp(0, 100).toDouble();
  }

  double get tax => taxableAmount * (taxPercent / 100);

  double get grandTotal => taxableAmount + tax;

  void _recalculate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadNextInvoiceNumber() async {
    final id = await ApiService.instance.obtenerSiguienteNoFactura();
    if (!mounted) {
      return;
    }
    setState(() => invoiceController.text = 'FAC-$id');
  }

  Future<void> _loadInvoiceHistory() async {
    if (!_validateHistoryFilters()) {
      return;
    }
    setState(() => historyLoading = true);
    final todayIso = _parseDateTextToIso(_currentDateText());
    final desdeIso = _parseDateTextToIso(fromDateController.text) ?? todayIso;
    final hastaIso = _parseDateTextToIso(toDateController.text) ?? todayIso;
    final invoices = await ApiService.instance.listarFacturas(
      desdeIso: desdeIso,
      hastaIso: hastaIso,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      invoiceHistory = invoices;
      historyLoading = false;
    });
  }

  void _addLine() {
    final line = _InvoiceLineController(onChanged: _recalculate);
    setState(() => lines.add(line));
  }

  void _removeLine(int index) {
    final line = lines.removeAt(index);
    line.dispose();
    setState(() {});
  }

  bool _validateInvoice() {
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos una linea a la factura.'),
        ),
      );
      return false;
    }

    final valid = formKey.currentState?.validate() ?? false;
    if (!valid) {
      return false;
    }

    return true;
  }

  Future<void> _saveInvoice() async {
    if (!_validateInvoice()) {
      return;
    }

    final invoiceId = await ApiService.instance.guardarFactura(
      clienteNombre: nameController.text,
      clienteDocumento: documentController.text,
      clienteTelefono: phoneController.text,
      clienteDireccion: addressController.text,
      fecha: dateController.text,
      fechaIso: _parseDateTextToIso(dateController.text) ?? '',
      subtotal: subtotal,
      descuentoPorcentaje: discountPercent,
      descuento: discountAmount,
      impuestoPorcentaje: taxPercent,
      impuesto: tax,
      total: grandTotal,
      lineas: [
        for (final line in lines)
          {
            'producto': line.productController.text.trim(),
            'cantidad': line.quantity,
            'precio_unitario': line.unitPrice,
            'total': line.total,
          },
      ],
    );

    if (!mounted) {
      return;
    }
    _clearForm();
    _loadInvoiceHistory();
    invoiceTabController.animateTo(1);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Factura FAC-$invoiceId guardada.')));
  }

  Future<void> _printInvoice() async {
    if (!_validateInvoice()) {
      return;
    }

    await printInvoice(
      InvoicePrintData(
        invoiceNumber: invoiceController.text,
        customerName: nameController.text,
        customerDocument: documentController.text,
        customerPhone: phoneController.text,
        customerAddress: addressController.text,
        date: dateController.text,
        lines: [
          for (final line in lines)
            InvoicePrintLine(
              product: line.productController.text.trim(),
              quantity: line.quantity,
              unitPrice: line.unitPrice,
              total: line.total,
            ),
        ],
        subtotal: subtotal,
        discountPercent: discountPercent,
        discountAmount: discountAmount,
        taxPercent: taxPercent,
        tax: tax,
        total: grandTotal,
      ),
    );
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseDateText(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    controller.text = _formatDate(picked);
    await _loadInvoiceHistory();
  }

  void _clearHistoryFilters() {
    fromDateController.clear();
    toDateController.clear();
    _loadInvoiceHistory();
  }

  bool _validateHistoryFilters() {
    final fromText = fromDateController.text.trim();
    final toText = toDateController.text.trim();
    final fromDate = fromText.isEmpty ? null : _parseDateText(fromText);
    final toDate = toText.isEmpty ? null : _parseDateText(toText);

    if ((fromText.isNotEmpty && fromDate == null) ||
        (toText.isNotEmpty && toDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usa fechas validas en formato dd/mm/yyyy.'),
        ),
      );
      return false;
    }

    if (fromDate != null && toDate != null && fromDate.isAfter(toDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La fecha desde no puede ser mayor que la fecha hasta.',
          ),
        ),
      );
      return false;
    }

    return true;
  }

  void _clearForm() {
    formKey.currentState?.reset();
    nameController.clear();
    documentController.clear();
    addressController.clear();
    phoneController.clear();
    dateController.text = _currentDateText();
    discountController.text = '0';
    taxController.text = '0';
    for (final line in lines) {
      line.dispose();
    }
    setState(lines.clear);
    _loadNextInvoiceNumber();
  }

  String _currentDateText() {
    return _formatDate(DateTime.now());
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  DateTime? _parseDateText(String value) {
    final parts = value.trim().split('/');
    if (parts.length != 3) {
      return null;
    }
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return null;
    }
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  String? _parseDateTextToIso(String value) {
    final date = _parseDateText(value);
    if (date == null) {
      return null;
    }
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static double _parseMoney(String value) {
    final normalized = value.replaceAll(',', '.').trim();
    return double.tryParse(normalized) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Factura', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Descuento e impuesto por porcentaje.'),
          const SizedBox(height: 18),
          TabBar(
            controller: invoiceTabController,
            isScrollable: true,
            tabs: const [
              Tab(
                icon: Icon(Icons.receipt_long_outlined),
                text: 'Nueva factura',
              ),
              Tab(icon: Icon(Icons.history_outlined), text: 'Historial'),
            ],
          ),
          const SizedBox(height: 20),
          if (invoiceTabController.index == 0)
            _buildInvoiceForm()
          else
            _InvoiceHistorySection(
              invoices: invoiceHistory,
              isLoading: historyLoading,
              fromDateController: fromDateController,
              toDateController: toDateController,
              onPickFrom: () => _pickDate(fromDateController),
              onPickTo: () => _pickDate(toDateController),
              onApplyFilters: _loadInvoiceHistory,
              onClearFilters: _clearHistoryFilters,
            ),
        ],
      ),
    );
  }

  Widget _buildInvoiceForm() {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _printInvoice,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Imprimir'),
                ),
                CustomButton(
                  label: 'Guardar factura',
                  icon: Icons.save_outlined,
                  onPressed: _saveInvoice,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 860;
              final customer = _InvoiceCustomerSection(
                nameController: nameController,
                documentController: documentController,
                addressController: addressController,
                phoneController: phoneController,
              );
              final meta = _InvoiceMetaSection(
                invoiceController: invoiceController,
                dateController: dateController,
              );
              if (!isWide) {
                return Column(
                  children: [customer, const SizedBox(height: 16), meta],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: customer),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: meta),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          SectionSurface(
            title: 'Detalle',
            actionLabel: '',
            icon: Icons.table_rows_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _addLine,
                    icon: const Icon(Icons.add_outlined),
                    label: const Text('Agregar linea'),
                  ),
                ),
                const SizedBox(height: 12),
                if (lines.isEmpty)
                  Container(
                    height: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.mist,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('La tabla esta vacia.'),
                  )
                else
                  _InvoiceLinesTable(lines: lines, onRemoveLine: _removeLine),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _InvoiceTotalsSection(
                discountController: discountController,
                taxController: taxController,
                subtotal: subtotal,
                discountPercent: discountPercent,
                discountAmount: discountAmount,
                taxPercent: taxPercent,
                tax: tax,
                total: grandTotal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCustomerSection extends StatelessWidget {
  const _InvoiceCustomerSection({
    required this.nameController,
    required this.documentController,
    required this.addressController,
    required this.phoneController,
  });

  final TextEditingController nameController;
  final TextEditingController documentController;
  final TextEditingController addressController;
  final TextEditingController phoneController;

  @override
  Widget build(BuildContext context) {
    return SectionSurface(
      title: 'Cliente',
      actionLabel: '',
      icon: Icons.person_outline,
      child: Column(
        children: [
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa el nombre del cliente';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: documentController,
            decoration: const InputDecoration(labelText: 'Cedula/NIT'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
            ],
            decoration: const InputDecoration(labelText: 'Telefono'),
            validator: (value) {
              final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
              if (digits.isEmpty) {
                return 'Ingresa el telefono';
              }
              if (digits.length != 8) {
                return 'El telefono debe tener 8 digitos';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: addressController,
            decoration: const InputDecoration(labelText: 'Direccion'),
          ),
        ],
      ),
    );
  }
}

class _InvoiceMetaSection extends StatelessWidget {
  const _InvoiceMetaSection({
    required this.invoiceController,
    required this.dateController,
  });

  final TextEditingController invoiceController;
  final TextEditingController dateController;

  @override
  Widget build(BuildContext context) {
    return SectionSurface(
      title: 'Datos',
      actionLabel: '',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          TextFormField(
            controller: invoiceController,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Factura No.'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: dateController,
            decoration: const InputDecoration(labelText: 'Fecha'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa la fecha';
              }
              if (!_isValidInvoiceDateText(value)) {
                return 'Usa una fecha valida dd/mm/yyyy';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _InvoiceLinesTable extends StatelessWidget {
  const _InvoiceLinesTable({required this.lines, required this.onRemoveLine});

  final List<_InvoiceLineController> lines;
  final void Function(int index) onRemoveLine;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 900,
        child: Column(
          children: [
            const _InvoiceTableHeader(),
            for (var i = 0; i < lines.length; i++)
              _InvoiceLineRow(
                index: i,
                line: lines[i],
                onRemove: () => onRemoveLine(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceTableHeader extends StatelessWidget {
  const _InvoiceTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.mist,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          SizedBox(width: 300, child: Text('Producto', style: style)),
          SizedBox(width: 140, child: Text('Cantidad', style: style)),
          SizedBox(width: 180, child: Text('Precio unitario', style: style)),
          SizedBox(width: 170, child: Text('Total', style: style)),
          SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _InvoiceLineRow extends StatelessWidget {
  const _InvoiceLineRow({
    required this.index,
    required this.line,
    required this.onRemove,
  });

  final int index;
  final _InvoiceLineController line;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 300,
            child: TextFormField(
              controller: line.productController,
              decoration: InputDecoration(labelText: 'Producto ${index + 1}'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Requerido';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: TextFormField(
              controller: line.quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [_decimalInputFormatter],
              decoration: const InputDecoration(labelText: 'Cantidad'),
              validator: (value) {
                final number = double.tryParse(
                  (value ?? '').replaceAll(',', '.'),
                );
                if (number == null || number <= 0) {
                  return 'Mayor que 0';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 170,
            child: TextFormField(
              controller: line.priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [_decimalInputFormatter],
              decoration: const InputDecoration(labelText: 'Precio'),
              validator: (value) {
                final number = double.tryParse(
                  (value ?? '').replaceAll(',', '.'),
                );
                if (number == null || number <= 0) {
                  return 'Mayor que 0';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 160,
            child: Padding(
              padding: const EdgeInsets.only(top: 17),
              child: Text(
                'L ${line.total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Quitar linea',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _InvoiceTotalsSection extends StatelessWidget {
  const _InvoiceTotalsSection({
    required this.discountController,
    required this.taxController,
    required this.subtotal,
    required this.discountPercent,
    required this.discountAmount,
    required this.taxPercent,
    required this.tax,
    required this.total,
  });

  final TextEditingController discountController;
  final TextEditingController taxController;
  final double subtotal;
  final double discountPercent;
  final double discountAmount;
  final double taxPercent;
  final double tax;
  final double total;

  @override
  Widget build(BuildContext context) {
    return SectionSurface(
      title: 'Totales',
      actionLabel: '',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          _InvoiceTotalRow(label: 'Subtotal', value: subtotal),
          const SizedBox(height: 10),
          TextFormField(
            controller: discountController,
            keyboardType: TextInputType.number,
            inputFormatters: [_decimalInputFormatter],
            decoration: const InputDecoration(labelText: 'Descuento (%)'),
            validator: (value) {
              final number = double.tryParse(
                (value ?? '0').replaceAll(',', '.'),
              );
              if (number == null || number < 0) {
                return 'Ingresa un porcentaje valido';
              }
              if (number > 100) {
                return 'No puede superar 100%';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          _InvoiceTotalRow(
            label: 'Descuento ${discountPercent.toStringAsFixed(2)}%',
            value: discountAmount,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: taxController,
            keyboardType: TextInputType.number,
            inputFormatters: [_decimalInputFormatter],
            decoration: const InputDecoration(labelText: 'Impuesto (%)'),
            validator: (value) {
              final number = double.tryParse(
                (value ?? '0').replaceAll(',', '.'),
              );
              if (number == null || number < 0) {
                return 'Ingresa un porcentaje valido';
              }
              if (number > 100) {
                return 'No puede superar 100%';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          _InvoiceTotalRow(
            label: 'Impuesto ${taxPercent.toStringAsFixed(2)}%',
            value: tax,
          ),
          const Divider(color: AppColors.border),
          _InvoiceTotalRow(label: 'Total factura', value: total, bold: true),
        ],
      ),
    );
  }
}

class _InvoiceHistorySection extends StatelessWidget {
  const _InvoiceHistorySection({
    required this.invoices,
    required this.isLoading,
    required this.fromDateController,
    required this.toDateController,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onApplyFilters,
    required this.onClearFilters,
  });

  final List<Map<String, Object?>> invoices;
  final bool isLoading;
  final TextEditingController fromDateController;
  final TextEditingController toDateController;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onApplyFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return SectionSurface(
      title: 'Historial de facturas',
      actionLabel: '',
      icon: Icons.history_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: fromDateController,
                  decoration: InputDecoration(
                    labelText: 'Desde',
                    suffixIcon: IconButton(
                      tooltip: 'Elegir fecha desde',
                      onPressed: onPickFrom,
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                  onSubmitted: (_) => onApplyFilters(),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: toDateController,
                  decoration: InputDecoration(
                    labelText: 'Hasta',
                    suffixIcon: IconButton(
                      tooltip: 'Elegir fecha hasta',
                      onPressed: onPickTo,
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                  onSubmitted: (_) => onApplyFilters(),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onApplyFilters,
                icon: const Icon(Icons.filter_alt_outlined),
                label: const Text('Filtrar'),
              ),
              TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.clear_outlined),
                label: const Text('Limpiar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (invoices.isEmpty)
            Container(
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.mist,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('No hay facturas en este rango.'),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Factura')),
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Cliente')),
                  DataColumn(label: Text('Subtotal')),
                  DataColumn(label: Text('Desc. %')),
                  DataColumn(label: Text('Imp. %')),
                  DataColumn(label: Text('Total')),
                ],
                rows: [
                  for (final invoice in invoices)
                    DataRow(
                      cells: [
                        DataCell(Text('FAC-${invoice['no_factura']}')),
                        DataCell(Text('${invoice['fecha'] ?? ''}')),
                        DataCell(Text('${invoice['cliente_nombre'] ?? ''}')),
                        DataCell(
                          Text(
                            'L ${_invoiceDouble(invoice['subtotal']).toStringAsFixed(2)}',
                          ),
                        ),
                        DataCell(
                          Text(
                            '${_invoiceDouble(invoice['descuento_porcentaje']).toStringAsFixed(2)}%',
                          ),
                        ),
                        DataCell(
                          Text(
                            '${_invoiceDouble(invoice['impuesto_porcentaje']).toStringAsFixed(2)}%',
                          ),
                        ),
                        DataCell(
                          Text(
                            'L ${_invoiceDouble(invoice['total']).toStringAsFixed(2)}',
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InvoiceTotalRow extends StatelessWidget {
  const _InvoiceTotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('L ${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}

double _invoiceDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('$value') ?? 0;
}

bool _isValidInvoiceDateText(String value) {
  final parts = value.trim().split('/');
  if (parts.length != 3) {
    return false;
  }
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) {
    return false;
  }
  final parsed = DateTime(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day;
}

class _InvoiceLineController {
  _InvoiceLineController({required VoidCallback onChanged})
    : productController = TextEditingController(),
      quantityController = TextEditingController(),
      priceController = TextEditingController() {
    quantityController.addListener(onChanged);
    priceController.addListener(onChanged);
  }

  final TextEditingController productController;
  final TextEditingController quantityController;
  final TextEditingController priceController;

  double get quantity => _parseDecimal(quantityController.text);

  double get unitPrice => _parseDecimal(priceController.text);

  double get total => quantity * unitPrice;

  void dispose() {
    productController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }

  static double _parseDecimal(String value) {
    return double.tryParse(value.replaceAll(',', '.').trim()) ?? 0;
  }
}

final _decimalInputFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9,.]'),
);

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
                if (actionLabel.isNotEmpty)
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

class EmptyPanelText extends StatelessWidget {
  const EmptyPanelText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.slate)),
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

Color _statusColor(String estado) {
  switch (estado) {
    case 'En revisión':
      return AppColors.amber;
    case 'En progreso':
      return AppColors.teal;
    case 'Completado':
      return AppColors.steel;
    case 'Cancelado':
      return AppColors.coral;
    default:
      return AppColors.steel;
  }
}

Color _reminderColor(DashboardReminderType tipo) {
  switch (tipo) {
    case DashboardReminderType.danger:
      return AppColors.coral;
    case DashboardReminderType.warning:
      return AppColors.amber;
    case DashboardReminderType.info:
      return AppColors.teal;
  }
}

String _formatCurrency(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    buffer.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return 'L ${buffer.toString()}.${parts.last}';
}
