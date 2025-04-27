import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Dados de backup
  final boxesJson = [
    '{"id":1745722837461,"name":"ITENS Diversos","category":"DIVERSOS","description":null,"image":null,"createdAt":"2025-04-27T00:00:37.458","updatedAt":null,"barcodeDataUrl":null}'
  ];
  
  final itemsJson = [
    '{"id":1745722868425,"name":"Controle Remoto","category":"DIVERSOS","description":null,"image":null,"boxId":1745722837461,"createdAt":"2025-04-27T00:01:08.400","updatedAt":null}',
    '{"id":1745722927997,"name":"Alicate de unha","category":"DIVERSOS","description":null,"image":null,"boxId":1745722837461,"createdAt":"2025-04-27T00:02:07.969","updatedAt":null}'
  ];
  
  // Salvar no SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('boxmagic_boxes_persistent', boxesJson);
  await prefs.setStringList('boxmagic_items_persistent', itemsJson);
  await prefs.setString('boxmagic_last_sync', DateTime.now().toIso8601String());
  
  print('Backup restaurado manualmente com sucesso!');
  print('Caixas: ${boxesJson.length}');
  print('Itens: ${itemsJson.length}');
  
  // Mostrar todas as chaves
  final keys = prefs.getKeys();
  print('===== CHAVES ARMAZENADAS =====');
  for (final key in keys) {
    print('Chave: $key');
  }
  print('==============================');
}
