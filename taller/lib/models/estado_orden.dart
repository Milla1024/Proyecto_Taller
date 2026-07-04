import 'package:flutter/material.dart';

import '../screens/home_screen.dart';

/// Maquina de estados de una orden, de un solo sentido:
/// En revision -> En progreso -> Completado, con una unica salida lateral
/// desde En revision hacia Cancelado.
enum EstadoOrden {
  enRevision,
  enProgreso,
  completado,
  cancelado;

  static EstadoOrden fromDb(String valor) {
    switch (valor) {
      case 'En progreso':
        return EstadoOrden.enProgreso;
      case 'Completado':
        return EstadoOrden.completado;
      case 'Cancelado':
        return EstadoOrden.cancelado;
      case 'En revisión':
      default:
        return EstadoOrden.enRevision;
    }
  }

  /// Texto para mostrar en la UI; coincide con el valor exacto persistido.
  String get label {
    switch (this) {
      case EstadoOrden.enRevision:
        return 'En revisión';
      case EstadoOrden.enProgreso:
        return 'En progreso';
      case EstadoOrden.completado:
        return 'Completado';
      case EstadoOrden.cancelado:
        return 'Cancelado';
    }
  }

  String toDb() => label;
}

bool esEstadoTerminal(EstadoOrden estado) {
  return estado == EstadoOrden.completado || estado == EstadoOrden.cancelado;
}

Color colorDeFondoEstado(EstadoOrden estado) {
  switch (estado) {
    case EstadoOrden.enRevision:
      return AppColors.softGray;
    case EstadoOrden.enProgreso:
      return AppColors.tealSoft;
    case EstadoOrden.completado:
      return AppColors.mist;
    case EstadoOrden.cancelado:
      return AppColors.coralSoft;
  }
}

Color colorDeTextoEstado(EstadoOrden estado) {
  switch (estado) {
    case EstadoOrden.enRevision:
      return AppColors.steel;
    case EstadoOrden.enProgreso:
      return AppColors.teal;
    case EstadoOrden.completado:
      return AppColors.slate;
    case EstadoOrden.cancelado:
      return AppColors.coral;
  }
}

bool _rolPuedeGestionarEnRevision(String rol) {
  return rol == 'Administrador' || rol == 'Mecánico';
}

bool puedeEditar(EstadoOrden estado, String rol) {
  return estado == EstadoOrden.enRevision && _rolPuedeGestionarEnRevision(rol);
}

bool puedeAceptar(EstadoOrden estado, String rol) {
  return estado == EstadoOrden.enRevision && _rolPuedeGestionarEnRevision(rol);
}

bool puedeCancelar(EstadoOrden estado, String rol) {
  return estado == EstadoOrden.enRevision && rol == 'Administrador';
}

bool puedeCompletar(EstadoOrden estado, String rol) {
  return estado == EstadoOrden.enProgreso && rol == 'Administrador';
}
