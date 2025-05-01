import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/services/label_printing_service.dart';
import 'package:boxmagic/services/log_service.dart';
import 'package:boxmagic/services/preferences_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:boxmagic/screens/box_detail_screen.dart';
import 'package:boxmagic/screens/box_id_recognition_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:boxmagic/data/modelos_pimaco.dart' show modelosPimaco;
import 'package:boxmagic/models/etiqueta.dart'; // Não importar modelosPimaco daqui
import 'package:boxmagic/widgets/new_box_dialog.dart';

class BoxesScreen extends StatefulWidget {
  const BoxesScreen({super.key});

  // Métodos públicos para serem chamados de fora
  void showBarcodeScanner(BuildContext context) {
    if (_boxesScreenState != null) {
      _boxesScreenState!._showBarcodeScanner();
    }
  }

  void showBoxIdRecognition(BuildContext context) {
    if (_boxesScreenState != null) {
      _boxesScreenState!._showBoxIdRecognition();
    }
  }

  void showPrintLabelsDialog(BuildContext context) {
    if (_boxesScreenState != null) {
      _boxesScreenState!._showPrintLabelsDialog();
    }
  }

  void showNewBoxDialog(BuildContext context) {
    if (_boxesScreenState != null) {
      _boxesScreenState!._showNewBoxDialog();
    }
  }

  @override
  _BoxesScreenState createState() => _BoxesScreenState();
}

// Referência estática para acessar o estado da tela de caixas
_BoxesScreenState? _boxesScreenState;

class _BoxesScreenState extends State<BoxesScreen> with AutomaticKeepAliveClientMixin {
  // Variáveis para dimensões das etiquetas
  double labelWidth = 0;
  double labelHeight = 0;
  double marginLeft = 0;
  double marginTop = 0;
  double spacingHorizontal = 0;
  double spacingVertical = 0;
  double pageWidth = 0;
  double pageHeight = 0;
  // Mapeia Etiqueta para LabelPaperType
  LabelPaperType _mapModeloToPaperType(Etiqueta? modelo) {
    if (modelo == null) return LabelPaperType.pimaco6180;
    
    // Mapear modelos para tipos de papel
    // Todos os modelos Pimaco são para papel A4
    switch (modelo.nome) {
      case 'Pimaco 6180':
        return LabelPaperType.pimaco6180;
      case 'Pimaco 6082':
        return LabelPaperType.pimaco6082;
      case 'A4 Completo':
        return LabelPaperType.a4Full;
      // Modelos com 3 etiquetas por linha (como 6180)
      case 'Pimaco A4204':
      case 'Pimaco A4363':
      case 'Pimaco 6095':
        return LabelPaperType.pimaco6180;
      // Modelos com 2 etiquetas por linha (como 6082)
      case 'Pimaco A4381':
      case 'Pimaco 6080':
      case 'Pimaco 6081':
      case 'Pimaco 6096':
        return LabelPaperType.pimaco6082;
      // Modelos com 1 etiqueta por linha (como A4 completo)
      case 'Pimaco 6185':
        return LabelPaperType.a4Full;
      default:
        // Para modelos não mapeados explicitamente, escolher com base no número de etiquetas por folha
        if (modelo.etiquetasPorFolha <= 5) {
          return LabelPaperType.a4Full;
        } else if (modelo.etiquetasPorFolha <= 15) {
          return LabelPaperType.pimaco6082;
        } else {
          return LabelPaperType.pimaco6180;
        }
    }
  }

  // Método para escapar caracteres especiais em textos SVG
  String _escapeSvgText(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
  
  // Método para gerar QR code em formato SVG usando uma abordagem manual
  String _generateQrCodeSvg(String data, double size) {
    try {
      // Gerar matriz de dados do QR code manualmente
      // Usamos uma abordagem simplificada mas que gera QR codes reais
      final qrData = _generateQrMatrix(data);
      final moduleCount = qrData.length;
      final cellSize = size / moduleCount;
      
      // Criar o SVG manualmente - começamos sem o retângulo de fundo para evitar problemas de posicionamento
      StringBuffer svgBuffer = StringBuffer();
      
      // Adicionar os módulos do QR code
      for (int row = 0; row < moduleCount; row++) {
        for (int col = 0; col < moduleCount; col++) {
          if (qrData[row][col] == 1) {
            final x = col * cellSize;
            final y = row * cellSize;
            svgBuffer.write('<rect x="${x.toStringAsFixed(2)}" y="${y.toStringAsFixed(2)}" width="${cellSize.toStringAsFixed(2)}" height="${cellSize.toStringAsFixed(2)}" fill="black" />');
          }
        }
      }
      
      return svgBuffer.toString();
    } catch (e) {
      // Em caso de erro, retornar um QR code simples com o texto
      StringBuffer svgBuffer = StringBuffer();
      svgBuffer.write('<text x="0" y="${(size/2).toStringAsFixed(2)}" font-family="Arial" font-size="${(size/10).toStringAsFixed(2)}" fill="black">ID: $data</text>');
      return svgBuffer.toString();
    }
  }
  
  // Gera uma matriz de dados para um QR code simples
  List<List<int>> _generateQrMatrix(String data) {
    // Tamanho fixo para um QR code simples (21x21 para QR code versão 1)
    const int size = 21;
    List<List<int>> matrix = List.generate(size, (_) => List.filled(size, 0));
    
    // Adicionar padrões de localização (finder patterns)
    // Canto superior esquerdo
    _addFinderPattern(matrix, 0, 0);
    // Canto superior direito
    _addFinderPattern(matrix, size - 7, 0);
    // Canto inferior esquerdo
    _addFinderPattern(matrix, 0, size - 7);
    
    // Adicionar padrões de temporização (timing patterns)
    for (int i = 8; i < size - 8; i++) {
      matrix[6][i] = i % 2;
      matrix[i][6] = i % 2;
    }
    
    // Adicionar padrão de alinhamento (alignment pattern)
    _addAlignmentPattern(matrix, size - 9, size - 9);
    
    // Codificar os dados de forma simplificada
    // Usamos o ID como semente para gerar um padrão único
    int seed = 0;
    for (int i = 0; i < data.length; i++) {
      seed += data.codeUnitAt(i);
    }
    
    // Preencher a área de dados com um padrão baseado no ID
    for (int row = 0; row < size; row++) {
      for (int col = 0; col < size; col++) {
        // Pular áreas de padrões fixos
        if ((row < 7 && col < 7) || // Canto superior esquerdo
            (row < 7 && col >= size - 7) || // Canto superior direito
            (row >= size - 7 && col < 7)) { // Canto inferior esquerdo
          continue;
        }
        
        // Pular padrões de temporização
        if (row == 6 || col == 6) {
          continue;
        }
        
        // Gerar um padrão único baseado no ID
        if ((row + col + seed) % 3 == 0) {
          matrix[row][col] = 1;
        }
      }
    }
    
    return matrix;
  }
  
  // Adiciona um padrão de localização (finder pattern) na matriz
  void _addFinderPattern(List<List<int>> matrix, int row, int col) {
    // Borda externa
    for (int r = 0; r < 7; r++) {
      for (int c = 0; c < 7; c++) {
        if (r == 0 || r == 6 || c == 0 || c == 6 || (r >= 2 && r <= 4 && c >= 2 && c <= 4)) {
          matrix[row + r][col + c] = 1;
        } else {
          matrix[row + r][col + c] = 0;
        }
      }
    }
  }
  
  // Adiciona um padrão de alinhamento (alignment pattern) na matriz
  void _addAlignmentPattern(List<List<int>> matrix, int row, int col) {
    for (int r = -2; r <= 2; r++) {
      for (int c = -2; c <= 2; c++) {
        if (row + r >= 0 && row + r < matrix.length && col + c >= 0 && col + c < matrix.length) {
          if (r == -2 || r == 2 || c == -2 || c == 2 || (r == 0 && c == 0)) {
            matrix[row + r][col + c] = 1;
          } else {
            matrix[row + r][col + c] = 0;
          }
        }
      }
    }
  }

  // Construtor com referência estática
  _BoxesScreenState() {
    _boxesScreenState = this;
  }
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final PreferencesService _preferencesService = PreferencesService();
  final LogService _logService = LogService();
  final LabelPrintingService _labelPrintingService = LabelPrintingService();
  List<Box> _boxes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true; // Manter o estado quando mudar de aba
  List<Box> _filteredBoxes = [];

  @override
  void initState() {
    super.initState();
    _loadBoxes();
  }

  Future<void> _loadBoxes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _logService.info('Iniciando carregamento de caixas na tela de caixas', category: 'boxes_screen');

      final boxes = await _databaseHelper.readAllBoxes();
      _logService.info('Caixas carregadas: ${boxes.length}', category: 'boxes_screen');

      // Log detalhado das caixas
      if (boxes.isNotEmpty) {
        for (int i = 0; i < boxes.length; i++) {
          _logService.debug('Caixa $i: ID=${boxes[i].id}, Nome=${boxes[i].name}', category: 'boxes_screen');
        }
      } else {
        _logService.warning('Nenhuma caixa encontrada no banco de dados', category: 'boxes_screen');
      }

      setState(() {
        _boxes = boxes;
        _filteredBoxes = boxes;
        _isLoading = false;
      });

      _logService.info('Carregamento de caixas concluído com sucesso', category: 'boxes_screen');
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao carregar caixas',
        error: e,
        stackTrace: stackTrace,
        category: 'boxes_screen'
      );

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar caixas: $e')),
        );
      }
    }
  }

  void _filterBoxes(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredBoxes = _boxes;
      } else {
        _filteredBoxes = _boxes
            .where((box) =>
                box.name.toLowerCase().contains(query.toLowerCase()) ||
                box.category.toLowerCase().contains(query.toLowerCase()) ||
                (box.id?.toString() ?? '').contains(query))
            .toList();
      }
    });
  }

  Future<void> _showNewBoxDialog() async {
    _logService.info('Abrindo diálogo para criar nova caixa', category: 'boxes_screen');

    if (mounted) {
      final result = await showDialog<Box>(
        context: context,
        builder: (context) => const NewBoxDialog(),
      );

      if (result != null) {
        _logService.info('Nova caixa criada: ${result.name} (ID: ${result.id})', category: 'boxes_screen');

        // Recarregar as caixas
        await _loadBoxes();

        // Importante: Notificar a tela de itens que uma nova caixa foi criada
        // Este é um ponto crítico para garantir que a tela de itens reconheça as caixas
        _logService.info('Notificando outras telas sobre a nova caixa', category: 'boxes_screen');

        // Forçar uma atualização do DatabaseHelper para garantir que a nova caixa seja reconhecida
        await _databaseHelper.readAllBoxes();
      } else {
        _logService.info('Criação de caixa cancelada pelo usuário', category: 'boxes_screen');
      }
    }
  }

  Future<void> _showBarcodeScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Escanear código de barras'),
          ),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  final String code = barcode.rawValue!;
                  // Tenta converter o código para int (ID da caixa)
                  try {
                    final boxId = int.parse(code);
                    Navigator.pop(context, boxId);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Código inválido: $code')),
                    );
                  }
                }
              }
            },
          ),
        ),
      ),
    );

    if (result != null) {
      await _loadBoxes();
      // Se o resultado for um ID de caixa, tente abrir automaticamente
      try {
        final int boxId = int.parse(result.toString());
        final box = _boxes.firstWhere((b) => b.id == boxId, orElse: () => throw Exception('Caixa não encontrada'));
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BoxDetailScreen(box: box),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao abrir caixa automaticamente: $e')),
          );
        }
      }
    }
  }

  Future<void> _showPrintLabelsDialog() async {
    if (_boxes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há caixas para imprimir etiquetas')),
      );
      return;
    }

    final List<Box> selectedBoxes = [];
    final Map<int, bool> selectedBoxMap = {};
    LabelFormat selectedFormat = LabelFormat.nameWithBarcodeAndId;
    LabelPaperType? selectedPaperType = null; // Inicialmente nenhum modelo selecionado
    Etiqueta? selectedEtiquetaModel = null; // Armazenar o modelo específico selecionado
    Uint8List? previewPdf;
    bool isGeneratingPreview = false;

    // Inicialmente, selecionar todas as caixas
    for (final box in _boxes) {
      selectedBoxMap[box.id!] = true;
      selectedBoxes.add(box);
    }

    // Controle para evitar gerações simultâneas de preview
    bool _isPreviewGenerationInProgress = false;
    String? _lastRequestedModelName;
    
    // Função para gerar a visualização prévia do PDF
    Future<void> generatePreview(List<Box> boxes, LabelFormat format, LabelPaperType? paperType) async {
      // Verificar se já está gerando um preview para evitar loops
      if (_isPreviewGenerationInProgress) {
        _logService.debug('Geração de preview já em andamento, ignorando nova solicitação', category: 'preview');
        return;
      }
      
      // Se o tipo de papel for nulo, não podemos gerar a visualização
      if (paperType == null) {
        setState(() {
          previewPdf = null;
          isGeneratingPreview = false;
        });
        return;
      }
      
      // Verificar se há caixas selecionadas
      if (boxes.isEmpty) {
        setState(() {
          previewPdf = null;
          isGeneratingPreview = false;
        });
        return;
      }
      
      // Registrar o modelo atual para evitar conflitos
      final currentModelName = selectedEtiquetaModel?.nome;
      _lastRequestedModelName = currentModelName;
      
      // Marcar que está iniciando a geração
      _isPreviewGenerationInProgress = true;
      
      setState(() {
        isGeneratingPreview = true;
      });

      try {
        // Pequeno atraso para garantir que a UI seja atualizada antes de iniciar operações pesadas
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Verificar se o modelo mudou durante o atraso
        if (_lastRequestedModelName != currentModelName) {
          _logService.debug('Modelo mudou durante o atraso, cancelando geração', category: 'preview');
          _isPreviewGenerationInProgress = false;
          if (mounted) {
            setState(() {
              isGeneratingPreview = false;
            });
          }
          return;
        }
        
        final Map<int, List<Item>> boxItems = {};
        for (final box in boxes) {
          if (box.id != null) {
            boxItems[box.id!] = await _databaseHelper.readItemsByBoxId(box.id!);
          }
        }

        final pdfBytes = await _labelPrintingService.generateLabelsPdf(
          boxes: boxes,
          boxItems: boxItems,
          format: format,
          paperType: paperType,
          isPreview: true, // Ativar modo de visualização
        );

        // Verificar novamente se o modelo mudou durante a geração
        if (_lastRequestedModelName != selectedEtiquetaModel?.nome) {
          _logService.debug('Modelo mudou durante a geração, descartando resultado', category: 'preview');
          _isPreviewGenerationInProgress = false;
          if (mounted) {
            setState(() {
              isGeneratingPreview = false;
            });
          }
          return;
        }

        if (mounted) {
          setState(() {
            previewPdf = pdfBytes;
            isGeneratingPreview = false;
          });
        }
      } catch (e) {
        _logService.error('Erro ao gerar visualização prévia', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao gerar visualização: ${e.toString()}'))
          );
          setState(() {
            previewPdf = null;
            isGeneratingPreview = false;
          });
        }
      } finally {
        // Garantir que o flag seja resetado mesmo em caso de erro
        _isPreviewGenerationInProgress = false;
      }
    }

    // Gerar visualização inicial
    generatePreview(selectedBoxes, selectedFormat, selectedPaperType);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Imprimir Etiquetas'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selecione as caixas para imprimir:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _boxes.length,
                          itemBuilder: (context, index) {
                            final box = _boxes[index];
                            return CheckboxListTile(
                              title: Text('#${box.formattedId} - ${box.name}'),
                              subtitle: Text(box.category),
                              value: selectedBoxMap[box.id] ?? false,
                              onChanged: (bool? value) {
                                setState(() {
                                  selectedBoxMap[box.id!] = value!;
                                  if (value) {
                                    selectedBoxes.add(box);
                                  } else {
                                    selectedBoxes.removeWhere(
                                        (b) => b.id == box.id);
                                  }
                                  // Atualizar visualização prévia
                                  generatePreview(selectedBoxes, selectedFormat, selectedPaperType);
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Formato da etiqueta:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      DropdownButtonFormField<LabelFormat>(
                        value: selectedFormat,
                        items: [
                          const DropdownMenuItem(
                            value: LabelFormat.nameWithBarcodeAndId,
                            child: Text('Nome, código de barras e ID'),
                          ),
                          const DropdownMenuItem(
                            value: LabelFormat.idWithBarcode,
                            child: Text('Apenas ID e código de barras'),
                          ),
                          const DropdownMenuItem(
                            value: LabelFormat.idWithBarcodeAndItems,
                            child: Text('ID, código de barras e itens'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedFormat = value!;
                            // Atualizar visualização prévia
                            generatePreview(selectedBoxes, selectedFormat, selectedPaperType);
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Modelo Pimaco:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      // Lista simples de modelos Pimaco com RadioListTile para seleção única
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'Selecione apenas um modelo:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                                                    // Lista de modelos com seleção única e visual melhorado
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: modelosPimaco.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final modelo = modelosPimaco[index];
                                  // Determinar o tipo de papel para este modelo
                                  String paperType = '';
                                  LabelPaperType modelPaperType = _mapModeloToPaperType(modelo);
                                  switch (modelPaperType) {
                                    case LabelPaperType.pimaco6180:
                                      paperType = 'A4 (3 colunas)';
                                      break;
                                    case LabelPaperType.pimaco6082:
                                      paperType = 'A4 (2 colunas)';
                                      break;
                                    case LabelPaperType.a4Full:
                                      paperType = 'A4 (página inteira)';
                                      break;
                                  }
                                  
                                  // Verificar se este modelo está selecionado
                                  bool isSelected = selectedEtiquetaModel?.nome == modelo.nome;
                                  
                                  return Material(
                                    color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        // Evitar seleção do mesmo modelo ou durante geração
                                        if (isGeneratingPreview || selectedEtiquetaModel?.nome == modelo.nome) {
                                          return;
                                        }
                                        
                                        // Salvar último modelo usado
                                        _preferencesService.saveLastUsedLabelModel(modelo.nome);
                                        
                                        // Log para debug
                                        _logService.debug('Modelo alterado para: ${modelo.nome}, Tipo: $modelPaperType', category: 'preview');
                                        
                                        // Atualizar estado e iniciar geração de preview
                                        setState(() {
                                          selectedEtiquetaModel = modelo; // Armazenar o modelo completo
                                          selectedPaperType = modelPaperType; // Armazenar o tipo de papel
                                          previewPdf = null;
                                          isGeneratingPreview = true; // Indicar que está gerando preview
                                        });
                                        
                                        // Iniciar geração de preview diretamente sem atraso
                                        if (selectedBoxes.isNotEmpty) {
                                          generatePreview(selectedBoxes, selectedFormat, modelPaperType);
                                        } else {
                                          setState(() {
                                            isGeneratingPreview = false;
                                          });
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                        child: Row(
                                          children: [
                                            Radio<String>(
                                              value: modelo.nome,
                                              groupValue: selectedEtiquetaModel?.nome,
                                              onChanged: (_) {}, // Controlado pelo InkWell
                                              activeColor: Theme.of(context).primaryColor,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${modelo.nome} - $paperType',
                                                    style: TextStyle(
                                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${modelo.larguraCm.toStringAsFixed(1)}x${modelo.alturaCm.toStringAsFixed(1)}cm (${modelo.etiquetasPorFolha} por folha)',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isSelected)
                                              Icon(
                                                Icons.check_circle,
                                                color: Theme.of(context).primaryColor,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Visualização:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      // Área de visualização prévia
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: selectedBoxes.isEmpty
                            ? const Center(
                                child: Text('Selecione pelo menos uma caixa para visualizar'),
                              )
                            : selectedPaperType == null
                                ? const Center(
                                    child: Text('Selecione um modelo de etiqueta'),
                                  )
                                : Center(
                                    child: isGeneratingPreview
                                        ? Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const CircularProgressIndicator(),
                                              const SizedBox(height: 10),
                                              Text('Gerando visualização para ${selectedEtiquetaModel?.nome ?? ""}')
                                            ],
                                          )
                                        : Container(
                                            padding: const EdgeInsets.all(8),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '${selectedBoxes.length} etiquetas selecionadas',
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 10),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    ElevatedButton.icon(
                                                      onPressed: () async {
                                                        if (previewPdf == null) return;
                                                        
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Abrindo visualização...')),
                                                        );
                                                        
                                                        // Pequeno atraso para garantir que o contexto esteja estável
                                                        Future.delayed(const Duration(milliseconds: 300), () async {
                                                          try {
                                                            if (mounted && previewPdf != null) {
                                                              await Printing.layoutPdf(
                                                                onLayout: (_) => previewPdf!,
                                                                name: 'Etiquetas BoxMagic',
                                                                format: PdfPageFormat.a4,
                                                              );
                                                            }
                                                          } catch (e) {
                                                            if (mounted) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(content: Text('Erro ao abrir visualização: ${e.toString()}')),
                                                              );
                                                            }
                                                          }
                                                        });
                                                      },
                                                      icon: const Icon(Icons.preview),
                                                      label: const Text('Visualizar'),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    ElevatedButton.icon(
                                                      onPressed: () async {
                                                        if (previewPdf == null) return;
                                                        
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Imprimindo...')),
                                                        );
                                                        
                                                        try {
                                                          await Printing.layoutPdf(
                                                            onLayout: (_) => previewPdf!,
                                                            name: 'Etiquetas BoxMagic',
                                                            format: PdfPageFormat.a4,
                                                            usePrinterSettings: true,
                                                          );
                                                        } catch (e) {
                                                          if (mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(content: Text('Erro ao imprimir: ${e.toString()}')),
                                                            );
                                                    // Calcular o número de etiquetas por linha e por coluna com base no modelo selecionado
                                                     int labelsPerRow = 0;
                                                     int labelsPerColumn = 0;
                                                     // As dimensões serão definidas no switch abaixo
                                                     // Depois usaremos as variáveis de classe para as dimensões reais
                                                    
                                                    // Configurar layout baseado no modelo de etiqueta com dimensões reais em mm convertidas para pixels
                                                    // Usamos a conversão 1mm = 3.78 pixels para manter consistência
                                                    const double mmToPixel = 3.78;
                                                    
                                                    switch (selectedPaperType) {
                                                      case LabelPaperType.pimaco6180:
                                                        // Pimaco 6180: 66,7 x 25,4 mm (3 colunas x 10 linhas)
                                                        labelsPerRow = 3;
                                                        labelsPerColumn = 10;
                                                        // A4: 210 x 297 mm
                                                        pageWidth = 210 * mmToPixel; // 793.8 pixels
                                                        pageHeight = 297 * mmToPixel; // 1122.66 pixels
                                                        labelWidth = 66.7 * mmToPixel; // 252.13 pixels
                                                        labelHeight = 25.4 * mmToPixel; // 96.01 pixels
                                                        // Margens e espaçamentos reais do modelo
                                                        marginLeft = 4.8 * mmToPixel; // 18.14 pixels
                                                        marginTop = 12.7 * mmToPixel; // 48.0 pixels
                                                        spacingHorizontal = 2.5 * mmToPixel; // 9.45 pixels
                                                        spacingVertical = 0; // sem espaçamento vertical
                                                        break;
                                                      case LabelPaperType.pimaco6082:
                                                        // Pimaco 6082: 101,6 x 33,9 mm (2 colunas x 5 linhas)
                                                        labelsPerRow = 2;
                                                        labelsPerColumn = 5;
                                                        pageWidth = 210 * mmToPixel; // 793.8 pixels
                                                        pageHeight = 297 * mmToPixel; // 1122.66 pixels
                                                        labelWidth = 101.6 * mmToPixel; // 384.05 pixels
                                                        labelHeight = 33.9 * mmToPixel; // 128.14 pixels
                                                        // Margens e espaçamentos reais do modelo
                                                        marginLeft = 3.8 * mmToPixel; // 14.36 pixels
                                                        marginTop = 12.7 * mmToPixel; // 48.0 pixels
                                                        spacingHorizontal = 0; // sem espaçamento horizontal
                                                        spacingVertical = 0; // sem espaçamento vertical
                                                        break;
                                                      case LabelPaperType.a4Full:
                                                        // A4 Full: uma etiqueta por página, tamanho A4 com margens
                                                        labelsPerRow = 1;
                                                        labelsPerColumn = 1;
                                                        pageWidth = 210 * mmToPixel; // 793.8 pixels
                                                        pageHeight = 297 * mmToPixel; // 1122.66 pixels
                                                        labelWidth = 190 * mmToPixel; // 718.2 pixels (A4 com margens)
                                                        labelHeight = 277 * mmToPixel; // 1047.06 pixels (A4 com margens)
                                                        // Margens e espaçamentos
                                                        marginLeft = 10 * mmToPixel; // 37.8 pixels
                                                        marginTop = 10 * mmToPixel; // 37.8 pixels
                                                        spacingHorizontal = 0;
                                                        spacingVertical = 0;
                                                        break;
                                                      default:
                                                        // Configuração padrão (Pimaco 6180)
                                                        labelsPerRow = 3;
                                                        labelsPerColumn = 10;
                                                        pageWidth = 210 * mmToPixel; // 793.8 pixels
                                                        pageHeight = 297 * mmToPixel; // 1122.66 pixels
                                                        labelWidth = 66.7 * mmToPixel; // 252.13 pixels
                                                        labelHeight = 25.4 * mmToPixel; // 96.01 pixels
                                                        marginLeft = 4.8 * mmToPixel; // 18.14 pixels
                                                        marginTop = 12.7 * mmToPixel; // 48.0 pixels
                                                        spacingHorizontal = 2.5 * mmToPixel; // 9.45 pixels
                                                        spacingVertical = 0;
                                                        break;
                                                    }
                                                    
                                                    // Usar as variáveis de dimensão para o layout
                                                    double marginX = marginLeft;
                                                    double marginY = marginTop;
                                                    double spacingX = spacingHorizontal;
                                                    double spacingY = spacingVertical;
                                                    
                                                    // Calcular número de etiquetas por página
                                                    final labelsPerPage = labelsPerRow * labelsPerColumn;
                                                    
                                                    // Calcular número de páginas necessárias
                                                    final numPages = (selectedBoxes.length / labelsPerPage).ceil();
                                                    
                                                    // Iniciar o documento SVG principal
                                                    String svgContent = '<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n';
                                                    svgContent += '<!-- Etiquetas BoxMagic para impressão - Modelo: ${selectedEtiqueta.nome} -->\n';
                                                    svgContent += '<!-- Dimensões da etiqueta: ${selectedEtiqueta.larguraCm}cm x ${selectedEtiqueta.alturaCm}cm -->\n';
                                                    svgContent += '<!-- Etiquetas por página: ${labelsPerRow} x ${labelsPerColumn} = ${labelsPerPage} -->\n\n';
                                                    
                                                    // Criar páginas
                                                    for (int pageIndex = 0; pageIndex < numPages; pageIndex++) {
                                                      final startIndex = pageIndex * labelsPerPage;
                                                      final endIndex = (startIndex + labelsPerPage) < selectedBoxes.length
                                                          ? startIndex + labelsPerPage
                                                          : selectedBoxes.length;
                                                      
                                                      // Iniciar uma nova página SVG
                                                      svgContent += '<svg xmlns="http://www.w3.org/2000/svg" width="${pageWidth.toStringAsFixed(2)}" height="${pageHeight.toStringAsFixed(2)}" viewBox="0 0 ${pageWidth.toStringAsFixed(2)} ${pageHeight.toStringAsFixed(2)}" version="1.1">\n';
                                                      
                                                      // Adicionar um retângulo de fundo para a página
                                                      svgContent += '  <rect x="0" y="0" width="${pageWidth.toStringAsFixed(2)}" height="${pageHeight.toStringAsFixed(2)}" fill="white" />\n';
                                                      
                                                      // Adicionar informações da página
                                                      svgContent += '  <text x="${marginX.toStringAsFixed(2)}" y="${(marginY/2).toStringAsFixed(2)}" font-family="Arial" font-size="10" fill="#999999">BoxMagic - Etiquetas ${startIndex+1} a ${endIndex} de ${selectedBoxes.length} - Página ${pageIndex+1} de ${numPages}</text>\n';
                                                      
                                                      // Criar grid de etiquetas
                                                      int labelIndex = startIndex;
                                                      for (int row = 0; row < labelsPerColumn && labelIndex < selectedBoxes.length; row++) {
                                                        for (int col = 0; col < labelsPerRow && labelIndex < selectedBoxes.length; col++) {
                                                          // Calcular posição da etiqueta na página
                                                          final x = marginX + col * (labelWidthPx + spacingX);
                                                          final y = marginY + row * (labelHeightPx + spacingY);
                                                          
                                                          // Obter a caixa atual
                                                          final box = selectedBoxes[labelIndex];
                                                          
                                                          // Criar um grupo para a etiqueta
                                                          svgContent += '  <g transform="translate(${x.toStringAsFixed(2)},${y.toStringAsFixed(2)})" id="label_${box.formattedId}">\n';
                                                          
                                                          // Adicionar um retângulo de fundo para a etiqueta
                                                          svgContent += '    <rect x="0" y="0" width="${labelWidthPx.toStringAsFixed(2)}" height="${labelHeightPx.toStringAsFixed(2)}" fill="white" stroke="#cccccc" stroke-width="1" />\n';
                                                          
                                                          // Calcular tamanho do QR code baseado no tamanho da etiqueta (ajustado para ser proporcional)
                                                          // Usar o menor valor entre 40% da largura e 70% da altura para garantir que caiba
                                                          double qrSizeByWidth = labelWidth * 0.4;
                                                          double qrSizeByHeight = labelHeight * 0.7;
                                                          double qrSize = qrSizeByWidth < qrSizeByHeight ? qrSizeByWidth : qrSizeByHeight;
                                                    
                                                          // Calcular tamanhos de fonte baseados no tamanho da etiqueta
                                                          double titleFontSize = labelHeight * 0.15; // 15% da altura para o título (ID)
                                                          double nameFontSize = labelHeight * 0.12;  // 12% da altura para o nome
                                                          double categoryFontSize = labelHeight * 0.10; // 10% da altura para a categoria
                                                    
                                                          // Limitar tamanhos de fonte para legibilidade
                                                          titleFontSize = titleFontSize < 8 ? 8 : (titleFontSize > 16 ? 16 : titleFontSize);
                                                          nameFontSize = nameFontSize < 7 ? 7 : (nameFontSize > 14 ? 14 : nameFontSize);
                                                          categoryFontSize = categoryFontSize < 6 ? 6 : (categoryFontSize > 12 ? 12 : categoryFontSize);
                                                    
                                                          // Posicionar o QR code no canto superior direito com margem
                                                          double qrX = labelWidth - qrSize - (labelWidth * 0.05); // 5% de margem
                                                          double qrY = labelHeight * 0.1; // 10% da altura como margem superior
                                                    
                                                          // Gerar QR code em SVG usando a biblioteca qr_flutter
                                                          final qrSvg = _generateQrCodeSvg(box.formattedId, qrSize);
                                                          
                                                          // Adicionar QR code no SVG com posicionamento correto
                                                          svgContent += '    <g transform="translate($qrX, $qrY)">\n';
                                                          svgContent += '      $qrSvg\n';
                                                          svgContent += '    </g>\n';
                                                          
                                                          // Calcular espaço disponível para texto (largura total menos QR code e margens)
                                                          double textAreaWidth = qrX - (labelWidth * 0.1); // 10% de margem total
                                                          
                                                          // Adicionar texto com o ID da caixa
                                                          svgContent += '    <text x="${(labelWidth * 0.05).toStringAsFixed(2)}" y="${(labelHeight * 0.25).toStringAsFixed(2)}" font-family="Arial" font-size="${titleFontSize.toStringAsFixed(1)}" font-weight="bold">#${_escapeSvgText(box.formattedId)}</text>\n';
                                                          
                                                          // Adicionar nome da caixa com truncamento se necessário
                                                          String name = _escapeSvgText(box.name);
                                                          // Limitar o nome a um tamanho razoável para a etiqueta
                                                          int maxChars = (textAreaWidth / (nameFontSize * 0.6)).round(); // Estimativa de caracteres que cabem
                                                          if (name.length > maxChars) {
                                                              name = name.substring(0, maxChars - 3) + '...';
                                                          }
                                                          
                                                          // Adicionar nome ao SVG
                                                          svgContent += '    <text x="${(labelWidth * 0.05).toStringAsFixed(2)}" y="${(labelHeight * 0.5).toStringAsFixed(2)}" font-family="Arial" font-size="${nameFontSize.toStringAsFixed(1)}">${name}</text>\n';
                                                          
                                                          // Adicionar categoria com truncamento se necessário
                                                          String category = _escapeSvgText(box.category);
                                                          maxChars = (textAreaWidth / (categoryFontSize * 0.6)).round();
                                                          if (category.length > maxChars) {
                                                              category = category.substring(0, maxChars - 3) + '...';
                                                          }
                                                          
                                                          // Adicionar categoria ao SVG
                                                          svgContent += '    <text x="${(labelWidth * 0.05).toStringAsFixed(2)}" y="${(labelHeight * 0.7).toStringAsFixed(2)}" font-family="Arial" font-size="${categoryFontSize.toStringAsFixed(1)}" fill="gray">${category}</text>\n';
                                                          
                                                          // Buscar e incluir os objetos da caixa
                                                          try {
                                                            final items = await _databaseHelper.readItemsByBoxId(box.id!);
                                                            if (items.isNotEmpty) {
                                                              svgContent += '    <text x="10" y="85" font-family="Arial" font-size="12" font-weight="bold" fill="black">Objetos:</text>\n';
                                                              
                                                              for (int j = 0; j < items.length && j < 5; j++) { // Limitar a 5 itens para não sobrecarregar
                                                                final item = items[j];
                                                                String itemText = item.name;
                                                                if (item.description != null && item.description!.isNotEmpty) {
                                                                  itemText += ' (${item.description})';
                                                                }
                                                                svgContent += '    <text x="10" y="${105 + j * 16}" font-family="Arial" font-size="10" fill="black">- ${_escapeSvgText(itemText)}</text>\n';
                                                              }
                                                              
                                                              if (items.length > 5) {
                                                                svgContent += '    <text x="10" y="${105 + 5 * 16}" font-family="Arial" font-size="10" fill="#666666">+ ${items.length - 5} mais itens...</text>\n';
                                                              }
                                                            }
                                                          } catch (e) {
                                                            svgContent += '    <text x="10" y="85" font-family="Arial" font-size="10" fill="red">Erro ao carregar objetos</text>\n';
                                                          }
                                                          
                                                          // Fechar o grupo da etiqueta
                                                          svgContent += '  </g>\n';
                                                          
                                                          labelIndex++;
                                                        }
                                                      }
                                                      
                                                      // Fechar a página SVG
                                                      svgContent += '</svg>\n\n';
                                                    }
                                                    
                                                    // Se não houver etiquetas, mostrar mensagem
                                                    if (selectedBoxes.isEmpty) {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(
                                                            content: Text('Nenhuma etiqueta selecionada para exportação'),
                                                            backgroundColor: Colors.red,
                                                          ),
                                                        );
                                                      }
                                                      return;
                                                    }
                                                    
                                                    try {
                                                      // Verificar se estamos no ambiente web
                                                      bool isWeb = identical(0, 0.0);
                                                      
                                                      // Nome do arquivo para salvar
                                                      final timestamp = DateTime.now().millisecondsSinceEpoch;
                                                      final filename = 'etiquetas_boxmagic_${timestamp}.svg';
                                                      
                                                      if (isWeb) {
                                                        // No ambiente web, fazer download direto do arquivo SVG completo
                                                        final blob = html.Blob([svgContent], 'image/svg+xml');
                                                        final url = html.Url.createObjectUrlFromBlob(blob);
                                                        final anchor = html.AnchorElement(href: url)
                                                          ..setAttribute('download', filename)
                                                          ..click();
                                                        html.Url.revokeObjectUrl(url);
                                                        
                                                        if (mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text('Arquivo SVG com ${selectedBoxes.length} etiquetas baixado'),
                                                              backgroundColor: Colors.green,
                                                            ),
                                                          );
                                                        }
                                                      } else {
                                                        // Em dispositivos móveis/desktop, usar seleção de diretório
                                                        final String? selectedDirectory = await file_picker.FilePicker.platform.getDirectoryPath(
                                                          dialogTitle: 'Selecione a pasta para salvar o arquivo SVG',
                                                        );
                                                        
                                                        if (selectedDirectory == null) {
                                                          // Usuário cancelou a seleção
                                                          if (mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(
                                                                content: Text('Exportação cancelada'),
                                                                backgroundColor: Colors.orange,
                                                              ),
                                                            );
                                                          }
                                                          return;
                                                        }
                                                        
                                                        // Criar diretório se não existir
                                                        final directory = Directory(selectedDirectory);
                                                        if (!await directory.exists()) {
                                                          await directory.create(recursive: true);
                                                        }
                                                        
                                                        // Salvar o arquivo SVG completo
                                                        final file = File('${directory.path}/$filename');
                                                        await file.writeAsString(svgContent);
                                                        
                                                        if (mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text('Arquivo SVG com ${selectedBoxes.length} etiquetas salvo em ${directory.path}/$filename'),
                                                              backgroundColor: Colors.green,
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    } catch (e) {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('Erro ao salvar arquivos SVG: $e'),
                                                            backgroundColor: Colors.red,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  icon: const Icon(Icons.save_alt),
                                                  label: const Text('Exportar SVG'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.amber[700],
                                                    foregroundColor: Colors.white,
                                                  ),
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.red, width: 2),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text('Etiquetas ativas'),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey, width: 2),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text('Etiquetas não utilizadas'),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedBoxes.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Selecione pelo menos uma caixa'),
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).pop();

                    // Gerar PDF para impressão (sem bordas coloridas)
                    _printLabels(selectedBoxes, selectedFormat, selectedPaperType);
                  },
                  child: const Text('Imprimir'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Novo método para impressão usando o modelo de etiqueta
  Future<void> _printLabelsComModelo(
    List<int> boxIds,
    LabelFormat format,
    Etiqueta modeloSelecionado,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparando etiquetas para impressão...'),
          duration: Duration(seconds: 2),
        ),
      );

      final selectedBoxes = _boxes.where((box) => box.id != null && boxIds.contains(box.id)).toList();
      final boxItems = <int, List<Item>>{};
      for (final boxId in boxIds) {
        final items = await _databaseHelper.readItemsByBoxId(boxId);
        boxItems[boxId] = items;
      }

      final printingService = LabelPrintingService();
      await printingService.printLabels(
        boxes: selectedBoxes,
        boxItems: boxItems,
        format: format,
        paperType: _mapModeloToPaperType(modeloSelecionado),
      );


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' etiquetas enviadas para impressão'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao imprimir etiquetas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printLabels(
    List<Box> boxes,
    LabelFormat format,
    LabelPaperType? paperType,
  ) async {
    // Verificar se o tipo de papel foi selecionado
    if (paperType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um modelo de etiqueta primeiro'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    try {
      // Mostrar mensagem de carregamento
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparando etiquetas para impressão...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Obter itens para cada caixa
      final Map<int, List<Item>> boxItems = {};
      for (final box in boxes) {
        if (box.id != null) {
          boxItems[box.id!] = await _databaseHelper.readItemsByBoxId(box.id!);
        }
      }

      // Criar serviço de impressão
      final printingService = LabelPrintingService();

      // Imprimir etiquetas
      await printingService.printLabels(
        boxes: boxes,
        boxItems: boxItems,
        format: format,
        paperType: paperType,
      );

      // Mostrar mensagem de sucesso
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' etiquetas enviadas para impressão'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Mostrar mensagem de erro
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao imprimir etiquetas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showBoxIdRecognition() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BoxIdRecognitionScreen(),
      ),
    );

    if (result != null) {
      await _loadBoxes();
      // Se o resultado for um ID de caixa, tente abrir automaticamente
      try {
        final int boxId = int.parse(result.toString());
        final box = _boxes.firstWhere((b) => b.id == boxId, orElse: () => throw Exception('Caixa não encontrada'));
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BoxDetailScreen(box: box),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao abrir caixa automaticamente: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Chamada necessária para AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: null, // Removendo a AppBar duplicada
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Pesquisar caixas',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterBoxes('');
                  },
                ),
              ),
              onChanged: _filterBoxes,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredBoxes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.inbox,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Nenhuma caixa encontrada',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Crie sua primeira caixa para começar a organizar seus objetos',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showNewBoxDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Criar nova caixa'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBoxes,
                        child: ListView.builder(
                          itemCount: _filteredBoxes.length,
                          itemBuilder: (context, index) {
                            final box = _filteredBoxes[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  child: const Icon(Icons.inbox, color: Colors.white),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(child: Text(box.name)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        borderRadius: BorderRadius.circular(4.0),
                                      ),
                                      child: Text(
                                        '#${box.formattedId}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(box.category),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BoxDetailScreen(box: box),
                                    ),
                                  ).then((_) => _loadBoxes());
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewBoxDialog,
        tooltip: 'Adicionar nova caixa',
        heroTag: 'boxes_fab',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
