import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RestoreApp());
}

class RestoreApp extends StatelessWidget {
  const RestoreApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BoxMagic Restore',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const RestoreScreen(),
    );
  }
}

class RestoreScreen extends StatefulWidget {
  const RestoreScreen({Key? key}) : super(key: key);

  @override
  _RestoreScreenState createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  bool _isRestoring = false;
  String _status = 'Pronto para restaurar dados';
  
  Future<void> _restoreData() async {
    setState(() {
      _isRestoring = true;
      _status = 'Restaurando dados...';
    });
    
    try {
      // Dados de backup
      final boxesJson = [
        '{"id":1745722837461,"name":"ITENS Diversos","category":"DIVERSOS","description":null,"image":null,"createdAt":"2025-04-27T00:00:37.458","updatedAt":null,"barcodeDataUrl":null}'
      ];
      
      final itemsJson = [
        '{"id":1745722868425,"name":"Controle Remoto","category":"DIVERSOS","description":null,"image":null,"boxId":1745722837461,"createdAt":"2025-04-27T00:01:08.400","updatedAt":null}',
        '{"id":1745722927997,"name":"Alicate de unha","category":"DIVERSOS","description":null,"image":null,"boxId":1745722837461,"createdAt":"2025-04-27T00:02:07.969","updatedAt":null}'
      ];
      
      // Salvar no SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('boxmagic_boxes_persistent', boxesJson);
      await prefs.setStringList('boxmagic_items_persistent', itemsJson);
      await prefs.setString('boxmagic_last_sync', DateTime.now().toIso8601String());
      
      // Mostrar todas as chaves
      final keys = prefs.getKeys();
      String keysInfo = '===== CHAVES ARMAZENADAS =====\n';
      for (final key in keys) {
        keysInfo += 'Chave: $key\n';
      }
      keysInfo += '==============================';
      
      setState(() {
        _status = 'Backup restaurado com sucesso!\n\nCaixas: ${boxesJson.length}\nItens: ${itemsJson.length}\n\n$keysInfo';
      });
    } catch (e) {
      setState(() {
        _status = 'Erro ao restaurar backup: $e';
      });
    } finally {
      setState(() {
        _isRestoring = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BoxMagic - Restauração de Backup'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Restauração de Backup',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_status),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isRestoring ? null : _restoreData,
                child: _isRestoring
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Restaurar Dados'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
