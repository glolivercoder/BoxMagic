import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/services/preferences_service.dart';
import 'package:boxmagic/services/log_service.dart';
import 'package:boxmagic/services/label_printing_service.dart';
import 'package:boxmagic/data/modelos_pimaco.dart' show modelosPimaco;
import 'package:boxmagic/models/etiqueta.dart'; // Não importar modelosPimaco daqui
import 'package:boxmagic/widgets/new_box_dialog.dart';
import 'package:boxmagic/screens/box_detail_screen.dart';
import 'package:boxmagic/screens/box_id_recognition_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

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
  // Mapeia Etiqueta para LabelPaperType
  LabelPaperType _mapModeloToPaperType(Etiqueta? modelo) {
    if (modelo == null) return LabelPaperType.pimaco6180;
    switch (modelo.nome) {
      case 'Pimaco 6180':
        return LabelPaperType.pimaco6180;
      case 'Pimaco 6082':
        return LabelPaperType.pimaco6082;
      case 'A4 Completo':
        return LabelPaperType.a4Full;
      default:
        // Você pode adicionar mais casos conforme necessário
        // Para modelos não suportados pelo serviço, retorna padrão
        return LabelPaperType.pimaco6180;
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
    LabelPaperType selectedPaperType = LabelPaperType.pimaco6180;
    Uint8List? previewPdf;
    bool isGeneratingPreview = false;

    // Inicialmente, selecionar todas as caixas
    for (final box in _boxes) {
      selectedBoxMap[box.id!] = true;
      selectedBoxes.add(box);
    }

    // Função para gerar a visualização prévia do PDF
    Future<void> generatePreview(List<Box> boxes, LabelFormat format, LabelPaperType paperType) async {
      if (boxes.isEmpty) return;

      setState(() {
        isGeneratingPreview = true;
      });

      try {
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

        setState(() {
          previewPdf = pdfBytes;
          isGeneratingPreview = false;
        });
      } catch (e) {
        setState(() {
          isGeneratingPreview = false;
        });
        _logService.error('Erro ao gerar visualização prévia', error: e);
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
              content: SingleChildScrollView(
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
                                // Atualizar visualização ao alterar seleção
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
                    const SizedBox(height: 10),
                    DropdownButtonFormField<LabelFormat>(
                      value: selectedFormat,
                      items: [
                        DropdownMenuItem(
                          value: LabelFormat.nameWithBarcodeAndId,
                          child: Text(
                              'Nome + QR Code + ID (${selectedBoxes.length} etiquetas)'),
                        ),
                        DropdownMenuItem(
                          value: LabelFormat.idWithBarcode,
                          child: Text(
                              'Apenas ID + QR Code (${selectedBoxes.length} etiquetas)'),
                        ),
                        DropdownMenuItem(
                          value: LabelFormat.idWithBarcodeAndItems,
                          child: Text(
                              'ID + QR Code + Itens (${selectedBoxes.length} etiquetas)'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedFormat = value!;
                          // Atualizar visualização ao alterar formato
                          generatePreview(selectedBoxes, selectedFormat, selectedPaperType);
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Tipo de papel:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<LabelPaperType>(
                      value: selectedPaperType,
                      items: [
                        DropdownMenuItem(
                          value: LabelPaperType.pimaco6180,
                          child: Text(
                              'Pimaco 6180 - Padrão Correios (${(selectedBoxes.length / 10).ceil()} páginas)'),
                        ),
                        DropdownMenuItem(
                          value: LabelPaperType.pimaco6082,
                          child: Text(
                              'Pimaco 6082 - Pequenas (${(selectedBoxes.length / 28).ceil()} páginas)'),
                        ),
                        DropdownMenuItem(
                          value: LabelPaperType.a4Full,
                          child: Text(
                              'Página A4 inteira (${(selectedBoxes.length / 3).ceil()} páginas)'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedPaperType = value!;
                          // Atualizar visualização ao alterar tipo de papel
                          generatePreview(selectedBoxes, selectedFormat, selectedPaperType);
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Visualização prévia:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: isGeneratingPreview
                          ? const Center(child: CircularProgressIndicator())
                          : previewPdf != null
                              ? GestureDetector(
                                  onTap: () {
                                    // Mostrar visualização em tela cheia ao tocar
                                    Printing.layoutPdf(
                                      onLayout: (_) => Future.value(previewPdf!),
                                      name: 'Visualização de Etiquetas',
                                    );
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Mostrar uma mensagem de visualização
                                      Container(
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.preview, size: 48, color: Colors.grey),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Etiquetas prontas para impressão',
                                              style: TextStyle(fontSize: 16),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Toque para visualizar em tela cheia',
                                              style: TextStyle(fontSize: 12, color: Colors.grey),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const Center(child: Text('Nenhuma etiqueta selecionada')),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.red, width: 2),
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
                                border: Border.all(color: Colors.grey.shade300),
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
            content: Text('${selectedBoxes.length} etiquetas enviadas para impressão'),
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
    LabelPaperType paperType,
  ) async {
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
            content: Text('${selectedBoxes.length} etiquetas enviadas para impressão'),
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
