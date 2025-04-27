import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:boxmagic/services/persistence_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final persistenceService = PersistenceService();
  
  // Ler o arquivo de backup
  final file = File('G:/Projetos2025BKP/BoxMagicFlutter/boxmagic_backup.json');
  if (!await file.exists()) {
    print('Arquivo de backup não encontrado!');
    return;
  }
  
  final backupJson = await file.readAsString();
  
  // Restaurar o backup
  final success = await persistenceService.restoreFromBackupJson(backupJson);
  
  if (success) {
    print('Backup restaurado com sucesso!');
  } else {
    print('Falha ao restaurar o backup!');
  }
}
