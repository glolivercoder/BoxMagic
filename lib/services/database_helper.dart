import 'dart:convert';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/models/user.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

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
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Get existing boxes or create empty list
      final boxesJson = prefs.getStringList('boxes') ?? [];

      // Generate a new ID
      final id = DateTime.now().millisecondsSinceEpoch;
      final newBox = box.copyWith(id: id);

      // Add new box to the list
      boxesJson.add(jsonEncode(newBox.toMap()));

      // Save updated list
      await prefs.setStringList('boxes', boxesJson);

      return newBox;
    }

    final id = await db.insert('boxes', box.toMap());
    return box.copyWith(id: id);
  }

  Future<Box?> readBox(int id) async {
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final boxesJson = prefs.getStringList('boxes') ?? [];

      for (final boxJson in boxesJson) {
        final map = jsonDecode(boxJson) as Map<String, dynamic>;
        if (map['id'] == id) {
          return Box.fromMap(map);
        }
      }

      return null;
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
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final boxesJson = prefs.getStringList('boxes') ?? [];

      return boxesJson.map((boxJson) {
        final map = jsonDecode(boxJson) as Map<String, dynamic>;
        return Box.fromMap(map);
      }).toList();
    }

    final result = await db.query('boxes');
    return result.map((map) => Box.fromMap(map)).toList();
  }

  Future<int> updateBox(Box box) async {
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final boxesJson = prefs.getStringList('boxes') ?? [];

      // Find and update the box
      final updatedBoxesJson = <String>[];
      bool found = false;

      for (final boxJson in boxesJson) {
        final map = jsonDecode(boxJson) as Map<String, dynamic>;
        if (map['id'] == box.id) {
          updatedBoxesJson.add(jsonEncode(box.toMap()));
          found = true;
        } else {
          updatedBoxesJson.add(boxJson);
        }
      }

      if (found) {
        await prefs.setStringList('boxes', updatedBoxesJson);
        return 1;
      }

      return 0;
    }

    return db.update(
      'boxes',
      box.toMap(),
      where: 'id = ?',
      whereArgs: [box.id],
    );
  }

  Future<int> deleteBox(int id) async {
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final boxesJson = prefs.getStringList('boxes') ?? [];

      // Filter out the box to delete
      final updatedBoxesJson = boxesJson.where((boxJson) {
        final map = jsonDecode(boxJson) as Map<String, dynamic>;
        return map['id'] != id;
      }).toList();

      if (updatedBoxesJson.length < boxesJson.length) {
        await prefs.setStringList('boxes', updatedBoxesJson);
        return 1;
      }

      return 0;
    }

    return await db.delete(
      'boxes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Item CRUD operations
  Future<Item> createItem(Item item) async {
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Get existing items or create empty list
      final itemsJson = prefs.getStringList('items') ?? [];

      // Generate a new ID
      final id = DateTime.now().millisecondsSinceEpoch;
      final newItem = item.copyWith(id: id);

      // Add new item to the list
      itemsJson.add(jsonEncode(newItem.toMap()));

      // Save updated list
      await prefs.setStringList('items', itemsJson);

      return newItem;
    }

    final id = await db.insert('items', item.toMap());
    return item.copyWith(id: id);
  }

  Future<Item?> readItem(int id) async {
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = prefs.getStringList('items') ?? [];

      for (final itemJson in itemsJson) {
        final map = jsonDecode(itemJson) as Map<String, dynamic>;
        if (map['id'] == id) {
          return Item.fromMap(map);
        }
      }

      return null;
    }

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
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = prefs.getStringList('items') ?? [];

      return itemsJson.map((itemJson) {
        final map = jsonDecode(itemJson) as Map<String, dynamic>;
        return Item.fromMap(map);
      }).toList();
    }

    final result = await db.query('items');
    return result.map((map) => Item.fromMap(map)).toList();
  }

  Future<List<Item>> readItemsByBoxId(int boxId) async {
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = prefs.getStringList('items') ?? [];

      return itemsJson
          .map((itemJson) {
            final map = jsonDecode(itemJson) as Map<String, dynamic>;
            return Item.fromMap(map);
          })
          .where((item) => item.boxId == boxId)
          .toList();
    }

    final result = await db.query(
      'items',
      where: 'boxId = ?',
      whereArgs: [boxId],
    );
    return result.map((map) => Item.fromMap(map)).toList();
  }

  Future<int> updateItem(Item item) async {
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = prefs.getStringList('items') ?? [];

      // Find and update the item
      final updatedItemsJson = <String>[];
      bool found = false;

      for (final itemJson in itemsJson) {
        final map = jsonDecode(itemJson) as Map<String, dynamic>;
        if (map['id'] == item.id) {
          updatedItemsJson.add(jsonEncode(item.toMap()));
          found = true;
        } else {
          updatedItemsJson.add(itemJson);
        }
      }

      if (found) {
        await prefs.setStringList('items', updatedItemsJson);
        return 1;
      }

      return 0;
    }

    return db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await instance.database;

    if (kIsWeb || db == null) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = prefs.getStringList('items') ?? [];

      // Filter out the item to delete
      final updatedItemsJson = itemsJson.where((itemJson) {
        final map = jsonDecode(itemJson) as Map<String, dynamic>;
        return map['id'] != id;
      }).toList();

      if (updatedItemsJson.length < itemsJson.length) {
        await prefs.setStringList('items', updatedItemsJson);
        return 1;
      }

      return 0;
    }

    return await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
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
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('boxes');
      await prefs.remove('items');
      await prefs.remove('users');
    } else {
      // Mobile implementation using SQLite
      await db.delete('items');
      await db.delete('boxes');
      await db.delete('users');
    }
  }
}
