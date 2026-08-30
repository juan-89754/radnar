import 'package:flutter/material';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cotizacion.dart';
import '../models/linea_cotizacion.dart';
import '../models/orden.dart';
import '../models/cliente.dart';

import '../repositories/cotizacion_repository.dart';
import '../repositories/orden_repository.dart';
import '../repositories/cliente_repository.dart';

import '../services/pdf_helper.dart';
import '../services/whatsapp_helper.dart';
import '../theme/app_theme.dart';

class CotizacionDetailScreen extends StatefulWidget {
  final int ordenId;

  const CotizacionDetailScreen({super.key, required this.ordenId});

  @override
  State<CotizacionDetailScreen> createState() => _CotizacionDetailScreenState();
}

class _CotizacionDetailScreenState extends State<CotizacionDetailScreen> {
  final _cotizacionRepo = CotizacionRepository();
  final _ordenRepo = OrdenRepository();
  final _clienteRepo = ClienteRepository();

  Orden? _orden;
  Cliente? _cliente;
  Cotizacion? _cotizacion;
  List<LineaCotizacion> _lineas = [];

  bool _isLoading = true;
  final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  // Form controllers for editing quote header
  final _tituloController = TextEditingController();
  final _notasController = TextEditingController();

  // Add line item state
  final _addFormKey = GlobalKey<FormState>();
  String _lineTipo = 'repuesto';
  String _lineOpcion = 'opcion_a';
  final _lineDescController = TextEditingController();
  final _lineCostoController = TextEditingController(text: '0');
  final _lineMargenController = TextEditingController(text: '30');
  final _lineCantidadController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _notasController.dispose();
    _lineDescController.dispose();
    _lineCostoController.dispose();
    _lineMargenController.dispose();
    _lineCantidadController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _orden = await _ordenRepo.getById(widget.ordenId);
      if (_orden != null) {
        _cliente = await _clienteRepo.getById(_orden!.clienteId);
        _cotizacion = await _cotizacionRepo.getByOrdenId(_orden!.id!);
        if (_cotizacion != null) {
          _tituloController.text = _cotizacion!.titulo;
          _notasController.text = _cotizacion!.notasCliente ?? '';
          _lineas = await _cotizacionRepo.getLineas(_cotizacion!.id!);
        }
      }
    } catch (e) {
      // error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveHeader() async {
    if (_cotizacion == null) return;
    try {
      final updated = _cotizacion!.copyWith(
        titulo: _tituloController.text.trim(),
        notasCliente: _notasController.text.trim(),
      );
      await _cotizacionRepo.update(updated);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cabecera de cotización guardada.'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      // error
    }
  }

  Future<void> _updateEstado(String estado) async {
    if (_cotizacion == null) return;
    try {
      final updated = _cotizacion!.copyWith(estado: estado);
      await _cotizacionRepo.update(updated);
      _loadData();
    } catch (e) {
      // error
    }
  }

  Future<void> _addLinea() async {
    if (!_addFormKey.currentState!.validate()) return;
    if (_cotizacion == null) return;

    final costo = double.tryParse(_lineCostoController.text) ?? 0.0;
    final margen = double.tryParse(_lineMargenController.text) ?? 30.0;
    final cantidad = int.tryParse(_lineCantidadController.text) ?? 1;

    final finalPrice = LineaCotizacion.autoCalculatePrecioCliente(costo, margen);

    final linea = LineaCotizacion(
      cotizacionId: _cotizacion!.id!,
      tipo: _lineTipo,
      opcion: _lineOpcion,
      descripcion: _lineDescController.text.trim(),
      costoProveedor: costo,
      margenPorcentaje: margen,
      precioCliente: finalPrice,
      cantidad: cantidad,
      aprobadaPorCliente: true,
      createdAt: DateTime.now(),
    );

    await _cotizacionRepo.insertLinea(linea);

    // Reset fields
    _lineDescController.clear();
    _lineCostoController.text = '0';
    _lineMargenController.text = '30';
    _lineCantidadController.text = '1';

    Navigator.pop(context);
    _loadData();
  }

  Future<void> _toggleAprobacion(LineaCotizacion linea) async {
    final updated = linea.copyWith(aprobadaPorCliente: !linea.aprobadaPorCliente);
    await _cotizacionRepo.updateLinea(updated);
    _loadData();
  }

  Future<void> _deleteLinea(int id) async {
    await _cotizacionRepo.deleteLinea(id);
    _loadData();
  }

  Future<void> _printPdfQuote() async {
    if (_cotizacion == null || _orden == null || _cliente == null) return;

    final prefs = await SharedPreferences.getInstance();
    final tNom = prefs.getString('taller_nombre') ?? 'Radnar Servicio Técnico';
    final tTel = prefs.getString('taller_telefono') ?? '+57 300 000 0000';
    final tDir = prefs.getString('taller_direccion') ?? 'Calle Principal #123';

    await PdfHelper.printCotizacion(
      cotizacion: _cotizacion!,
      orden: _orden!,
      cliente: _cliente!,
      lineas: _lineas,
      tallerNombre: tNom,
      tallerTelefono: tTel,
      tallerDireccion: tDir,
    );
  }

  Future<void> _sendWhatsAppQuote() async {
    if (_cotizacion == null || _orden == null || _cliente == null) return;

    final lineasA = _lineas.where((l) => l.opcion == 'opcion_a').toList();
    final lineasB = _lineas.where((l) => l.opcion == 'opcion_b').toList();

    double totalA = lineasA.where((l) => l.aprobadaPorCliente).fold(0.0, (sum, item) => sum + item.subtotalCliente);
    double totalB = lineasB.where((l) => l.aprobadaPorCliente).fold(0.0, (sum, item) => sum + item.subtotalCliente);

    final prefs = await SharedPreferences.getInstance();
    final tNom = prefs.getString('taller_nombre') ?? 'Radnar';

    String text = 'Hola ${_cliente!.nombreCompleto}, te saluda $tNom.\n\n'
        'Hemos generado el presupuesto para la orden *${_orden!.codigoOrden}*.\n\n'
        '*OPCIÓN A (Recomendada):*\n';

    if (lineasA.isEmpty) {
      text += '- No hay conceptos cargados.\n';
    } else {
      for (var l in lineasA) {
        text += '- ${l.descripcion} (${l.cantidad}x): ${currencyFormat.format(l.precioCliente)}\n';
      }
      text += '*Total Opción A: ${currencyFormat.format(totalA)}*\n';
    }

    if (lineasB.isNotEmpty) {
      text += '\n*OPCIÓN B (Alternativa económica):*\n';
      for (var l in lineasB) {
        text += '- ${l.descripcion} (${l.cantidad}x): ${currencyFormat.format(l.precioCliente)}\n';
      }
      text += '*Total Opción B: ${currencyFormat.format(totalB)}*\n';
    }

    text += '\nNotas adicionales: ${_cotizacion!.notasCliente ?? "Ninguna."}\n\n'
        'Por favor confírmanos cuál opción apruebas para iniciar con la reparación.';

    try {
      await WhatsAppHelper.sendWhatsAppMessage(_cliente!.telefono, text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir por WhatsApp: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkCard,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 16,
                right: 16,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _addFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Añadir Concepto de Cobro', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18)),
                      const SizedBox(height: 16),
                      
                      // Segmented Option selector
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Opción A (Recomendada)')),
                              selected: _lineOpcion == 'opcion_a',
                              onSelected: (val) => setDialogState(() => _lineOpcion = 'opcion_a'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Opción B (Económica)')),
                              selected: _lineOpcion == 'opcion_b',
                              onSelected: (val) => setDialogState(() => _lineOpcion = 'opcion_b'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _lineTipo,
                        decoration: const InputDecoration(labelText: 'Tipo de Concepto'),
                        items: LineaCotizacion.nombresTipos.entries.map((e) {
                          return DropdownMenuItem<String>(value: e.key, child: Text(e.value));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => _lineTipo = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _lineDescController,
                        decoration: const InputDecoration(labelText: 'Descripción del Servicio o Repuesto *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _lineCostoController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Costo Proveedor'),
                              onChanged: (v) {
                                // Trigger dialog redraw to show calculated price
                                setDialogState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lineMargenController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Margen de Ganancia (%)'),
                              onChanged: (v) {
                                setDialogState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _lineCantidadController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Cantidad'),
                      ),
                      const SizedBox(height: 16),

                      // Calculated final price summary
                      Builder(builder: (context) {
                        final cost = double.tryParse(_lineCostoController.text) ?? 0.0;
                        final marg = double.tryParse(_lineMargenController.text) ?? 30.0;
                        final finalP = LineaCotizacion.autoCalculatePrecioCliente(cost, marg);
                        final cant = int.tryParse(_lineCantidadController.text) ?? 1;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.darkBg.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.darkBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Precio Unitario Cliente:', style: TextStyle(color: AppTheme.textSecondary)),
                              Text(
                                currencyFormat.format(finalP),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _addLinea,
                          child: const Text('Agregar Concepto'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_cotizacion == null) {
      return const Scaffold(body: Center(child: Text('Error al cargar cotización.')));
    }

    final lineasA = _lineas.where((l) => l.opcion == 'opcion_a').toList();
    final lineasB = _lineas.where((l) => l.opcion == 'opcion_b').toList();

    double totalA = lineasA.where((l) => l.aprobadaPorCliente).fold(0.0, (sum, item) => sum + item.subtotalCliente);
    double totalB = lineasB.where((l) => l.aprobadaPorCliente).fold(0.0, (sum, item) => sum + item.subtotalCliente);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presupuesto y Cotización'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            tooltip: 'Imprimir PDF',
            onPressed: _printPdfQuote,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.greenAccent),
            tooltip: 'Enviar a WhatsApp',
            onPressed: _sendWhatsAppQuote,
          ),
        ],
      ),
      body: Column(
        children: [
          // Quote header and state selection
          Container(
            color: AppTheme.darkCard,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Estado de la Cotización:', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: _cotizacion!.estado,
                      dropdownColor: AppTheme.darkCard,
                      underline: Container(),
                      items: Cotizacion.nombresEstados.entries.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) _updateEstado(val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _tituloController,
                  decoration: const InputDecoration(labelText: 'Título del Presupuesto'),
                  onFieldSubmitted: (v) => _saveHeader(),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notasController,
                  decoration: const InputDecoration(labelText: 'Notas para el Cliente (Garantía, etc.)'),
                  onFieldSubmitted: (v) => _saveHeader(),
                ),
              ],
            ),
          ),

          // Lists of Options A and B
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Opción A (Recomendada)', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.primary)),
                      Text('Total: ${currencyFormat.format(totalA)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildLineList(lineasA),
                  
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Opción B (Económica / Alternativa)', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.accent)),
                      Text('Total: ${currencyFormat.format(totalB)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildLineList(lineasB),
                ],
              ),
            ),
          ),

          // Bottom Bar showing totals summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.darkCard,
              border: Border(top: BorderSide(color: AppTheme.darkBorder, width: 1)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Total A: ${currencyFormat.format(totalA)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                        Text('Total B: ${currencyFormat.format(totalB)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accent)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir Concepto'),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLineList(List<LineaCotizacion> items) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text('Sin conceptos registrados para esta opción.', style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textSecondary)),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Checkbox(
              value: item.aprobadaPorCliente,
              activeColor: AppTheme.primary,
              onChanged: (val) => _toggleAprobacion(item),
            ),
            title: Text(
              item.descripcion,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                decoration: item.aprobadaPorCliente ? null : TextDecoration.lineThrough,
                color: item.aprobadaPorCliente ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
            subtitle: Text(
              '${LineaCotizacion.nombresTipos[item.tipo]?.split(" / ").first} • ${item.cantidad}x ${currencyFormat.format(item.precioCliente)}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currencyFormat.format(item.subtotalCliente),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: item.aprobadaPorCliente ? AppTheme.success : AppTheme.textSecondary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                  onPressed: () => _deleteLinea(item.id!),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
