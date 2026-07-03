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

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        _header(data),
        pw.SizedBox(height: 12),
        _section('DATOS DEL CLIENTE', [
          ['Nombre', data.customerName],
          ['Direccion', data.customerAddress],
          ['Telefono', data.customerPhone],
          ['Email', data.customerEmail],
        ]),
        pw.SizedBox(height: 8),
        _section('DATOS DE ORDEN', [
          ['No. orden', data.orderNumber],
          ['Fecha de ingreso', data.entryDate],
          ['Fecha de compromiso', data.deliveryDate],
        ]),
        pw.SizedBox(height: 8),
        _section('DATOS DEL VEHICULO', [
          ['Marca', data.vehicleBrand],
          ['Modelo', data.vehicleModel],
          ['Ano', data.vehicleYear],
          ['Color', data.vehicleColor],
          ['Placas', data.vehiclePlate],
          ['VIN', data.vehicleVin],
          ['Kilometraje', data.mileage],
          ['Gasolina', data.fuelLevel],
        ]),
        pw.SizedBox(height: 8),
        _textBox('DESCRIPCION DE LA FALLA', data.failureDescription),
        pw.SizedBox(height: 8),
        _accessoryTable(data.accessories),
        pw.SizedBox(height: 8),
        _listBox('EMPLEADOS ASIGNADOS', data.assignedEmployees),
        pw.SizedBox(height: 8),
        _authorizationBox(data),
        pw.SizedBox(height: 34),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 220,
              child: pw.Column(
                children: [
                  pw.Divider(color: PdfColors.black),
                  pw.Text('FIRMA DEL CLIENTE'),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  await Printing.layoutPdf(
    name: 'orden_servicio_${data.orderNumber}.pdf',
    onLayout: (_) async => document.save(),
  );
}

pw.Widget _header(ServiceOrderPrintData data) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 72,
        height: 58,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(border: pw.Border.all()),
        child: pw.Text('LOGO'),
      ),
      pw.SizedBox(width: 18),
      pw.Expanded(
        child: pw.Column(
          children: [
            pw.Text(
              'Orden de Servicio',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('No. ${data.orderNumber}'),
          ],
        ),
      ),
      pw.SizedBox(width: 18),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'Nombre de Taller',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Direccion'),
        ],
      ),
    ],
  );
}

pw.Widget _section(String title, List<List<String>> rows) {
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all()),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(title),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final row in rows)
                pw.Container(
                  width: 230,
                  child: pw.Text('${row[0]}: ${row[1].isEmpty ? '-' : row[1]}'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _textBox(String title, String value) {
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all()),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(title),
        pw.Container(
          constraints: const pw.BoxConstraints(minHeight: 82),
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value.isEmpty ? '-' : value),
        ),
      ],
    ),
  );
}

pw.Widget _accessoryTable(Map<String, bool> accessories) {
  final rows = accessories.entries
      .map((entry) => [entry.key, entry.value ? 'SI' : 'NO'])
      .toList();
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all()),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('RECEPCION DEL VEHICULO'),
        pw.TableHelper.fromTextArray(
          headers: ['Accesorio', 'Presente'],
          data: rows,
          border: null,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        ),
      ],
    ),
  );
}

pw.Widget _listBox(String title, List<String> values) {
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all()),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(title),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (values.isEmpty) pw.Text('-'),
              for (final value in values) pw.Text('- $value'),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _authorizationBox(ServiceOrderPrintData data) {
  final options = [
    ['Solicito presupuesto previo', data.requiresQuote],
    ['Autorizo reparacion sin presupuesto previo', data.authorizeRepair],
    ['Autorizo conducir mi vehiculo para pruebas', data.authorizeTestDrive],
    ['Acepto condiciones de la orden', data.acceptsTerms],
  ];

  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all()),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('AUTORIZACIONES'),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final option in options)
                pw.Text('[${option[1] == true ? 'X' : ' '}] ${option[0]}'),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _sectionTitle(String title) {
  return pw.Container(
    color: PdfColors.grey200,
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
    child: pw.Text(
      title,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    ),
  );
}
