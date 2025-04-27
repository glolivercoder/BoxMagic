import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const String _categoriesKey = 'boxmagic_categories';
  static const String _nextBoxIdKey = 'boxmagic_next_id';
  static const String _themeKey = 'boxmagic_theme';
  static const String _labelSizeKey = 'boxmagic_label_size';

  // Default categories
  static const List<String> _defaultCategories = [
    'Eletrônicos',
    'Ferramentas manuais de marcenaria',
    'Ferramentas elétricas de marcenaria',
    'Equipamentos de áudio',
    'Informática',
    'Itens de escritório'
  ];

  // Get categories
  Future<List<String>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getString(_categoriesKey);
    if (categoriesJson == null) {
      await saveCategories(_defaultCategories);
      return _defaultCategories;
    }
    return List<String>.from(jsonDecode(categoriesJson));
  }

  // Save categories
  Future<bool> saveCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_categoriesKey, jsonEncode(categories));
  }

  // Add a new category
  Future<bool> addCategory(String category) async {
    final categories = await getCategories();
    if (!categories.contains(category)) {
      categories.add(category);
      return saveCategories(categories);
    }
    return true;
  }

  // Remove a category
  Future<bool> removeCategory(String category) async {
    final categories = await getCategories();
    if (categories.contains(category)) {
      categories.remove(category);
      return saveCategories(categories);
    }
    return true;
  }

  // Get next box ID
  Future<int> getNextBoxId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_nextBoxIdKey) ?? 1001;
  }

  // Save next box ID
  Future<bool> saveNextBoxId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setInt(_nextBoxIdKey, id);
  }

  // Increment and get next box ID
  Future<int> incrementAndGetNextBoxId() async {
    final currentId = await getNextBoxId();

    // Garantir que o ID tenha no máximo 4 dígitos
    int idToUse = currentId;
    if (idToUse > 9999) {
      // Se passar de 9999, volta para 1001
      idToUse = 1001;
    }

    // Incrementar para o próximo ID
    final nextId = idToUse + 1;
    await saveNextBoxId(nextId);

    return idToUse;
  }

  // Get theme (light or dark)
  Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'light';
  }

  // Save theme
  Future<bool> saveTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_themeKey, theme);
  }

  // Get label size
  Future<String> getLabelSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_labelSizeKey) ?? 'correios';
  }

  // Save label size
  Future<bool> saveLabelSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_labelSizeKey, size);
  }
}
