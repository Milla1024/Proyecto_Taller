import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../services/api_service.dart';
import '../services/print_service.dart';
import '../widgets/custom_button.dart';
import 'home_screen.dart';

class ServiceOrderScreen extends StatefulWidget {
  const ServiceOrderScreen({super.key, this.currentUser});

  final Usuario? currentUser;

  @override
  State<ServiceOrderScreen> createState() => _ServiceOrderScreenState();
}

class _ServiceOrderScreenState extends State<ServiceOrderScreen> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final orderController = TextEditingController();
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
  int? selectedEmployeeId;
  String selectedEmployeeRole = 'Mecanico';
  final Map<int, String> assignedEmployees = {};
  List<Usuario> employees = [];
  int? currentEmployeeId;
  int? previewOrderId;
  bool employeesLoading = true;
  bool orderSaved = false;

  @override
  void initState() {
    super.initState();
    loadEmployees();
    loadNextOrderNumber();
  }

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

  Future<void> saveOrder() async {
    final orderId = previewOrderId;
    if (orderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generando numero de orden, intenta de nuevo.'),
        ),
      );
      return;
    }

    if (orderSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La orden ${formatOrderNumber(orderId)} ya fue guardada.',
          ),
        ),
      );
      return;
    }

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

    if (assignedEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asigna al menos un empleado.')),
      );
      return;
    }

    try {
      await ApiService.instance.guardarOrdenServicio(
        noOrden: orderId,
        clienteNombre: nameController.text,
        clienteDireccion: addressController.text,
        clienteTelefono: phoneController.text,
        clienteCorreo: emailController.text,
        vehiculoVin: vinController.text,
        vehiculoMarca: brandController.text,
        vehiculoModelo: modelController.text,
        vehiculoColor: colorController.text,
        vehiculoAnio: int.tryParse(yearController.text.trim()),
        vehiculoPlacas: plateController.text,
        descripcionFalla: faultController.text,
        fechaIngreso: entryDateController.text,
        fechaSalida: deliveryDateController.text,
        kilometrajeIngreso: int.tryParse(mileageController.text.trim()),
        gasolina: '${(fuelLevel * 100).round()}%',
        accesorios: inventory,
        empleadosAsignados: assignedEmployees,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        orderSaved = true;
        orderController.text = formatOrderNumber(orderId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Orden ${formatOrderNumber(orderId)} guardada con '
            '${assignedEmployees.length} empleado(s) asignado(s).',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la orden: $error')),
      );
      await loadNextOrderNumber();
    }
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
      orderSaved = false;
      assignedEmployees.clear();
      final currentId = currentEmployeeId;
      if (currentId != null) {
        assignedEmployees[currentId] = 'Responsable';
      }
      selectedEmployeeId = firstAvailableEmployeeId();
      selectedEmployeeRole = 'Mecanico';
    });
    loadNextOrderNumber();
  }

  Future<void> loadNextOrderNumber() async {
    final orderId = await ApiService.instance.obtenerSiguienteNoOrden();
    if (!mounted || orderSaved) {
      return;
    }

    setState(() {
      previewOrderId = orderId;
      orderController.text = formatOrderNumber(orderId);
    });
  }

  String formatOrderNumber(int id) => 'OT-$id';

  Future<void> loadEmployees() async {
    final loaded = await ApiService.instance.listarUsuarios();
    if (!mounted) {
      return;
    }

    final activeEmployees = loaded
        .where((employee) => employee.activo)
        .toList();
    setState(() {
      employees = activeEmployees;
      currentEmployeeId =
          widget.currentUser?.id ??
          (activeEmployees.isEmpty ? null : activeEmployees.first.id);
      assignedEmployees.clear();
      final currentId = currentEmployeeId;
      if (currentId != null) {
        assignedEmployees[currentId] = 'Responsable';
      }
      selectedEmployeeId = firstAvailableEmployeeId();
      employeesLoading = false;
    });
  }

  int? firstAvailableEmployeeId() {
    for (final employee in employees) {
      if (!assignedEmployees.containsKey(employee.id)) {
        return employee.id;
      }
    }
    return null;
  }

  void addEmployeeToOrder() {
    final employeeId = selectedEmployeeId;
    if (employeeId == null) {
      return;
    }

    setState(() {
      assignedEmployees[employeeId] = selectedEmployeeRole;
      selectedEmployeeId = firstAvailableEmployeeId();
    });
  }

  void removeEmployeeFromOrder(int employeeId) {
    if (employeeId == currentEmployeeId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El empleado actual debe permanecer en la orden.'),
        ),
      );
      return;
    }

    setState(() {
      assignedEmployees.remove(employeeId);
      selectedEmployeeId = employeeId;
    });
  }

  void updateEmployeeRole(int employeeId, String role) {
    setState(() => assignedEmployees[employeeId] = role);
  }

  Future<void> printOrder() async {
    if (previewOrderId == null || orderController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generando numero de orden, intenta de nuevo.'),
        ),
      );
      return;
    }

    final employeeLabels = assignedEmployees.entries.map((entry) {
      final employee = employees.firstWhere((item) => item.id == entry.key);
      return '${employee.nombre} - ${entry.value}';
    }).toList();

    await printServiceOrder(
      ServiceOrderPrintData(
        orderNumber: orderController.text.trim(),
        customerName: nameController.text,
        customerAddress: addressController.text,
        customerPhone: phoneController.text,
        customerEmail: emailController.text,
        entryDate: entryDateController.text,
        deliveryDate: deliveryDateController.text,
        vehicleBrand: brandController.text,
        vehicleModel: modelController.text,
        vehicleYear: yearController.text,
        vehicleColor: colorController.text,
        vehiclePlate: plateController.text,
        vehicleVin: vinController.text,
        mileage: mileageController.text,
        fuelLevel: '${(fuelLevel * 100).round()}%',
        failureDescription: faultController.text,
        accessories: inventory,
        assignedEmployees: employeeLabels,
        requiresQuote: requiresQuote,
        authorizeRepair: authorizeRepair,
        authorizeTestDrive: authorizeTestDrive,
        acceptsTerms: acceptsTerms,
      ),
    );
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
            EmployeeAssignmentSection(
              employees: employees,
              assignedEmployees: assignedEmployees,
              currentEmployeeId: currentEmployeeId,
              isLoading: employeesLoading,
              selectedEmployeeId: selectedEmployeeId,
              selectedEmployeeRole: selectedEmployeeRole,
              onEmployeeSelected: (value) {
                if (value != null) {
                  setState(() => selectedEmployeeId = value);
                }
              },
              onRoleSelected: (value) {
                if (value != null) {
                  setState(() => selectedEmployeeRole = value);
                }
              },
              onAddEmployee: addEmployeeToOrder,
              onRemoveEmployee: removeEmployeeFromOrder,
              onAssignedRoleChanged: updateEmployeeRole,
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
                  onPressed: printOrder,
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
                Text(
                  'Dirección: Gracias Lempira, Frente a Puma Circunvalación',
                ),
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
            hintText: 'OT-id',
            readOnly: true,
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

class EmployeeAssignmentSection extends StatelessWidget {
  const EmployeeAssignmentSection({
    super.key,
    required this.employees,
    required this.assignedEmployees,
    required this.currentEmployeeId,
    required this.isLoading,
    required this.selectedEmployeeId,
    required this.selectedEmployeeRole,
    required this.onEmployeeSelected,
    required this.onRoleSelected,
    required this.onAddEmployee,
    required this.onRemoveEmployee,
    required this.onAssignedRoleChanged,
  });

  static const roles = ['Responsable', 'Mecanico', 'Ayudante', 'Supervisor'];

  final List<Usuario> employees;
  final Map<int, String> assignedEmployees;
  final int? currentEmployeeId;
  final bool isLoading;
  final int? selectedEmployeeId;
  final String selectedEmployeeRole;
  final ValueChanged<int?> onEmployeeSelected;
  final ValueChanged<String?> onRoleSelected;
  final VoidCallback onAddEmployee;
  final ValueChanged<int> onRemoveEmployee;
  final void Function(int employeeId, String role) onAssignedRoleChanged;

  @override
  Widget build(BuildContext context) {
    final availableEmployees = employees
        .where((employee) => !assignedEmployees.containsKey(employee.id))
        .toList();
    final selectedAvailable = availableEmployees.any(
      (employee) => employee.id == selectedEmployeeId,
    );

    return FormSection(
      title: 'Empleados asignados',
      icon: Icons.engineering_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'El empleado actual se agrega automaticamente a la orden. '
            'Estos datos corresponden a la relacion trabaja(id_empleado, no_orden, rol).',
          ),
          const SizedBox(height: 14),
          if (isLoading)
            const LinearProgressIndicator(
              minHeight: 4,
              color: AppColors.teal,
              backgroundColor: AppColors.softGray,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final selector = DropdownButtonFormField<int>(
                  initialValue: selectedAvailable ? selectedEmployeeId : null,
                  decoration: const InputDecoration(
                    labelText: 'Empleado',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final employee in availableEmployees)
                      DropdownMenuItem<int>(
                        value: employee.id,
                        child: Text('${employee.nombre} - ${employee.rol}'),
                      ),
                  ],
                  onChanged: availableEmployees.isEmpty
                      ? null
                      : onEmployeeSelected,
                );

                final roleSelector = DropdownButtonFormField<String>(
                  initialValue: selectedEmployeeRole,
                  decoration: const InputDecoration(
                    labelText: 'Rol en la orden',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final role in roles)
                      DropdownMenuItem<String>(value: role, child: Text(role)),
                  ],
                  onChanged: availableEmployees.isEmpty ? null : onRoleSelected,
                );

                final addButton = SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: availableEmployees.isEmpty
                        ? null
                        : onAddEmployee,
                    icon: const Icon(Icons.person_add_alt_outlined),
                    label: const Text('Agregar'),
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      selector,
                      const SizedBox(height: 10),
                      roleSelector,
                      const SizedBox(height: 10),
                      addButton,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: selector),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: roleSelector),
                    const SizedBox(width: 12),
                    addButton,
                  ],
                );
              },
            ),
          const SizedBox(height: 14),
          for (final entry in assignedEmployees.entries) ...[
            AssignedEmployeeTile(
              employee: employees.firstWhere(
                (employee) => employee.id == entry.key,
              ),
              role: entry.value,
              isCurrentEmployee: entry.key == currentEmployeeId,
              roles: roles,
              onRoleChanged: (role) {
                if (role != null) {
                  onAssignedRoleChanged(entry.key, role);
                }
              },
              onRemove: () => onRemoveEmployee(entry.key),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class AssignedEmployeeTile extends StatelessWidget {
  const AssignedEmployeeTile({
    super.key,
    required this.employee,
    required this.role,
    required this.isCurrentEmployee,
    required this.roles,
    required this.onRoleChanged,
    required this.onRemove,
  });

  final Usuario employee;
  final String role;
  final bool isCurrentEmployee;
  final List<String> roles;
  final ValueChanged<String?> onRoleChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentEmployee ? AppColors.tealSoft : AppColors.mist,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentEmployee ? AppColors.teal : AppColors.border,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final employeeInfo = Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.panel,
                foregroundColor: AppColors.steel,
                child: Text(employee.nombre.substring(0, 1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.nombre,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(employee.rol),
                  ],
                ),
              ),
              if (isCurrentEmployee)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: StatusLabel(text: 'Actual'),
                ),
            ],
          );

          final roleDropdown = DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(
              labelText: 'Rol',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final option in roles)
                DropdownMenuItem<String>(value: option, child: Text(option)),
            ],
            onChanged: onRoleChanged,
          );

          final removeButton = IconButton(
            tooltip: isCurrentEmployee
                ? 'El empleado actual no se puede quitar'
                : 'Quitar empleado',
            onPressed: onRemove,
            icon: const Icon(Icons.close_outlined),
          );

          if (compact) {
            return Column(
              children: [
                employeeInfo,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: roleDropdown),
                    const SizedBox(width: 8),
                    removeButton,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: employeeInfo),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: roleDropdown),
              const SizedBox(width: 8),
              removeButton,
            ],
          );
        },
      ),
    );
  }
}

class StatusLabel extends StatelessWidget {
  const StatusLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.teal,
          fontWeight: FontWeight.w800,
        ),
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
            AppTextField(
              label: 'VIN',
              controller: vinController,
              validator: requiredField,
            ),
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
    required this.onRequiresQuoteChanged,
    required this.onAuthorizeRepairChanged,
    required this.onAuthorizeTestDriveChanged,
    required this.onAcceptsTermsChanged,
  });

  final bool requiresQuote;
  final bool authorizeRepair;
  final bool authorizeTestDrive;
  final bool acceptsTerms;
  final ValueChanged<bool?> onRequiresQuoteChanged;
  final ValueChanged<bool?> onAuthorizeRepairChanged;
  final ValueChanged<bool?> onAuthorizeTestDriveChanged;
  final ValueChanged<bool?> onAcceptsTermsChanged;

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
                const SignatureLine(),
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

class SignatureLine extends StatelessWidget {
  const SignatureLine({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 28),
      child: Column(
        children: [
          Divider(color: AppColors.ink, thickness: 1),
          SizedBox(height: 8),
          Center(
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
    this.obscureText = false,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        obscureText: obscureText,
        readOnly: readOnly,
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
