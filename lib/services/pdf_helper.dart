import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/orden.dart';
import '../models/cliente.dart';
import '../models/equipo.dart';
import '../models/cotizacion.dart';
import '../models/linea_cotizacion.dart';

class PdfHelper {
  static final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  /// Generates and shows the print/layout dialog for a service order receipt
  static Future<void> printComprobanteOrden({
    required Orden orden,
    required Cliente cliente,
    required Equipo equipo,
    required String tallerNombre,
    required String tallerTelefono,
    required String tallerDireccion,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              cross: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      cross: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(tallerNombre, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        pw.Text('Tel: $tallerTelefono', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text(tallerDireccion, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      cross: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('COMPROBANTE DE INGRESO', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                        pw.Text(orden.codigoOrden, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                        pw.Text('Fecha: ${dateFormat.format(orden.fechaIngreso)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1, color: PdfColors.blue800),
                pw.SizedBox(height: 15),

                // Customer details
                pw.Text('DATOS DEL CLIENTE', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.SizedBox(height: 4),
                pw.Text('Nombre: ${cliente.nombreCompleto}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Teléfono: ${cliente.telefono}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Email: ${cliente.email ?? "No registrado"}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Dirección: ${cliente.direccion ?? "No registrada"}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 15),

                // Device details
                pw.Text('DATOS DEL EQUIPO', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.SizedBox(height: 4),
                pw.Text('Tipo: ${equipo.tipo.toUpperCase()}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Marca y Modelo: ${equipo.marca} ${equipo.modelo}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Número de Serie: ${equipo.numeroSerie ?? "N/A"}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Especificaciones: CPU: ${equipo.procesador ?? "N/A"} | RAM: ${equipo.ram ?? "N/A"} | Disco: ${equipo.almacenamiento ?? "N/A"}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 15),

                // Reason for entry
                pw.Text('MOTIVO DE INGRESO / FALLAS REPORTADAS', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.SizedBox(height: 4),
                pw.Text(orden.motivoIngreso, style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 6),
                pw.Text('Accesorios incluidos: ${orden.accesoriosIncluidos ?? "Ninguno"}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 25),

                // Terms
                pw.Text('TÉRMINOS DEL SERVICIO:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Bullet(text: 'El diagnóstico inicial toma de 24 a 48 horas.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                pw.Bullet(text: 'El cliente autoriza la manipulación del equipo para fines de revisión.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                pw.Bullet(text: 'No nos responsabilizamos por pérdida de datos. Respalde antes de entregar.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                pw.Bullet(text: 'Equipos no retirados después de 30 días causarán recargos de bodegaje.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                pw.SizedBox(height: 40),

                // Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Container(width: 140, border: const pw.Border(top: pw.BorderSide(width: 0.8, color: PdfColors.grey500))),
                        pw.SizedBox(height: 4),
                        pw.Text('Recibe Técnico', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(width: 140, border: const pw.Border(top: pw.BorderSide(width: 0.8, color: PdfColors.grey500))),
                        pw.SizedBox(height: 4),
                        pw.Text('Firma Cliente', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Comprobante_Ingreso_${orden.codigoOrden}.pdf',
    );
  }

  /// Generates and shows the print/layout dialog for a Quotation showing Option A (recommended) and Option B (economical)
  static Future<void> printCotizacion({
    required Cotizacion cotizacion,
    required Orden orden,
    required Cliente cliente,
    required List<LineaCotizacion> lineas,
    required String tallerNombre,
    required String tallerTelefono,
    required String tallerDireccion,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Split lines by options
    final lineasA = lineas.where((l) => l.opcion == 'opcion_a').toList();
    final lineasB = lineas.where((l) => l.opcion == 'opcion_b').toList();

    double totalA = lineasA.where((l) => l.aprobadaPorCliente).fold(0.0, (sum, item) => sum + item.subtotalCliente);
    double totalB = lineasB.where((l) => l.aprobadaPorCliente).fold(0.0, (sum, item) => sum + item.subtotalCliente);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              cross: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      cross: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(tallerNombre, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        pw.Text('Tel: $tallerTelefono', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text(tallerDireccion, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      cross: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('COTIZACIÓN DE SERVICIOS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                        pw.Text(orden.codigoOrden, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        pw.Text('Fecha: ${dateFormat.format(cotizacion.createdAt)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1, color: PdfColors.blue800),
                pw.SizedBox(height: 10),

                pw.Text('Cliente: ${cliente.nombreCompleto}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('Teléfono: ${cliente.telefono}', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 12),

                // Option A table
                pw.Text('OPCIÓN A: Principal / Recomendada', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.SizedBox(height: 4),
                _buildTable(lineasA),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    pw.Text('Total Opción A: ${currencyFormat.format(totalA)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  ),
                ),
                pw.SizedBox(height: 15),

                // Option B table (if exists)
                if (lineasB.isNotEmpty) ...[
                  pw.Text('OPCIÓN B: Alternativa / Económica', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  _buildTable(lineasB),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6),
                      pw.Text('Total Opción B: ${currencyFormat.format(totalB)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                    ),
                  ),
                ],

                pw.SizedBox(height: 20),
                pw.Text('Notas al Cliente:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(cotizacion.notesForClient, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                pw.SizedBox(height: 40),

                pw.Text('Agradecemos su confianza. Si tiene dudas, contáctenos directamente.', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Cotizacion_${orden.codigoOrden}.pdf',
    );
  }

  static pw.Widget _buildTable(List<LineaCotizacion> items) {
    if (items.isEmpty) {
      return pw.Text('No se especificaron conceptos para esta opción.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Descripción / Servicio', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Cantidad', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Unitario', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Subtotal', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
          ],
        ),
        // Rows
        ...items.map((linea) {
          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  linea.descripcion + (linea.aprobadaPorCliente ? '' : ' (No aprobada)'),
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: linea.aprobadaPorCliente ? PdfColors.black : PdfColors.grey500,
                    decoration: linea.aprobadaPorCliente ? null : pw.TextDecoration.lineThrough,
                  ),
                ),
              ),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(linea.cantidad.toString(), style: const pw.TextStyle(fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(currencyFormat.format(linea.precioCliente), style: const pw.TextStyle(fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(currencyFormat.format(linea.subtotalCliente), style: const pw.TextStyle(fontSize: 8))),
            ],
          );
        }),
      ],
    );
  }
}

// Extension to avoid compilation issues in case fields are named slightly differently
extension CotizacionNotesExt on Cotizacion {
  String get notesForClient => notasCliente ?? 'Sin notas adicionales.';
}
