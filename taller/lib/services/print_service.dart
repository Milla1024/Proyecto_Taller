import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ServiceOrderPrintData {
  const ServiceOrderPrintData({
    required this.orderNumber,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.customerEmail,
    required this.entryDate,
    required this.deliveryDate,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.vehicleColor,
    required this.vehiclePlate,
    required this.vehicleVin,
    required this.mileage,
    required this.fuelLevel,
    required this.failureDescription,
    required this.accessories,
    required this.assignedEmployees,
    required this.requiresQuote,
    required this.authorizeRepair,
    required this.authorizeTestDrive,
    required this.acceptsTerms,
  });

  final String orderNumber;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final String customerEmail;
  final String entryDate;
  final String deliveryDate;
  final String vehicleBrand;
  final String vehicleModel;
  final String vehicleYear;
  final String vehicleColor;
  final String vehiclePlate;
  final String vehicleVin;
  final String mileage;
  final String fuelLevel;
  final String failureDescription;
  final Map<String, bool> accessories;
  final List<String> assignedEmployees;
  final bool requiresQuote;
  final bool authorizeRepair;
  final bool authorizeTestDrive;
  final bool acceptsTerms;
}

Future<void> printServiceOrder(ServiceOrderPrintData data) async {
  final document = pw.Document();
  final logoImage = await _loadLogoImage();
  final vehicleImage = await _loadVehicleImage();

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
      build: (context) {
        return pw.DefaultTextStyle(
          style: const pw.TextStyle(fontSize: 8),
          child: pw.Align(
            alignment: pw.Alignment.topLeft,
            child: pw.Container(
              width: 552,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _header(logoImage),
                  pw.SizedBox(height: 8),
                  _topData(data),
                  pw.SizedBox(height: 8),
                  _vehicleTable(data),
                  pw.SizedBox(height: 8),
                  _failureBox(data.failureDescription),
                  pw.SizedBox(height: 8),
                  _receptionBox(data, vehicleImage),
                  pw.SizedBox(height: 8),
                  _footer(data),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  await Printing.layoutPdf(
    name: 'orden_servicio_${data.orderNumber}.pdf',
    onLayout: (_) async => document.save(),
  );
}

Future<pw.MemoryImage?> _loadVehicleImage() async {
  try {
    final bytes = await rootBundle.load(
      'assets/images/vehiculo_inspeccion.png',
    );
    return pw.MemoryImage(bytes.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

Future<pw.MemoryImage?> _loadLogoImage() async {
  try {
    final bytes = await rootBundle.load('assets/images/pit_stop_logo.png');
    return pw.MemoryImage(bytes.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

pw.Widget _header(pw.MemoryImage? logoImage) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 150,
        height: 70,
        child: pw.Row(
          children: [
            pw.Container(
              width: 92,
              height: 62,
              alignment: pw.Alignment.center,
              child: logoImage == null
                  ? pw.Container(
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.grey500,
                          width: 1,
                        ),
                      ),
                      child: pw.Text(
                        'LOGO',
                        style: const pw.TextStyle(
                          color: PdfColors.grey500,
                          fontSize: 18,
                        ),
                      ),
                    )
                  : pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
          ],
        ),
      ),
      pw.SizedBox(width: 18),
      pw.Expanded(
        child: pw.Column(
          children: [
            pw.SizedBox(height: 24),
            pw.Text(
              'Orden de Servicio',
              style: const pw.TextStyle(fontSize: 24),
            ),
          ],
        ),
      ),
      pw.SizedBox(width: 18),
      pw.Container(
        width: 150,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.SizedBox(height: 8),
            pw.Text(
              'Taller PitStop',
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 17),
            ),
            pw.Text(
              'Gracias Lempira',
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 13),
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _topData(ServiceOrderPrintData data) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        flex: 3,
        child: _boxedSection(
          title: 'DATOS DEL CLIENTE',
          height: 108,
          child: pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 10, 12, 8),
            child: pw.Column(
              children: [
                _lineField('NOMBRE:', data.customerName),
                _lineField('DIRECCION:', data.customerAddress),
                _lineField('TELEFONO:', data.customerPhone),
                _lineField('EMAIL:', data.customerEmail),
              ],
            ),
          ),
        ),
      ),
      pw.SizedBox(width: 8),
      pw.Expanded(
        flex: 2,
        child: _boxedSection(
          title: 'DATOS DE ORDEN DE SERVICIO',
          height: 108,
          child: pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 13, 12, 8),
            child: pw.Column(
              children: [
                _lineField('No. ORDEN:', data.orderNumber),
                _lineField('FECHA DE INGRESO:', data.entryDate),
                _lineField('FECHA DE ENTREGA:', data.deliveryDate),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

pw.Widget _vehicleTable(ServiceOrderPrintData data) {
  final values = [
    data.vehicleBrand,
    data.vehicleModel,
    data.vehicleYear,
    data.vehicleColor,
    data.vehiclePlate,
    data.vehicleVin,
  ];

  return pw.Container(
    height: 56,
    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('DATOS DEL VEHICULO'),
        pw.Table(
          border: pw.TableBorder.all(width: 0.6),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.1),
            1: pw.FlexColumnWidth(1.3),
            2: pw.FlexColumnWidth(0.7),
            3: pw.FlexColumnWidth(1),
            4: pw.FlexColumnWidth(0.9),
            5: pw.FlexColumnWidth(1.8),
          },
          children: [
            pw.TableRow(
              children: [
                _tableHeader('MARCA'),
                _tableHeader('MODELO'),
                _tableHeader('ANO'),
                _tableHeader('COLOR'),
                _tableHeader('PLACAS'),
                _tableHeader('VIN'),
              ],
            ),
            pw.TableRow(
              children: [
                for (final value in values)
                  pw.Container(
                    height: 18,
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 3),
                    child: pw.Text(value),
                  ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _failureBox(String value) {
  return _boxedSection(
    title: 'DESCRIPCION DE LA FALLA',
    height: 122,
    child: pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(value),
    ),
  );
}

pw.Widget _receptionBox(
  ServiceOrderPrintData data,
  pw.MemoryImage? vehicleImage,
) {
  final entries = data.accessories.entries.toList();
  final left = entries.take((entries.length / 2).ceil()).toList();
  final right = entries.skip((entries.length / 2).ceil()).toList();

  return _boxedSection(
    title: 'RECEPCION DEL VEHICULO',
    height: 214,
    child: pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: _accessoryColumn(left)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: _accessoryColumn(right)),
          pw.SizedBox(width: 12),
          pw.Container(
            width: 230,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _lineField('Kilometraje', data.mileage),
                pw.SizedBox(height: 8),
                _fuelLine(data.fuelLevel),
                pw.SizedBox(height: 10),
                pw.Expanded(child: _vehicleImage(vehicleImage)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _footer(ServiceOrderPrintData data) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        flex: 3,
        child: pw.Container(
          height: 108,
          padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _optionLine(
                data.requiresQuote,
                'Solicito presupuesto previo antes de autorizar el trabajo',
              ),
              _optionLine(
                data.authorizeRepair,
                'Autorizo realizar reparacion sin presupuesto previo',
              ),
              _optionLine(
                data.authorizeTestDrive,
                'Autorizo para conducir mi vehiculo para pruebas',
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'El Taller y sus empleados no se responsabilizan por objetos '
                'dejados dentro del vehiculo y que no hayan sido inventariados '
                'y entregados al recepcionista.',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
      ),
      pw.SizedBox(width: 8),
      pw.Expanded(
        flex: 2,
        child: pw.Container(
          height: 108,
          padding: const pw.EdgeInsets.fromLTRB(12, 12, 12, 8),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
          child: pw.Column(
            children: [
              pw.Text(
                'Acepto las condiciones expresamente indicadas en esta Orden de Servicio',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Spacer(),
              pw.Divider(thickness: 0.8),
              pw.Text('CLIENTE', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
      ),
    ],
  );
}

pw.Widget _boxedSection({
  required String title,
  required double height,
  required pw.Widget child,
}) {
  return pw.Container(
    height: height,
    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(title),
        pw.Expanded(child: child),
      ],
    ),
  );
}

pw.Widget _sectionTitle(String title) {
  return pw.Container(
    height: 22,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(
      color: PdfColors.grey200,
      border: pw.Border(bottom: pw.BorderSide(width: 0.7)),
    ),
    child: pw.Text(title, style: const pw.TextStyle(fontSize: 9)),
  );
}

pw.Widget _lineField(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Row(
      children: [
        pw.Container(
          width: label.length > 12 ? 84 : 60,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(
          child: pw.Container(
            height: 12,
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 0.6)),
            ),
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(left: 3, bottom: 1),
              child: pw.Text(value),
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _tableHeader(String text) {
  return pw.Container(
    height: 15,
    alignment: pw.Alignment.center,
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 7)),
  );
}

pw.Widget _accessoryColumn(List<MapEntry<String, bool>> entries) {
  return pw.Column(
    children: [
      pw.Row(
        children: [
          pw.Expanded(child: pw.SizedBox()),
          pw.Container(
            width: 18,
            alignment: pw.Alignment.center,
            child: pw.Text('SI'),
          ),
          pw.Container(
            width: 18,
            alignment: pw.Alignment.center,
            child: pw.Text('NO'),
          ),
        ],
      ),
      pw.SizedBox(height: 2),
      for (final entry in entries)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  entry.key,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.Container(
                width: 18,
                alignment: pw.Alignment.center,
                child: _checkBox(entry.value),
              ),
              pw.Container(
                width: 18,
                alignment: pw.Alignment.center,
                child: _checkBox(!entry.value),
              ),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _checkBox(bool checked) {
  return pw.Container(
    width: 11,
    height: 11,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.7)),
    child: checked
        ? pw.Text(
            'X',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          )
        : pw.SizedBox(),
  );
}

pw.Widget _fuelLine(String fuelLevel) {
  final percent = _fuelPercent(fuelLevel);
  const barWidth = 112.0;

  return pw.Row(
    children: [
      pw.Text('Gasolina', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(width: 8),
      pw.Text('V'),
      pw.SizedBox(width: 4),
      pw.Container(
        width: barWidth,
        height: 7,
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          border: pw.Border.all(color: PdfColors.grey300, width: 0.3),
        ),
        child: pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Container(
            width: barWidth * percent,
            height: 7,
            color: PdfColors.grey600,
          ),
        ),
      ),
      pw.SizedBox(width: 4),
      pw.Text('LL'),
    ],
  );
}

pw.Widget _vehicleImage(pw.MemoryImage? image) {
  if (image == null) {
    return pw.Center(child: pw.Text('Imagen del vehiculo'));
  }

  return pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain));
}

pw.Widget _optionLine(bool checked, String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _checkBox(checked),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    ),
  );
}

double _fuelPercent(String fuelLevel) {
  final digits = RegExp(r'\d+').firstMatch(fuelLevel)?.group(0);
  final value = int.tryParse(digits ?? '') ?? 0;
  if (value <= 0) {
    return 0;
  }
  if (value >= 100) {
    return 1;
  }
  return value / 100;
}
