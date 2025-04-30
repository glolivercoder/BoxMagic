import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:boxmagic/services/log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;

  final LogService _logService = LogService();
  static const String _apiKeyPrefKey = 'gemini_api_key';
  GenerativeModel? _model;
  bool _isInitialized = false;

  GeminiService._internal() {
    _logService.info('GeminiService inicializado', category: 'gemini');
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      final apiKey = await getApiKey();
      _model = GenerativeModel(
        model: 'gemini-pro-vision',
        apiKey: apiKey,
      );
      _isInitialized = true;
      _logService.info('GeminiService inicializado com sucesso', category: 'gemini');
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao inicializar GeminiService',
        error: e,
        stackTrace: stackTrace,
        category: 'gemini',
      );
    }
  }

  Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPrefKey) ?? '';
  }

  Future<bool> updateApiKey(String apiKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_apiKeyPrefKey, apiKey);
      
      // Reinicializar o modelo com a nova chave
      _model = GenerativeModel(
        model: 'gemini-pro-vision',
        apiKey: apiKey,
      );
      
      _logService.info('Chave da API Gemini atualizada com sucesso', category: 'gemini');
      return true;
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao atualizar chave da API Gemini',
        error: e,
        stackTrace: stackTrace,
        category: 'gemini',
      );
      return false;
    }
  }

  Future<String?> recognizeBoxId(XFile imageFile) async {
    try {
      if (!_isInitialized) await _initialize();
      if (_model == null) throw Exception('Modelo Gemini não inicializado');

      _logService.info('Iniciando reconhecimento de ID de caixa', category: 'gemini');
      final bytes = await imageFile.readAsBytes();

      final content = [
        Content.multi([
          TextPart('Analise esta imagem e encontre um número de identificação de caixa com exatamente 4 dígitos. '
                  'O número pode estar precedido pelo símbolo # (por exemplo, #1234). '
                  'Retorne apenas os 4 dígitos encontrados, sem o símbolo # e sem texto adicional. '
                  'Se não encontrar um número de 4 dígitos, retorne "NÃO ENCONTRADO".'),
          DataPart('image/jpeg', bytes),
        ]),
      ];

      final response = await _model!.generateContent(content);
      final text = response.text?.trim() ?? '';

      // Regex para extrair 4 dígitos, com ou sem # prefixo
      final regex = RegExp(r'#?(\d{4})');
      final match = regex.firstMatch(text);
      
      if (match != null) {
        final digits = match.group(1)!;
        _logService.info('ID da caixa reconhecido: $digits', category: 'gemini');
        return digits;
      } else {
        _logService.warning('ID da caixa não encontrado na imagem', category: 'gemini');
        return null;
      }
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao reconhecer ID da caixa',
        error: e,
        stackTrace: stackTrace,
        category: 'gemini',
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> analyzeObject(XFile imageFile) async {
    try {
      if (!_isInitialized) await _initialize();
      if (_model == null) throw Exception('Modelo Gemini não inicializado');

      _logService.info('Iniciando análise de objeto', category: 'gemini');
      final bytes = await imageFile.readAsBytes();

      final content = [
        Content.multi([
          TextPart('Analise esta imagem e descreva o objeto principal em formato JSON com os seguintes campos:\n'
                  '- name: Nome do objeto em português (curto e preciso, máximo 3 palavras)\n'
                  '- description: Descrição breve do objeto em português (máximo 100 caracteres)\n\n'
                  'Retorne apenas o JSON, sem texto adicional.'),
          DataPart('image/jpeg', bytes),
        ]),
      ];

      final response = await _model!.generateContent(content);
      final text = response.text ?? '';

      try {
        final jsonStart = text.indexOf('{');
        final jsonEnd = text.lastIndexOf('}');
        if (jsonStart == -1 || jsonEnd == -1) {
          throw FormatException('JSON não encontrado na resposta');
        }

        final jsonString = text.substring(jsonStart, jsonEnd + 1);
        final jsonData = jsonDecode(jsonString);

        final result = {
          'name': jsonData['name'] ?? 'Objeto não identificado',
          'description': jsonData['description'] ?? 'Sem descrição disponível',
        };

        _logService.info('Objeto analisado com sucesso: ${result['name']}', category: 'gemini');
        return result;
      } catch (e) {
        _logService.error('Erro ao processar resposta JSON', error: e, category: 'gemini');
        return {
          'name': 'Objeto não identificado',
          'description': 'Não foi possível analisar o objeto na imagem.'
        };
      }
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao analisar objeto',
        error: e,
        stackTrace: stackTrace,
        category: 'gemini',
      );
      return null;
    }
  }

  Future<String?> recognizeHandwrittenText(XFile imageFile) async {
    try {
      if (!_isInitialized) await _initialize();
      if (_model == null) throw Exception('Modelo Gemini não inicializado');

      _logService.info('Iniciando reconhecimento de texto manuscrito', category: 'gemini');
      final bytes = await imageFile.readAsBytes();

      final content = [
        Content.multi([
          TextPart('Leia e transcreva qualquer texto manuscrito presente nesta imagem. '
                  'Retorne apenas o texto encontrado, sem comentários adicionais.'),
          DataPart('image/jpeg', bytes),
        ]),
      ];

      final response = await _model!.generateContent(content);
      final text = response.text?.trim();

      if (text != null && text.isNotEmpty) {
        _logService.info('Texto manuscrito reconhecido com sucesso', category: 'gemini');
        return text;
      } else {
        _logService.warning('Nenhum texto manuscrito encontrado', category: 'gemini');
        return null;
      }
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao reconhecer texto manuscrito',
        error: e,
        stackTrace: stackTrace,
        category: 'gemini',
      );
      return null;
    }
  }
}
