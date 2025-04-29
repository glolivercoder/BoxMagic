# Reconhecimento de Objetos com Gemini API no Flutter

## Etapa 2/3 — Integração do Reconhecimento na Tela Flutter

---

## 1. Captura da Imagem

- Utilize o pacote `image_picker` para capturar a imagem via câmera ou galeria.
- Exemplo:
```dart
final ImagePicker _picker = ImagePicker();
final XFile? image = await _picker.pickImage(source: ImageSource.camera);
```

---

## 2. (Opcional) Extração de Texto via OCR

- Para melhorar a precisão, você pode extrair texto da imagem localmente usando o pacote `google_ml_kit`.
- Exemplo:
```dart
import 'package:google_ml_kit/google_ml_kit.dart';

Future<String> extractTextFromImage(XFile imageFile) async {
  final inputImage = InputImage.fromFilePath(imageFile.path);
  final textDetector = GoogleMlKit.vision.textDetector();
  final RecognisedText recognisedText = await textDetector.processImage(inputImage);
  await textDetector.close();
  return recognisedText.text;
}
```

---

## 3. Chamada ao Serviço Gemini

- No método de ação do botão (por exemplo, `_takePhoto`), após capturar a imagem e (opcionalmente) extrair o texto:

```dart
final ocrText = await extractTextFromImage(image); // Opcional
final geminiResult = await GeminiService().analyzeObject(image, ocrText: ocrText);
```

- Trate erros e estados de carregamento para melhor UX.

---

## 4. Preenchimento Automático do Formulário

- O JSON retornado pela Gemini API deve ser parseado e usado para preencher os campos. Garanta que a categoria seja sempre uma das permitidas (ex: 'Diversos', 'Eletrônicos', etc). Se vier uma categoria desconhecida, use 'Diversos':
```dart
const categoriasPermitidas = [
  'Eletrônicos',
  'Ferramentas manuais',
  'Ferramentas elétricas',
  'Informática',
  'Equipamentos de áudio',
  'Diversos',
];

if (geminiResult != null) {
  _nameController.text = geminiResult['name'] ?? '';
  _descriptionController.text = geminiResult['description'] ?? '';
  String categoria = geminiResult['category'] ?? 'Diversos';
  if (!categoriasPermitidas.contains(categoria)) {
    categoria = 'Diversos';
  }
  _selectedCategory = categoria;
}
```
- **Observação:** Oriente a Gemini no prompt: "Se não souber a categoria exata ou se for uma categoria muito específica, use sempre 'Diversos' para evitar criar categorias infinitas."
- **Dica:** Se houver código de barras (GTIN) na imagem ou texto extraído, a Gemini pode utilizá-lo para identificar o produto com maior precisão.

---

## 5. Exemplo de Fluxo Completo

```dart
Future<void> _takePhoto() async {
  setState(() { _isProcessing = true; });
  final XFile? image = await _picker.pickImage(source: ImageSource.camera);
  if (image != null) {
    final ocrText = await extractTextFromImage(image); // Opcional
    final geminiResult = await GeminiService().analyzeObject(image, ocrText: ocrText);
    if (geminiResult != null) {
      // Preencher campos automaticamente
      // ... (ver item 4)
    } else {
      // Tratar erro
    }
  }
  setState(() { _isProcessing = false; });
}
```

---

## 6. Dicas de UX

- Mostre um indicador de carregamento durante o processamento.
- Exiba mensagens claras em caso de erro (falha na API, imagem ruim, etc).
- Permita ao usuário editar manualmente os campos preenchidos.

---

## Etapa 3/3 — Prompt, Parsing e Segurança

### 1. Estruturando o Prompt para Diferentes Objetos

- Adapte o prompt para o contexto do seu app. Exemplos:
  - Produtos: "Analise a imagem de um produto e retorne um JSON com os campos: nome, categoria, descrição, código de barras, marca, etc."
  - Documentos: "Analise a imagem deste documento e retorne um JSON com os campos: nome, CPF, RG, datas, naturalidade, filiação."
- Sempre peça para responder apenas com JSON válido.
- Inclua o texto extraído por OCR no prompt para aumentar a precisão.

Exemplo:
```text
Analise a imagem enviada e o texto extraído por OCR abaixo. Retorne um JSON com os campos encontrados.
Texto OCR: ...
Responda somente com JSON válido.
```

### 2. Parsing Seguro da Resposta do Gemini

- O Gemini pode retornar texto com explicações antes ou depois do JSON. Use regex para extrair apenas o JSON.
- Exemplo em Dart:
```dart
import 'dart:convert';
final responseText = geminiResponse['candidates'][0]['content']['parts'][0]['text'];
final jsonMatch = RegExp(r'{[\s\S]*}').firstMatch(responseText);
if (jsonMatch != null) {
  final jsonData = jsonDecode(jsonMatch.group(0)!);
  // Use jsonData normalmente
}
```
- Trate erros de parsing e sempre valide os campos esperados.

### 3. Segurança e Uso da Chave da API

- Nunca exponha a chave da API Gemini em repositórios públicos.
- Use variáveis de ambiente ou arquivos de configuração fora do versionamento para armazenar a chave.
- Em produção, restrinja o uso da chave no console do Google Cloud (origem, quota, etc).

---

## Resumo Final

- O fluxo agora utiliza IA real para reconhecimento de objetos.
- O prompt pode ser adaptado conforme o contexto.
- O parsing seguro garante que apenas dados válidos sejam usados.
- A chave da API deve ser protegida.

Implemente, teste e evolua conforme a necessidade do seu negócio!
