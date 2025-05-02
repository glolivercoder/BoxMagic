import 'package:flutter/material.dart';
import 'package:boxmagic/screens/main_screen.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/services/log_service.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Iniciar serviço de log
  final logService = LogService();
  logService.info('Iniciando aplicativo BoxMagic', category: 'startup');

  // Initialize the database with error handling
  try {
    logService.info('Inicializando banco de dados', category: 'startup');
    await DatabaseHelper.instance.database;
    logService.info('Banco de dados inicializado com sucesso', category: 'startup');
  } catch (e) {
    logService.error('Erro ao inicializar banco de dados: $e', category: 'startup');
    // Continuar mesmo com erro no banco de dados
    // O DatabaseHelper deve ter um fallback para armazenamento em memória
  }

  // Run the app
  runApp(const BoxMagicApp());
}

class BoxMagicApp extends StatelessWidget {
  const BoxMagicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BoxMagic',
      theme: ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2), // Primary color from HTML reference
          primary: const Color(0xFF1976D2),
          secondary: const Color(0xFFF50057), // Secondary color from HTML reference
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1976D2),
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1976D2),
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          primary: const Color(0xFF1976D2),
          secondary: const Color(0xFFF50057),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
    );
  }
}
