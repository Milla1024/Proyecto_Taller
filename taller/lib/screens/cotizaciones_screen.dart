import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/cotizacion.dart';
import '../services/api_service.dart';
import '../services/print_service.dart';
import '../widgets/custom_button.dart';
import 'home_screen.dart';

class CotizacionesScreen extends StatefulWidget {
  const CotizacionesScreen({super.key});

  @override
  State<CotizacionesScreen> createState() => _CotizacionesScreenState();
}

class _CotizacionesScreenState extends State<CotizacionesScreen>
    with SingleTickerProviderStateMixin {
  final formKey = GlobalKey<FormState>();
  late final TabController tabController;
  final quoteController = TextEditingController();
  final dateController = TextEditingController();
  final providerCompanyController = TextEditingController(text: 'PIT STOP');
  final providerRtnController = TextEditingController(text: '13241971000275');
  final providerPhoneController = TextEditingController(text: '+504 9622-9701');
  final providerEmailController = TextEditingController(text: 'oamahon@gmail.com');
  final providerAddressController = TextEditingController(
    text:
        'Blvd. Marco Tulio Rodriguez, frente a Autobanco de Occidente, Barrio Brisas de Celaque, Gracias, Lempira, Honduras.',
  );
  final providerAttendsController = TextEditingController(
    text: 'Onan Arnaldo Milla Alas',
  );
  final clientNameController = TextEditingController();
  final clientAttentionController = TextEditingController();
  final vehicleController = TextEditingController();
  final plateController = TextEditingController();
  final vinController = TextEditingController();
  final mileageController = TextEditingController();
  final taxController = TextEditingController(text: '15');
  final termsController = TextEditingController(
    text:
        'Esta cotizacion tiene una validez de 16 dias a partir de la fecha de emision. Los precios mostrados no incluyen impuesto sobre ventas cuando el ISV esta en 0.',
  );
  final searchController = TextEditingController();
  final List<_QuoteLineController> lines = [];
  List<CotizacionResumen> quotes = [];
  bool isSearching = true;
  bool isViewingQuote = false;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    tabController.addListener(() {
      if (!tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    dateController.text = _formatDate(DateTime.now());
    taxController.addListener(_recalculate);
    _loadNextQuoteNumber();
    _loadQuotes();
    _addLine();
  }

  @override
  void dispose() {
    tabController.dispose();
    quoteController.dispose();
    dateController.dispose();
    providerCompanyController.dispose();
    providerRtnController.dispose();
    providerPhoneController.dispose();
    providerEmailController.dispose();
    providerAddressController.dispose();
    providerAttendsController.dispose();
    clientNameController.dispose();
    clientAttentionController.dispose();
    vehicleController.dispose();
    plateController.dispose();
    vinController.dispose();
    mileageController.dispose();
    taxController.dispose();
    termsController.dispose();
    searchController.dispose();
    for (final line in lines) {
      line.dispose();
    }
    super.dispose();
  }

  double get subtotal => lines.fold(0, (sum, line) => sum + line.total);

  double get taxPercent {
    final value = _parseDecimal(taxController.text);
    return value.clamp(0, 100).toDouble();
  }

  double get tax => subtotal * (taxPercent / 100);

  double get grandTotal => subtotal + tax;

  void _recalculate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadNextQuoteNumber() async {
    final id = await ApiService.instance.obtenerSiguienteNoCotizacion();
    if (!mounted) {
      return;
    }
    setState(() => quoteController.text = 'COT-$id');
  }

  Future<void> _loadQuotes() async {
    setState(() => isSearching = true);
    final loaded = await ApiService.instance.listarCotizaciones(
      clienteNombre: searchController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      quotes = loaded;
      isSearching = false;
    });
  }

  void _addLine() {
    if (isViewingQuote) {
      return;
    }
    final line = _QuoteLineController(onChanged: _recalculate);
    setState(() => lines.add(line));
  }

  void _removeLine(int index) {
    if (isViewingQuote) {
      return;
    }
    if (lines.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cotizacion necesita al menos una linea.')),
      );
      return;
    }
    final line = lines.removeAt(index);
    line.dispose();
    setState(() {});
  }

  bool _validateQuote() {
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos una linea.')),
      );
      return false;
    }
    final valid = formKey.currentState?.validate() ?? false;
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa los datos requeridos de la cotizacion.'),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _saveQuote() async {
    if (isViewingQuote) {
      return;
    }
    if (!_validateQuote()) {
      return;
    }

    final id = await ApiService.instance.guardarCotizacion(
      proveedorEmpresa: providerCompanyController.text,
      proveedorRtn: providerRtnController.text,
      proveedorTelefono: providerPhoneController.text,
      proveedorCorreo: providerEmailController.text,
      proveedorDireccion: providerAddressController.text,
      proveedorAtiende: providerAttendsController.text,
      clienteNombre: clientNameController.text,
      clienteAtencion: clientAttentionController.text,
      vehiculo: vehicleController.text,
      placa: plateController.text,
      vin: vinController.text,
      kilometraje: mileageController.text,
      fechaEmision: dateController.text,
      fechaIso: _parseDateTextToIso(dateController.text) ?? '',
      subtotal: subtotal,
      impuestoPorcentaje: taxPercent,
      impuesto: tax,
      total: grandTotal,
      terminos: termsController.text,
      lineas: [
        for (final line in lines)
          {
            'cantidad': line.quantity,
            'descripcion': line.descriptionController.text.trim(),
            'precio_unitario': line.unitPrice,
            'total': line.total,
          },
      ],
    );

    if (!mounted) {
      return;
    }
    _clearForm();
    await _loadQuotes();
    tabController.animateTo(1);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Cotizacion COT-$id guardada.')));
  }

  Future<void> _printQuote() async {
    if (!_validateQuote()) {
      return;
    }

    try {
      await printQuote(
        QuotePrintData(
          quoteNumber: quoteController.text,
          issueDate: dateController.text,
          providerCompany: providerCompanyController.text,
          providerRtn: providerRtnController.text,
          providerPhone: providerPhoneController.text,
          providerEmail: providerEmailController.text,
          providerAddress: providerAddressController.text,
          providerAttends: providerAttendsController.text,
          customerName: clientNameController.text,
          customerAttention: clientAttentionController.text,
          vehicle: vehicleController.text,
          plate: plateController.text,
          vin: vinController.text,
          mileage: mileageController.text,
          lines: [
            for (final line in lines)
              QuotePrintLine(
                quantity: line.quantity,
                description: line.descriptionController.text.trim(),
                unitPrice: line.unitPrice,
                total: line.total,
              ),
          ],
          subtotal: subtotal,
          taxPercent: taxPercent,
          tax: tax,
          total: grandTotal,
          terms: termsController.text,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo imprimir la cotizacion: $error')),
      );
    }
  }

  Future<void> _pickDate() async {
    if (isViewingQuote) {
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseDateText(dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() => dateController.text = _formatDate(picked));
  }

  void _clearForm() {
    formKey.currentState?.reset();
    isViewingQuote = false;
    clientNameController.clear();
    clientAttentionController.clear();
    vehicleController.clear();
    plateController.clear();
    vinController.clear();
    mileageController.clear();
    dateController.text = _formatDate(DateTime.now());
    taxController.text = '15';
    for (final line in lines) {
      line.dispose();
    }
    lines.clear();
    _addLine();
    _loadNextQuoteNumber();
  }

  Future<void> _viewQuote(int noCotizacion) async {
    final detalle = await ApiService.instance.obtenerCotizacionCompleta(
      noCotizacion,
    );
    if (!mounted) {
      return;
    }
    if (detalle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontro la cotizacion.')),
      );
      return;
    }

    for (final line in lines) {
      line.dispose();
    }
    lines.clear();
    for (final line in detalle.lineas) {
      lines.add(
        _QuoteLineController(
          onChanged: _recalculate,
          quantity: line.cantidad,
          description: line.descripcion,
          unitPrice: line.precioUnitario,
        ),
      );
    }

    setState(() {
      isViewingQuote = true;
      quoteController.text = 'COT-${detalle.noCotizacion}';
      dateController.text = detalle.fechaEmision;
      providerCompanyController.text = detalle.proveedorEmpresa;
      providerRtnController.text = detalle.proveedorRtn;
      providerPhoneController.text = detalle.proveedorTelefono;
      providerEmailController.text = detalle.proveedorCorreo;
      providerAddressController.text = detalle.proveedorDireccion;
      providerAttendsController.text = detalle.proveedorAtiende;
      clientNameController.text = detalle.clienteNombre;
      clientAttentionController.text = detalle.clienteAtencion;
      vehicleController.text = detalle.vehiculo;
      plateController.text = detalle.placa;
      vinController.text = detalle.vin;
      mileageController.text = detalle.kilometraje;
      taxController.text = detalle.impuestoPorcentaje.toStringAsFixed(2);
      termsController.text = detalle.terminos;
    });
    tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cotizaciones',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('Cotizacion comercial con datos de cliente y vehiculo.'),
          const SizedBox(height: 18),
          TabBar(
            controller: tabController,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.request_quote_outlined), text: 'Nueva'),
              Tab(icon: Icon(Icons.search_outlined), text: 'Buscar'),
            ],
          ),
          const SizedBox(height: 20),
          if (tabController.index == 0) _buildForm() else _buildSearch(),
        ],
      ),
    );
  }

  Widget _buildForm() {
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
                  onPressed: _printQuote,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Imprimir'),
                ),
                if (isViewingQuote)
                  OutlinedButton.icon(
                    onPressed: _clearForm,
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Nueva cotizacion'),
                  )
                else
                  CustomButton(
                    label: 'Guardar cotizacion',
                    icon: Icons.save_outlined,
                    onPressed: _saveQuote,
                  ),
                if (isViewingQuote)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Solo lectura'),
                  ),
              ],
            ),
          ),
          if (isViewingQuote) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tealSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Estas viendo una cotizacion guardada. Solo puedes imprimirla.',
              ),
            ),
          ],
          const SizedBox(height: 16),
          AbsorbPointer(
            absorbing: isViewingQuote,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 980;
                    final provider = _ProviderSection(
                      companyController: providerCompanyController,
                      rtnController: providerRtnController,
                      phoneController: providerPhoneController,
                      emailController: providerEmailController,
                      addressController: providerAddressController,
                      attendsController: providerAttendsController,
                    );
                    final meta = _QuoteMetaSection(
                      quoteController: quoteController,
                      dateController: dateController,
                      onPickDate: _pickDate,
                    );
                    final client = _ClientSection(
                      nameController: clientNameController,
                      attentionController: clientAttentionController,
                    );
                    final vehicle = _VehicleSection(
                      vehicleController: vehicleController,
                      plateController: plateController,
                      vinController: vinController,
                      mileageController: mileageController,
                    );
                    if (!isWide) {
                      return Column(
                        children: [
                          provider,
                          const SizedBox(height: 16),
                          meta,
                          const SizedBox(height: 16),
                          client,
                          const SizedBox(height: 16),
                          vehicle,
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: provider),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: meta),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: client),
                            const SizedBox(width: 16),
                            Expanded(child: vehicle),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                SectionSurface(
                  title: 'Repuesto / servicio',
                  actionLabel: '',
                  icon: Icons.build_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: isViewingQuote
                            ? const SizedBox.shrink()
                            : OutlinedButton.icon(
                                onPressed: _addLine,
                                icon: const Icon(Icons.add_outlined),
                                label: const Text('Agregar linea'),
                              ),
                      ),
                      const SizedBox(height: 12),
                      _QuoteLinesTable(lines: lines, onRemoveLine: _removeLine),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 860;
                    final terms = SectionSurface(
                      title: 'Terminos y condiciones',
                      actionLabel: '',
                      icon: Icons.rule_outlined,
                      child: TextFormField(
                        controller: termsController,
                        minLines: 4,
                        maxLines: 6,
                        decoration: const InputDecoration(labelText: 'Terminos'),
                      ),
                    );
                    final totals = _QuoteTotalsSection(
                      taxController: taxController,
                      subtotal: subtotal,
                      taxPercent: taxPercent,
                      tax: tax,
                      total: grandTotal,
                    );
                    if (!isWide) {
                      return Column(
                        children: [terms, const SizedBox(height: 16), totals],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: terms),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: totals),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return SectionSurface(
      title: 'Buscar cotizaciones',
      actionLabel: '',
      icon: Icons.search_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del cliente',
                    prefixIcon: Icon(Icons.person_search_outlined),
                  ),
                  onSubmitted: (_) => _loadQuotes(),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadQuotes,
                icon: const Icon(Icons.search_outlined),
                label: const Text('Buscar'),
              ),
              TextButton.icon(
                onPressed: () {
                  searchController.clear();
                  _loadQuotes();
                },
                icon: const Icon(Icons.clear_outlined),
                label: const Text('Limpiar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isSearching)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (quotes.isEmpty)
            Container(
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.mist,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('No hay cotizaciones para este cliente.'),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Cotizacion')),
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Cliente')),
                  DataColumn(label: Text('Atencion')),
                  DataColumn(label: Text('Vehiculo')),
                  DataColumn(label: Text('Placa')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Accion')),
                ],
                rows: [
                  for (final quote in quotes)
                    DataRow(
                      cells: [
                        DataCell(Text('COT-${quote.noCotizacion}')),
                        DataCell(Text(quote.fechaEmision)),
                        DataCell(Text(quote.clienteNombre)),
                        DataCell(Text(quote.clienteAtencion)),
                        DataCell(Text(quote.vehiculo)),
                        DataCell(Text(quote.placa)),
                        DataCell(Text('L ${quote.total.toStringAsFixed(2)}')),
                        DataCell(
                          OutlinedButton.icon(
                            onPressed: () => _viewQuote(quote.noCotizacion),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Ver'),
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

class _ProviderSection extends StatelessWidget {
  const _ProviderSection({
    required this.companyController,
    required this.rtnController,
    required this.phoneController,
    required this.emailController,
    required this.addressController,
    required this.attendsController,
  });

  final TextEditingController companyController;
  final TextEditingController rtnController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController addressController;
  final TextEditingController attendsController;

  @override
  Widget build(BuildContext context) {
    return SectionSurface(
      title: 'Datos del proveedor',
      actionLabel: '',
      icon: Icons.storefront_outlined,
      child: Column(
        children: [
          _requiredTextField(companyController, 'Empresa'),
          const SizedBox(height: 12),
          TextFormField(
            controller: rtnController,
            decoration: const InputDecoration(labelText: 'RTN'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phoneController,
            decoration: const InputDecoration(labelText: 'Telefono'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Correo'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: addressController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Direccion'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: attendsController,
            decoration: const InputDecoration(labelText: 'Atiende'),
          ),
        ],
      ),
    );
  }
}

class _QuoteMetaSection extends StatelessWidget {
  const _QuoteMetaSection({
    required this.quoteController,
    required this.dateController,
    required this.onPickDate,
  });

  final TextEditingController quoteController;
  final TextEditingController dateController;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return SectionSurface(
      title: 'Cotizacion comercial',
      actionLabel: '',
      icon: Icons.request_quote_outlined,
      child: Column(
        children: [
          TextFormField(
            controller: quoteController,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'No. COT'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: dateController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Fecha de emision',
              suffixIcon: IconButton(
                tooltip: 'Elegir fecha',
                onPressed: onPickDate,
                icon: const Icon(Icons.calendar_month_outlined),
              ),
            ),
            validator: (value) {
              if (_parseDateText(value ?? '') == null) {
                return 'Usa dd/mm/yyyy';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _ClientSection extends StatelessWidget {
  const _ClientSection({
    required this.nameController,
    required this.attentionController,
  });

  final TextEditingController nameController;
  final TextEditingController attentionController;

  @override
  Widget build(BuildContext context) {
    return SectionSurface(
      title: 'Datos del cliente',
      actionLabel: '',
      icon: Icons.person_outline,
      child: Column(
        children: [
          _requiredTextField(nameController, 'Cliente'),
          const SizedBox(height: 12),
          TextFormField(
            controller: attentionController,
            decoration: const InputDecoration(labelText: 'Atencion'),
          ),
        ],
      ),
    );
  }
}

class _VehicleSection extends StatelessWidget {
  const _VehicleSection({
    required this.vehicleController,
    required this.plateController,
    required this.vinController,
    required this.mileageController,
  });

  final TextEditingController vehicleController;
  final TextEditingController plateController;
  final TextEditingController vinController;
  final TextEditingController mileageController;

  @override
  Widget build(BuildContext context) {
    return SectionSurface(
      title: 'Datos del vehiculo',
      actionLabel: '',
      icon: Icons.directions_car_outlined,
      child: Column(
        children: [
          TextFormField(
            controller: vehicleController,
            decoration: const InputDecoration(labelText: 'Vehiculo'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: plateController,
            decoration: const InputDecoration(labelText: 'Placa'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: vinController,
            decoration: const InputDecoration(labelText: 'VIN'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: mileageController,
            decoration: const InputDecoration(labelText: 'KM'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
      ),
    );
  }
}

class _QuoteLinesTable extends StatelessWidget {
  const _QuoteLinesTable({required this.lines, required this.onRemoveLine});

  final List<_QuoteLineController> lines;
  final void Function(int index) onRemoveLine;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 960,
        child: Column(
          children: [
            const _QuoteTableHeader(),
            for (var i = 0; i < lines.length; i++)
              _QuoteLineRow(
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

class _QuoteTableHeader extends StatelessWidget {
  const _QuoteTableHeader();

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
          SizedBox(width: 90, child: Text('Cant.', style: style)),
          SizedBox(width: 430, child: Text('Descripcion', style: style)),
          SizedBox(width: 180, child: Text('P. unitario', style: style)),
          SizedBox(width: 170, child: Text('Total', style: style)),
          SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _QuoteLineRow extends StatelessWidget {
  const _QuoteLineRow({
    required this.index,
    required this.line,
    required this.onRemove,
  });

  final int index;
  final _QuoteLineController line;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: TextFormField(
              controller: line.quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [_decimalInputFormatter],
              decoration: const InputDecoration(labelText: 'Cant.'),
              validator: (value) {
                final number = _parseDecimal(value ?? '');
                if (number <= 0) {
                  return 'Mayor que 0';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 420,
            child: TextFormField(
              controller: line.descriptionController,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(labelText: 'Descripcion ${index + 1}'),
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
            width: 170,
            child: TextFormField(
              controller: line.priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [_decimalInputFormatter],
              decoration: const InputDecoration(labelText: 'P. unitario'),
              validator: (value) {
                final number = _parseDecimal(value ?? '');
                if (number < 0) {
                  return 'Invalido';
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

class _QuoteTotalsSection extends StatelessWidget {
  const _QuoteTotalsSection({
    required this.taxController,
    required this.subtotal,
    required this.taxPercent,
    required this.tax,
    required this.total,
  });

  final TextEditingController taxController;
  final double subtotal;
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
          _QuoteTotalRow(label: 'Sub-total', value: subtotal),
          const SizedBox(height: 10),
          TextFormField(
            controller: taxController,
            keyboardType: TextInputType.number,
            inputFormatters: [_decimalInputFormatter],
            decoration: const InputDecoration(labelText: 'ISV (%)'),
            validator: (value) {
              final number = _parseDecimal(value ?? '');
              if (number < 0 || number > 100) {
                return 'Entre 0 y 100';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          _QuoteTotalRow(
            label: 'ISV ${taxPercent.toStringAsFixed(2)}%',
            value: tax,
          ),
          const Divider(color: AppColors.border),
          _QuoteTotalRow(label: 'Total general', value: total, bold: true),
        ],
      ),
    );
  }
}

class _QuoteTotalRow extends StatelessWidget {
  const _QuoteTotalRow({
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

class _QuoteLineController {
  _QuoteLineController({
    required VoidCallback onChanged,
    double quantity = 1,
    String description = '',
    double unitPrice = 0,
  }) : quantityController = TextEditingController(
         text: _formatEditableDecimal(quantity),
       ),
       descriptionController = TextEditingController(text: description),
       priceController = TextEditingController(
         text: unitPrice == 0 ? '' : _formatEditableDecimal(unitPrice),
       ) {
    quantityController.addListener(onChanged);
    priceController.addListener(onChanged);
  }

  final TextEditingController quantityController;
  final TextEditingController descriptionController;
  final TextEditingController priceController;

  double get quantity => _parseDecimal(quantityController.text);

  double get unitPrice => _parseDecimal(priceController.text);

  double get total => quantity * unitPrice;

  void dispose() {
    quantityController.dispose();
    descriptionController.dispose();
    priceController.dispose();
  }
}

TextFormField _requiredTextField(
  TextEditingController controller,
  String label,
) {
  return TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      if (value == null || value.trim().isEmpty) {
        return 'Requerido';
      }
      return null;
    },
  );
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

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
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

double _parseDecimal(String value) {
  return double.tryParse(value.replaceAll(',', '.').trim()) ?? 0;
}

String _formatEditableDecimal(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

final _decimalInputFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9,.]'),
);
