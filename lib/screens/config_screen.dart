import 'dart:io';
import 'package:flutter/material';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tecnico.dart';
import '../repositories/tecnico_repository.dart';
import '../services/backup_helper.dart';
import '../services/seed_data_helper.dart';
import '../theme/app_theme.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreTallerController = TextEditingController();
  final _telefonoTallerController = TextEditingController();
  final _direccionTallerController = TextEditingController();
  final _nuevoTecnicoController = TextEditingController();

  final _tecnicoRepo = TecnicoRepository();
  List<Tecnico> _tecnicos = [];
  int? _tecnicoActivoId;
  List<File> _backups = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _refreshTecnicos();
    _refreshBackups();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nombreTallerController.text = prefs.getString('taller_nombre') ?? 'Radnar Servicio Técnico';
      _telefonoTallerController.text = prefs.getString('taller_telefono') ?? '+57 300 000 0000';
      _direccionTallerController.text = prefs.getString('taller_direccion') ?? 'Calle Principal #123';
      _tecnicoActivoId = prefs.getInt('tecnico_activo_id');
    });
  }

  Future<void> _saveConfig() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('taller_nombre', _nombreTallerController.text.trim());
      await prefs.setString('taller_telefono', _telefonoTallerController.text.trim());
      await prefs.setString('taller_direccion', _direccionTallerController.text.trim());
      if (_tecnicoActivoId != null) {
        await prefs.setInt('tecnico_activo_id', _tecnicoActivoId!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada correctamente.'), backgroundColor: AppTheme.success),
        );
      }
    }
  }

  Future<void> _refreshTecnicos() async {
    final list = await _tecnicoRepo.getAll();
    setState(() {
      _tecnicos = list;
      if (_tecnicos.isNotEmpty && _tecnicoActivoId == null) {
        _tecnicoActivoId = _tecnicos.first.id;
      }
    });
  }

  Future<void> _refreshBackups() async {
    final list = await BackupHelper.listBackups();
    setState(() {
      _backups = list;
    });
  }

  Future<void> _agregarTecnico() async {
    final nombre = _nuevoTecnicoController.text.trim();
    if (nombre.isEmpty) return;

    final nuevo = Tecnico(
      nombreCompleto: nombre,
      createdAt: DateTime.now(),
    );
    await _tecnicoRepo.insert(nuevo);
    _nuevoTecnicoController.clear();
    await _refreshTecnicos();
    
    // Auto set active if it was empty
    if (_tecnicoActivoId == null && _tecnicos.isNotEmpty) {
      _tecnicoActivoId = _tecnicos.first.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('tecnico_activo_id', _tecnicoActivoId!);
    }
  }

  Future<void> _cargarSemillas() async {
    setState(() => _isLoading = true);
    try {
      await SeedDataHelper.loadSeedData();
      await _refreshTecnicos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos semilla cargados con éxito.'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar semillas: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportarCopia() async {
    try {
      final path = await BackupHelper.exportBackup();
      await _refreshBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Respaldo guardado en: $path'), backgroundColor: AppTheme.success, duration: const Duration(seconds: 4)),
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

  Future<void> _importarCopia(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Restauración'),
        content: Text('¿Está seguro de restaurar este respaldo? Se sobrescribirá toda la información actual.\n\nArchivo: ${file.path.split(Platform.pathSeparator).last}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await BackupHelper.importBackup(file.path);
        await _loadConfig();
        await _refreshTecnicos();
        await _refreshBackups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Base de datos restaurada con éxito.'), backgroundColor: AppTheme.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al restaurar: $e'), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración del Taller'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  cross: CrossAxisAlignment.start,
                  children: [
                    // Taller Info Form
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          cross: CrossAxisAlignment.start,
                          children: [
                            Text('Datos del Taller (Para comprobantes)', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nombreTallerController,
                              decoration: const InputDecoration(labelText: 'Nombre Comercial'),
                              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _telefonoTallerController,
                              decoration: const InputDecoration(labelText: 'Teléfono Contacto'),
                              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _direccionTallerController,
                              decoration: const InputDecoration(labelText: 'Dirección física'),
                              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _saveConfig,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save),
                                  SizedBox(width: 8),
                                  Text('Guardar Configuración'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Technicians Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          cross: CrossAxisAlignment.start,
                          children: [
                            Text('Técnicos del Sistema', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            if (_tecnicos.isEmpty)
                              const Text('No hay técnicos registrados. Añada uno abajo o cargue datos semilla.', style: TextStyle(color: AppTheme.textSecondary))
                            else ...[
                              const Text('Seleccione el Técnico Activo por defecto:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: _tecnicoActivoId,
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                items: _tecnicos.map((t) {
                                  return DropdownMenuItem<int>(
                                    value: t.id,
                                    child: Text(t.nombreCompleto),
                                  );
                                }).toList(),
                                onChanged: (val) async {
                                  setState(() => _tecnicoActivoId = val);
                                  final prefs = await SharedPreferences.getInstance();
                                  if (val != null) {
                                    await prefs.setInt('tecnico_activo_id', val);
                                  }
                                },
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _nuevoTecnicoController,
                                    decoration: const InputDecoration(labelText: 'Nombre Técnico Nuevo', hintText: 'Ej. Juan Pérez'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  onPressed: _agregarTecnico,
                                  icon: const Icon(Icons.add),
                                  style: IconButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Backup and Data seed
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          cross: CrossAxisAlignment.start,
                          children: [
                            Text('Acciones de Datos y Copias', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _exportarCopia,
                                    icon: const Icon(Icons.backup),
                                    label: const Text('Exportar BD'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primary,
                                      side: const BorderSide(color: AppTheme.primary),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _cargarSemillas,
                                    icon: const Icon(Icons.data_array),
                                    label: const Text('Cargar Semillas'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.accent,
                                      side: const BorderSide(color: AppTheme.accent),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text('Respaldos Disponibles:', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                            const SizedBox(height: 8),
                            if (_backups.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text('No se encontraron copias de seguridad locales.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _backups.length,
                                separatorBuilder: (c, i) => const Divider(color: AppTheme.darkBorder),
                                itemBuilder: (c, i) {
                                  final file = _backups[i];
                                  final filename = file.path.split(Platform.pathSeparator).last;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(filename, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      'Modificado: ${file.lastModifiedSync().toString().split('.').first}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.restore, color: AppTheme.accent),
                                      onPressed: () => _importarCopia(file),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
