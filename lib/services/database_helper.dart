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
      // For web, we'll use a mock database or return null
      // In a real app, you might use IndexedDB or another web storage solution
      // Using a logger would be better in production code
      return null;
    } else {
      // For mobile platforms, use SQLite
      _database = await _initDB('boxmagic_database.db');
      return _database;
    }
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

    _logService.info('Retornando ${boxes.length} caixas', category: 'database');
    return boxes;
  }

  Future<int> updateBox(Box box) async {
    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      await _loadPersistedData();
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Atualizar na lista em memória
      final index = _boxes.indexWhere((b) => b.id == box.id);
      if (index >= 0) {
        _boxes[index] = box;

        // Persistir os dados
        await _savePersistedData();
        return 1;
      }
      return 0;
    }

    // Para dispositivos móveis, ainda usamos o SQLite
    final result = await db.update(
      'boxes',
      box.toMap(),
      where: 'id = ?',
      whereArgs: [box.id],
    );

    // Atualizar também na lista em memória
    if (result > 0) {
      final index = _boxes.indexWhere((b) => b.id == box.id);
      if (index >= 0) {
        _boxes[index] = box;
      }

      // Persistir os dados
      await _savePersistedData();
    }

    return result;
  }

  Future<int> deleteBox(int id) async {
    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      await _loadPersistedData();
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Remover da lista em memória
      final initialLength = _boxes.length;
      _boxes.removeWhere((box) => box.id == id);

      // Também remover todos os itens associados a esta caixa
      _items.removeWhere((item) => item.boxId == id);

      if (_boxes.length < initialLength) {
        // Persistir os dados
        await _savePersistedData();
        return 1;
      }

      return 0;
    }

    // Para dispositivos móveis, ainda usamos o SQLite
    final result = await db.delete(
      'boxes',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Atualizar também na lista em memória
    if (result > 0) {
      _boxes.removeWhere((box) => box.id == id);
      // Também remover todos os itens associados a esta caixa
      _items.removeWhere((item) => item.boxId == id);

      // Persistir os dados
      await _savePersistedData();
    }

    return result;
  }

  // Item CRUD operations
  Future<Item> createItem(Item item) async {
    _logService.info('Criando novo item: ${item.name} para caixa ID: ${item.boxId}', category: 'database');

    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      _logService.debug('Dados não carregados, carregando agora', category: 'database');
      await _loadPersistedData();
    }

    // Verificar se a caixa existe
    final boxExists = _boxes.any((box) => box.id == item.boxId);
    if (!boxExists) {
      _logService.warning('Tentativa de criar item para caixa inexistente (ID: ${item.boxId}). Recarregando caixas...', category: 'database');

      // Tentar recarregar as caixas
      await readAllBoxes();

      // Verificar novamente
      final boxExistsAfterReload = _boxes.any((box) => box.id == item.boxId);
      if (!boxExistsAfterReload) {
        _logService.error('Caixa não encontrada mesmo após recarregar (ID: ${item.boxId})', category: 'database');
        throw Exception('Caixa não encontrada (ID: ${item.boxId})');
      } else {
        _logService.info('Caixa encontrada após recarregar (ID: ${item.boxId})', category: 'database');
      }
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      _logService.debug('Usando implementação web para criar item', category: 'database');

      // Gerar um novo ID
      final id = DateTime.now().millisecondsSinceEpoch;
      final newItem = item.copyWith(id: id);

      _logService.debug('Novo item criado com ID: ${newItem.id}', category: 'database');

      // Adicionar à lista em memória
      _items.add(newItem);

      // Persistir os dados
      await _savePersistedData();

      _logService.info('Item criado e persistido com sucesso: ${newItem.name} (ID: ${newItem.id})', category: 'database');

      return newItem;
    }

    // Para dispositivos móveis, ainda usamos o SQLite
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

  Future<Item?> readItem(int id) async {
    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      await _loadPersistedData();
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Buscar na lista em memória
      try {
        return _items.firstWhere((item) => item.id == id);
      } catch (e) {
        return null;
      }
    }

    // Para dispositivos móveis, ainda usamos o SQLite
    final maps = await db.query(
      'items',
      columns: ['id', 'name', 'category', 'description', 'image', 'boxId', 'createdAt', 'updatedAt'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Item.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Item>> readAllItems() async {
    _logService.info('Solicitação para ler todos os itens', category: 'database');

    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      _logService.debug('Dados não carregados, carregando agora', category: 'database');
      await _loadPersistedData();
    }

    // Garantir que as caixas estejam carregadas antes de carregar os itens
    if (_boxes.isEmpty) {
      _logService.warning('Nenhuma caixa encontrada em memória ao carregar itens, carregando caixas primeiro', category: 'database');
      await readAllBoxes();
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Retornar a lista em memória
      _logService.debug('Usando implementação web, retornando ${_items.length} itens da memória', category: 'database');
      return List<Item>.from(_items);
    }

    // Para dispositivos móveis, ainda usamos o SQLite
    _logService.debug('Usando implementação mobile, consultando banco de dados SQLite', category: 'database');
    final result = await db.query('items');
    final items = result.map((map) => Item.fromMap(map)).toList();

    _logService.info('Itens carregados do SQLite: ${items.length}', category: 'database');

    // Se não houver itens no SQLite, mas houver em memória, usar os da memória
    if (items.isEmpty && _items.isNotEmpty) {
      _logService.warning('Nenhum item encontrado no SQLite, mas há ${_items.length} itens em memória. Usando itens da memória.', category: 'database');

      // Salvar os itens da memória no SQLite
      for (final item in _items) {
        await db.insert('items', item.toMap());
      }

      _logService.info('Itens da memória salvos no SQLite', category: 'database');
      return List<Item>.from(_items);
    }

    // Atualizar a lista em memória
    _items = items;

    // Salvar os dados para garantir que estejam disponíveis em todas as fontes
    await _savePersistedData();

    _logService.info('Retornando ${items.length} itens', category: 'database');
    return items;
  }

  Future<List<Item>> readItemsByBoxId(int boxId) async {
    _logService.info('Solicitação para ler itens da caixa ID: $boxId', category: 'database');

    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      _logService.debug('Dados não carregados, carregando agora', category: 'database');
      await _loadPersistedData();
    }

    // Verificar se a caixa existe
    final boxExists = _boxes.any((box) => box.id == boxId);
    if (!boxExists) {
      _logService.warning('Tentativa de ler itens de caixa inexistente (ID: $boxId). Recarregando caixas...', category: 'database');

      // Tentar recarregar as caixas
      await readAllBoxes();

      // Verificar novamente
      final boxExistsAfterReload = _boxes.any((box) => box.id == boxId);
      if (!boxExistsAfterReload) {
        _logService.error('Caixa não encontrada mesmo após recarregar (ID: $boxId)', category: 'database');
        // Não lançar exceção, apenas retornar lista vazia
        return [];
      } else {
        _logService.info('Caixa encontrada após recarregar (ID: $boxId)', category: 'database');
      }
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Filtrar a lista em memória
      _logService.debug('Usando implementação web, filtrando itens em memória', category: 'database');
      final items = _items.where((item) => item.boxId == boxId).toList();
      _logService.info('Encontrados ${items.length} itens para a caixa ID: $boxId', category: 'database');
      return items;
    }

    // Para dispositivos móveis, ainda usamos o SQLite
    _logService.debug('Usando implementação mobile, consultando banco de dados SQLite', category: 'database');
    final result = await db.query(
      'items',
      where: 'boxId = ?',
      whereArgs: [boxId],
    );
    final items = result.map((map) => Item.fromMap(map)).toList();

    _logService.info('Encontrados ${items.length} itens para a caixa ID: $boxId no SQLite', category: 'database');

    // Se não houver itens no SQLite, mas houver em memória, usar os da memória
    if (items.isEmpty) {
      _logService.debug('Verificando itens em memória para a caixa ID: $boxId', category: 'database');
      final memoryItems = _items.where((item) => item.boxId == boxId).toList();

      if (memoryItems.isNotEmpty) {
        _logService.warning('Nenhum item encontrado no SQLite, mas há ${memoryItems.length} itens em memória para a caixa ID: $boxId', category: 'database');
        return memoryItems;
      }
    }

    return items;
  }

  Future<int> updateItem(Item item) async {
    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      await _loadPersistedData();
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Atualizar na lista em memória
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index >= 0) {
        _items[index] = item;

        // Persistir os dados
        await _savePersistedData();
        return 1;
      }
      return 0;
    }

    // Para dispositivos móveis, ainda usamos o SQLite
    final result = await db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );

    // Atualizar também na lista em memória
    if (result > 0) {
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index >= 0) {
        _items[index] = item;
      }

      // Persistir os dados
      await _savePersistedData();
    }

    return result;
  }

  Future<int> deleteItem(int id) async {
    // Garantir que os dados foram carregados
    if (!_dataLoaded) {
      await _loadPersistedData();
    }

    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Remover da lista em memória
      final initialLength = _items.length;
      _items.removeWhere((item) => item.id == id);

      if (_items.length < initialLength) {
        // Persistir os dados
        await _savePersistedData();
        return 1;
      }

      return 0;
    }

    // Para dispositivos móveis, ainda usamos o SQLite
    final result = await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Atualizar também na lista em memória
    if (result > 0) {
      _items.removeWhere((item) => item.id == id);

      // Persistir os dados
      await _savePersistedData();
    }

    return result;
  }

  // User CRUD operations
  Future<User> createUser(User user) async {
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Get existing users or create empty list
      final usersJson = prefs.getStringList('users') ?? [];

      // Generate a new ID
      final id = DateTime.now().millisecondsSinceEpoch;
      final newUser = user.copyWith(id: id);

      // Add new user to the list
      usersJson.add(jsonEncode(newUser.toMap()));

      // Save updated list
      await prefs.setStringList('users', usersJson);

      return newUser;
    }

    final id = await db.insert('users', user.toMap());
    return user.copyWith(id: id);
  }

  Future<User?> readUser(int id) async {
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getStringList('users') ?? [];

      for (final userJson in usersJson) {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        if (map['id'] == id) {
          return User.fromMap(map);
        }
      }

      return null;
    }

    final maps = await db.query(
      'users',
      columns: ['id', 'name', 'email', 'whatsapp', 'createdAt', 'updatedAt'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<User>> readAllUsers() async {
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getStringList('users') ?? [];

      return usersJson.map((userJson) {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        return User.fromMap(map);
      }).toList();
    }

    final result = await db.query('users');
    return result.map((map) => User.fromMap(map)).toList();
  }

  Future<int> updateUser(User user) async {
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getStringList('users') ?? [];

      // Find and update the user
      final updatedUsersJson = <String>[];
      bool found = false;

      for (final userJson in usersJson) {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        if (map['id'] == user.id) {
          updatedUsersJson.add(jsonEncode(user.toMap()));
          found = true;
        } else {
          updatedUsersJson.add(userJson);
        }
      }

      if (found) {
        await prefs.setStringList('users', updatedUsersJson);
        return 1;
      }

      return 0;
    }

    return db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getStringList('users') ?? [];

      // Filter out the user to delete
      final updatedUsersJson = usersJson.where((userJson) {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        return map['id'] != id;
      }).toList();

      if (updatedUsersJson.length < usersJson.length) {
        await prefs.setStringList('users', updatedUsersJson);
        return 1;
      }

      return 0;
    }

    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;

    if (db != null) {
      db.close();
    }

    // No need to close SharedPreferences as it's managed by the system
  }

  // Method to clear all data (useful for testing)
  Future clearAllData() async {
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Limpar dados em memória
      _boxes = [];
      _items = [];
      _users = [];
      _dataLoaded = false;

      // Limpar dados persistentes
      await _persistenceService.clearAllData();
    } else {
      // Mobile implementation using SQLite
      await db.delete('items');
      await db.delete('boxes');
      await db.delete('users');

      // Limpar dados em memória
      _boxes = [];
      _items = [];
      _users = [];
      _dataLoaded = false;
    }
  }
}
