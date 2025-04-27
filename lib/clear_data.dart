import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ClearDataApp());
}

class ClearDataApp extends StatelessWidget {
  const ClearDataApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BoxMagic Clear Data',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ClearDataScreen(),
    );
  }
}

class ClearDataScreen extends StatefulWidget {
  const ClearDataScreen({Key? key}) : super(key: key);

  @override
  _ClearDataScreenState createState() => _ClearDataScreenState();
}

class _ClearDataScreenState extends State<ClearDataScreen> {
  bool _isClearing = false;
  String _status = 'Pronto para limpar dados';
  
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
      _status = 'Dados atuais:\nCaixas: ${boxesJson.length}\nItens: ${itemsJson.length}\n\nPronto para limpar.';
    });
  }
  
  Future<void> _clearData() async {
    setState(() {
      _isClearing = true;
      _status = 'Limpando dados...';
    });
    
    try {
      // Limpar dados
      final prefs = await SharedPreferences.getInstance();
      
      // Salvar o valor de next_id para garantir que os IDs sejam sequenciais
      final nextId = prefs.getInt('boxmagic_next_id') ?? 1001;
      
      // Limpar todos os dados
      await prefs.remove('boxmagic_boxes_persistent');
      await prefs.remove('boxmagic_items_persistent');
      await prefs.remove('boxmagic_last_sync');
      
      // Restaurar o next_id
      await prefs.setInt('boxmagic_next_id', nextId);
      
      // Verificar se os dados foram limpos
      final boxesJson = prefs.getStringList('boxmagic_boxes_persistent') ?? [];
      final itemsJson = prefs.getStringList('boxmagic_items_persistent') ?? [];
      
      setState(() {
        _status = 'Dados limpos com sucesso!\n\n'
            'Caixas: ${boxesJson.length}\n'
            'Itens: ${itemsJson.length}\n\n'
            'Você pode fechar esta janela e abrir o aplicativo principal para criar novas caixas.';
      });
    } catch (e) {
      setState(() {
        _status = 'Erro ao limpar dados: $e';
      });
    } finally {
      setState(() {
        _isClearing = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BoxMagic - Limpar Dados'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Limpar Dados do Aplicativo',
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
                onPressed: _isClearing ? null : _clearData,
                child: _isClearing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('LIMPAR DADOS AGORA'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ATENÇÃO: Esta ação removerá todas as caixas e itens!',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
