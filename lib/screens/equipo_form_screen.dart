import 'package:flutter/material';
import '../models/equipo.dart';
import '../repositories/equipo_repository.dart';
import '../theme/app_theme.dart';

class EquipoFormScreen extends StatefulWidget {
  final int clienteId;
  final Equipo? equipo; // If provided, we are editing

  const EquipoFormScreen({super.key, required this.clienteId, this.equipo});

  @override
  State<EquipoFormScreen> createState() => _EquipoFormScreenState();
}

class _EquipoFormScreenState extends State<EquipoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _equipoRepo = EquipoRepository();

  late String _tipo;
  late final TextEditingController _marcaController;
  late final TextEditingController _modeloController;
  late final TextEditingController _numeroSerieController;
  late final TextEditingController _pinController;
  late final TextEditingController _procesadorController;
  late final TextEditingController _ramController;
  late final TextEditingController _almacenamientoController;

  bool _isEditing = false;
  bool _isSaving = false;

  final List<Map<String, String>> _tipos = [
    {'value': 'laptop', 'label': 'Laptop / Portátil'},
    {'value': 'desktop', 'label': 'PC de Escritorio'},
    {'value': 'all_in_one', 'label': 'All-in-One'},
    {'value': 'console', 'label': 'Consola de Videojuegos'},
    {'value': 'servidor', 'label': 'Servidor / Workstation'},
    {'value': 'otro', 'label': 'Otro'},
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.equipo != null;

    _tipo = widget.equipo?.tipo ?? 'laptop';
    _marcaController = TextEditingController(text: widget.equipo?.marca ?? '');
    _modeloController = TextEditingController(text: widget.equipo?.modelo ?? '');
    _numeroSerieController = TextEditingController(text: widget.equipo?.numeroSerie ?? '');
    _pinController = TextEditingController(text: widget.equipo?.pinPlano ?? '');
    _procesadorController = TextEditingController(text: widget.equipo?.procesador ?? '');
    _ramController = TextEditingController(text: widget.equipo?.ram ?? '');
    _almacenamientoController = TextEditingController(text: widget.equipo?.almacenamiento ?? '');
  }

  @override
  void dispose() {
    _marcaController.dispose();
    _modeloController.dispose();
    _numeroSerieController.dispose();
    _pinController.dispose();
    _procesadorController.dispose();
    _ramController.dispose();
    _almacenamientoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final pinText = _pinController.text.trim();

      final eq = Equipo.create(
        id: widget.equipo?.id,
        clienteId: widget.clienteId,
        tipo: _tipo,
        marca: _marcaController.text.trim(),
        modelo: _modeloController.text.trim(),
        numeroSerie: _numeroSerieController.text.trim().isEmpty ? null : _numeroSerieController.text.trim(),
        pinPlano: pinText.isEmpty ? null : pinText,
        procesador: _procesadorController.text.trim().isEmpty ? null : _procesadorController.text.trim(),
        ram: _ramController.text.trim().isEmpty ? null : _ramController.text.trim(),
        almacenamiento: _almacenamientoController.text.trim().isEmpty ? null : _almacenamientoController.text.trim(),
      );

      if (_isEditing) {
        // preserve createdAt
        final updated = eq.copyWith(
          createdAt: widget.equipo!.createdAt,
          updatedAt: DateTime.now(),
        );
        await _equipoRepo.update(updated);
      } else {
        await _equipoRepo.insert(eq);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Equipo actualizado.' : 'Equipo registrado.'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar equipo: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Equipo' : 'Registrar Equipo'),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _tipo,
                              decoration: const InputDecoration(labelText: 'Tipo de Equipo *'),
                              items: _tipos.map((t) {
                                return DropdownMenuItem<String>(
                                  value: t['value'],
                                  child: Text(t['label']!),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _tipo = val);
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _marcaController,
                              decoration: const InputDecoration(
                                labelText: 'Marca *',
                                prefixIcon: Icon(Icons.branding_watermark),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _modeloController,
                              decoration: const InputDecoration(
                                labelText: 'Modelo Exacto *',
                                prefixIcon: Icon(Icons.devices),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _numeroSerieController,
                              decoration: const InputDecoration(
                                labelText: 'Número de Serie (S/N)',
                                prefixIcon: Icon(Icons.tag),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _pinController,
                              decoration: const InputDecoration(
                                labelText: 'PIN / Contraseña de acceso',
                                prefixIcon: Icon(Icons.lock_outline),
                                helperText: 'Se guardará cifrado de forma local en el dispositivo.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Especificaciones Técnicas (Opcional)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _procesadorController,
                              decoration: const InputDecoration(
                                labelText: 'Procesador / CPU',
                                prefixIcon: Icon(Icons.developer_board),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _ramController,
                              decoration: const InputDecoration(
                                labelText: 'Memoria RAM',
                                prefixIcon: Icon(Icons.memory),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _almacenamientoController,
                              decoration: const InputDecoration(
                                labelText: 'Almacenamiento (HDD/SSD)',
                                prefixIcon: Icon(Icons.storage),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        child: Text(_isEditing ? 'Actualizar Equipo' : 'Registrar Equipo'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
