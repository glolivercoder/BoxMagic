import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // Ler o arquivo de backup
  final file = File('G:/Projetos2025BKP/BoxMagicFlutter/boxmagic_backup.json');
  final backupJson = await file.readAsString();
  final backupData = jsonDecode(backupJson);
  
  // Obter as listas de caixas e itens
  final boxesData = backupData['boxes'];
  final itemsData = backupData['items'];
  
  // Converter para JSON strings
  final boxesJson = boxesData.map((box) => jsonEncode(box)).toList();
  final itemsJson = itemsData.map((item) => jsonEncode(item)).toList();
  
  // Salvar no SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('boxmagic_boxes_persistent', boxesJson.cast<String>());
  await prefs.setStringList('boxmagic_items_persistent', itemsJson.cast<String>());
  await prefs.setString('boxmagic_last_sync', DateTime.now().toIso8601String());
  
  print('Backup restaurado com sucesso!');
  print('Caixas: ${boxesData.length}');
  print('Itens: ${itemsData.length}');
}
