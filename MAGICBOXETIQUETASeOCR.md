# MAGICBOX - Backup de Funcionalidades de Etiquetas e OCR

## Funcionalidades de Etiquetas

### Modelos de Etiquetas Pimaco
- Suporte para 8 modelos diferentes (A4363, A4204, A4381, 6080, 6081, 6082, 6180, 6185)
- Cada modelo com dimensões, margens e número de etiquetas por folha específicos
- Interface para seleção entre modelos predefinidos

### Personalização de Etiquetas
- Interface para personalizar etiquetas
- Campos para ajustar altura, largura, margens, espaçamento e quantidade
- Botão para aplicar alterações

### Opções de Conteúdo
- Três opções de conteúdo:
  1. Apenas ID e código de barras
  2. ID, código de barras e nome da caixa
  3. ID, código de barras, nome e conteúdo da caixa

### Preview e Exportação
- Visualização em tela cheia do PDF gerado
- Botões para imprimir e compartilhar
- Exportação para PDF em A4
- Compartilhamento simplificado

### Código Principal de Etiquetas

```dart
// Modelo de Etiqueta
class Etiqueta {
  final String nome;
  final double alturaCm;
  final double larguraCm;
  final double margemSuperiorCm;
  final double margemInferiorCm;
  final double margemEsquerdaCm;
  final double margemDireitaCm;
  final double espacoEntreEtiquetasCm;
  final int etiquetasPorFolha;
  final bool personalizada;

  Etiqueta({
    required this.nome,
    required this.alturaCm,
    required this.larguraCm,
    required this.margemSuperiorCm,
    required this.margemInferiorCm,
    required this.margemEsquerdaCm,
    required this.margemDireitaCm,
    required this.espacoEntreEtiquetasCm,
    required this.etiquetasPorFolha,
    this.personalizada = false,
  });
}

// Tipo de conteúdo da etiqueta
enum TipoEtiqueta { idApenas, idENome, idNomeEConteudo }

// Método para gerar o PDF
Future<pw.Document> _gerarPdf() async {
  final pdf = pw.Document();
  final etiqueta = _selectedEtiqueta!;

  // Carregar a fonte para o código de barras
  final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
  final ttf = pw.Font.ttf(fontData);

  // Converter cm para pontos (1 cm = 28.35 pontos)
  final alturaPt = etiqueta.alturaCm * 28.35;
  final larguraPt = etiqueta.larguraCm * 28.35;
  final margemSuperiorPt = etiqueta.margemSuperiorCm * 28.35;
  final margemInferiorPt = etiqueta.margemInferiorCm * 28.35;
  final margemEsquerdaPt = etiqueta.margemEsquerdaCm * 28.35;
  final margemDireitaPt = etiqueta.margemDireitaCm * 28.35;
  final espacoEntreEtiquetasPt = etiqueta.espacoEntreEtiquetasCm * 28.35;

  // Calcular o número de colunas e linhas
  final pageWidth = PdfPageFormat.a4.width;
  final pageHeight = PdfPageFormat.a4.height;

  final areaUtilWidth = pageWidth - margemEsquerdaPt - margemDireitaPt;
  final areaUtilHeight = pageHeight - margemSuperiorPt - margemInferiorPt;

  final numColunas = (areaUtilWidth / (larguraPt + espacoEntreEtiquetasPt)).floor();
  final numLinhas = (areaUtilHeight / (alturaPt + espacoEntreEtiquetasPt)).floor();

  // Calcular o número de etiquetas por página
  final etiquetasPorPagina = numColunas * numLinhas;

  // Simular dados de caixas para demonstração
  final caixas = List.generate(
    etiqueta.etiquetasPorFolha,
    (index) => {
      'id': (1000 + index).toString().padLeft(4, '0'),
      'nome': 'Caixa ${(1000 + index).toString().padLeft(4, '0')}',
      'conteudo': 'Livros, documentos, fotos',
    },
  );

  // Calcular o número de páginas necessárias
  final numPaginas = (caixas.length / etiquetasPorPagina).ceil();

  // Gerar as páginas
  for (int pagina = 0; pagina < numPaginas; pagina++) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.only(
          top: margemSuperiorPt,
          bottom: margemInferiorPt,
          left: margemEsquerdaPt,
          right: margemDireitaPt,
        ),
        build: (context) {
          // Calcular o número de etiquetas nesta página
          final etiquetasRestantes = caixas.length - (pagina * etiquetasPorPagina);
          final etiquetasNestaPagina = etiquetasRestantes > etiquetasPorPagina
              ? etiquetasPorPagina
              : etiquetasRestantes;

          // Criar uma grade de etiquetas
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: List.generate(numLinhas, (linha) {
              return pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: List.generate(numColunas, (coluna) {
                  final index = linha * numColunas + coluna;

                  // Verificar se ainda há etiquetas para mostrar
                  if (index >= etiquetasNestaPagina) {
                    return pw.SizedBox(
                      width: larguraPt,
                      height: alturaPt,
                    );
                  }

                  // Obter os dados da caixa
                  final caixaIndex = pagina * etiquetasPorPagina + index;
                  if (caixaIndex >= caixas.length) {
                    return pw.SizedBox(
                      width: larguraPt,
                      height: alturaPt,
                    );
                  }

                  final caixa = caixas[caixaIndex];
                  final caixaId = caixa['id'] as String;
                  final caixaNome = caixa['nome'] as String;
                  final caixaConteudo = caixa['conteudo'] as String;

                  return pw.Padding(
                    padding: pw.EdgeInsets.only(
                      right: coluna < numColunas - 1 ? espacoEntreEtiquetasPt : 0,
                      bottom: linha < numLinhas - 1 ? espacoEntreEtiquetasPt : 0,
                    ),
                    child: pw.Container(
                      width: larguraPt,
                      height: alturaPt,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black),
                      ),
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            // Código de barras (sempre presente)
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.code128(),
                              data: caixaId,
                              width: larguraPt * 0.8,
                              height: 30,
                              drawText: true,
                              textStyle: pw.TextStyle(
                                font: ttf,
                                fontSize: 8,
                              ),
                            ),

                            pw.SizedBox(height: 5),

                            // ID da caixa (sempre presente)
                            pw.Text(
                              'ID: $caixaId',
                              style: pw.TextStyle(
                                font: ttf,
                                fontSize: 10,
                              ),
                            ),

                            // Nome da caixa (presente em idENome e idNomeEConteudo)
                            if (_tipoEtiqueta == TipoEtiqueta.idENome ||
                                _tipoEtiqueta == TipoEtiqueta.idNomeEConteudo) ...[
                              pw.SizedBox(height: 5),
                              pw.Text(
                                caixaNome,
                                style: pw.TextStyle(
                                  font: ttf,
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ],

                            // Conteúdo da caixa (apenas em idNomeEConteudo)
                            if (_tipoEtiqueta == TipoEtiqueta.idNomeEConteudo && alturaPt > 100) ...[
                              pw.SizedBox(height: 5),
                              pw.Container(
                                width: larguraPt * 0.9,
                                child: pw.Text(
                                  'Conteúdo: $caixaConteudo',
                                  style: pw.TextStyle(
                                    font: ttf,
                                    fontSize: 8,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
          );
        },
      ),
    );
  }

  return pdf;
}
```

## Funcionalidades de OCR e Reconhecimento com Gemini

### Reconhecimento de IDs de Caixas
- Uso da câmera para reconhecer IDs de caixas
- Integração com Google ML Kit para OCR
- Busca automática da caixa pelo ID reconhecido

### Reconhecimento de Objetos com IA
- Integração com API Gemini para reconhecimento de objetos
- Geração automática de descrições para objetos fotografados
- Preenchimento automático de campos de nome e descrição

### Modo de Reconhecimento Contínuo
- Funcionalidade para reconhecimento contínuo de objetos
- Adição rápida de múltiplos objetos em sequência
- Interface otimizada para uso em inventários

### Código Principal de OCR e Gemini

```dart
// Chave da API Gemini
final String apiKey = 'AIzaSyD7bbOPh0BVjPISXAdHM5djJc-tLU0dmi8';

// Método para reconhecimento de texto (OCR)
Future<String> recognizeText(InputImage inputImage) async {
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
  
  String text = recognizedText.text;
  for (TextBlock block in recognizedText.blocks) {
    for (TextLine line in block.lines) {
      for (TextElement element in line.elements) {
        // Procurar por padrões de ID de caixa (4 dígitos)
        if (RegExp(r'^\d{4}$').hasMatch(element.text)) {
          return element.text;
        }
      }
    }
  }
  
  textRecognizer.close();
  return text;
}

// Método para reconhecimento de objetos com Gemini
Future<Map<String, String>> recognizeObjectWithGemini(XFile imageFile) async {
  try {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    
    final model = GenerativeModel(
      model: 'gemini-pro-vision',
      apiKey: apiKey,
    );
    
    final prompt = '''
    Analise esta imagem de um objeto e forneça:
    1. Um nome curto e descritivo para o objeto (máximo 30 caracteres)
    2. Uma categoria adequada para o objeto (Eletrônicos, Livros, Documentos, Roupas, Ferramentas, Decoração, Brinquedos, Diversos)
    3. Uma descrição detalhada do objeto (máximo 100 caracteres)
    
    Responda no formato:
    Nome: [nome do objeto]
    Categoria: [categoria]
    Descrição: [descrição detalhada]
    ''';
    
    final content = [
      Content.text(prompt),
      Content.image(base64Image),
    ];
    
    final response = await model.generateContent(content);
    final responseText = response.text;
    
    // Extrair informações da resposta
    final nameMatch = RegExp(r'Nome: (.*?)(\n|$)').firstMatch(responseText);
    final categoryMatch = RegExp(r'Categoria: (.*?)(\n|$)').firstMatch(responseText);
    final descriptionMatch = RegExp(r'Descrição: (.*?)(\n|$)').firstMatch(responseText);
    
    final name = nameMatch?.group(1)?.trim() ?? 'Objeto não identificado';
    final category = categoryMatch?.group(1)?.trim() ?? 'Diversos';
    final description = descriptionMatch?.group(1)?.trim() ?? '';
    
    return {
      'name': name,
      'category': category,
      'description': description,
    };
  } catch (e) {
    return {
      'name': 'Erro no reconhecimento',
      'category': 'Diversos',
      'description': 'Ocorreu um erro ao analisar a imagem: $e',
    };
  }
}

// Método para modo de reconhecimento contínuo
Future<void> startContinuousRecognition(Function(Map<String, String>) onObjectRecognized) async {
  final controller = CameraController(
    cameras.first,
    ResolutionPreset.medium,
    enableAudio: false,
  );
  
  await controller.initialize();
  await controller.startImageStream((image) async {
    // Processar apenas a cada 2 segundos para evitar sobrecarga
    if (_lastProcessingTime == null || 
        DateTime.now().difference(_lastProcessingTime!).inSeconds >= 2) {
      _lastProcessingTime = DateTime.now();
      
      // Converter CameraImage para XFile
      final xFile = await _convertCameraImageToXFile(image);
      
      // Reconhecer objeto com Gemini
      final objectData = await recognizeObjectWithGemini(xFile);
      
      // Chamar callback com os dados reconhecidos
      onObjectRecognized(objectData);
    }
  });
}
```

## Integração com o Aplicativo Principal

Para integrar estas funcionalidades no aplicativo principal:

1. Adicione as dependências necessárias no pubspec.yaml:
   - pdf: ^3.10.8
   - printing: ^5.12.0
   - barcode: ^2.2.4
   - google_generative_ai: ^0.4.7
   - google_ml_kit: ^0.16.3
   - google_mlkit_text_recognition: ^0.11.0
   - camera: ^0.11.1
   - image_picker: ^1.1.2

2. Importe os arquivos de modelo e telas:
   - models/etiqueta.dart
   - data/modelos_pimaco.dart
   - screens/etiquetas_screen.dart
   - screens/object_recognition_screen.dart
   - screens/continuous_recognition_screen.dart

3. Adicione os botões na interface principal:
   - Botão de impressão de etiquetas na tela de caixas
   - Botão de reconhecimento de objetos na tela de itens
   - Botão de reconhecimento de IDs na tela de caixas

4. Configure a chave da API Gemini no arquivo .env ou diretamente no código.

## Observações Importantes

- A funcionalidade de etiquetas depende das bibliotecas pdf e printing
- O reconhecimento de objetos requer a API Gemini configurada corretamente
- O OCR funciona melhor com boa iluminação e texto claro
- Mantenha backup deste arquivo para restaurar funcionalidades em caso de perda
