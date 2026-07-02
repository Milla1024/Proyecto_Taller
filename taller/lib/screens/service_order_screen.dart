import 'package:flutter/material.dart';

import '../widgets/custom_button.dart';
import 'home_screen.dart';

class ServiceOrderScreen extends StatefulWidget {
  const ServiceOrderScreen({super.key});

  @override
  State<ServiceOrderScreen> createState() => _ServiceOrderScreenState();
}

class _ServiceOrderScreenState extends State<ServiceOrderScreen> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final orderController = TextEditingController(text: 'OT-1043');
  final entryDateController = TextEditingController();
  final deliveryDateController = TextEditingController();
  final brandController = TextEditingController();
  final modelController = TextEditingController();
  final yearController = TextEditingController();
  final colorController = TextEditingController();
  final plateController = TextEditingController();
  final vinController = TextEditingController();
  final mileageController = TextEditingController();
  final faultController = TextEditingController();

  final Map<String, bool> inventory = {
    'Espejo izquierdo': false,
    'Espejo derecho': false,
    'Vidrios': false,
    'Radio': false,
    'Pantalla': false,
    'Encendedor': false,
    'Antena': false,
    'Controles de puertas': false,
    'Cargador celular': false,
    'Triangulos': false,
    'Cubresol': false,
    'Herramientas': false,
    'Gato': false,
    'Llanta de refaccion': false,
    'Faros/Lunas': false,
    'Tapa de gasolina': false,
    'Placas': false,
    'Tapetes': false,
    'Extintor': false,
    'Llave de tuercas': false,
  };

  double fuelLevel = 0.45;
  bool requiresQuote = true;
  bool authorizeRepair = false;
  bool authorizeTestDrive = false;
  bool acceptsTerms = false;
  final List<Offset?> signaturePoints = [];

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    phoneController.dispose();
    emailController.dispose();
    orderController.dispose();
    entryDateController.dispose();
    deliveryDateController.dispose();
    brandController.dispose();
    modelController.dispose();
    yearController.dispose();
    colorController.dispose();
    plateController.dispose();
    vinController.dispose();
    mileageController.dispose();
    faultController.dispose();
    super.dispose();
  }

  void saveOrder() {
    final valid = formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }

    if (!acceptsTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes confirmar la aceptacion del cliente.'),
        ),
      );
      return;
    }

    if (signaturePoints.whereType<Offset>().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El cliente debe firmar la orden.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Orden ${orderController.text.trim()} guardada correctamente.',
        ),
      ),
    );
  }

  void clearForm() {
    formKey.currentState?.reset();
    setState(() {
      for (final key in inventory.keys) {
        inventory[key] = false;
      }
      fuelLevel = 0.45;
      requiresQuote = true;
      authorizeRepair = false;
      authorizeTestDrive = false;
      acceptsTerms = false;
      signaturePoints.clear();
    });
  }

  void addSignaturePoint(Offset point) {
    setState(() => signaturePoints.add(point));
  }

  void finishSignatureStroke() {
    setState(() => signaturePoints.add(null));
  }

  void clearSignature() {
    setState(signaturePoints.clear);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ServiceOrderHeader(),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;
                if (!isWide) {
                  return Column(
                    children: [
                      CustomerSection(
                        nameController: nameController,
                        addressController: addressController,
                        phoneController: phoneController,
                        emailController: emailController,
                      ),
                      const SizedBox(height: 16),
                      OrderMetaSection(
                        orderController: orderController,
                        entryDateController: entryDateController,
                        deliveryDateController: deliveryDateController,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: CustomerSection(
                        nameController: nameController,
                        addressController: addressController,
                        phoneController: phoneController,
                        emailController: emailController,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: OrderMetaSection(
                        orderController: orderController,
                        entryDateController: entryDateController,
                        deliveryDateController: deliveryDateController,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            VehicleSection(
              brandController: brandController,
              modelController: modelController,
              yearController: yearController,
              colorController: colorController,
              plateController: plateController,
              vinController: vinController,
            ),
            const SizedBox(height: 16),
            FormSection(
              title: 'Descripcion de la falla',
              icon: Icons.report_problem_outlined,
              child: TextFormField(
                controller: faultController,
                minLines: 5,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText:
                      'Describe los sintomas, ruidos, condiciones y observaciones del cliente.',
                  border: OutlineInputBorder(),
                ),
                validator: requiredField,
              ),
            ),
            const SizedBox(height: 16),
            ReceptionSection(
              inventory: inventory,
              fuelLevel: fuelLevel,
              mileageController: mileageController,
              onInventoryChanged: (key, value) {
                setState(() => inventory[key] = value);
              },
              onFuelChanged: (value) {
                setState(() => fuelLevel = value);
              },
            ),
            const SizedBox(height: 16),
            AuthorizationSection(
              requiresQuote: requiresQuote,
              authorizeRepair: authorizeRepair,
              authorizeTestDrive: authorizeTestDrive,
              acceptsTerms: acceptsTerms,
              onRequiresQuoteChanged: (value) {
                setState(() => requiresQuote = value ?? false);
              },
              onAuthorizeRepairChanged: (value) {
                setState(() => authorizeRepair = value ?? false);
              },
              onAuthorizeTestDriveChanged: (value) {
                setState(() => authorizeTestDrive = value ?? false);
              },
              onAcceptsTermsChanged: (value) {
                setState(() => acceptsTerms = value ?? false);
              },
              signaturePoints: signaturePoints,
              onSignaturePointAdded: addSignaturePoint,
              onSignatureStrokeFinished: finishSignatureStroke,
              onSignatureCleared: clearSignature,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                CustomButton(
                  label: 'Guardar orden',
                  icon: Icons.save_outlined,
                  onPressed: saveOrder,
                ),
                OutlinedButton.icon(
                  onPressed: clearForm,
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('Limpiar'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'La impresion se conectara al modulo de facturacion.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Imprimir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceOrderHeader extends StatelessWidget {
  const ServiceOrderHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final logo = Container(
              width: 90,
              height: 74,
              decoration: BoxDecoration(
                color: AppColors.mist,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.handyman_outlined,
                color: AppColors.steel,
                size: 34,
              ),
            );

            final title = Column(
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Text(
                  'Orden de Servicio',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Documento de recepcion y autorizacion del vehiculo',
                ),
              ],
            );

            final workshop = const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ' Taller PitStop',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text('Dirección: Gracias Lempira, Frente a Puma Circunvalación'),
                Text('Telefono: 9622-9701 '),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  logo,
                  const SizedBox(height: 14),
                  title,
                  const SizedBox(height: 14),
                  workshop,
                ],
              );
            }

            return Row(
              children: [
                logo,
                const SizedBox(width: 24),
                Expanded(child: Center(child: title)),
                const SizedBox(width: 24),
                workshop,
              ],
            );
          },
        ),
      ),
    );
  }
}

class CustomerSection extends StatelessWidget {
  const CustomerSection({
    super.key,
    required this.nameController,
    required this.addressController,
    required this.phoneController,
    required this.emailController,
  });

  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController phoneController;
  final TextEditingController emailController;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Datos del cliente',
      icon: Icons.person_outline,
      child: Column(
        children: [
          AppTextField(
            label: 'Nombre',
            controller: nameController,
            validator: requiredField,
          ),
          AppTextField(label: 'Direccion', controller: addressController),
          AppTextField(
            label: 'Telefono',
            controller: phoneController,
            keyboardType: TextInputType.phone,
            validator: requiredField,
          ),
          AppTextField(
            label: 'Email',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
    );
  }
}

class OrderMetaSection extends StatelessWidget {
  const OrderMetaSection({
    super.key,
    required this.orderController,
    required this.entryDateController,
    required this.deliveryDateController,
  });

  final TextEditingController orderController;
  final TextEditingController entryDateController;
  final TextEditingController deliveryDateController;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Datos de orden',
      icon: Icons.assignment_outlined,
      child: Column(
        children: [
          AppTextField(
            label: 'No. orden',
            controller: orderController,
            validator: requiredField,
          ),
          AppTextField(
            label: 'Fecha de ingreso',
            controller: entryDateController,
            hintText: 'DD/MM/AAAA',
            validator: requiredField,
          ),
          AppTextField(
            label: 'Fecha de entrega',
            controller: deliveryDateController,
            hintText: 'DD/MM/AAAA',
          ),
        ],
      ),
    );
  }
}

class VehicleSection extends StatelessWidget {
  const VehicleSection({
    super.key,
    required this.brandController,
    required this.modelController,
    required this.yearController,
    required this.colorController,
    required this.plateController,
    required this.vinController,
  });

  final TextEditingController brandController;
  final TextEditingController modelController;
  final TextEditingController yearController;
  final TextEditingController colorController;
  final TextEditingController plateController;
  final TextEditingController vinController;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Datos del vehiculo',
      icon: Icons.directions_car_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900
              ? 3
              : constraints.maxWidth >= 560
              ? 2
              : 1;
          final fields = [
            AppTextField(
              label: 'Marca',
              controller: brandController,
              validator: requiredField,
            ),
            AppTextField(
              label: 'Modelo',
              controller: modelController,
              validator: requiredField,
            ),
            AppTextField(
              label: 'Ano',
              controller: yearController,
              keyboardType: TextInputType.number,
            ),
            AppTextField(label: 'Color', controller: colorController),
            AppTextField(
              label: 'Placas',
              controller: plateController,
              validator: requiredField,
            ),
            AppTextField(label: 'VIN', controller: vinController),
          ];

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: fields.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 76,
            ),
            itemBuilder: (context, index) => fields[index],
          );
        },
      ),
    );
  }
}

class ReceptionSection extends StatelessWidget {
  const ReceptionSection({
    super.key,
    required this.inventory,
    required this.fuelLevel,
    required this.mileageController,
    required this.onInventoryChanged,
    required this.onFuelChanged,
  });

  final Map<String, bool> inventory;
  final double fuelLevel;
  final TextEditingController mileageController;
  final void Function(String key, bool value) onInventoryChanged;
  final ValueChanged<double> onFuelChanged;

  @override
  Widget build(BuildContext context) {
    final entries = inventory.entries.toList();

    return FormSection(
      title: 'Recepcion del vehiculo',
      icon: Icons.fact_check_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          final checklist = GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 2 : 1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 4,
              mainAxisExtent: 42,
            ),
            itemBuilder: (context, index) {
              final item = entries[index];
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(item.key),
                value: item.value,
                onChanged: (value) {
                  onInventoryChanged(item.key, value ?? false);
                },
              );
            },
          );

          final vehicleStatus = VehicleStatusPanel(
            fuelLevel: fuelLevel,
            mileageController: mileageController,
            onFuelChanged: onFuelChanged,
          );

          if (!isWide) {
            return Column(
              children: [checklist, const SizedBox(height: 16), vehicleStatus],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: checklist),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: vehicleStatus),
            ],
          );
        },
      ),
    );
  }
}

class VehicleStatusPanel extends StatelessWidget {
  const VehicleStatusPanel({
    super.key,
    required this.fuelLevel,
    required this.mileageController,
    required this.onFuelChanged,
  });

  final double fuelLevel;
  final TextEditingController mileageController;
  final ValueChanged<double> onFuelChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final mileage = AppTextField(
                label: 'Kilometraje',
                controller: mileageController,
                keyboardType: TextInputType.number,
              );
              final fuel = FuelLevelControl(
                fuelLevel: fuelLevel,
                onFuelChanged: onFuelChanged,
              );

              if (compact) {
                return Column(
                  children: [mileage, const SizedBox(height: 8), fuel],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: mileage),
                  const SizedBox(width: 16),
                  Expanded(child: fuel),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          const VehicleSketch(),
        ],
      ),
    );
  }
}

class FuelLevelControl extends StatelessWidget {
  const FuelLevelControl({
    super.key,
    required this.fuelLevel,
    required this.onFuelChanged,
  });

  final double fuelLevel;
  final ValueChanged<double> onFuelChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.tealSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${(fuelLevel * 100).round()}%',
              style: const TextStyle(
                color: AppColors.teal,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Gasolina',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.teal,
                inactiveTrackColor: AppColors.border,
                thumbColor: AppColors.teal,
                overlayColor: AppColors.tealSoft,
                trackHeight: 4,
              ),
              child: Slider(value: fuelLevel, onChanged: onFuelChanged),
            ),
          ),
        ],
      ),
    );
  }
}

class VehicleSketch extends StatelessWidget {
  const VehicleSketch({super.key});

  static const assetPath = 'assets/images/vehiculo_inspeccion.png';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth >= 720 ? 310.0 : 240.0;

        return Container(
          height: height,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              return const Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      color: AppColors.slate,
                      size: 36,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Agrega la imagen original del vehiculo en:',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      VehicleSketch.assetPath,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class AuthorizationSection extends StatelessWidget {
  const AuthorizationSection({
    super.key,
    required this.requiresQuote,
    required this.authorizeRepair,
    required this.authorizeTestDrive,
    required this.acceptsTerms,
    required this.signaturePoints,
    required this.onRequiresQuoteChanged,
    required this.onAuthorizeRepairChanged,
    required this.onAuthorizeTestDriveChanged,
    required this.onAcceptsTermsChanged,
    required this.onSignaturePointAdded,
    required this.onSignatureStrokeFinished,
    required this.onSignatureCleared,
  });

  final bool requiresQuote;
  final bool authorizeRepair;
  final bool authorizeTestDrive;
  final bool acceptsTerms;
  final List<Offset?> signaturePoints;
  final ValueChanged<bool?> onRequiresQuoteChanged;
  final ValueChanged<bool?> onAuthorizeRepairChanged;
  final ValueChanged<bool?> onAuthorizeTestDriveChanged;
  final ValueChanged<bool?> onAcceptsTermsChanged;
  final ValueChanged<Offset> onSignaturePointAdded;
  final VoidCallback onSignatureStrokeFinished;
  final VoidCallback onSignatureCleared;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Autorizaciones y condiciones',
      icon: Icons.verified_user_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final options = Column(
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: requiresQuote,
                onChanged: onRequiresQuoteChanged,
                title: const Text('Solicito presupuesto previo'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: authorizeRepair,
                onChanged: onAuthorizeRepairChanged,
                title: const Text('Autorizo reparacion sin presupuesto previo'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: authorizeTestDrive,
                onChanged: onAuthorizeTestDriveChanged,
                title: const Text('Autorizo conducir mi vehiculo para pruebas'),
              ),
            ],
          );

          final terms = Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: acceptsTerms,
                  onChanged: onAcceptsTermsChanged,
                  title: const Text(
                    'Acepto las condiciones indicadas en esta orden de servicio',
                  ),
                ),
                const SizedBox(height: 12),
                SignaturePad(
                  points: signaturePoints,
                  onPointAdded: onSignaturePointAdded,
                  onStrokeFinished: onSignatureStrokeFinished,
                  onCleared: onSignatureCleared,
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'FIRMA DEL CLIENTE',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              children: [options, const SizedBox(height: 12), terms],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: options),
              const SizedBox(width: 16),
              Expanded(child: terms),
            ],
          );
        },
      ),
    );
  }
}

class SignaturePad extends StatelessWidget {
  const SignaturePad({
    super.key,
    required this.points,
    required this.onPointAdded,
    required this.onStrokeFinished,
    required this.onCleared,
  });

  final List<Offset?> points;
  final ValueChanged<Offset> onPointAdded;
  final VoidCallback onStrokeFinished;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Acepto:',
          style: TextStyle(color: AppColors.slate, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: AppColors.mist,
            border: Border.all(color: AppColors.slate),
            borderRadius: BorderRadius.circular(4),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  onPointAdded(details.localPosition);
                },
                onPanUpdate: (details) {
                  final point = details.localPosition;
                  final inside =
                      point.dx >= 0 &&
                      point.dy >= 0 &&
                      point.dx <= constraints.maxWidth &&
                      point.dy <= constraints.maxHeight;
                  if (inside) {
                    onPointAdded(point);
                  }
                },
                onPanEnd: (_) => onStrokeFinished(),
                child: CustomPaint(
                  painter: SignaturePainter(points),
                  child: points.whereType<Offset>().isEmpty
                      ? const Center(
                          child: Text(
                            'Firma aqui',
                            style: TextStyle(color: AppColors.slate),
                          ),
                        )
                      : const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onCleared,
              icon: const Icon(Icons.backspace_outlined),
              label: const Text('Limpiar firma'),
            ),
            StatusChip(signed: points.whereType<Offset>().length >= 2),
          ],
        ),
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.signed});

  final bool signed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: signed ? AppColors.tealSoft : AppColors.softGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            signed ? Icons.check_circle_outline : Icons.edit_outlined,
            color: signed ? AppColors.teal : AppColors.slate,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            signed ? 'Firmado' : 'Pendiente',
            style: TextStyle(
              color: signed ? AppColors.teal : AppColors.slate,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  const SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.steel),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

String? requiredField(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Campo requerido';
  }
  return null;
}
