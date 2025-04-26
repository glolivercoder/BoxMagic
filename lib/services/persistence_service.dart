import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/models/user.dart';

class PersistenceService {
  static final PersistenceService _instance = PersistenceService._internal();
  factory PersistenceService() => _instance;
  PersistenceService._internal();

  // Chaves para armazenamento
  static const String _boxesKey = 'boxmagic_boxes_persistent';
  static const String _itemsKey = 'boxmagic_items_persistent';
  static const String _usersKey = 'boxmagic_users_persistent';
  static const String _lastSyncKey = 'boxmagic_last_sync';

  // Salvar dados
  Future<void> saveAllData({
    required List<Box> boxes,
    required List<Item> items,
    required List<User> users,
  }) async {
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
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    
    print('Dados salvos com sucesso! Boxes: ${boxes.length}, Items: ${items.length}, Users: ${users.length}');
  }

  // Carregar dados
  Future<Map<String, dynamic>> loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Obter dados do SharedPreferences
    final boxesJson = prefs.getStringList(_boxesKey) ?? [];
    final itemsJson = prefs.getStringList(_itemsKey) ?? [];
    final usersJson = prefs.getStringList(_usersKey) ?? [];
    
    // Converter JSON para objetos
    final boxes = boxesJson.map((json) => Box.fromMap(jsonDecode(json))).toList();
    final items = itemsJson.map((json) => Item.fromMap(jsonDecode(json))).toList();
    final users = usersJson.map((json) => User.fromMap(jsonDecode(json))).toList();
    
    print('Dados carregados com sucesso! Boxes: ${boxes.length}, Items: ${items.length}, Users: ${users.length}');
    
    return {
      'boxes': boxes,
      'items': items,
      'users': users,
    };
  }

  // Verificar se há dados salvos
  Future<bool> hasPersistedData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_boxesKey) || prefs.containsKey(_itemsKey);
  }

  // Obter data da última sincronização
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString(_lastSyncKey);
    if (lastSync != null) {
      return DateTime.parse(lastSync);
    }
    return null;
  }

  // Limpar todos os dados persistentes
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_boxesKey);
    await prefs.remove(_itemsKey);
    await prefs.remove(_usersKey);
    await prefs.remove(_lastSyncKey);
    print('Todos os dados persistentes foram removidos');
  }
}
