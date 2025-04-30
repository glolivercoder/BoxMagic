import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/models/user.dart';
import 'package:boxmagic/services/log_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

class PersistenceService {
  static final PersistenceService _instance = PersistenceService._internal();
  factory PersistenceService() => _instance;

  final LogService _logService = LogService();

  PersistenceService._internal();

  // Chaves para armazenamento
  static const String _boxesKey = 'boxmagic_boxes_persistent';
  static const String _itemsKey = 'boxmagic_items_persistent';
  static const String _usersKey = 'boxmagic_users_persistent';
  static const String _lastSyncKey = 'boxmagic_last_sync';
  static const String _backupDirPrefKey = 'backup_directory_path';

  // Pasta de backups - pasta fixa na raiz do projeto
  static const String _backupFolderName = 'backups';

  // Pasta de backup fixa para facilitar a localização
  static const String _fixedBackupPath = 'G:/Projetos2025BKP/BoxMagicFlutter/boxmagic/backups';

  // Método para obter o diretório de backup
  Future<Directory> _getBackupDirectory() async {
    Directory backupDir;

    if (kIsWeb) {
      // No ambiente web, não podemos acessar o sistema de arquivos diretamente
      // Retornamos um diretório temporário que não será usado
      _logService.warning('Ambiente web detectado, backups serão armazenados em memória', category: 'backup');
      backupDir = Directory('web_backup_dir');
      return backupDir;
    }

    // Verificar se existe um diretório personalizado salvo nas preferências
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString(_backupDirPrefKey);

    if (customPath != null && customPath.isNotEmpty) {
      // Usar o diretório personalizado
      backupDir = Directory(customPath);
      _logService.info('Usando diretório de backup personalizado: ${backupDir.path}', category: 'backup');
    } else {
      // Usar o diretório padrão para Android
      final defaultPath = await getDefaultBackupPath();
      backupDir = Directory(defaultPath);
      _logService.info('Usando diretório de backup padrão: ${backupDir.path}', category: 'backup');
    }

    // Criar diretório de backup se não existir
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
      _logService.info('Diretório de backup criado: ${backupDir.path}', category: 'backup');
    }

    return backupDir;
  }

  // Salvar dados
  Future<void> saveAllData({
    required List<Box> boxes,
    required List<Item> items,
    required List<User> users,
  }) async {
    try {
      _logService.info('Iniciando salvamento de dados', category: 'persistence');
      final prefs = await SharedPreferences.getInstance();

      // Converter objetos para JSON
      final boxesJson = boxes.map((box) => jsonEncode(box.toMap())).toList();
      final itemsJson = items.map((item) => jsonEncode(item.toMap())).toList();
      final usersJson = users.map((user) => jsonEncode(user.toMap())).toList();

      // Salvar no SharedPreferences
      await prefs.setStringList(_boxesKey, boxesJson);
      await prefs.setStringList(_itemsKey, itemsJson);
      await prefs.setStringList(_usersKey, usersJson);

      // Registrar horário da sincronização
      final now = DateTime.now();
      await prefs.setString(_lastSyncKey, now.toIso8601String());

      // Registrar no log
      _logService.info(
        'Dados salvos com sucesso! Boxes: ${boxes.length}, Items: ${items.length}, Users: ${users.length}',
        category: 'persistence',
      );

      // Criar backup automático
      try {
        _logService.info('Criando backup automático após salvamento de dados', category: 'persistence');
        final backupPath = await createBackupFile(boxes, items, users, now);
        if (backupPath != null) {
          _logService.info('Backup automático criado com sucesso: $backupPath', category: 'persistence');

          // Salvar o caminho do último backup
          if (!kIsWeb) {
            await prefs.setString('last_backup_path', backupPath);
            _logService.debug('Caminho do último backup salvo: $backupPath', category: 'persistence');
          }
        }
      } catch (e) {
        _logService.error(
          'Erro ao criar backup automático',
          error: e,
          category: 'persistence',
        );
      }
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao salvar dados',
        error: e,
        stackTrace: stackTrace,
        category: 'persistence',
      );
    }
  }

  // Criar arquivo de backup
  Future<String?> createBackupFile(
    List<Box> boxes,
    List<Item> items,
    List<User> users,
    [DateTime? timestamp]
  ) async {
    try {
      timestamp ??= DateTime.now();

      // Criar objeto de backup
      final backupData = {
        'timestamp': timestamp.toIso8601String(),
        'version': '1.0.0',
        'boxes': boxes.map((box) => box.toMap()).toList(),
        'items': items.map((item) => item.toMap()).toList(),
        'users': users.map((user) => user.toMap()).toList(),
      };

      // Converter para JSON
      final backupJson = jsonEncode(backupData);

      if (kIsWeb) {
        // No ambiente web, retornamos o JSON com um prefixo especial para indicar que é um backup
        _logService.info('Backup criado em memória (ambiente web)', category: 'backup');
        return 'BOXMAGIC_BACKUP_JSON:$backupJson';
      } else {
        // Em dispositivos nativos, salvamos em arquivo
        final fileName = 'boxmagic_backup_${timestamp.millisecondsSinceEpoch}.json';

        // Obter o diretório de backup
        final backupDir = await _getBackupDirectory();

        // Criar arquivo de backup
        final file = File('${backupDir.path}/$fileName');
        await file.writeAsString(backupJson);

        _logService.info('Backup criado em: ${file.path}', category: 'backup');
        return file.path;
      }
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao criar arquivo de backup',
        error: e,
        stackTrace: stackTrace,
        category: 'backup',
      );
      return null;
    }
  }

  // Carregar dados
  Future<Map<String, dynamic>> loadAllData() async {
    try {
      _logService.info('Iniciando carregamento de dados', category: 'persistence');
      final prefs = await SharedPreferences.getInstance();

      // Obter dados do SharedPreferences
      final boxesJson = prefs.getStringList(_boxesKey) ?? [];
      final itemsJson = prefs.getStringList(_itemsKey) ?? [];
      final usersJson = prefs.getStringList(_usersKey) ?? [];

      // Converter JSON para objetos
      final boxes = boxesJson.map((json) => Box.fromMap(jsonDecode(json))).toList();
      final items = itemsJson.map((json) => Item.fromMap(jsonDecode(json))).toList();
      final users = usersJson.map((json) => User.fromMap(jsonDecode(json))).toList();

      _logService.info(
        'Dados carregados com sucesso! Boxes: ${boxes.length}, Items: ${items.length}, Users: ${users.length}',
        category: 'persistence',
      );

      // Se não houver caixas, tentar carregar do último backup
      if (boxes.isEmpty) {
        _logService.warning('Nenhuma caixa encontrada no SharedPreferences, tentando carregar do último backup', category: 'persistence');
        final backupData = await loadFromLastBackup();

        if (backupData != null && backupData['boxes'] != null && (backupData['boxes'] as List).isNotEmpty) {
          _logService.info('Dados carregados do último backup com sucesso', category: 'persistence');
          return backupData;
        }
      }

      return {
        'boxes': boxes,
        'items': items,
        'users': users,
      };
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao carregar dados',
        error: e,
        stackTrace: stackTrace,
        category: 'persistence',
      );

      // Tentar carregar do último backup em caso de erro
      _logService.info('Tentando carregar dados do último backup após erro', category: 'persistence');
      final backupData = await loadFromLastBackup();

      if (backupData != null) {
        _logService.info('Dados carregados do último backup após erro', category: 'persistence');
        return backupData;
      }

      // Retornar dados vazios se tudo falhar
      return {
        'boxes': <Box>[],
        'items': <Item>[],
        'users': <User>[],
      };
    }
  }

  // Carregar dados do último backup
  Future<Map<String, dynamic>?> loadFromLastBackup() async {
    try {
      _logService.info('Tentando carregar dados do último backup', category: 'persistence');

      if (kIsWeb) {
        _logService.warning('Carregamento de backup não suportado no ambiente web', category: 'persistence');
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastBackupPath = prefs.getString('last_backup_path');

      if (lastBackupPath == null) {
        _logService.warning('Nenhum caminho de backup encontrado', category: 'persistence');

        // Tentar encontrar o backup mais recente
        final backups = await listBackups();
        if (backups.isNotEmpty) {
          final latestBackup = backups.first; // O primeiro é o mais recente
          _logService.info('Usando o backup mais recente: ${latestBackup['path']}', category: 'persistence');
          return await _loadBackupFromPath(latestBackup['path'] as String);
        }

        return null;
      }

      return await _loadBackupFromPath(lastBackupPath);
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao carregar dados do último backup',
        error: e,
        stackTrace: stackTrace,
        category: 'persistence',
      );
      return null;
    }
  }

  // Método auxiliar para carregar backup de um caminho
  Future<Map<String, dynamic>?> _loadBackupFromPath(String path) async {
    try {
      _logService.debug('Carregando backup do caminho: $path', category: 'persistence');

      final file = File(path);
      if (!await file.exists()) {
        _logService.warning('Arquivo de backup não encontrado: $path', category: 'persistence');
        return null;
      }

      final backupJson = await file.readAsString();
      final backupData = jsonDecode(backupJson) as Map<String, dynamic>;

      // Verificar versão
      final version = backupData['version'];
      if (version != '1.0.0') {
        _logService.error('Versão de backup incompatível: $version', category: 'persistence');
        return null;
      }

      // Extrair dados
      final boxesData = backupData['boxes'] as List;
      final itemsData = backupData['items'] as List;
      final usersData = backupData['users'] as List;

      // Converter para objetos
      final boxes = boxesData.map((data) => Box.fromMap(data as Map<String, dynamic>)).toList();
      final items = itemsData.map((data) => Item.fromMap(data as Map<String, dynamic>)).toList();
      final users = usersData.map((data) => User.fromMap(data as Map<String, dynamic>)).toList();

      _logService.info(
        'Backup carregado com sucesso! Boxes: ${boxes.length}, Items: ${items.length}, Users: ${users.length}',
        category: 'persistence',
      );

      return {
        'boxes': boxes,
        'items': items,
        'users': users,
      };
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao carregar backup do caminho: $path',
        error: e,
        stackTrace: stackTrace,
        category: 'persistence',
      );
      return null;
    }
  }

  // Restaurar dados de um arquivo de backup
  Future<bool> restoreFromBackupFile(String filePath) async {
    try {
      _logService.info('Iniciando restauração de backup: $filePath', category: 'backup');

      // Ler o arquivo
      final file = File(filePath);
      if (!await file.exists()) {
        _logService.error('Arquivo de backup não encontrado: $filePath', category: 'backup');
        return false;
      }

      final backupJson = await file.readAsString();
      return await restoreFromBackupJson(backupJson);
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao restaurar backup do arquivo',
        error: e,
        stackTrace: stackTrace,
        category: 'backup',
      );
      return false;
    }
  }

  // Restaurar dados de um JSON de backup
  Future<bool> restoreFromBackupJson(String backupJson) async {
    try {
      // Decodificar JSON
      final backupData = jsonDecode(backupJson) as Map<String, dynamic>;

      // Verificar versão
      final version = backupData['version'];
      if (version != '1.0.0') {
        _logService.error(
          'Versão de backup incompatível: $version',
          category: 'backup',
        );
        return false;
      }

      // Extrair dados
      final boxesData = backupData['boxes'] as List;
      final itemsData = backupData['items'] as List;
      final usersData = backupData['users'] as List;

      // Converter para objetos
      final boxes = boxesData.map((data) => Box.fromMap(data as Map<String, dynamic>)).toList();
      final items = itemsData.map((data) => Item.fromMap(data as Map<String, dynamic>)).toList();
      final users = usersData.map((data) => User.fromMap(data as Map<String, dynamic>)).toList();

      // Salvar dados
      await saveAllData(boxes: boxes, items: items, users: users);

      _logService.info(
        'Backup restaurado com sucesso! Boxes: ${boxes.length}, Items: ${items.length}, Users: ${users.length}',
        category: 'backup',
      );

      return true;
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao restaurar backup do JSON',
        error: e,
        stackTrace: stackTrace,
        category: 'backup',
      );
      return false;
    }
  }

  // Verificar se há dados salvos
  Future<bool> hasPersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasData = prefs.containsKey(_boxesKey) || prefs.containsKey(_itemsKey);
      _logService.debug('Verificação de dados persistentes: $hasData', category: 'persistence');
      return hasData;
    } catch (e) {
      _logService.error('Erro ao verificar dados persistentes', error: e, category: 'persistence');
      return false;
    }
  }

  // Obter data da última sincronização
  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString(_lastSyncKey);
      if (lastSync != null) {
        final date = DateTime.parse(lastSync);
        _logService.debug('Última sincronização: $date', category: 'persistence');
        return date;
      }
      _logService.debug('Nenhuma sincronização encontrada', category: 'persistence');
      return null;
    } catch (e) {
      _logService.error('Erro ao obter data da última sincronização', error: e, category: 'persistence');
      return null;
    }
  }

  // Limpar todos os dados persistentes
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_boxesKey);
      await prefs.remove(_itemsKey);
      await prefs.remove(_usersKey);
      await prefs.remove(_lastSyncKey);
      _logService.info('Todos os dados persistentes foram removidos', category: 'persistence');
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao limpar dados persistentes',
        error: e,
        stackTrace: stackTrace,
        category: 'persistence',
      );
    }
  }

  // Listar backups disponíveis
  Future<List<Map<String, dynamic>>> listBackups() async {
    try {
      if (kIsWeb) {
        _logService.info('Listagem de backups não disponível no ambiente web', category: 'backup');
        return [];
      }

      // Obter o diretório de backup
      final backupDir = await _getBackupDirectory();

      // Verificar se o diretório existe
      if (!await backupDir.exists()) {
        _logService.info('Diretório de backups não encontrado', category: 'backup');
        return [];
      }

      // Listar arquivos
      final files = await backupDir.list().where((entity) =>
        entity is File && entity.path.endsWith('.json')
      ).toList();

      // Ordenar por data de modificação (mais recente primeiro)
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      // Converter para lista de mapas
      final backups = <Map<String, dynamic>>[];
      for (final file in files) {
        if (file is File) {
          try {
            final fileName = file.path.split(Platform.pathSeparator).last;
            final content = await file.readAsString();
            final data = jsonDecode(content) as Map<String, dynamic>;

            backups.add({
              'path': file.path,
              'name': fileName,
              'timestamp': data['timestamp'] ?? 'Desconhecido',
              'size': file.lengthSync(),
              'boxes': (data['boxes'] as List?)?.length ?? 0,
              'items': (data['items'] as List?)?.length ?? 0,
              'users': (data['users'] as List?)?.length ?? 0,
            });
          } catch (e) {
            _logService.warning(
              'Erro ao processar arquivo de backup: ${file.path}',
              category: 'backup',
            );
          }
        }
      }

      _logService.info('${backups.length} backups encontrados', category: 'backup');
      return backups;
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao listar backups',
        error: e,
        stackTrace: stackTrace,
        category: 'backup',
      );
      return [];
    }
  }

  // Método para obter o caminho do diretório de backup
  Future<String> getBackupDirectoryPath() async {
    if (kIsWeb) {
      return 'Não disponível no ambiente web';
    }

    final backupDir = await _getBackupDirectory();
    return backupDir.path;
  }

  // Método para depuração - mostrar todas as chaves armazenadas
  Future<String> debugShowAllKeys() async {
    final buffer = StringBuffer();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      buffer.writeln('===== CHAVES ARMAZENADAS =====');
      for (final key in keys) {
        buffer.writeln('Chave: $key');
        if (key.contains('boxmagic_boxes')) {
          final boxesJson = prefs.getStringList(key) ?? [];
          buffer.writeln('  Caixas: ${boxesJson.length}');
          for (int i = 0; i < boxesJson.length; i++) {
            final box = Box.fromMap(jsonDecode(boxesJson[i]));
            buffer.writeln('    Caixa $i: ID=${box.id}, Nome=${box.name}');
          }
        } else if (key.contains('boxmagic_items')) {
          final itemsJson = prefs.getStringList(key) ?? [];
          buffer.writeln('  Itens: ${itemsJson.length}');
          for (int i = 0; i < itemsJson.length; i++) {
            final item = Item.fromMap(jsonDecode(itemsJson[i]));
            buffer.writeln('    Item $i: ID=${item.id}, Nome=${item.name}, BoxID=${item.boxId}');
          }
        }
      }
      buffer.writeln('==============================');

      final result = buffer.toString();
      _logService.debug(result, category: 'persistence');
      return result;
    } catch (e, stackTrace) {
      buffer.writeln('Erro ao mostrar chaves: $e');
      buffer.writeln(stackTrace);

      final result = buffer.toString();
      _logService.error(
        'Erro ao mostrar chaves',
        error: e,
        stackTrace: stackTrace,
        category: 'persistence',
      );
      return result;
    }
  }

  // Obter o diretório padrão de backup
  Future<String> getDefaultBackupPath() async {
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        // Solicitar permissão de armazenamento
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            throw Exception('Permissão de armazenamento negada');
          }
        }

        // No Android, usar o diretório de documentos do app
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final backupDir = Directory('${directory.path}/BoxMagic/backups');
          if (!await backupDir.exists()) {
            await backupDir.create(recursive: true);
          }
          return backupDir.path;
        }
      }
      // Em outros sistemas, usar o diretório de documentos
      return (await getApplicationDocumentsDirectory()).path;
    }
    return 'web_storage';
  }

  // Selecionar novo diretório de backup
  Future<String?> selectBackupDirectory() async {
    try {
      if (kIsWeb) {
        return null;
      }

      // No Android, verificar permissões
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            throw Exception('Permissão de armazenamento negada');
          }
        }
      }

      // Abrir seletor de diretório
      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Selecione a pasta para backups',
        initialDirectory: await getBackupDirectoryPath(),
      );

      if (selectedDirectory != null) {
        // Verificar se o diretório é gravável
        final testDir = Directory(selectedDirectory);
        if (!await testDir.exists()) {
          await testDir.create(recursive: true);
        }

        // Salvar o novo caminho
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_backupDirPrefKey, selectedDirectory);

        _logService.info('Novo diretório de backup definido: $selectedDirectory', category: 'persistence');
        return selectedDirectory;
      }
    } catch (e) {
      _logService.error('Erro ao selecionar diretório de backup', error: e, category: 'persistence');
      rethrow;
    }
    return null;
  }
}
