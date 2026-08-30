import 'package:flutter/material';
import '../models/cliente.dart';
import '../repositories/cliente_repository.dart';
import '../theme/app_theme.dart';

class ClienteFormScreen extends StatefulWidget {
  final Cliente? cliente; // If provided, we are editing

  const ClienteFormScreen({super.key, this.cliente});

  @override
  State<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clienteRepo = ClienteRepository();

  late final TextEditingController _nombreController;
  late final TextEditingController _telefonoController;
  late final TextEditingController _emailController;
  late final TextEditingController _direccionController;
  late final TextEditingController _notasController;

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.cliente != null;

    _nombreController = TextEditingController(text: widget.cliente?.nombreCompleto ?? '');
    _telefonoController = TextEditingController(text: widget.cliente?.telefono ?? '');
    _emailController = TextEditingController(text: widget.cliente?.email ?? '');
    _direccionController = TextEditingController(text: widget.cliente?.direccion ?? '');
    _notasController = TextEditingController(text: widget.cliente?.notas ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _direccionController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // Validate and clean phone format
      final cleanPhone = Cliente.cleanAndValidatePhone(_telefonoController.text);

      final c = Cliente(
        id: widget.cliente?.id,
        nombreCompleto: _nombreController.text.trim(),
        telefono: cleanPhone,
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        direccion: _direccionController.text.trim().isEmpty ? null : _direccionController.text.trim(),
        notas: _notasController.text.trim().isEmpty ? null : _notasController.text.trim(),
        createdAt: widget.cliente?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEditing) {
        await _clienteRepo.update(c);
      } else {
        await _clienteRepo.insert(c);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Cliente actualizado.' : 'Cliente creado.'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } on FormatException catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Número de Teléfono Inválido'),
            content: Text(e.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: El teléfono ya podría estar registrado.'),
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
        title: Text(_isEditing ? 'Editar Cliente' : 'Registrar Cliente'),
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
                          children: [
                            TextFormField(
                              controller: _nombreController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre Completo *',
                                prefixIcon: Icon(Icons.person),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _telefonoController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Teléfono (Formato E.164) *',
                                prefixIcon: Icon(Icons.phone),
                                hintText: 'Ej. +573206672858 o 3206672858',
                                helperText: 'Si es de Colombia (10 dígitos), se le añadirá +57 automáticamente.',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Correo Electrónico',
                                prefixIcon: Icon(Icons.email),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _direccionController,
                              decoration: const InputDecoration(
                                labelText: 'Dirección de Domicilio',
                                prefixIcon: Icon(Icons.location_on),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _notasController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Notas Internas',
                                prefixIcon: Icon(Icons.notes),
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
                        child: Text(_isEditing ? 'Actualizar Cliente' : 'Registrar Cliente'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
