import 'package:flutter/material';
import '../models/orden.dart';
import '../models/cliente.dart';
import '../models/equipo.dart';
import '../repositories/orden_repository.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/equipo_repository.dart';
import '../theme/app_theme.dart';
import 'cliente_list_screen.dart';
import 'orden_form_screen.dart';
import 'orden_detail_screen.dart';
import 'config_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _ordenRepo = OrdenRepository();
  final _clienteRepo = ClienteRepository();
  final _equipoRepo = EquipoRepository();

  List<Orden> _ordenes = [];
  List<Cliente> _clientes = [];
  List<Equipo> _equipos = [];

  String _filtroEstado = 'todos';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  int _totalClientes = 0;
  int _totalActivas = 0;
  int _totalListas = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final listOrdenes = await _ordenRepo.getAll(search: _searchQuery);
      final listClientes = await _clienteRepo.getAll();
      final listEquipos = await _equipoRepo.getAll();

      // Stats
      final activas = listOrdenes.where((o) => o.estado != 'entregado_cobrado').length;
      final listas = listOrdenes.where((o) => o.estado == 'listo_entrega').length;

      setState(() {
        _ordenes = listOrdenes;
        _clientes = listClientes;
        _equipos = listEquipos;
        _totalClientes = listClientes.length;
        _totalActivas = activas;
        _totalListas = listas;
      });
    } catch (e) {
      // Error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Cliente? _findCliente(int id) {
    try {
      return _clientes.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  Equipo? _findEquipo(int id) {
    try {
      return _equipos.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'ingresado':
        return Colors.blue;
      case 'en_diagnostico':
        return Colors.orange;
      case 'cotizado':
        return Colors.purple;
      case 'aprobado':
        return Colors.teal;
      case 'en_reparacion':
        return Colors.amber;
      case 'en_pruebas':
        return Colors.indigo;
      case 'listo_entrega':
        return AppTheme.success;
      case 'entregado_cobrado':
        return AppTheme.textSecondary;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter orders
    final ordenesFiltradas = _ordenes.where((o) {
      if (_filtroEstado == 'todos') return true;
      if (_filtroEstado == 'activas') return o.estado != 'entregado_cobrado';
      return o.estado == _filtroEstado;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('RADNAR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConfigScreen()),
              );
              _refreshData();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              cross: CrossAxisAlignment.start,
              children: [
                // Stats Banner
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Clientes',
                        value: _totalClientes.toString(),
                        icon: Icons.people,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Activas',
                        value: _totalActivas.toString(),
                        icon: Icons.pending_actions,
                        color: AppTheme.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Listas para entrega',
                        value: _totalListas.toString(),
                        icon: Icons.done_all,
                        color: AppTheme.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Quick Navigation Grid
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ClienteListScreen()),
                          );
                          _refreshData();
                        },
                        icon: const Icon(Icons.people),
                        label: const Text('Clientes / Equipos'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.darkCard,
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.darkBorder),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const OrdenFormScreen()),
                          );
                          _refreshData();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Nueva Orden'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Search Bar
                TextFormField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar orden por código, cliente o equipo...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _refreshData();
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _refreshData();
                  },
                ),
                const SizedBox(height: 20),

                // Horizontal scroll of filters (Kanban state visual selector)
                Text('Estados Kanban', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterBadge('todos', 'Todos'),
                      _buildFilterBadge('activas', 'Activas'),
                      _buildFilterBadge('ingresado', '1. Ingresado'),
                      _buildFilterBadge('en_diagnostico', '2. Diagnóstico'),
                      _buildFilterBadge('cotizado', '3. Cotizado'),
                      _buildFilterBadge('aprobado', '4. Aprobado'),
                      _buildFilterBadge('en_reparacion', '5. Reparación'),
                      _buildFilterBadge('en_pruebas', '6. Pruebas'),
                      _buildFilterBadge('listo_entrega', '7. Listo'),
                      _buildFilterBadge('entregado_cobrado', '8. Entregado'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Feed / List of Orders
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Órdenes (${ordenesFiltradas.length})', style: Theme.of(context).textTheme.titleLarge),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppTheme.primary),
                      onPressed: _refreshData,
                    )
                  ],
                ),
                const SizedBox(height: 10),

                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                else if (ordenesFiltradas.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 48, color: AppTheme.textSecondary.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          const Text('No se encontraron órdenes.', style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ordenesFiltradas.length,
                    itemBuilder: (context, idx) {
                      final orden = ordenesFiltradas[idx];
                      final cliente = _findCliente(orden.clienteId);
                      final equipo = _findEquipo(orden.equipoId);

                      return GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrdenDetailScreen(ordenId: orden.id!),
                            ),
                          );
                          _refreshData();
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              cross: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      orden.codigoOrden,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getEstadoColor(orden.estado).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: _getEstadoColor(orden.estado)),
                                      ),
                                      child: Text(
                                        orden.estadoDisplay.split('. ').last,
                                        style: TextStyle(
                                          color: _getEstadoColor(orden.estado),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  cliente?.nombreCompleto ?? 'Cliente Desconocido',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${equipo?.marca ?? ""} ${equipo?.modelo ?? "Dispositivo"} (${equipo?.tipo.toUpperCase() ?? ""})',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                const Divider(color: AppTheme.darkBorder, height: 16),
                                Row(
                                  children: [
                                    const Icon(Icons.error_outline, size: 14, color: AppTheme.textSecondary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        orden.motivoIngreso,
                                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          cross: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBadge(String value, String label) {
    final isSelected = _filtroEstado == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filtroEstado = value);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.darkBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
