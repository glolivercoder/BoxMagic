import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ReportScreen extends StatefulWidget {
  final List<Box> boxes;
  final List<Item> items;

  const ReportScreen({
    Key? key,
    required this.boxes,
    required this.items,
  }) : super(key: key);

  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();
  String _reportFormat = 'text'; // 'text' ou 'pdf'
  bool _isGenerating = false;
  String _reportContent = '';

  @override
  void initState() {
    super.initState();
    _generateReportContent();
  }

  void _generateReportContent() {
    final buffer = StringBuffer();
    
    // Cabeçalho do relatório
    buffer.writeln('RELATÓRIO DE CAIXAS E OBJETOS');
    buffer.writeln('Data: ${DateTime.now().toString().substring(0, 16)}');
    buffer.writeln('Total de caixas: ${widget.boxes.length}');
    buffer.writeln('Total de objetos: ${widget.items.length}');
    buffer.writeln('');
    buffer.writeln('='.padRight(50, '='));
    buffer.writeln('');
    
    // Detalhes de cada caixa e seus objetos
    for (final box in widget.boxes) {
      buffer.writeln('CAIXA: ${box.name} (ID: ${box.id})');
      buffer.writeln('Categoria: ${box.category}');
      if (box.description != null && box.description!.isNotEmpty) {
        buffer.writeln('Descrição: ${box.description}');
      }
      buffer.writeln('');
      
      // Listar objetos desta caixa
      final boxItems = widget.items.where((item) => item.boxId == box.id).toList();
      if (boxItems.isEmpty) {
        buffer.writeln('Nenhum objeto nesta caixa.');
      } else {
        buffer.writeln('OBJETOS (${boxItems.length}):');
        for (int i = 0; i < boxItems.length; i++) {
          final item = boxItems[i];
          buffer.writeln('${i + 1}. ${item.name}');
          if (item.category != null && item.category!.isNotEmpty) {
            buffer.writeln('   Categoria: ${item.category}');
          }
          if (item.description != null && item.description!.isNotEmpty) {
            buffer.writeln('   Descrição: ${item.description}');
          }
        }
      }
      
      buffer.writeln('');
      buffer.writeln('-'.padRight(50, '-'));
      buffer.writeln('');
    }
    
    setState(() {
      _reportContent = buffer.toString();
    });
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _reportContent));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Relatório copiado para a área de transferência'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _shareViaEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, insira um endereço de e-mail'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final subject = 'Relatório BoxMagic - ${DateTime.now().toString().substring(0, 10)}';
    final body = _reportContent;
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o cliente de e-mail'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareViaWhatsApp() async {
    final whatsapp = _whatsappController.text.trim();
    if (whatsapp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, insira um número de WhatsApp'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Formatar número do WhatsApp (remover caracteres não numéricos)
    final formattedNumber = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Criar URL do WhatsApp
    final text = Uri.encodeComponent(_reportContent);
    final url = 'https://wa.me/$formattedNumber?text=$text';
    
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareReport() async {
    if (kIsWeb) {
      // No web, apenas copiar para a área de transferência
      await _copyToClipboard();
      return;
    }
    
    try {
      // Criar arquivo temporário
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/boxmagic_report.txt');
      await file.writeAsString(_reportContent);
      
      // Compartilhar arquivo
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Relatório BoxMagic',
        subject: 'Relatório BoxMagic - ${DateTime.now().toString().substring(0, 10)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao compartilhar relatório: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyToClipboard,
            tooltip: 'Copiar para área de transferência',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareReport,
            tooltip: 'Compartilhar',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Opções de compartilhamento
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Compartilhar relatório',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // E-mail
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          hintText: 'exemplo@email.com',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _shareViaEmail,
                        icon: const Icon(Icons.send),
                        label: const Text('Enviar por e-mail'),
                      ),
                      
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      // WhatsApp
                      TextFormField(
                        controller: _whatsappController,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp',
                          hintText: '+55 11 98765-4321',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _shareViaWhatsApp,
                        icon: const Icon(Icons.message),
                        label: const Text('Enviar por WhatsApp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Visualização do relatório
            const Text(
              'Visualização do relatório',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _reportContent,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }
}
