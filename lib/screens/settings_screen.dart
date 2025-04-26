import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/models/user.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/services/persistence_service.dart';
import 'package:boxmagic/services/preferences_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final PersistenceService _persistenceService = PersistenceService();
  final PreferencesService _preferencesService = PreferencesService();
  
  bool _isDarkMode = false;
  String _labelSize = 'correios';
  bool _isLoading = false;
  String _lastBackupDate = 'Nunca';
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkLastBackup();
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
      
      // Criar objeto de backup
      final backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0.0',
        'boxes': boxes.map((box) => box.toMap()).toList(),
        'items': items.map((item) => item.toMap()).toList(),
        'users': users.map((user) => user.toMap()).toList(),
      };
      
      // Converter para JSON
      final backupJson = jsonEncode(backupData);
      
      if (kIsWeb) {
        // No web, copiar para a área de transferência
        await Clipboard.setData(ClipboardData(text: backupJson));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup copiado para a área de transferência'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Em dispositivos móveis, salvar como arquivo
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'boxmagic_backup_${DateTime.now().millisecondsSinceEpoch}.json';
        final file = File('${directory.path}/$fileName');
        
        await file.writeAsString(backupJson);
        
        // Compartilhar o arquivo
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Backup BoxMagic',
          subject: 'Backup BoxMagic - ${DateTime.now().toString().substring(0, 10)}',
        );
      }
      
      // Atualizar data do último backup
      await _checkLastBackup();
      
    } catch (e) {
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
    if (kIsWeb) {
      // No web, solicitar texto da área de transferência
      final clipboardData = await Clipboard.getData('text/plain');
      final backupJson = clipboardData?.text;
      
      if (backupJson == null || backupJson.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhum backup encontrado na área de transferência'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      _processBackupData(backupJson);
    } else {
      // Em dispositivos móveis, selecionar arquivo
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        
        if (result == null || result.files.isEmpty) {
          return;
        }
        
        final file = File(result.files.single.path!);
        final backupJson = await file.readAsString();
        
        _processBackupData(backupJson);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao restaurar backup: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }
  
  Future<void> _processBackupData(String backupJson) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Decodificar JSON
      final backupData = jsonDecode(backupJson) as Map<String, dynamic>;
      
      // Verificar versão
      final version = backupData['version'];
      if (version != '1.0.0') {
        throw Exception('Versão de backup incompatível: $version');
      }
      
      // Confirmar restauração
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restaurar backup'),
          content: const Text(
            'Esta ação substituirá todos os dados atuais. Deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restaurar'),
            ),
          ],
        ),
      );
      
      if (confirm != true) {
        return;
      }
      
      // Limpar dados atuais
      await _databaseHelper.clearAllData();
      
      // Restaurar caixas
      final boxesData = backupData['boxes'] as List;
      for (final boxData in boxesData) {
        final box = Box.fromMap(boxData as Map<String, dynamic>);
        await _databaseHelper.createBox(box);
      }
      
      // Restaurar itens
      final itemsData = backupData['items'] as List;
      for (final itemData in itemsData) {
        final item = Item.fromMap(itemData as Map<String, dynamic>);
        await _databaseHelper.createItem(item);
      }
      
      // Restaurar usuários
      final usersData = backupData['users'] as List;
      for (final userData in usersData) {
        final user = User.fromMap(userData as Map<String, dynamic>);
        await _databaseHelper.createUser(user);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup restaurado com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao processar backup: $e'),
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
