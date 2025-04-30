import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DirectRestoreApp());
}

class DirectRestoreApp extends StatelessWidget {
  const DirectRestoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BoxMagic Direct Restore',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const DirectRestoreScreen(),
    );
  }
}

class DirectRestoreScreen extends StatefulWidget {
  const DirectRestoreScreen({super.key});

  @override
  _DirectRestoreScreenState createState() => _DirectRestoreScreenState();
}

class _DirectRestoreScreenState extends State<DirectRestoreScreen> {
  bool _isRestoring = false;
  String _status = 'Pronto para restaurar dados';
  
  @override
  void initState() {
    super.initState();
    _checkExistingData();
  }
  
  Future<void> _checkExistingData() async {
    final prefs = await SharedPreferences.getInstance();
    final boxesJson = prefs.getStringList('boxmagic_boxes_persistent') ?? [];
    final itemsJson = prefs.getStringList('boxmagic_items_persistent') ?? [];
    
    setState(() {
      _status = 'Dados atuais:\nCaixas: ${boxesJson.length}\nItens: ${itemsJson.length}\n\nPronto para restaurar.';
    });
  }
  
  Future<void> _restoreData() async {
    setState(() {
      _isRestoring = true;
      _status = 'Restaurando dados...';
    });
    
    try {
      // Dados de backup fixos
      final boxesJson = [
        '{"id":1001,"name":"Caixa de Ferramentas","category":"FERRAMENTAS","description":"Ferramentas diversas","image":null,"createdAt":"2025-04-27T12:00:00.000","updatedAt":null,"barcodeDataUrl":null}',
        '{"id":1002,"name":"Caixa de Eletrônicos","category":"ELETRONICOS","description":"Equipamentos eletrônicos","image":null,"createdAt":"2025-04-27T12:30:00.000","updatedAt":null,"barcodeDataUrl":null}'
      ];
      
      final itemsJson = [
        '{"id":2001,"name":"Martelo","category":"FERRAMENTAS","description":"Martelo de carpinteiro","image":null,"boxId":1001,"createdAt":"2025-04-27T12:05:00.000","updatedAt":null}',
        '{"id":2002,"name":"Chave de fenda","category":"FERRAMENTAS","description":"Chave de fenda Phillips","image":null,"boxId":1001,"createdAt":"2025-04-27T12:10:00.000","updatedAt":null}',
        '{"id":2003,"name":"Smartphone","category":"ELETRONICOS","description":"Smartphone antigo","image":null,"boxId":1002,"createdAt":"2025-04-27T12:35:00.000","updatedAt":null}',
        '{"id":2004,"name":"Carregador","category":"ELETRONICOS","description":"Carregador USB","image":null,"boxId":1002,"createdAt":"2025-04-27T12:40:00.000","updatedAt":null}'
      ];
      
      // Salvar no SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      // Limpar dados existentes
      await prefs.remove('boxmagic_boxes_persistent');
      await prefs.remove('boxmagic_items_persistent');
      
      // Salvar novos dados
      await prefs.setStringList('boxmagic_boxes_persistent', boxesJson);
      await prefs.setStringList('boxmagic_items_persistent', itemsJson);
      await prefs.setString('boxmagic_last_sync', DateTime.now().toIso8601String());
      
      // Verificar se os dados foram salvos
      final savedBoxes = prefs.getStringList('boxmagic_boxes_persistent') ?? [];
      final savedItems = prefs.getStringList('boxmagic_items_persistent') ?? [];
      
      setState(() {
        _status = 'Backup restaurado com sucesso!\n\n'
            'Caixas salvas: ${savedBoxes.length}\n'
            'Itens salvos: ${savedItems.length}\n\n'
            'Você pode fechar esta janela e abrir o aplicativo principal para ver os dados restaurados.';
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
        title: const Text('BoxMagic - Restauração Direta'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Restauração Direta de Dados',
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
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: Colors.red,
                ),
                child: _isRestoring
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('RESTAURAR DADOS AGORA'),
              ),
              const SizedBox(height: 20),
              const Text(
                'ATENÇÃO: Esta ação substituirá todos os dados existentes!',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
