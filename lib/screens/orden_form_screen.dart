import 'package:flutter/material';
import '../models/orden.dart';
import '../models/cliente.dart';
import '../models/equipo.dart';
import '../models/tecnico.dart';
import '../repositories/orden_repository.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/equipo_repository.dart';
import '../repositories/tecnico_repository.dart';
import '../theme/app_theme.dart';

class OrdenFormScreen extends StatefulWidget {
  final int? clienteId;
  final int? equipoId;
  final Orden? orden; // If editing

  const OrdenFormScreen({
    super.key,
    this.clienteId,
    this.equipoId,
    this.orden,
  });

  @override
  State<OrdenFormScreen> createState() => _OrdenFormScreenState();
}

class _OrdenFormScreenState extends State<OrdenFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ordenRepo = OrdenRepository();
  final _clienteRepo = ClienteRepository();
  final _equipoRepo = EquipoRepository();
  final _tecnicoRepo = TecnicoRepository();

  List<Cliente> _clientes = [];
  List<Equipo> _equipos = [];
  List<Tecnico> _tecnicos = [];

  int? _selectedClienteId;
  int? _selectedEquipoId;
  int? _selectedTecnicoId;
  String _estado = 'ingresado';

  final _motivoController = TextEditingController();
  final _accesoriosController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.orden != null;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final listClientes = await _clienteRepo.getAll();
      final listTecnicos = await _tecnicoRepo.getActivos();

      setState(() {
        _clientes = listClientes;
        _tecnicos = listTecnicos;
      });

      if (_isEditing) {
        final o = widget.orden!;
        _selectedClienteId = o.clienteId;
        _selectedEquipoId = o.equipoId;
        _selectedTecnicoId = o.tecnicoId;
        _estado = o.estado;
        _motivoController.text = o.motivoIngreso;
        _accesoriosController.text = o.accesoriosIncluidos ?? '';
        await _loadEquiposForCliente(o.clienteId);
      } else {
        _selectedClienteId = widget.clienteId;
        _selectedEquipoId = widget.equipoId;
        if (_selectedClienteId != null) {
          await _loadEquiposForCliente(_selectedClienteId!);
        }
      }
    } catch (e) {
      // error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEquiposForCliente(int cId) async {
    final list = await _equipoRepo.getByClienteId(cId);
    setState(() {
      _equipos = list;
      // Auto-select if there's only one, or clear if the selected doesn't belong
      if (_equipos.any((e) => e.id == _selectedEquipoId)) {
        // Keep it
      } else if (_equipos.isNotEmpty) {
        _selectedEquipoId = _equipos.first.id;
      } else {
        _selectedEquipoId = null;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClienteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe seleccionar un cliente.'), backgroundColor: AppTheme.error),
      );
      return;
    }
    if (_selectedEquipoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe seleccionar un equipo.'), backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final o = Orden(
        id: widget.orden?.id,
        codigoOrden: widget.orden?.codigoOrden ?? '', // generated automatically in repo on insert
        clienteId: _selectedClienteId!,
        equipoId: _selectedEquipoId!,
        tecnicoId: _selectedTecnicoId,
        estado: _estado,
        motivoIngreso: _motivoController.text.trim(),
        accesoriosIncluidos: _accesoriosController.text.trim().isEmpty ? null : _accesoriosController.text.trim(),
        fechaIngreso: widget.orden?.fechaIngreso ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEditing) {
        await _ordenRepo.update(o);
      } else {
        await _ordenRepo.insert(o);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Orden actualizada correctamente.' : 'Orden creada correctamente.'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la orden: $e'), backgroundColor: AppTheme.error),
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
        title: Text(_isEditing ? 'Editar Orden de Servicio' : 'Nueva Orden de Servicio'),
      ),
      body: _isLoading || _isSaving
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
                            // Client Dropdown
                            DropdownButtonFormField<int>(
                              value: _selectedClienteId,
                              decoration: const InputDecoration(
                                labelText: 'Cliente *',
                                prefixIcon: Icon(Icons.person),
                              ),
                              items: _clientes.map((c) {
                                return DropdownMenuItem<int>(
                                  value: c.id,
                                  child: Text(c.nombreCompleto),
                                );
                              }).toList(),
                              onChanged: _isEditing ? null : (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedClienteId = val;
                                  });
                                  _loadEquiposForCliente(val);
                                }
                              },
                              validator: (v) => v == null ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 16),

                            // Device Dropdown
                            DropdownButtonFormField<int>(
                              value: _selectedEquipoId,
                              decoration: const InputDecoration(
                                labelText: 'Equipo *',
                                prefixIcon: Icon(Icons.devices),
                              ),
                              items: _equipos.map((e) {
                                return DropdownMenuItem<int>(
                                  value: e.id,
                                  child: Text('${e.marca} ${e.modelo} (${e.tipo.toUpperCase()})'),
                                );
                              }).toList(),
                              onChanged: _isEditing ? null : (val) {
                                setState(() => _selectedEquipoId = val);
                              },
                              validator: (v) => v == null ? 'Requerido' : null,
                              disabledHint: const Text('Seleccione primero un cliente'),
                            ),
                            const SizedBox(height: 16),

                            // Technician Dropdown
                            DropdownButtonFormField<int>(
                              value: _selectedTecnicoId,
                              decoration: const InputDecoration(
                                labelText: 'Técnico Asignado',
                                prefixIcon: Icon(Icons.badge),
                              ),
                              items: _tecnicos.map((t) {
                                return DropdownMenuItem<int>(
                                  value: t.id,
                                  child: Text(t.nombreCompleto),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedTecnicoId = val);
                              },
                            ),
                            if (_isEditing) ...[
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _estado,
                                decoration: const InputDecoration(labelText: 'Estado Kanban'),
                                items: Orden.nombresEstados.entries.map((e) {
                                  return DropdownMenuItem<String>(
                                    value: e.key,
                                    child: Text(e.value),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _estado = val);
                                },
                              ),
                            ]
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
                            Text('Detalles del Reporte', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _motivoController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Motivo de Ingreso / Fallas Reportadas *',
                                alignLabelWithHint: true,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _accesoriosController,
                              decoration: const InputDecoration(
                                labelText: 'Accesorios Recibidos (Funda, Cargador, etc.)',
                                prefixIcon: Icon(Icons.card_giftcard),
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
                        child: Text(_isEditing ? 'Actualizar Orden' : 'Registrar Orden'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
