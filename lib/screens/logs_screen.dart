import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:boxmagic/services/log_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class LogsScreen extends StatefulWidget {
  const LogsScreen({Key? key}) : super(key: key);

  @override
  _LogsScreenState createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final LogService _logService = LogService();
  List<LogEntry> _logs = [];
  LogLevel? _selectedLevel;
  String? _selectedCategory;
  List<String> _categories = [];
  bool _isExporting = false;
  bool _isAutoRefresh = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
    
    // Adicionar um log para teste
    _logService.debug('Tela de logs aberta', category: 'ui');
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadLogs() {
    setState(() {
      _logs = _logService.getLogs();
      
      // Extrair categorias únicas
      final categories = <String>{};
      for (final log in _logs) {
        if (log.category != null) {
          categories.add(log.category!);
        }
      }
      _categories = categories.toList()..sort();
    });
  }

  void _filterLogs() {
    setState(() {
      if (_selectedLevel != null && _selectedCategory != null) {
        _logs = _logService.getLogs().where((log) => 
          log.level == _selectedLevel && log.category == _selectedCategory
        ).toList();
      } else if (_selectedLevel != null) {
        _logs = _logService.getLogsByLevel(_selectedLevel!);
      } else if (_selectedCategory != null) {
        _logs = _logService.getLogsByCategory(_selectedCategory!);
      } else {
        _logs = _logService.getLogs();
      }
    });
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Logs'),
        content: const Text('Tem certeza que deseja limpar todos os logs? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _logService.clearLogs();
      _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logs limpos com sucesso')),
        );
      }
    }
  }

  Future<void> _exportLogs() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final path = await _logService.exportLogs();
      
      if (path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não há logs para exportar')),
          );
        }
        return;
      }

      if (kIsWeb) {
        // No ambiente web, copiamos para a área de transferência
        await Clipboard.setData(ClipboardData(text: path));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logs copiados para a área de transferência')),
          );
        }
      } else {
        // Em dispositivos móveis, compartilhamos o arquivo
        await Share.shareXFiles(
          [XFile(path)],
          subject: 'BoxMagic Logs',
          text: 'Logs do aplicativo BoxMagic',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar logs: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  void _toggleAutoRefresh() {
    setState(() {
      _isAutoRefresh = !_isAutoRefresh;
    });
    
    if (_isAutoRefresh) {
      // Configurar um timer para atualizar os logs periodicamente
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isAutoRefresh) {
          _loadLogs();
          _toggleAutoRefresh(); // Recursivo para continuar atualizando
        }
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.debug:
        return Colors.grey;
    }
  }

  IconData _getLogIcon(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Icons.info_outline;
      case LogLevel.warning:
        return Icons.warning_amber_outlined;
      case LogLevel.error:
        return Icons.error_outline;
      case LogLevel.debug:
        return Icons.bug_report_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs do Sistema'),
        actions: [
          IconButton(
            icon: Icon(_isAutoRefresh ? Icons.sync_disabled : Icons.sync),
            onPressed: _toggleAutoRefresh,
            tooltip: _isAutoRefresh ? 'Desativar atualização automática' : 'Ativar atualização automática',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Atualizar',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
            tooltip: 'Limpar logs',
          ),
          IconButton(
            icon: _isExporting 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Icon(Icons.share),
            onPressed: _isExporting ? null : _exportLogs,
            tooltip: 'Exportar logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtros',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<LogLevel>(
                            decoration: const InputDecoration(
                              labelText: 'Nível',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            value: _selectedLevel,
                            items: [
                              const DropdownMenuItem<LogLevel>(
                                value: null,
                                child: Text('Todos'),
                              ),
                              ...LogLevel.values.map((level) => DropdownMenuItem<LogLevel>(
                                value: level,
                                child: Text(level.toString().split('.').last.toUpperCase()),
                              )).toList(),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedLevel = value;
                              });
                              _filterLogs();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Categoria',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            value: _selectedCategory,
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Todas'),
                              ),
                              ..._categories.map((category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              )).toList(),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value;
                              });
                              _filterLogs();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Lista de logs
          Expanded(
            child: _logs.isEmpty
                ? const Center(
                    child: Text('Nenhum log encontrado'),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[_logs.length - 1 - index]; // Mostrar mais recentes primeiro
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ExpansionTile(
                          leading: Icon(
                            _getLogIcon(log.level),
                            color: _getLogColor(log.level),
                          ),
                          title: Text(
                            log.message.split('\n').first, // Mostrar apenas a primeira linha
                            style: TextStyle(
                              color: _getLogColor(log.level),
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${log.timestamp.substring(0, 19)} ${log.category != null ? '• ${log.category}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mensagem:',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: SelectableText(log.message),
                                  ),
                                  if (log.stackTrace != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Stack Trace:',
                                      style: Theme.of(context).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      width: double.infinity,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: SelectableText(
                                          log.stackTrace!,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.copy),
                                        label: const Text('Copiar'),
                                        onPressed: () {
                                          final text = log.stackTrace != null
                                              ? '${log.message}\n\n${log.stackTrace}'
                                              : log.message;
                                          Clipboard.setData(ClipboardData(text: text));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Copiado para a área de transferência')),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scrollToBottom,
        tooltip: 'Ir para o final',
        child: const Icon(Icons.arrow_downward),
      ),
    );
  }
}
