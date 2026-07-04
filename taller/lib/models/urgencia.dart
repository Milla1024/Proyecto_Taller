import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import 'estado_orden.dart';

enum Urgencia { urgente, media, baja }

/// Reglas: solo las ordenes en un estado no terminal (En revision o En
/// progreso) con fecha de compromiso entran al calculo; el resto se
/// considera fuera de foco (baja).
///
/// Recibe los campos primitivos (no un modelo especifico) para que tanto la
/// orden de la lista como el detalle completo puedan reusar la misma logica
/// sin duplicarla.
Urgencia calcularUrgencia({
  required String estado,
  required String? fechaCompromiso,
  DateTime? ahora,
  bool trabada = false,
}) {
  if (esEstadoTerminal(EstadoOrden.fromDb(estado))) {
    return Urgencia.baja;
  }

  final compromiso = _parseFecha(fechaCompromiso);
  if (compromiso == null) {
    return Urgencia.baja;
  }

  // Hook para "esperando autorizacion/repuesto": aun no hay dato persistido
  // para esto, se deja el parametro listo y se omite del calculo por ahora.
  if (trabada) {
    return Urgencia.urgente;
  }

  final hoy = _soloFecha(ahora ?? DateTime.now());
  final dias = compromiso.difference(hoy).inDays;

  if (dias <= 1) {
    return Urgencia.urgente;
  }
  if (dias <= 3) {
    return Urgencia.media;
  }
  return Urgencia.baja;
}

Color colorDeUrgencia(Urgencia urgencia) {
  switch (urgencia) {
    case Urgencia.urgente:
      return AppColors.coral;
    case Urgencia.media:
      return AppColors.amber;
    case Urgencia.baja:
      return AppColors.teal;
  }
}

String etiquetaUrgencia(Urgencia urgencia) {
  switch (urgencia) {
    case Urgencia.urgente:
      return 'Urgente';
    case Urgencia.media:
      return 'Media';
    case Urgencia.baja:
      return 'Baja';
  }
}

String textoEntrega({
  required String estado,
  required String? fechaCompromiso,
  DateTime? ahora,
}) {
  if (esEstadoTerminal(EstadoOrden.fromDb(estado))) {
    return 'Entregado';
  }

  final compromiso = _parseFecha(fechaCompromiso);
  if (compromiso == null) {
    return 'Sin fecha';
  }

  final hoy = _soloFecha(ahora ?? DateTime.now());
  final dias = compromiso.difference(hoy).inDays;

  if (dias < 0) {
    return 'Vencida';
  }
  if (dias == 0) {
    return 'Hoy';
  }
  if (dias == 1) {
    return 'Mañana';
  }
  return 'En $dias días';
}

DateTime? _parseFecha(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final parts = value.trim().split('/');
  if (parts.length != 3) {
    return null;
  }
  final dia = int.tryParse(parts[0]);
  final mes = int.tryParse(parts[1]);
  final anio = int.tryParse(parts[2]);
  if (dia == null || mes == null || anio == null) {
    return null;
  }
  return DateTime(anio, mes, dia);
}

DateTime _soloFecha(DateTime fecha) {
  return DateTime(fecha.year, fecha.month, fecha.day);
}
