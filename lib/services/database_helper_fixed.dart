import 'dart:convert';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/models/user.dart';
import 'package:boxmagic/services/persistence_service.dart';
import 'package:boxmagic/services/log_service.dart';
import 'package:boxmagic/services/preferences_service.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  final PersistenceService _persistenceService = PersistenceService();
  final LogService _logService = LogService();
  final PreferencesService _preferencesService = PreferencesService();

  // Listas em memória para armazenar os dados
  List<Box> _boxes = [];
  List<Item> _items = [];
  List<User> _users = [];
  bool _dataLoaded = false;

  DatabaseHelper._init() {
    // Carregar dados persistentes ao inicializar
    _loadPersistedData();
  }

  // Método para carregar dados persistentes
  Future<void> _loadPersistedData() async {
    if (!_dataLoaded) {
      try {
        _logService.info('Carregando dados persistentes', category: 'database');

        // Carregar dados do serviço de persistência (que agora também tenta carregar do backup)
        final data = await _persistenceService.loadAllData();
        _boxes = data['boxes'] as List<Box>;
        _items = data['items'] as List<Item>;
        _users = data['users'] as List<User>;
        _dataLoaded = true;

        _logService.info(
          'Dados persistentes carregados com sucesso: ${_boxes.length} caixas, ${_items.length} itens, ${_users.length} usuários',
          category: 'database'
        );

        // Log detalhado das caixas carregadas
        if (_boxes.isNotEmpty) {
          for (int i = 0; i < _boxes.length; i++) {
            _logService.debug('Caixa $i: ID=${_boxes[i].id}, Nome=${_boxes[i].name}', category: 'database');
          }
        } else {
          _logService.warning('Nenhuma caixa carregada dos dados persistentes', category: 'database');
        }
      } catch (e, stackTrace) {
        _logService.error(
          'Erro ao carregar dados persistentes',
          error: e,
          stackTrace: stackTrace,
          category: 'database'
        );

        // Inicializar com listas vazias em caso de erro
        _boxes = [];
        _items = [];
        _users = [];
        _dataLoaded = true;
      }
    }
  }

  // Método para salvar dados persistentes
  Future<void> _savePersistedData() async {
    try {
      _logService.info('Salvando dados persistentes', category: 'database');

      await _persistenceService.saveAllData(
        boxes: _boxes,
        items: _items,
        users: _users,
      );

      _logService.info(
        'Dados persistentes salvos com sucesso: ${_boxes.length} caixas, ${_items.length} itens, ${_users.length} usuários',
        category: 'database'
      );
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao salvar dados persistentes',
        error: e,
        stackTrace: stackTrace,
        category: 'database'
      );
    }
  }

  Future<Database?> get database async {
    if (_database != null) return _database!;

    // Check if running on web
    if (kIsWeb) {
      _logService.info('Ambiente web detectado, usando banco de dados em memória', category: 'database');
      // Para web, usamos um banco de dados em memória
      try {
        _database = await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: _createDB,
        );
        _logService.info('Banco de dados em memória inicializado com sucesso', category: 'database');
      } catch (e) {
        _logService.error('Erro ao inicializar banco de dados em memória: $e', category: 'database');
        // Retornar null e usar apenas o armazenamento em memória do DatabaseHelper
        return null;
      }
    } else {
      // Para dispositivos móveis, tentar usar SQLite com fallback para banco em memória
      try {
        _logService.info('Inicializando banco de dados SQLite', category: 'database');
        _database = await _initDB('boxmagic_database.db');
        _logService.info('Banco de dados SQLite inicializado com sucesso', category: 'database');
      } catch (e) {
        _logService.error('Erro ao inicializar banco de dados SQLite: $e', category: 'database');
        _logService.info('Usando fallback para banco de dados em memória', category: 'database');
        // Criar um banco de dados em memória como fallback
        try {
          _database = await openDatabase(
            inMemoryDatabasePath,
            version: 1,
            onCreate: _createDB,
          );
          _logService.info('Banco de dados em memória inicializado com sucesso', category: 'database');
        } catch (e2) {
          _logService.error('Erro ao inicializar banco de dados em memória: $e2', category: 'database');
          return null;
        }
      }
    }
    
    return _database;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Create boxes table
    await db.execute('''
      CREATE TABLE boxes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        image TEXT,
        barcodeDataUrl TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');

    // Create items table
    await db.execute('''
      CREATE TABLE items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT,
        description TEXT,
        image TEXT,
        boxId INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        FOREIGN KEY(boxId) REFERENCES boxes(id)
      )
    ''');

    // Create users table
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT,
        whatsapp TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');
  }

  // Box CRUD operations
  Future<Box> createBox(Box box) async {
    _logService.info('Criando nova caixa: ${box.name}', category: 'database');

    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      _logService.debug('Dados não carregados, carregando agora', category: 'database');
      await _loadPersistedData();
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      _logService.debug('Usando implementação web para criar caixa', category: 'database');

      // Gerar um novo ID sequencial de 4 dígitos
      final id = await _preferencesService.incrementAndGetNextBoxId();
      final newBox = box.copyWith(id: id);

      _logService.debug('Nova caixa criada com ID sequencial: ${newBox.id} (formatado: ${newBox.formattedId})', category: 'database');

      // Adicionar à lista em memória
      _boxes.add(newBox);

      // Persistir os dados
      await _savePersistedData();

      _logService.info('Caixa criada e persistida com sucesso: ${newBox.name} (ID: ${newBox.id})', category: 'database');

      return newBox;
    }

    _logService.debug('Usando implementação mobile para criar caixa', category: 'database');
    final id = await db.insert('boxes', box.toMap());
    final newBox = box.copyWith(id: id);

    _logService.debug('Nova caixa criada no SQLite com ID: ${newBox.id}', category: 'database');

    // Adicionar à lista em memória
    _boxes.add(newBox);

    // Persistir os dados
    await _savePersistedData();

    _logService.info('Caixa criada e persistida com sucesso: ${newBox.name} (ID: ${newBox.id})', category: 'database');

    return newBox;
  }

  Future<Box?> readBox(int id) async {
    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      await _loadPersistedData();
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Buscar na lista em memória
      try {
        return _boxes.firstWhere((box) => box.id == id);
      } catch (e) {
        return null;
      }
    }

    final maps = await db.query(
      'boxes',
      columns: ['id', 'name', 'category', 'description', 'image', 'barcodeDataUrl', 'createdAt', 'updatedAt'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Box.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Box>> readAllBoxes() async {
    _logService.info('Solicitação para ler todas as caixas', category: 'database');

    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      _logService.debug('Dados não carregados, carregando agora', category: 'database');
      await _loadPersistedData();
    }

    // Se não houver caixas, tentar recarregar do backup
    if (_boxes.isEmpty) {
      _logService.warning('Nenhuma caixa encontrada em memória, tentando recarregar do backup', category: 'database');

      // Forçar recarregamento dos dados
      _dataLoaded = false;
      await _loadPersistedData();

      if (_boxes.isEmpty) {
        _logService.warning('Nenhuma caixa encontrada mesmo após recarregar do backup', category: 'database');
      } else {
        _logService.info('Caixas carregadas com sucesso do backup: ${_boxes.length}', category: 'database');
      }
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Retornar a lista em memória
      _logService.debug('Usando implementação web, retornando ${_boxes.length} caixas da memória', category: 'database');
      return List<Box>.from(_boxes);
    }

    // Para dispositivos móveis, ainda usamos o SQLite
    _logService.debug('Usando implementação mobile, consultando banco de dados SQLite', category: 'database');
    final result = await db.query('boxes');
    final boxes = result.map((map) => Box.fromMap(map)).toList();

    _logService.info('Caixas carregadas do SQLite: ${boxes.length}', category: 'database');

    // Se não houver caixas no SQLite, mas houver em memória, usar as da memória
    if (boxes.isEmpty && _boxes.isNotEmpty) {
      _logService.warning('Nenhuma caixa encontrada no SQLite, mas há ${_boxes.length} caixas em memória. Usando caixas da memória.', category: 'database');

      // Salvar as caixas da memória no SQLite
      for (final box in _boxes) {
        await db.insert('boxes', box.toMap());
      }

      _logService.info('Caixas da memória salvas no SQLite', category: 'database');
      return List<Box>.from(_boxes);
    }

    // Atualizar a lista em memória
    _boxes = boxes;

    // Salvar os dados para garantir que estejam disponíveis em todas as fontes
    await _savePersistedData();

    return boxes;
  }

  // Método para ler itens por ID da caixa
  Future<List<Item>> readItemsByBoxId(int boxId) async {
    _logService.info('Solicitação para ler itens da caixa ID: $boxId', category: 'database');
    
    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      _logService.debug('Dados não carregados, carregando agora', category: 'database');
      await _loadPersistedData();
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Buscar na lista em memória
      _logService.debug('Usando implementação web para buscar itens da caixa $boxId', category: 'database');
      final items = _items.where((item) => item.boxId == boxId).toList();
      _logService.info('${items.length} itens encontrados para a caixa $boxId', category: 'database');
      return items;
    }

    // Para dispositivos móveis, usar SQLite
    _logService.debug('Usando implementação mobile para buscar itens da caixa $boxId', category: 'database');
    final result = await db.query(
      'items',
      where: 'boxId = ?',
      whereArgs: [boxId],
    );

    final items = result.map((map) => Item.fromMap(map)).toList();
    _logService.info('${items.length} itens encontrados para a caixa $boxId no SQLite', category: 'database');
    return items;
  }

  // Método para ler todos os itens
  Future<List<Item>> readAllItems() async {
    _logService.info('Solicitação para ler todos os itens', category: 'database');
    
    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      _logService.debug('Dados não carregados, carregando agora', category: 'database');
      await _loadPersistedData();
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Retornar a lista em memória
      _logService.debug('Usando implementação web, retornando ${_items.length} itens da memória', category: 'database');
      return List<Item>.from(_items);
    }

    // Para dispositivos móveis, usar SQLite
    _logService.debug('Usando implementação mobile, consultando banco de dados SQLite', category: 'database');
    final result = await db.query('items');
    final items = result.map((map) => Item.fromMap(map)).toList();

    _logService.info('Itens carregados do SQLite: ${items.length}', category: 'database');

    // Atualizar a lista em memória
    _items = items;

    // Salvar os dados para garantir que estejam disponíveis em todas as fontes
    await _savePersistedData();

    return items;
  }

  // Método para excluir um item
  Future<bool> deleteItem(int id) async {
    _logService.info('Excluindo item com ID: $id', category: 'database');
    
    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      await _loadPersistedData();
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Remover da lista em memória
      _logService.debug('Usando implementação web para excluir item', category: 'database');
      final initialLength = _items.length;
      _items.removeWhere((item) => item.id == id);
      
      // Verificar se o item foi removido
      final removed = initialLength > _items.length;
      
      if (removed) {
        // Persistir os dados
        await _savePersistedData();
        _logService.info('Item excluído com sucesso da memória', category: 'database');
      } else {
        _logService.warning('Item com ID $id não encontrado na memória', category: 'database');
      }
      
      return removed;
    }

    // Para dispositivos móveis, usar SQLite
    _logService.debug('Usando implementação mobile para excluir item', category: 'database');
    final count = await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Remover da lista em memória também
    _items.removeWhere((item) => item.id == id);
    
    // Persistir os dados
    await _savePersistedData();

    _logService.info('Item excluído com sucesso: $count registros afetados', category: 'database');
    return count > 0;
  }

  // Método para ler todos os usuários
  Future<List<User>> readAllUsers() async {
    _logService.info('Solicitação para ler todos os usuários', category: 'database');
    
    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      _logService.debug('Dados não carregados, carregando agora', category: 'database');
      await _loadPersistedData();
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Retornar a lista em memória
      _logService.debug('Usando implementação web, retornando ${_users.length} usuários da memória', category: 'database');
      return List<User>.from(_users);
    }

    // Para dispositivos móveis, usar SQLite
    _logService.debug('Usando implementação mobile, consultando banco de dados SQLite', category: 'database');
    final result = await db.query('users');
    final users = result.map((map) => User.fromMap(map)).toList();

    _logService.info('Usuários carregados do SQLite: ${users.length}', category: 'database');

    // Atualizar a lista em memória
    _users = users;

    // Salvar os dados para garantir que estejam disponíveis em todas as fontes
    await _savePersistedData();

    return users;
  }

  // Método para excluir um usuário
  Future<bool> deleteUser(int id) async {
    _logService.info('Excluindo usuário com ID: $id', category: 'database');
    
    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      await _loadPersistedData();
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Remover da lista em memória
      _logService.debug('Usando implementação web para excluir usuário', category: 'database');
      final initialLength = _users.length;
      _users.removeWhere((user) => user.id == id);
      
      // Verificar se o usuário foi removido
      final removed = initialLength > _users.length;
      
      if (removed) {
        // Persistir os dados
        await _savePersistedData();
        _logService.info('Usuário excluído com sucesso da memória', category: 'database');
      } else {
        _logService.warning('Usuário com ID $id não encontrado na memória', category: 'database');
      }
      
      return removed;
    }

    // Para dispositivos móveis, usar SQLite
    _logService.debug('Usando implementação mobile para excluir usuário', category: 'database');
    final count = await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Remover da lista em memória também
    _users.removeWhere((user) => user.id == id);
    
    // Persistir os dados
    await _savePersistedData();

    _logService.info('Usuário excluído com sucesso: $count registros afetados', category: 'database');
    return count > 0;
  }

  // Método para limpar todos os dados
  Future<void> clearAllData() async {
    _logService.info('Limpando todos os dados', category: 'database');
    
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Limpar listas em memória
      _logService.debug('Usando implementação web para limpar dados', category: 'database');
      _boxes = [];
      _items = [];
      _users = [];
      
      // Persistir os dados vazios
      await _savePersistedData();
      
      _logService.info('Todos os dados limpos da memória', category: 'database');
    } else {
      // Para dispositivos móveis, usar SQLite
      _logService.debug('Usando implementação mobile para limpar dados', category: 'database');
      
      // Limpar todas as tabelas
      await db.delete('items');
      await db.delete('boxes');
      await db.delete('users');
      
      // Limpar listas em memória também
      _boxes = [];
      _items = [];
      _users = [];
      
      // Persistir os dados vazios
      await _savePersistedData();
      
      _logService.info('Todos os dados limpos do SQLite e da memória', category: 'database');
    }
    
    // Limpar preferências compartilhadas também
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    _logService.info('Preferências compartilhadas limpas', category: 'database');
  }

  // Método para excluir uma caixa
  Future<bool> deleteBox(int id) async {
    _logService.info('Excluindo caixa com ID: $id', category: 'database');
    
    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      await _loadPersistedData();
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Remover da lista em memória
      _logService.debug('Usando implementação web para excluir caixa', category: 'database');
      final initialLength = _boxes.length;
      _boxes.removeWhere((box) => box.id == id);
      
      // Também remover todos os itens associados a esta caixa
      _items.removeWhere((item) => item.boxId == id);
      
      // Verificar se a caixa foi removida
      final removed = initialLength > _boxes.length;
      
      if (removed) {
        // Persistir os dados
        await _savePersistedData();
        _logService.info('Caixa excluída com sucesso da memória', category: 'database');
      } else {
        _logService.warning('Caixa com ID $id não encontrada na memória', category: 'database');
      }
      
      return removed;
    }

    // Para dispositivos móveis, usar SQLite
    _logService.debug('Usando implementação mobile para excluir caixa', category: 'database');
    
    // Primeiro excluir todos os itens associados a esta caixa
    await db.delete(
      'items',
      where: 'boxId = ?',
      whereArgs: [id],
    );
    
    // Depois excluir a caixa
    final count = await db.delete(
      'boxes',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Remover da lista em memória também
    _boxes.removeWhere((box) => box.id == id);
    _items.removeWhere((item) => item.boxId == id);
    
    // Persistir os dados
    await _savePersistedData();

    _logService.info('Caixa excluída com sucesso: $count registros afetados', category: 'database');
    return count > 0;
  }

  // Método para criar um item
  Future<Item> createItem(Item item) async {
    _logService.info('Criando novo item: ${item.name}', category: 'database');

    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      _logService.debug('Dados não carregados, carregando agora', category: 'database');
      await _loadPersistedData();
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      _logService.debug('Usando implementação web para criar item', category: 'database');

      // Gerar um novo ID sequencial
      final id = await _preferencesService.incrementAndGetNextItemId();
      final newItem = item.copyWith(id: id);

      _logService.debug('Novo item criado com ID sequencial: ${newItem.id}', category: 'database');

      // Adicionar à lista em memória
      _items.add(newItem);

      // Persistir os dados
      await _savePersistedData();

      _logService.info('Item criado e persistido com sucesso: ${newItem.name} (ID: ${newItem.id})', category: 'database');

      return newItem;
    }

    _logService.debug('Usando implementação mobile para criar item', category: 'database');
    final id = await db.insert('items', item.toMap());
    final newItem = item.copyWith(id: id);

    _logService.debug('Novo item criado no SQLite com ID: ${newItem.id}', category: 'database');

    // Adicionar à lista em memória
    _items.add(newItem);

    // Persistir os dados
    await _savePersistedData();

    _logService.info('Item criado e persistido com sucesso: ${newItem.name} (ID: ${newItem.id})', category: 'database');

    return newItem;
  }

  // Método para atualizar um item
  Future<int> updateItem(Item item) async {
    _logService.info('Atualizando item com ID: ${item.id}', category: 'database');
    
    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      await _loadPersistedData();
    }

    if (item.id == null) {
      _logService.error('Tentativa de atualizar item sem ID', category: 'database');
      return 0;
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Atualizar na lista em memória
      _logService.debug('Usando implementação web para atualizar item', category: 'database');
      
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index >= 0) {
        _items[index] = item;
        
        // Persistir os dados
        await _savePersistedData();
        
        _logService.info('Item atualizado com sucesso na memória', category: 'database');
        return 1; // Retorna 1 para indicar sucesso (1 registro afetado)
      } else {
        _logService.warning('Item com ID ${item.id} não encontrado na memória', category: 'database');
        return 0; // Retorna 0 para indicar falha (0 registros afetados)
      }
    }

    // Para dispositivos móveis, usar SQLite
    _logService.debug('Usando implementação mobile para atualizar item', category: 'database');
    final count = await db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );

    // Atualizar na lista em memória também
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      _items[index] = item;
    }
    
    // Persistir os dados
    await _savePersistedData();

    _logService.info('Item atualizado com sucesso: $count registros afetados', category: 'database');
    return count;
  }

  // Método para criar um usuário
  Future<User> createUser(User user) async {
    _logService.info('Criando novo usuário: ${user.name}', category: 'database');

    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      _logService.debug('Dados não carregados, carregando agora', category: 'database');
      await _loadPersistedData();
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      _logService.debug('Usando implementação web para criar usuário', category: 'database');

      // Gerar um novo ID sequencial (começando em 1 para usuários)
      int id = 1;
      if (_users.isNotEmpty) {
        // Encontrar o maior ID existente e adicionar 1
        id = _users.map((u) => u.id ?? 0).reduce((a, b) => a > b ? a : b) + 1;
      }
      
      final newUser = user.copyWith(id: id);

      _logService.debug('Novo usuário criado com ID sequencial: ${newUser.id}', category: 'database');

      // Adicionar à lista em memória
      _users.add(newUser);

      // Persistir os dados
      await _savePersistedData();

      _logService.info('Usuário criado e persistido com sucesso: ${newUser.name} (ID: ${newUser.id})', category: 'database');

      return newUser;
    }

    _logService.debug('Usando implementação mobile para criar usuário', category: 'database');
    final id = await db.insert('users', user.toMap());
    final newUser = user.copyWith(id: id);

    _logService.debug('Novo usuário criado no SQLite com ID: ${newUser.id}', category: 'database');

    // Adicionar à lista em memória
    _users.add(newUser);

    // Persistir os dados
    await _savePersistedData();

    _logService.info('Usuário criado e persistido com sucesso: ${newUser.name} (ID: ${newUser.id})', category: 'database');

    return newUser;
  }

  // Método para atualizar um usuário
  Future<int> updateUser(User user) async {
    _logService.info('Atualizando usuário com ID: ${user.id}', category: 'database');
    
    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      await _loadPersistedData();
    }

    if (user.id == null) {
      _logService.error('Tentativa de atualizar usuário sem ID', category: 'database');
      return 0;
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Atualizar na lista em memória
      _logService.debug('Usando implementação web para atualizar usuário', category: 'database');
      
      final index = _users.indexWhere((u) => u.id == user.id);
      if (index >= 0) {
        _users[index] = user;
        
        // Persistir os dados
        await _savePersistedData();
        
        _logService.info('Usuário atualizado com sucesso na memória', category: 'database');
        return 1; // Retorna 1 para indicar sucesso (1 registro afetado)
      } else {
        _logService.warning('Usuário com ID ${user.id} não encontrado na memória', category: 'database');
        return 0; // Retorna 0 para indicar falha (0 registros afetados)
      }
    }

    // Para dispositivos móveis, usar SQLite
    _logService.debug('Usando implementação mobile para atualizar usuário', category: 'database');
    final count = await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );

    // Atualizar na lista em memória também
    final index = _users.indexWhere((u) => u.id == user.id);
    if (index >= 0) {
      _users[index] = user;
    }
    
    // Persistir os dados
    await _savePersistedData();

    _logService.info('Usuário atualizado com sucesso: $count registros afetados', category: 'database');
    return count;
  }

  // Método para atualizar uma caixa
  Future<int> updateBox(Box box) async {
    _logService.info('Atualizando caixa com ID: ${box.id}', category: 'database');
    
    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      await _loadPersistedData();
    }

    if (box.id == null) {
      _logService.error('Tentativa de atualizar caixa sem ID', category: 'database');
      return 0;
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Atualizar na lista em memória
      _logService.debug('Usando implementação web para atualizar caixa', category: 'database');
      
      final index = _boxes.indexWhere((b) => b.id == box.id);
      if (index >= 0) {
        _boxes[index] = box;
        
        // Persistir os dados
        await _savePersistedData();
        
        _logService.info('Caixa atualizada com sucesso na memória', category: 'database');
        return 1; // Retorna 1 para indicar sucesso (1 registro afetado)
      } else {
        _logService.warning('Caixa com ID ${box.id} não encontrada na memória', category: 'database');
        return 0; // Retorna 0 para indicar falha (0 registros afetados)
      }
    }

    // Para dispositivos móveis, usar SQLite
    _logService.debug('Usando implementação mobile para atualizar caixa', category: 'database');
    final count = await db.update(
      'boxes',
      box.toMap(),
      where: 'id = ?',
      whereArgs: [box.id],
    );

    // Atualizar na lista em memória também
    final index = _boxes.indexWhere((b) => b.id == box.id);
    if (index >= 0) {
      _boxes[index] = box;
    }
    
    // Persistir os dados
    await _savePersistedData();

    _logService.info('Caixa atualizada com sucesso: $count registros afetados', category: 'database');
    return count;
  }
}
