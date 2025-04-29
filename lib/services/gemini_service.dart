import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:boxmagic/services/log_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;

  final LogService _logService = LogService();

  GeminiService._internal() {
    _logService.info('GeminiService inicializado', category: 'gemini');
  }

  // Nota: Em uma implementação real, usaríamos a API do Gemini
  // Esta é uma versão simulada para demonstração

  static const String _apiKeyPrefKey = 'gemini_api_key';

  /// Recupera a chave da API Gemini salva nas preferências.
  Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    // Chave padrão do repositório (substitua pelo valor real, se necessário)
    const String defaultApiKey = 'AIzaSyA...';
    return prefs.getString(_apiKeyPrefKey) ?? defaultApiKey;
  }

  /// Atualiza a chave da API Gemini nas preferências.
  Future<bool> updateApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_apiKeyPrefKey, apiKey);
  }

  // Reconhecer ID de caixa a partir de uma imagem
  Future<String?> recognizeBoxId(XFile imageFile) async {
    try {
      _logService.info('Iniciando reconhecimento de ID de caixa', category: 'gemini');
      _logService.debug('Arquivo de imagem: ${imageFile.path}', category: 'gemini');

      // PROMPT MELHORADO PARA GEMINI (para uso futuro com API real):
      // "Analise a imagem e identifique se há algum QR Code ou número de identificação de caixa escrito à mão (ex: 1001, 1002, etc). 
      // Se encontrar um QR Code, extraia o valor e retorne o tipo 'qr_code'.
      // Se encontrar um número escrito à mão, extraia o valor e retorne o tipo 'handwritten'.
      // Responda apenas com um JSON válido no formato:
      // { "type": "qr_code" | "handwritten", "value": "<id ou valor lido>" }
      // Se não encontrar nada, responda { "type": "none", "value": "" }
      // Não inclua nenhum texto extra além do JSON."

      // Simular o reconhecimento (em um app real, usaríamos a API do Gemini)
      // Retornar um ID aleatório entre 1001 e 1010 para simular o reconhecimento
      final simulatedId = 1000 + (DateTime.now().millisecondsSinceEpoch % 10) + 1;

      _logService.info('ID reconhecido: $simulatedId', category: 'gemini');
      return simulatedId.toString();
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

  // Analisar objeto e gerar nome e descrição
  Future<Map<String, String>?> analyzeObject(XFile imageFile) async {
    try {
      _logService.info('Iniciando análise de objeto', category: 'gemini');
      _logService.debug('Arquivo de imagem: ${imageFile.path}', category: 'gemini');

      final apiKey = await getApiKey();
      if (apiKey.isEmpty) {
        _logService.error('Chave da API Gemini não configurada', category: 'gemini');
        return null;
      }

      final prompt = '''
Analise a imagem de um produto.
Retorne um JSON com os seguintes campos:
- name: nome do produto identificado
- description: uma breve descrição do produto, com no máximo 2 linhas

Responda SOMENTE com um JSON válido.
''';

      // Carregar bytes da imagem
      final imageBytes = await imageFile.readAsBytes();

      // Usar o pacote google_generative_ai para enviar imagem e prompt
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ]),
      ];

      _logService.info('Enviando requisição para Gemini API (análise de objeto)...', category: 'gemini');
      print('[Gemini] Enviando requisição para Gemini API (análise de objeto)...');
      GenerateContentResponse response;
      try {
        response = await model.generateContent(content);
        _logService.info('Resposta recebida da Gemini API.', category: 'gemini');
        _logService.debug('Conteúdo bruto da resposta Gemini: \'${response.text}\'', category: 'gemini');
        print('[Gemini] Resposta recebida da Gemini API.');
        print('[Gemini] Conteúdo bruto da resposta: ${response.text}');
      } catch (e, stackTrace) {
        _logService.error('Erro de conexão ou requisição à Gemini API', error: e, stackTrace: stackTrace, category: 'gemini');
        print('[Gemini] Erro de conexão ou requisição à Gemini API: $e');
        return null;
      }

      final text = response.text;
      if (text == null || text.isEmpty) {
        _logService.error('Resposta vazia da Gemini API', category: 'gemini');
        print('[Gemini] Resposta vazia da Gemini API');
        return null;
      }

      // Extrair JSON da resposta
      Map<String, dynamic>? result;
      try {
        // Pode haver texto extra, tentar extrair apenas o JSON
        final jsonStart = text.indexOf('{');
        final jsonEnd = text.lastIndexOf('}');
        if (jsonStart == -1 || jsonEnd == -1) {
          _logService.error('JSON não encontrado na resposta da Gemini. Resposta completa: $text', category: 'gemini');
          print('[Gemini] JSON não encontrado na resposta da Gemini. Resposta completa: $text');
          throw Exception('JSON não encontrado na resposta');
        }
        final jsonString = text.substring(jsonStart, jsonEnd + 1);
        _logService.debug('JSON extraído da resposta Gemini: $jsonString', category: 'gemini');
        print('[Gemini] JSON extraído da resposta: $jsonString');
        result = jsonDecode(jsonString);
      } catch (e) {
        _logService.error('Erro ao extrair ou decodificar JSON da resposta Gemini: $e', category: 'gemini');
        print('[Gemini] Erro ao extrair ou decodificar JSON da resposta Gemini: $e');
        return null;
      }

      // Garantir categoria Diversos
      if (result == null) {
        _logService.error('O JSON extraído da resposta Gemini é nulo', category: 'gemini');
        return null;
      }
      final retorno = {
        'name': result['name']?.toString() ?? '',
        'description': result['description']?.toString() ?? '',
      };



      _logService.info('Objeto analisado: ${retorno['name']}', category: 'gemini');
      _logService.debug('Detalhes do objeto: $retorno', category: 'gemini');
      print('[Gemini] Objeto analisado: ${retorno['name']}');
      print('[Gemini] Detalhes do objeto: $retorno');
      return retorno;
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

  // Reconhecer texto manuscrito (incluindo letras cursivas) em uma imagem
  Future<String?> recognizeHandwrittenText(XFile imageFile) async {
    try {
      _logService.info('Iniciando reconhecimento de texto manuscrito', category: 'gemini');
      _logService.debug('Arquivo de imagem: ${imageFile.path}', category: 'gemini');

      // Simular o reconhecimento de texto manuscrito
      final simulatedTexts = [
        'Lista de compras:\n1. Leite\n2. Pão\n3. Ovos\n4. Frutas',
        'Reunião às 15:00 - Não esquecer!',
        'Ligar para João - (11) 98765-4321',
        'ID da caixa: 1234',
        'Caixa de ferramentas #2567',
      ];

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomIndex = timestamp % simulatedTexts.length;
      final result = simulatedTexts[randomIndex];

      _logService.info('Texto reconhecido', category: 'gemini');
      _logService.debug('Texto: $result', category: 'gemini');

      return result;
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

  // Nota: Este método seria usado em uma implementação real com a API do Gemini
  // para converter a imagem em bytes e enviá-la para a API
}
