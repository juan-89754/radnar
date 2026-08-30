import 'package:flutter/material';
import '../models/cliente.dart';
import '../models/equipo.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/equipo_repository.dart';
import '../theme/app_theme.dart';
import 'cliente_form_screen.dart';
import 'equipo_form_screen.dart';
import 'orden_form_screen.dart';

class ClienteListScreen extends StatefulWidget {
  const ClienteListScreen({super.key});

  @override
  State<ClienteListScreen> createState() => _ClienteListScreenState();
}

class _ClienteListScreenState extends State<ClienteListScreen> {
  final _clienteRepo = ClienteRepository();
  final _equipoRepo = EquipoRepository();

  List<Cliente> _clientes = [];
  Map<int, List<Equipo>> _equiposPorCliente = {};

  String _searchQuery = '';
  bool _isLoading = true;
  int? _expandedClienteId;

  @override
  void initState() {
    super.initState();
    _refreshClientes();
  }

  Future<void> _refreshClientes() async {
    setState(() => _isLoading = true);
    try {
      final list = await _clienteRepo.getAll(search: _searchQuery);
      
      // Load devices for all clients to display count
      final Map<int, List<Equipo>> map = {};
      for (var cliente in list) {
        if (cliente.id != null) {
          final eqList = await _equipoRepo.getByClienteId(cliente.id!);
          map[cliente.id!] = eqList;
        }
      }

      setState(() {
        _clientes = list;
        _equiposPorCliente = map;
      });
    } catch (e) {
      // Error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleExpand(int clienteId) async {
    setState(() {
      if (_expandedClienteId == clienteId) {
        _expandedClienteId = null;
      } else {
        _expandedClienteId = clienteId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Clientes'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search field
            TextFormField(
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, teléfono o correo...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _refreshClientes();
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _refreshClientes();
              },
            ),
            const SizedBox(height: 16),

            // Clients List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _clientes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 48, color: AppTheme.textSecondary.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              const Text('No hay clientes registrados.', style: TextStyle(color: AppTheme.textSecondary)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _clientes.length,
                          itemBuilder: (context, index) {
                            final cliente = _clientes[index];
                            final id = cliente.id!;
                            final isExpanded = _expandedClienteId == id;
                            final equipos = _equiposPorCliente[id] ?? [];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                children: [
                                  ListTile(
                                    title: Text(
                                      cliente.nombreCompleto,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    subtitle: Text(
                                      '${cliente.telefono} • ${equipos.length} Equipos',
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: AppTheme.accent, size: 20),
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ClienteFormScreen(cliente: cliente),
                                              ),
                                            );
                                            _refreshClientes();
                                          },
                                        ),
                                        Icon(
                                          isExpanded ? Icons.expand_less : Icons.expand_more,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ],
                                    ),
                                    onTap: () => _toggleExpand(id),
                                  ),
                                  if (isExpanded) ...[
                                    const Divider(color: AppTheme.darkBorder, height: 1),
                                    Container(
                                      color: AppTheme.darkBg.withOpacity(0.3),
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (cliente.email != null && cliente.email!.isNotEmpty)
                                            _buildInfoRow(Icons.email, cliente.email!),
                                          if (cliente.direccion != null && cliente.direccion!.isNotEmpty)
                                            _buildInfoRow(Icons.location_on, cliente.direccion!),
                                          if (cliente.notas != null && cliente.notas!.isNotEmpty)
                                            _buildInfoRow(Icons.notes, cliente.notas!),
                                          
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Equipos Vinculados', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14)),
                                              TextButton.icon(
                                                onPressed: () async {
                                                  await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => EquipoFormScreen(clienteId: id),
                                                    ),
                                                  );
                                                  _refreshClientes();
                                                },
                                                icon: const Icon(Icons.add, size: 16),
                                                label: const Text('Agregar Equipo', style: TextStyle(fontSize: 12)),
                                              )
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          if (equipos.isEmpty)
                                            const Padding(
                                              padding: EdgeInsets.symmetric(vertical: 8.0),
                                              child: Text('Sin equipos registrados.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: AppTheme.textSecondary)),
                                            )
                                          else
                                            ...equipos.map((eq) {
                                              return Container(
                                                margin: const EdgeInsets.only(bottom: 8),
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.darkCard,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: AppTheme.darkBorder),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text('${eq.marca} ${eq.modelo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                          Text(
                                                            'Tipo: ${eq.tipo.toUpperCase()} | S/N: ${eq.numeroSerie ?? "N/A"}',
                                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Row(
                                                      children: [
                                                        IconButton(
                                                          icon: const Icon(Icons.edit, color: AppTheme.textSecondary, size: 16),
                                                          onPressed: () async {
                                                            await Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) => EquipoFormScreen(clienteId: id, equipo: eq),
                                                              ),
                                                            );
                                                            _refreshClientes();
                                                          },
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(Icons.assignment_add, color: AppTheme.primary, size: 18),
                                                          tooltip: 'Crear Orden',
                                                          onPressed: () async {
                                                            await Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) => OrdenFormScreen(
                                                                  clienteId: id,
                                                                  equipoId: eq.id,
                                                                ),
                                                              ),
                                                            );
                                                            _refreshClientes();
                                                          },
                                                        ),
                                                      ],
                                                    )
                                                  ],
                                                ),
                                              );
                                            }),
                                        ],
                                      ),
                                    )
                                  ]
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ClienteFormScreen()),
          );
          _refreshClientes();
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
