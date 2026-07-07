class CotizacionResumen {
  const CotizacionResumen({
    required this.noCotizacion,
    required this.fechaEmision,
    required this.fechaIso,
    required this.clienteNombre,
    required this.clienteAtencion,
    required this.vehiculo,
    required this.placa,
    required this.vin,
    required this.kilometraje,
    required this.subtotal,
    required this.impuestoPorcentaje,
    required this.impuesto,
    required this.total,
  });

  final int noCotizacion;
  final String fechaEmision;
  final String fechaIso;
  final String clienteNombre;
  final String clienteAtencion;
  final String vehiculo;
  final String placa;
  final String vin;
  final String kilometraje;
  final double subtotal;
  final double impuestoPorcentaje;
  final double impuesto;
  final double total;

  factory CotizacionResumen.fromMap(Map<String, Object?> map) {
    return CotizacionResumen(
      noCotizacion: map['no_cotizacion'] as int,
      fechaEmision: map['fecha_emision'] as String? ?? '',
      fechaIso: map['fecha_iso'] as String? ?? '',
      clienteNombre: map['cliente_nombre'] as String? ?? '',
      clienteAtencion: map['cliente_atencion'] as String? ?? '',
      vehiculo: map['vehiculo'] as String? ?? '',
      placa: map['placa'] as String? ?? '',
      vin: map['vin'] as String? ?? '',
      kilometraje: map['kilometraje'] as String? ?? '',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      impuestoPorcentaje:
          (map['impuesto_porcentaje'] as num?)?.toDouble() ?? 0,
      impuesto: (map['impuesto'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CotizacionLinea {
  const CotizacionLinea({
    required this.cantidad,
    required this.descripcion,
    required this.precioUnitario,
    required this.total,
  });

  final double cantidad;
  final String descripcion;
  final double precioUnitario;
  final double total;

  factory CotizacionLinea.fromMap(Map<String, Object?> map) {
    return CotizacionLinea(
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0,
      descripcion: map['descripcion'] as String? ?? '',
      precioUnitario: (map['precio_unitario'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CotizacionDetalle {
  const CotizacionDetalle({
    required this.noCotizacion,
    required this.proveedorEmpresa,
    required this.proveedorRtn,
    required this.proveedorTelefono,
    required this.proveedorCorreo,
    required this.proveedorDireccion,
    required this.proveedorAtiende,
    required this.clienteNombre,
    required this.clienteAtencion,
    required this.vehiculo,
    required this.placa,
    required this.vin,
    required this.kilometraje,
    required this.fechaEmision,
    required this.fechaIso,
    required this.subtotal,
    required this.impuestoPorcentaje,
    required this.impuesto,
    required this.total,
    required this.terminos,
    required this.lineas,
  });

  final int noCotizacion;
  final String proveedorEmpresa;
  final String proveedorRtn;
  final String proveedorTelefono;
  final String proveedorCorreo;
  final String proveedorDireccion;
  final String proveedorAtiende;
  final String clienteNombre;
  final String clienteAtencion;
  final String vehiculo;
  final String placa;
  final String vin;
  final String kilometraje;
  final String fechaEmision;
  final String fechaIso;
  final double subtotal;
  final double impuestoPorcentaje;
  final double impuesto;
  final double total;
  final String terminos;
  final List<CotizacionLinea> lineas;

  factory CotizacionDetalle.fromMap(
    Map<String, Object?> map,
    List<Map<String, Object?>> lineas,
  ) {
    return CotizacionDetalle(
      noCotizacion: map['no_cotizacion'] as int,
      proveedorEmpresa: map['proveedor_empresa'] as String? ?? '',
      proveedorRtn: map['proveedor_rtn'] as String? ?? '',
      proveedorTelefono: map['proveedor_telefono'] as String? ?? '',
      proveedorCorreo: map['proveedor_correo'] as String? ?? '',
      proveedorDireccion: map['proveedor_direccion'] as String? ?? '',
      proveedorAtiende: map['proveedor_atiende'] as String? ?? '',
      clienteNombre: map['cliente_nombre'] as String? ?? '',
      clienteAtencion: map['cliente_atencion'] as String? ?? '',
      vehiculo: map['vehiculo'] as String? ?? '',
      placa: map['placa'] as String? ?? '',
      vin: map['vin'] as String? ?? '',
      kilometraje: map['kilometraje'] as String? ?? '',
      fechaEmision: map['fecha_emision'] as String? ?? '',
      fechaIso: map['fecha_iso'] as String? ?? '',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      impuestoPorcentaje:
          (map['impuesto_porcentaje'] as num?)?.toDouble() ?? 0,
      impuesto: (map['impuesto'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      terminos: map['terminos'] as String? ?? '',
      lineas: lineas.map(CotizacionLinea.fromMap).toList(),
    );
  }
}
