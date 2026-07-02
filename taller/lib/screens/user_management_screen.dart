import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../widgets/custom_button.dart';
import 'home_screen.dart';
import 'service_order_screen.dart';

const _roles = ['Administrador', 'Mecanico', 'Recepcion', 'Supervisor'];

const _initialUsuarios = [
  Usuario(
    id: 1,
    nombre: 'Carlos Martinez',
    correo: 'carlos.martinez@tallerpitstop.com',
    rol: 'Administrador',
    activo: true,
    numeroEmpleado: 'EMP-001',
  ),
  Usuario(
    id: 2,
    nombre: 'Ana Lopez',
    correo: 'ana.lopez@tallerpitstop.com',
    rol: 'Recepcion',
    activo: true,
    numeroEmpleado: 'EMP-002',
  ),
  Usuario(
    id: 3,
    nombre: 'Jose Ramirez',
    correo: 'jose.ramirez@tallerpitstop.com',
    rol: 'Mecanico',
    activo: true,
    numeroEmpleado: 'EMP-003',
  ),
  Usuario(
    id: 4,
    nombre: 'Miriam Cruz',
    correo: 'miriam.cruz@tallerpitstop.com',
    rol: 'Supervisor',
    activo: false,
    numeroEmpleado: 'EMP-004',
  ),
];

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final searchController = TextEditingController();
  final List<Usuario> usuarios = List.of(_initialUsuarios);
  int nextId = _initialUsuarios.length + 1;
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Usuario> get filteredUsuarios {
    if (query.trim().isEmpty) {
      return usuarios;
    }
    final normalized = query.trim().toLowerCase();
    return usuarios.where((usuario) {
      return usuario.nombre.toLowerCase().contains(normalized) ||
          usuario.numeroEmpleado.toLowerCase().contains(normalized) ||
          usuario.rol.toLowerCase().contains(normalized);
    }).toList();
  }

  Future<void> openCreateDialog() async {
    final created = await showDialog<Usuario>(
      context: context,
      builder: (_) => const _UserFormDialog(),
    );
    if (created == null) {
      return;
    }
    setState(() {
      usuarios.add(created.copyWith(id: nextId));
      nextId += 1;
    });
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${created.nombre} fue agregado correctamente.')),
    );
  }

  Future<void> openEditDialog(Usuario usuario) async {
    final updated = await showDialog<Usuario>(
      context: context,
      builder: (_) => _UserFormDialog(usuario: usuario),
    );
    if (updated == null) {
      return;
    }
    setState(() {
      final index = usuarios.indexWhere((item) => item.id == usuario.id);
      if (index != -1) {
        usuarios[index] = updated;
      }
    });
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updated.nombre} fue actualizado correctamente.')),
    );
  }

  Future<void> confirmDelete(Usuario usuario) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar empleado'),
        content: Text(
          'Estas seguro de eliminar a ${usuario.nombre} (${usuario.numeroEmpleado})? Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }
    setState(() {
      usuarios.removeWhere((item) => item.id == usuario.id);
    });
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${usuario.nombre} fue eliminado del sistema.')),
    );
  }

  void viewProfile(Usuario usuario) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfileScreen(usuario: usuario),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserManagementHeader(
            searchController: searchController,
            onSearchChanged: (value) => setState(() => query = value),
            onCreate: openCreateDialog,
          ),
          const SizedBox(height: 20),
          UserTable(
            usuarios: filteredUsuarios,
            onViewProfile: viewProfile,
            onEdit: openEditDialog,
            onDelete: confirmDelete,
          ),
        ],
      ),
    );
  }
}

class UserManagementHeader extends StatelessWidget {
  const UserManagementHeader({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onCreate,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Usuarios', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Administra los empleados del taller: creacion, edicion, perfil y eliminacion.',
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserSearchBar(controller: searchController, onChanged: onSearchChanged),
        const SizedBox(width: 12),
        CustomButton(
          label: 'Crear Usuario',
          icon: Icons.person_add_alt_1_outlined,
          onPressed: onCreate,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              actions,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerRight, child: actions),
          ],
        );
      },
    );
  }
}

class UserSearchBar extends StatelessWidget {
  const UserSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 42,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.panel,
          hintText: 'Nombre, No. empleado o rol',
          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.slate),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpiar',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
          ),
        ),
      ),
    );
  }
}

class UserTable extends StatelessWidget {
  const UserTable({
    super.key,
    required this.usuarios,
    required this.onViewProfile,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Usuario> usuarios;
  final ValueChanged<Usuario> onViewProfile;
  final ValueChanged<Usuario> onEdit;
  final ValueChanged<Usuario> onDelete;

  @override
  Widget build(BuildContext context) {
    if (usuarios.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('No se encontraron empleados con ese criterio.'),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth < 720
              ? 720.0
              : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  const UserTableHeaderRow(),
                  for (var i = 0; i < usuarios.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.border),
                    UserTableRow(
                      usuario: usuarios[i],
                      onViewProfile: () => onViewProfile(usuarios[i]),
                      onEdit: () => onEdit(usuarios[i]),
                      onDelete: () => onDelete(usuarios[i]),
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

class UserTableHeaderRow extends StatelessWidget {
  const UserTableHeaderRow({super.key});

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
          Expanded(flex: 5, child: Text('NOMBRE', style: _headerStyle)),
          Expanded(
            flex: 3,
            child: Text('NUMERO DE EMPLEADO', style: _headerStyle),
          ),
          Expanded(flex: 3, child: Text('ROL', style: _headerStyle)),
          SizedBox(
            width: 64,
            child: Text(
              'ACCIONES',
              style: _headerStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class UserTableRow extends StatelessWidget {
  const UserTableRow({
    super.key,
    required this.usuario,
    required this.onViewProfile,
    required this.onEdit,
    required this.onDelete,
  });

  final Usuario usuario;
  final VoidCallback onViewProfile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              usuario.nombre,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(flex: 3, child: Text(usuario.numeroEmpleado)),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: RoleChip(label: usuario.rol, active: usuario.activo),
            ),
          ),
          SizedBox(
            width: 64,
            child: Align(
              alignment: Alignment.centerRight,
              child: UserRowActions(
                usuario: usuario,
                onViewProfile: onViewProfile,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.teal : AppColors.slate;
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

enum _UserAction { viewProfile, edit, delete }

class UserRowActions extends StatelessWidget {
  const UserRowActions({
    super.key,
    required this.usuario,
    required this.onViewProfile,
    required this.onEdit,
    required this.onDelete,
  });

  final Usuario usuario;
  final VoidCallback onViewProfile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_UserAction>(
      tooltip: 'Acciones',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _UserAction.viewProfile:
            onViewProfile();
            break;
          case _UserAction.edit:
            onEdit();
            break;
          case _UserAction.delete:
            onDelete();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _UserAction.viewProfile,
          child: ListTile(
            leading: Icon(Icons.badge_outlined),
            title: Text('Visualizar perfil'),
          ),
        ),
        PopupMenuItem(
          value: _UserAction.edit,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Editar'),
          ),
        ),
        PopupMenuItem(
          value: _UserAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: AppColors.coral),
            title: Text('Eliminar', style: TextStyle(color: AppColors.coral)),
          ),
        ),
      ],
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({this.usuario});

  final Usuario? usuario;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nombreController;
  late final TextEditingController numeroController;
  late final TextEditingController correoController;
  late String rol;
  late bool activo;

  @override
  void initState() {
    super.initState();
    final usuario = widget.usuario;
    nombreController = TextEditingController(text: usuario?.nombre ?? '');
    numeroController = TextEditingController(text: usuario?.numeroEmpleado ?? '');
    correoController = TextEditingController(text: usuario?.correo ?? '');
    rol = usuario?.rol ?? _roles.first;
    activo = usuario?.activo ?? true;
  }

  @override
  void dispose() {
    nombreController.dispose();
    numeroController.dispose();
    correoController.dispose();
    super.dispose();
  }

  void submit() {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      Usuario(
        id: widget.usuario?.id ?? 0,
        nombre: nombreController.text.trim(),
        correo: correoController.text.trim(),
        rol: rol,
        activo: activo,
        numeroEmpleado: numeroController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.usuario != null;
    return AlertDialog(
      title: Text(isEditing ? 'Editar empleado' : 'Nuevo empleado'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'Nombre',
                controller: nombreController,
                validator: requiredField,
              ),
              AppTextField(
                label: 'Numero de empleado',
                controller: numeroController,
                validator: requiredField,
              ),
              AppTextField(
                label: 'Correo',
                controller: correoController,
                keyboardType: TextInputType.emailAddress,
                validator: requiredField,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: rol,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final r in _roles)
                      DropdownMenuItem(value: r, child: Text(r)),
                  ],
                  onChanged: (value) => setState(() => rol = value ?? rol),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: activo,
                onChanged: (value) => setState(() => activo = value),
                title: const Text('Empleado activo'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: submit, child: const Text('Guardar')),
      ],
    );
  }
}

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key, required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil del empleado')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.tealSoft,
                          borderRadius: BorderRadius.circular(42),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          size: 42,
                          color: AppColors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        usuario.nombre,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    Center(child: RoleChip(label: usuario.rol, active: usuario.activo)),
                    const SizedBox(height: 24),
                    ProfileField(label: 'Numero de empleado', value: usuario.numeroEmpleado),
                    ProfileField(label: 'Correo', value: usuario.correo),
                    ProfileField(
                      label: 'Estado',
                      value: usuario.activo ? 'Activo' : 'Inactivo',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileField extends StatelessWidget {
  const ProfileField({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.slate,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
