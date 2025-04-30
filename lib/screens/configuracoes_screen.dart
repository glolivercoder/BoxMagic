import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _caixaPadraoController = TextEditingController(text: 'Itens Diversos');
  final _categoriaPadraoController = TextEditingController(text: 'Diversos');

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
  }

  Future<void> _carregarConfiguracoes() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKeyController.text = prefs.getString('gemini_api_key') ?? 'AIzaSyA...'; // Chave padrão do repo
    _caixaPadraoController.text = prefs.getString('caixa_padrao') ?? 'Itens Diversos';
    _categoriaPadraoController.text = prefs.getString('categoria_padrao') ?? 'Diversos';
    setState(() {});
  }

  Future<void> _salvarConfiguracoes() async {
    if (_formKey.currentState?.validate() ?? false) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gemini_api_key', _apiKeyController.text.trim());
      await prefs.setString('caixa_padrao', _caixaPadraoController.text.trim());
      await prefs.setString('categoria_padrao', _categoriaPadraoController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configurações salvas!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Chave da API Gemini',
                  helperText: 'Configure sua chave de API do Google Gemini',
                ),
                validator: (v) => v == null || v.isEmpty ? 'Informe a chave da API' : null,
                autocorrect: false,
                enableSuggestions: false,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _caixaPadraoController,
                decoration: const InputDecoration(
                  labelText: 'Caixa padrão',
                  helperText: 'Nome da caixa padrão para novos itens',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoriaPadraoController,
                decoration: const InputDecoration(
                  labelText: 'Categoria padrão',
                  helperText: 'Categoria padrão para novos itens',
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Salvar Configurações'),
                onPressed: _salvarConfiguracoes,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
