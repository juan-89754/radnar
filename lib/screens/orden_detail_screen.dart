import 'dart:convert';
import 'dart:io';
import 'package:flutter/material';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';

import '../models/orden.dart';
import '../models/cliente.dart';
import '../models/equipo.dart';
import '../models/tecnico.dart';
import '../models/checklist_recepcion.dart';
import '../models/bitacora_tecnica.dart';
import '../models/historial_estado.dart';
import '../models/foto_evidencia.dart';
import '../models/cotizacion.dart';

import '../repositories/orden_repository.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/equipo_repository.dart';
import '../repositories/tecnico_repository.dart';
import '../repositories/cotizacion_repository.dart';

import '../services/pdf_helper.dart';
import '../services/whatsapp_helper.dart';
import '../theme/app_theme.dart';
import 'cotizacion_detail_screen.dart';

class OrdenDetailScreen extends StatefulWidget {
  final int ordenId;

  const OrdenDetailScreen({super.key, required this.ordenId});

  @override
  State<OrdenDetailScreen> createState() => _OrdenDetailScreenState();
}

class _OrdenDetailScreenState extends State<OrdenDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _ordenRepo = OrdenRepository();
  final _clienteRepo = ClienteRepository();
  final _equipoRepo = EquipoRepository();
  final _tecnicoRepo = TecnicoRepository();
  final _cotizacionRepo = CotizacionRepository();

  Orden? _orden;
  Cliente? _cliente;
  Equipo? _equipo;
  Tecnico? _tecnico;
  ChecklistRecepcion? _checklist;
  Cotizacion? _cotizacion;

  List<BitacoraTecnica> _bitacoras = [];
  List<HistorialEstado> _historial = [];
  List<FotoEvidencia> _fotos = [];

  bool _isLoading = true;

  // Checklist Form State
  final Map<String, bool> _chkEstados = {
    'pantalla': true,
    'teclado': true,
    'bisagras': true,
    'cargador': true,
    'encendido': true,
    'rayones': false, // Si tiene rayones = falla/si
    'puerto_carga': true,
    'bateria': true,
  };
  final Map<String, TextEditingController> _chkControllers = {
    'pantalla': TextEditingController(),
    'teclado': TextEditingController(),
    'bisagras': TextEditingController(),
    'cargador': TextEditingController(),
    'encendido': TextEditingController(),
    'rayones': TextEditingController(),
    'puerto_carga': TextEditingController(),
    'bateria': TextEditingController(),
  };

  final Map<String, String> _chkLabels = {
    'pantalla': 'Pantalla / Táctil',
    'teclado': 'Teclado / Botones',
    'bisagras': 'Bisagras / Carcasa',
    'cargador': 'Cargador / Cable',
    'encendido': 'Encendido / Post',
    'rayones': '¿Rayones o golpes físicos?',
    'puerto_carga': 'Puerto de carga',
    'bateria': 'Batería / Autonomía',
  };

  // Bitacora Entry state
  final _bitacoraController = TextEditingController();
  bool _bitacoraPrivada = true;

  // Photo state
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bitacoraController.dispose();
    for (var controller in _chkControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final ord = await _ordenRepo.getById(widget.ordenId);
      if (ord != null) {
        _orden = ord;
        _cliente = await _clienteRepo.getById(ord.clienteId);
        _equipo = await _equipoRepo.getById(ord.equipoId);
        if (ord.tecnicoId != null) {
          _tecnico = await _tecnicoRepo.getById(ord.tecnicoId!);
        }
        _checklist = await _ordenRepo.getChecklist(ord.id!);
        _cotizacion = await _cotizacionRepo.getByOrdenId(ord.id!);

        _bitacoras = await _ordenRepo.getBitacora(ord.id!);
        _historial = await _ordenRepo.getHistorial(ord.id!);
        _fotos = await _ordenRepo.getFotos(ord.id!);

        // Load checklist values if already exists
        if (_checklist != null) {
          final datos = _checklist!.datosInspeccion;
          datos.forEach((key, val) {
            if (_chkEstados.containsKey(key)) {
              _chkEstados[key] = val['estado'] ?? true;
              _chkControllers[key]?.text = val['observacion'] ?? '';
            }
          });
        }
      }
    } catch (e) {
      // log error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- Kanban State Updates ---
  Future<void> _updateEstado(String nuevoEstado) async {
    if (_orden == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cambiar Estado Kanban'),
        content: Text('¿Desea cambiar el estado de esta orden a: "${Orden.nombresEstados[nuevoEstado]}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmar')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final updated = _orden!.copyWith(estado: nuevoEstado);
        await _ordenRepo.update(updated);
        await _loadAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Estado actualizado en el tablero Kanban.'), backgroundColor: AppTheme.success),
          );
        }
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Acción Bloqueada por Regla de Negocio'),
              content: Text(e.toString().replaceAll('Exception: ', '')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido')),
              ],
            ),
          );
        }
      }
    }
  }

  // --- Checklist Sealing ---
  Future<void> _sellarChecklist() async {
    if (_orden == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Sellar Checklist?'),
        content: const Text(
          'ADVERTENCIA: Al sellar el checklist, se generará una firma SHA-256 inmutable de integridad. No se podrán realizar modificaciones posteriores.'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.success),
            child: const Text('Sellar e Inmutar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final Map<String, dynamic> datos = {};
        _chkEstados.forEach((key, val) {
          datos[key] = {
            'estado': val,
            'observacion': _chkControllers[key]?.text.trim() ?? '',
          };
        });

        final chk = ChecklistRecepcion.seal(
          ordenId: _orden!.id!,
          codigoOrden: _orden!.codigoOrden,
          datosInspeccion: datos,
        );

        await _ordenRepo.saveChecklist(chk);
        await _loadAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Checklist sellado con firma digital SHA-256.'), backgroundColor: AppTheme.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  // --- Photos Management ---
  Future<void> _addFoto() async {
    if (_orden == null) return;

    if (_fotos.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Límite excedido: Máximo 10 fotografías de evidencia.'), backgroundColor: AppTheme.error),
      );
      return;
    }

    final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (image == null) return;

    // Prompt user for description
    final descController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Anotación de la Imagen'),
        content: TextFormField(
          controller: descController,
          decoration: const InputDecoration(labelText: 'Ej: Rayón en esquina inferior derecha'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Omitir')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar')),
        ],
      ),
    );

    // Save image locally to app documents folder
    final appDir = await getApplicationDocumentsDirectory();
    final evidenceDir = Directory(p.join(appDir.path, 'Evidencias'));
    if (!await evidenceDir.exists()) {
      await evidenceDir.create(recursive: true);
    }

    final String filename = 'evidence_${_orden!.codigoOrden}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File savedImage = await File(image.path).copy(p.join(evidenceDir.path, filename));

    // Calculate sha256 of image bytes
    final bytes = await savedImage.readAsBytes();
    final hash = sha256.convert(bytes).toString();

    final foto = FotoEvidencia(
      ordenId: _orden!.id!,
      checklistId: _checklist?.id,
      imagePath: savedImage.path,
      anotacion: confirm == true ? descController.text.trim() : 'Evidencia visual',
      hashSha256: hash,
      timestampSellado: DateTime.now(),
    );

    await _ordenRepo.addFoto(foto);
    descController.dispose();
    await _loadAllData();
  }

  // --- Add Bitacora Entry ---
  Future<void> _addBitacora() async {
    final txt = _bitacoraController.text.trim();
    if (txt.isEmpty) return;

    final entry = BitacoraTecnica(
      ordenId: widget.ordenId,
      contenido: txt,
      esPrivado: _bitacoraPrivada,
      timestamp: DateTime.now(),
    );

    await _ordenRepo.addBitacora(entry);
    _bitacoraController.clear();
    await _loadAllData();
  }

  // --- PDF print and WhatsApp sending ---
  Future<void> _printPdfReceipt() async {
    if (_orden == null || _cliente == null || _equipo == null) return;

    final prefs = await SharedPreferences.getInstance();
    final tNom = prefs.getString('taller_nombre') ?? 'Radnar Servicio Técnico';
    final tTel = prefs.getString('taller_telefono') ?? '+57 300 000 0000';
    final tDir = prefs.getString('taller_direccion') ?? 'Calle Principal #123';

    await PdfHelper.printComprobanteOrden(
      orden: _orden!,
      cliente: _cliente!,
      equipo: _equipo!,
      tallerNombre: tNom,
      tallerTelefono: tTel,
      tallerDireccion: tDir,
    );
  }

  Future<void> _sendWhatsAppAlert() async {
    if (_orden == null || _cliente == null || _equipo == null) return;

    final prefs = await SharedPreferences.getInstance();
    final tNom = prefs.getString('taller_nombre') ?? 'Radnar';

    final String message = 'Hola ${_cliente!.nombreCompleto}, te saludamos de $tNom.\n\n'
        'Tu equipo *${_equipo!.marca} ${_equipo!.modelo}* se encuentra registrado bajo la orden *${_orden!.codigoOrden}*.\n'
        'Estado actual del servicio: *${_orden!.estadoDisplay.split(". ").last}*.\n\n'
        'Detalles reportados: ${_orden!.motivoIngreso}';

    try {
      await WhatsAppHelper.sendWhatsAppMessage(_cliente!.telefono, message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar WhatsApp: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_orden == null) {
      return const Scaffold(body: Center(child: Text('Orden no encontrada.')));
    }

    final isChecklistSealed = _checklist != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_orden!.codigoOrden),
        actions: [
          // Quote shortcut
          IconButton(
            icon: Icon(Icons.receipt_long, color: _cotizacion != null ? AppTheme.success : AppTheme.accent),
            tooltip: _cotizacion != null ? 'Ver Cotización' : 'Crear Cotización',
            onPressed: () async {
              // Create default quote if not exists
              if (_cotizacion == null) {
                final repo = CotizacionRepository();
                final c = Cotizacion(
                  ordenId: _orden!.id!,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await repo.insert(c);
              }
              if (mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CotizacionDetailScreen(ordenId: _orden!.id!)),
                );
                _loadAllData();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            tooltip: 'Imprimir Comprobante',
            onPressed: _printPdfReceipt,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.greenAccent),
            tooltip: 'WhatsApp Cliente',
            onPressed: _sendWhatsAppAlert,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Selector banner
          Container(
            color: AppTheme.darkCard,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Estado Kanban:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _orden!.estado,
                  dropdownColor: AppTheme.darkCard,
                  underline: Container(),
                  items: Orden.nombresEstados.entries.map((e) {
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
          ),

          // Overview Details
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_cliente?.nombreCompleto ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(_cliente?.telefono ?? '', style: const TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Equipo: ${_equipo?.marca} ${_equipo?.modelo} | PIN: ${_equipo?.pinPlano.isEmpty == true ? "Ninguno" : _equipo?.pinPlano}',
                  style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: const [
              Tab(text: 'Checklist'),
              Tab(text: 'Fotos'),
              Tab(text: 'Bitácora'),
              Tab(text: 'Historial'),
            ],
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. CHECKLIST TAB
                _buildChecklistTab(isChecklistSealed),

                // 2. FOTOS TAB
                _buildFotosTab(),

                // 3. BITACORA TAB
                _buildBitacoraTab(),

                // 4. HISTORIAL TAB
                _buildHistorialTab(),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- Tab building helpers ---

  Widget _buildChecklistTab(bool sealed) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sealed) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified, color: AppTheme.success, size: 20),
                      SizedBox(width: 8),
                      Text('Checklist Sellado e Inmutable', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Firma Hash SHA-256:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  SelectableText(
                    _checklist!.hashSha256,
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sellado el: ${DateFormat('dd/MM/yyyy HH:mm').format(_checklist!.timestampSellado)}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _chkEstados.length,
            itemBuilder: (context, index) {
              final key = _chkEstados.keys.elementAt(index);
              final isOk = _chkEstados[key]!;
              final controller = _chkControllers[key]!;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_chkLabels[key]!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Switch(
                            value: isOk,
                            activeColor: AppTheme.success,
                            inactiveTrackColor: AppTheme.error.withOpacity(0.3),
                            inactiveThumbColor: AppTheme.error,
                            onChanged: sealed ? null : (val) {
                              setState(() => _chkEstados[key] = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: controller,
                        enabled: !sealed,
                        decoration: InputDecoration(
                          hintText: 'Observaciones / Detalles del fallo...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          fillColor: AppTheme.darkBg.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (!sealed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sellarChecklist,
                icon: const Icon(Icons.lock),
                label: const Text('Sellar Checklist de Recepción'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFotosTab() {
    return Scaffold(
      body: _fotos.isEmpty
          ? const Center(
              child: Text(
                'No hay fotografías cargadas para esta orden.',
                style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: _fotos.length,
              itemBuilder: (context, index) {
                final foto = _fotos[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Image.file(
                          File(foto.imagePath),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: AppTheme.darkBorder,
                            child: const Center(child: Icon(Icons.broken_image)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              foto.anotacion ?? 'Evidencia',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'SHA256: ${foto.hashSha256?.substring(0, 8)}...',
                              style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFoto,
        tooltip: 'Tomar Fotografía',
        child: const Icon(Icons.camera_alt),
      ),
    );
  }

  Widget _buildBitacoraTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _bitacoraController,
                  decoration: const InputDecoration(
                    labelText: 'Nota Técnica / Entrada Bitácora',
                    hintText: 'Ej: Mediciones realizadas en regulador de voltaje...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addBitacora,
                icon: const Icon(Icons.send),
                style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _bitacoraPrivada,
                activeColor: AppTheme.primary,
                onChanged: (val) {
                  if (val != null) setState(() => _bitacoraPrivada = val);
                },
              ),
              const Text('Entrada Privada (Solo Técnicos)', style: TextStyle(fontSize: 13)),
            ],
          ),
          const Divider(height: 24, color: AppTheme.darkBorder),
          Expanded(
            child: _bitacoras.isEmpty
                ? const Center(child: Text('Bitácora vacía.', style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic)))
                : ListView.builder(
                    itemCount: _bitacoras.length,
                    itemBuilder: (context, idx) {
                      final note = _bitacoras[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: note.esPrivado ? AppTheme.darkBg.withOpacity(0.5) : AppTheme.darkCard,
                        child: ListTile(
                          title: Text(note.contenido, style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                            'Por: ${note.autorTexto} • ${DateFormat('dd/MM/yyyy HH:mm').format(note.timestamp)}',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          ),
                          trailing: note.esPrivado
                              ? const Tooltip(message: 'Privada', child: Icon(Icons.lock, size: 16, color: AppTheme.warning))
                              : const Tooltip(message: 'Pública', child: Icon(Icons.public, size: 16, color: AppTheme.success)),
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  Widget _buildHistorialTab() {
    return _historial.isEmpty
        ? const Center(child: Text('Sin historial de transiciones.', style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic)))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _historial.length,
            itemBuilder: (context, index) {
              final step = _historial[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.circle, color: AppTheme.primary, size: 12),
                      if (index < _historial.length - 1)
                        Container(width: 2, height: 40, color: AppTheme.darkBorder),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${Orden.nombresEstados[step.estadoAnterior]?.split(". ").last ?? step.estadoAnterior} ➔ ${Orden.nombresEstados[step.estadoNuevo]?.split(". ").last ?? step.estadoNuevo}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(step.timestamp),
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  )
                ],
              );
            },
          );
  }
}
