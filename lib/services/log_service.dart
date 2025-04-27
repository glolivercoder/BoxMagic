import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LogLevel {
  info,
  warning,
  error,
  debug,
}

class LogEntry {
  final LogLevel level;
  final String message;
  final String? stackTrace;
  final String timestamp;
  final String? category;

  LogEntry({
    required this.level,
    required this.message,
    this.stackTrace,
    required this.timestamp,
    this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'level': level.toString().split('.').last,
      'message': message,
      'stackTrace': stackTrace,
      'timestamp': timestamp,
      'category': category,
    };
  }

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      level: LogLevel.values.firstWhere(
        (e) => e.toString().split('.').last == map['level'],
        orElse: () => LogLevel.info,
      ),
      message: map['message'] ?? '',
      stackTrace: map['stackTrace'],
      timestamp: map['timestamp'] ?? DateTime.now().toIso8601String(),
      category: map['category'],
    );
  }

  String toJson() => jsonEncode(toMap());

  factory LogEntry.fromJson(String source) => LogEntry.fromMap(jsonDecode(source));

  @override
  String toString() {
    return '[$timestamp] ${level.toString().split('.').last.toUpperCase()}: $message${stackTrace != null ? '\n$stackTrace' : ''}';
  }
}

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  static const int _maxLogEntries = 1000; // Limite de entradas de log armazenadas
  static const String _logsKey = 'boxmagic_logs';
  static const String _logsEnabledKey = 'boxmagic_logs_enabled';

  final List<LogEntry> _inMemoryLogs = [];
  bool _initialized = false;
  bool _enabled = true; // Por padrão, o logging está ativado

  // Inicializar o serviço de log
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Carregar configuração de ativação/desativação
      await _loadLoggingState();

      // Carregar logs armazenados
      await _loadLogs();
      _initialized = true;
      log(LogLevel.info, 'LogService inicializado com sucesso', category: 'system');
    } catch (e, stackTrace) {
      // Não podemos usar o próprio log aqui para evitar recursão
      debugPrint('Erro ao inicializar LogService: $e');
      debugPrint(stackTrace.toString());
    }
  }

  // Carregar o estado de ativação/desativação do logging
  Future<void> _loadLoggingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_logsEnabledKey) ?? true; // Por padrão, ativado
    } catch (e) {
      debugPrint('Erro ao carregar estado do logging: $e');
      _enabled = true; // Em caso de erro, manter ativado por padrão
    }
  }

  // Ativar ou desativar o logging
  Future<bool> setLoggingEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_logsEnabledKey, enabled);
      _enabled = enabled;

      if (enabled) {
        // Registrar que o logging foi ativado (sem verificar _enabled para garantir que este log seja registrado)
        final entry = LogEntry(
          level: LogLevel.info,
          message: 'Logging ativado pelo usuário',
          timestamp: DateTime.now().toIso8601String(),
          category: 'system',
        );
        _inMemoryLogs.add(entry);
        _saveLogs();
      }

      return true;
    } catch (e) {
      debugPrint('Erro ao definir estado do logging: $e');
      return false;
    }
  }

  // Verificar se o logging está ativado
  bool isLoggingEnabled() {
    return _enabled;
  }

  // Registrar uma entrada de log
  void log(LogLevel level, String message, {String? stackTrace, String? category}) {
    // Verificar se o logging está ativado (exceto para logs do sistema)
    if (!_enabled && category != 'system') {
      // Se o logging estiver desativado, apenas exibir no console em modo de desenvolvimento
      if (kDebugMode) {
        debugPrint('Log desativado: ${level.toString().split('.').last} - $message');
      }
      return;
    }

    final entry = LogEntry(
      level: level,
      message: message,
      stackTrace: stackTrace,
      timestamp: DateTime.now().toIso8601String(),
      category: category,
    );

    // Adicionar à memória
    _inMemoryLogs.add(entry);

    // Limitar o tamanho dos logs em memória
    if (_inMemoryLogs.length > _maxLogEntries) {
      _inMemoryLogs.removeAt(0);
    }

    // Exibir no console durante o desenvolvimento
    if (kDebugMode) {
      switch (level) {
        case LogLevel.info:
          debugPrint('ℹ️ INFO: $message');
          break;
        case LogLevel.warning:
          debugPrint('⚠️ WARNING: $message');
          break;
        case LogLevel.error:
          debugPrint('❌ ERROR: $message');
          if (stackTrace != null) {
            debugPrint(stackTrace);
          }
          break;
        case LogLevel.debug:
          debugPrint('🔍 DEBUG: $message');
          break;
      }
    }

    // Salvar logs periodicamente
    _saveLogs();
  }

  // Métodos de conveniência para diferentes níveis de log
  void info(String message, {String? category}) {
    log(LogLevel.info, message, category: category);
  }

  void warning(String message, {String? category}) {
    log(LogLevel.warning, message, category: category);
  }

  void error(String message, {Object? error, StackTrace? stackTrace, String? category}) {
    final errorStr = error != null ? ': $error' : '';
    final stackTraceStr = stackTrace != null ? stackTrace.toString() : null;

    // Adicionar informações do sistema para ajudar no diagnóstico
    final systemInfo = 'Platform: ${kIsWeb ? 'Web' : 'Native'}, '
        'Time: ${DateTime.now().toIso8601String()}';

    log(LogLevel.error, '$message$errorStr\n$systemInfo',
        stackTrace: stackTraceStr,
        category: category);

    // Em modo de desenvolvimento, também imprimir no console para facilitar o debug
    if (kDebugMode) {
      print('❌ ERROR [$category]: $message$errorStr');
      if (stackTraceStr != null) {
        print(stackTraceStr);
      }
    }
  }

  void debug(String message, {String? category}) {
    log(LogLevel.debug, message, category: category);
  }

  // Obter todos os logs
  List<LogEntry> getLogs() {
    return List.unmodifiable(_inMemoryLogs);
  }

  // Obter logs filtrados por nível
  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _inMemoryLogs.where((log) => log.level == level).toList();
  }

  // Obter logs filtrados por categoria
  List<LogEntry> getLogsByCategory(String category) {
    return _inMemoryLogs.where((log) => log.category == category).toList();
  }

  // Limpar todos os logs
  Future<void> clearLogs() async {
    _inMemoryLogs.clear();
    await _saveLogs();
    log(LogLevel.info, 'Logs limpos', category: 'system');
  }

  // Exportar logs para um arquivo
  Future<String?> exportLogs() async {
    try {
      if (_inMemoryLogs.isEmpty) {
        return null;
      }

      if (kIsWeb) {
        // Para web, retornamos uma string JSON
        final logsJson = jsonEncode(_inMemoryLogs.map((e) => e.toMap()).toList());
        return logsJson;
      } else {
        // Para dispositivos móveis, salvamos em um arquivo
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path = '${directory.path}/boxmagic_logs_$timestamp.txt';
        final file = File(path);

        final buffer = StringBuffer();
        for (final entry in _inMemoryLogs) {
          buffer.writeln(entry.toString());
        }

        await file.writeAsString(buffer.toString());
        return path;
      }
    } catch (e, stackTrace) {
      debugPrint('Erro ao exportar logs: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  // Carregar logs do armazenamento
  Future<void> _loadLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getStringList(_logsKey) ?? [];

      _inMemoryLogs.clear();
      for (final logJson in logsJson) {
        try {
          final entry = LogEntry.fromJson(logJson);
          _inMemoryLogs.add(entry);
        } catch (e) {
          // Ignorar entradas inválidas
          debugPrint('Erro ao carregar entrada de log: $e');
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar logs: $e');
    }
  }

  // Salvar logs no armazenamento
  Future<void> _saveLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = _inMemoryLogs.map((e) => e.toJson()).toList();
      await prefs.setStringList(_logsKey, logsJson);
    } catch (e) {
      debugPrint('Erro ao salvar logs: $e');
    }
  }
}
