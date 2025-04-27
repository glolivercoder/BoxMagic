import 'package:flutter/material.dart';
import 'package:boxmagic/screens/boxes_screen.dart';
import 'package:boxmagic/screens/items_screen.dart';
import 'package:boxmagic/screens/users_screen.dart';
import 'package:boxmagic/screens/settings_screen.dart';
import 'package:boxmagic/screens/logs_screen.dart';
import 'package:boxmagic/services/log_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final LogService _logService = LogService();

  final List<Widget> _screens = [
    const BoxesScreen(),
    const ItemsScreen(),
    const UsersScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeLogService();
  }

  Future<void> _initializeLogService() async {
    await _logService.initialize();
    _logService.info('Aplicativo iniciado', category: 'app');
  }

  // Métodos para ações da barra de ferramentas
  void _showBarcodeScanner() {
    if (_selectedIndex == 0) {
      // Implementar scanner de código de barras para caixas
      final boxesScreen = _screens[0] as BoxesScreen;
      boxesScreen.showBarcodeScanner(context);
    }
  }

  void _showBoxIdRecognition() {
    if (_selectedIndex == 0) {
      // Implementar reconhecimento de ID com IA para caixas
      _logService.info('Iniciando reconhecimento de ID de caixa', category: 'recognition');
      final boxesScreen = _screens[0] as BoxesScreen;
      boxesScreen.showBoxIdRecognition(context);
    }
  }

  void _showPrintLabelsDialog() {
    if (_selectedIndex == 0) {
      // Implementar impressão de etiquetas para caixas
      final boxesScreen = _screens[0] as BoxesScreen;
      boxesScreen.showPrintLabelsDialog(context);
    }
  }

  void _showNewBoxDialog() {
    if (_selectedIndex == 0) {
      // Criar nova caixa
      final boxesScreen = _screens[0] as BoxesScreen;
      boxesScreen.showNewBoxDialog(context);
    } else if (_selectedIndex == 1) {
      // Criar nova caixa a partir da tela de objetos
      final itemsScreen = _screens[1] as ItemsScreen;
      itemsScreen.showNewBoxDialog(context);
    }
  }

  void _generateReport() {
    if (_selectedIndex == 1) {
      // Gerar relatório de objetos
      final itemsScreen = _screens[1] as ItemsScreen;
      itemsScreen.generateReport(context);
    }
  }

  void _showObjectRecognition() {
    if (_selectedIndex == 1) {
      // Reconhecimento de objetos com IA
      _logService.info('Iniciando reconhecimento de objeto', category: 'recognition');
      final itemsScreen = _screens[1] as ItemsScreen;
      itemsScreen.showObjectRecognition(context);
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _openLogs() {
    // Registrar que a tela de logs foi aberta
    _logService.info('Tela de logs aberta pelo usuário', category: 'navigation');

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LogsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BoxMagic'),
        actions: [
          // Botões específicos para a aba de Caixas
          if (_selectedIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _showBarcodeScanner,
              tooltip: 'Escanear código de barras',
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: _showBoxIdRecognition,
              tooltip: 'Reconhecer ID com IA',
            ),
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _showPrintLabelsDialog,
              tooltip: 'Imprimir etiquetas',
            ),
          ],

          // Botões específicos para a aba de Objetos
          if (_selectedIndex == 1) ...[
            IconButton(
              icon: const Icon(Icons.add_box),
              onPressed: _showNewBoxDialog,
              tooltip: 'Criar nova caixa',
            ),
            IconButton(
              icon: const Icon(Icons.summarize),
              onPressed: _generateReport,
              tooltip: 'Gerar relatório',
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: _showObjectRecognition,
              tooltip: 'Identificar objeto com IA',
            ),
          ],

          // Botão de logs (sempre visível)
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _openLogs,
            tooltip: 'Logs do sistema',
          ),

          // Botão de configurações (sempre visível)
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Configurações',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox),
            label: 'Caixas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Objetos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Usuários',
          ),
        ],
      ),
    );
  }
}
