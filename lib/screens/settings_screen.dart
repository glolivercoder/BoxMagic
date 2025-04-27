import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/services/persistence_service.dart';
import 'package:boxmagic/services/preferences_service.dart';
import 'package:boxmagic/services/log_service.dart';
import 'package:boxmagic/services/gemini_service.dart';
import 'package:boxmagic/screens/logs_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final PersistenceService _persistenceService = PersistenceService();
  final PreferencesService _preferencesService = PreferencesService();
  final LogService _logService = LogService();
  final GeminiService _geminiService = GeminiService();

  bool _isDarkMode = false;
  String _labelSize = 'correios';
  bool _isLoading = false;
  String _lastBackupDate = 'Nunca';
  String _backupDirectoryPath = 'Carregando...';
  int _logCount = 0;
  bool _isLoggingEnabled = true;

  // Variáveis para a API Gemini
  String _geminiApiKey = '';
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isApiKeyVisible = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkLastBackup();
    _loadLoggingState();
    _countLogs();
    _loadBackupDirectoryPath();
    _loadGeminiApiKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadGeminiApiKey() async {
    try {
      final apiKey = await _geminiService.getApiKey();
      setState(() {
        _geminiApiKey = apiKey;
        _apiKeyController.text = apiKey;
      });
    } catch (e) {
      _logService.error('Erro ao carregar chave da API Gemini', error: e, category: 'settings');
    }
  }

  Future<void> _saveGeminiApiKey() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiKey = _apiKeyController.text.trim();
      final success = await _geminiService.updateApiKey(apiKey);

      if (success) {
        setState(() {
          _geminiApiKey = apiKey;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chave da API Gemini atualizada com sucesso'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao atualizar chave da API Gemini'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _logService.error('Erro ao salvar chave da API Gemini', error: e, category: 'settings');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar chave da API: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBackupDirectoryPath() async {
    try {
      final path = await _persistenceService.getBackupDirectoryPath();
      setState(() {
        _backupDirectoryPath = path;
      });
    } catch (e) {
      setState(() {
        _backupDirectoryPath = 'Erro ao carregar caminho';
      });
    }
  }

  Future<void> _loadLoggingState() async {
    setState(() {
      _isLoggingEnabled = _logService.isLoggingEnabled();
    });
  }

  Future<void> _countLogs() async {
    final logs = _logService.getLogs();
    setState(() {
      _logCount = logs.length;
    });
  }

  Future<void> _loadSettings() async {
    final theme = await _preferencesService.getTheme();
    final labelSize = await _preferencesService.getLabelSize();

    setState(() {
      _isDarkMode = theme == 'dark';
      _labelSize = labelSize;
    });
  }

  Future<void> _checkLastBackup() async {
    final lastBackupTime = await _persistenceService.getLastSyncTime();

    setState(() {
      if (lastBackupTime != null) {
        _lastBackupDate = '${lastBackupTime.day}/${lastBackupTime.month}/${lastBackupTime.year} às ${lastBackupTime.hour}:${lastBackupTime.minute.toString().padLeft(2, '0')}';
      } else {
        _lastBackupDate = 'Nunca';
      }
    });
  }

  Future<void> _toggleTheme() async {
    final newTheme = _isDarkMode ? 'light' : 'dark';
    await _preferencesService.saveTheme(newTheme);

    setState(() {
      _isDarkMode = !_isDarkMode;
    });

    // Notificar a mudança de tema
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tema alterado para ${_isDarkMode ? 'escuro' : 'claro'}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Método para ativar/desativar o logging
  Future<void> _toggleLogging(bool value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _logService.setLoggingEnabled(value);

      if (success) {
        setState(() {
          _isLoggingEnabled = value;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logs ${value ? 'ativados' : 'desativados'}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao alterar configuração de logs'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });

      // Atualizar a contagem de logs
      _countLogs();
    }
  }

  Future<void> _changeLabelSize(String size) async {
    await _preferencesService.saveLabelSize(size);

    setState(() {
      _labelSize = size;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tamanho de etiqueta alterado para $size'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _createBackup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Carregar todos os dados
      final boxes = await _databaseHelper.readAllBoxes();
      final items = await _databaseHelper.readAllItems();
      final users = await _databaseHelper.readAllUsers();

      // Usar o serviço de persistência para criar o backup
      final backupPath = await _persistenceService.createBackupFile(boxes, items, users);

      if (backupPath != null) {
        if (kIsWeb) {
          // No web, o backupPath contém o JSON com um prefixo especial
          if (backupPath.startsWith('BOXMAGIC_BACKUP_JSON:')) {
            // Extrair o JSON
            final jsonData = backupPath.substring('BOXMAGIC_BACKUP_JSON:'.length);

            // Criar um arquivo para download
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final fileName = 'boxmagic_backup_$timestamp.json';

            // Criar um blob com o JSON
            final blob = html.Blob([jsonData], 'application/json');

            // Criar um link para download
            final url = html.Url.createObjectUrlFromBlob(blob);
            final anchor = html.AnchorElement(href: url)
              ..setAttribute('download', fileName)
              ..style.display = 'none';

            // Adicionar o link ao documento
            html.document.body?.append(anchor);

            // Clicar no link para iniciar o download
            anchor.click();

            // Remover o link
            html.Url.revokeObjectUrl(url);
            anchor.remove();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Backup salvo como: $fileName'),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } else {
            // Fallback para o comportamento anterior
            await Clipboard.setData(ClipboardData(text: backupPath));

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Backup copiado para a área de transferência'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        } else {
          // Em dispositivos nativos, mostrar mensagem de sucesso
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Backup salvo em: $backupPath'),
                duration: const Duration(seconds: 5),
              ),
            );
          }

          // Atualizar o caminho do diretório de backup
          await _loadBackupDirectoryPath();
        }

        // Registrar no log
        _logService.info('Backup criado com sucesso', category: 'settings');
      } else {
        throw Exception('Falha ao criar arquivo de backup');
      }

      // Atualizar data do último backup
      await _checkLastBackup();

    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao criar backup',
        error: e,
        stackTrace: stackTrace,
        category: 'settings',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar backup: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreBackup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (kIsWeb) {
        // No web, permitir que o usuário selecione um arquivo
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );

        if (result == null || result.files.isEmpty) {
          return;
        }

        // Ler o conteúdo do arquivo
        final file = result.files.first;
        final backupJson = file.bytes != null
            ? utf8.decode(file.bytes!)
            : null;

        if (backupJson == null || backupJson.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Não foi possível ler o arquivo de backup'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // Usar o serviço de persistência para restaurar o backup
        final success = await _persistenceService.restoreFromBackupJson(backupJson);

        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Backup restaurado com sucesso!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
          _logService.info('Backup restaurado com sucesso do arquivo', category: 'settings');
        } else {
          throw Exception('Falha ao restaurar backup');
        }
      } else {
        // Em dispositivos móveis, mostrar opções: selecionar arquivo ou usar backup local
        final choice = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restaurar Backup'),
            content: const Text('De onde você deseja restaurar o backup?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'file'),
                child: const Text('Selecionar arquivo'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'local'),
                child: const Text('Usar backup local'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );

        if (choice == null) {
          return;
        }

        if (choice == 'file') {
          // Selecionar arquivo
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['json'],
          );

          if (result == null || result.files.isEmpty) {
            return;
          }

          final filePath = result.files.single.path!;

          // Usar o serviço de persistência para restaurar o backup
          final success = await _persistenceService.restoreFromBackupFile(filePath);

          if (success) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Backup restaurado com sucesso!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            _logService.info('Backup restaurado com sucesso do arquivo: $filePath', category: 'settings');
          } else {
            throw Exception('Falha ao restaurar backup do arquivo');
          }
        } else if (choice == 'local') {
          // Mostrar lista de backups locais
          final backups = await _persistenceService.listBackups();

          if (backups.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Nenhum backup local encontrado'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            return;
          }

          // Mostrar diálogo para selecionar backup
          final selectedBackup = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Selecionar Backup'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  itemCount: backups.length,
                  itemBuilder: (context, index) {
                    final backup = backups[index];
                    final timestamp = DateTime.parse(backup['timestamp'] as String);
                    final formattedDate = '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';

                    return ListTile(
                      title: Text('Backup de $formattedDate'),
                      subtitle: Text('Caixas: ${backup['boxes']}, Objetos: ${backup['items']}'),
                      onTap: () => Navigator.pop(context, backup),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          );

          if (selectedBackup == null) {
            return;
          }

          // Restaurar o backup selecionado
          final filePath = selectedBackup['path'] as String;
          final success = await _persistenceService.restoreFromBackupFile(filePath);

          if (success) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Backup restaurado com sucesso!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            _logService.info('Backup restaurado com sucesso do arquivo local: $filePath', category: 'settings');
          } else {
            throw Exception('Falha ao restaurar backup local');
          }
        }
      }
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao restaurar backup',
        error: e,
        stackTrace: stackTrace,
        category: 'settings',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao restaurar backup: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }



  Future<void> _clearAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar todos os dados'),
        content: const Text(
          'Esta ação excluirá permanentemente todas as caixas e objetos. Esta ação não pode ser desfeita. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar dados'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _databaseHelper.clearAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todos os dados foram excluídos'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao limpar dados: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Seção de aparência
                const _SectionHeader(title: 'Aparência'),
                SwitchListTile(
                  title: const Text('Tema escuro'),
                  subtitle: Text(_isDarkMode ? 'Ativado' : 'Desativado'),
                  value: _isDarkMode,
                  onChanged: (value) => _toggleTheme(),
                  secondary: Icon(
                    _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: _isDarkMode ? Colors.amber : Colors.blueGrey,
                  ),
                ),

                // Seção de etiquetas
                const _SectionHeader(title: 'Etiquetas'),
                RadioListTile<String>(
                  title: const Text('Correios'),
                  subtitle: const Text('Tamanho padrão para etiquetas dos Correios'),
                  value: 'correios',
                  groupValue: _labelSize,
                  onChanged: (value) => _changeLabelSize(value!),
                ),
                RadioListTile<String>(
                  title: const Text('A4'),
                  subtitle: const Text('Etiquetas em folha A4'),
                  value: 'a4',
                  groupValue: _labelSize,
                  onChanged: (value) => _changeLabelSize(value!),
                ),
                RadioListTile<String>(
                  title: const Text('Pequena'),
                  subtitle: const Text('Etiquetas pequenas'),
                  value: 'small',
                  groupValue: _labelSize,
                  onChanged: (value) => _changeLabelSize(value!),
                ),

                // Seção de backup
                const _SectionHeader(title: 'Backup e Restauração'),
                ListTile(
                  title: const Text('Último backup'),
                  subtitle: Text(_lastBackupDate),
                  leading: const Icon(Icons.history),
                ),
                ListTile(
                  title: const Text('Diretório de backup'),
                  subtitle: Text(_backupDirectoryPath),
                  leading: const Icon(Icons.folder),
                  isThreeLine: true,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: _createBackup,
                    icon: const Icon(Icons.backup),
                    label: const Text('Criar backup'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: OutlinedButton.icon(
                    onPressed: _restoreBackup,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restaurar backup'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),

                // Seção de logs
                const _SectionHeader(title: 'Logs do Sistema'),
                SwitchListTile(
                  title: const Text('Ativar logs'),
                  subtitle: Text(_isLoggingEnabled
                    ? 'Ativado - $_logCount logs armazenados'
                    : 'Desativado - Os logs podem ajudar a diagnosticar problemas'),
                  value: _isLoggingEnabled,
                  onChanged: _toggleLogging,
                  secondary: Icon(
                    Icons.bug_report,
                    color: _isLoggingEnabled ? Colors.green : Colors.grey,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LogsScreen()),
                      ).then((_) => _countLogs());
                    },
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Visualizar logs'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),

                // Seção de dados
                const _SectionHeader(title: 'Dados'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: _clearAllData,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Limpar todos os dados'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),

                // Seção de API Gemini
                const _SectionHeader(title: 'API Gemini'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Configure a chave da API Gemini para reconhecimento de imagens e análise de objetos.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _apiKeyController,
                        decoration: InputDecoration(
                          labelText: 'Chave da API Gemini',
                          hintText: 'Insira sua chave da API Gemini',
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isApiKeyVisible ? Icons.visibility_off : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isApiKeyVisible = !_isApiKeyVisible;
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.save),
                                onPressed: _saveGeminiApiKey,
                              ),
                            ],
                          ),
                        ),
                        obscureText: !_isApiKeyVisible,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'A chave padrão é compartilhada e pode ter limitações. Para melhor desempenho, use sua própria chave.',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),

                // Sobre o aplicativo
                const _SectionHeader(title: 'Sobre'),
                const ListTile(
                  title: Text('BoxMagic'),
                  subtitle: Text('Versão 1.0.0'),
                  leading: Icon(Icons.info_outline),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({
    Key? key,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
