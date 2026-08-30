import 'package:flutter/material';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/tecnico.dart';
import 'repositories/tecnico_repository.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize workshop settings in SharedPreferences if they do not exist
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString('taller_nombre') == null) {
    await prefs.setString('taller_nombre', 'Radnar Servicio Técnico');
    await prefs.setString('taller_telefono', '+57 320 667 2858');
    await prefs.setString('taller_direccion', 'Calle 100 #15-30, Bogotá');
  }

  // Prepopulate a default technician in SQLite if none exist
  final tecnicoRepo = TecnicoRepository();
  try {
    final list = await tecnicoRepo.getAll();
    if (list.isEmpty) {
      final defaultTec = Tecnico(
        nombreCompleto: 'Técnico Principal',
        telefono: '+57 320 667 2858',
        activo: true,
        createdAt: DateTime.now(),
      );
      final id = await tecnicoRepo.insert(defaultTec);
      await prefs.setInt('tecnico_activo_id', id);
    } else if (prefs.getInt('tecnico_activo_id') == null) {
      await prefs.setInt('tecnico_activo_id', list.first.id!);
    }
  } catch (e) {
    // DB might be lazy-loaded on first query
  }

  runApp(const RadnarApp());
}

class RadnarApp extends StatelessWidget {
  const RadnarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radnar Offline-First',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const DashboardScreen(),
    );
  }
}
