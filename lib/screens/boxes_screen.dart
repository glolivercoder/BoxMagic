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

class BoxesScreen extends StatefulWidget {
  const BoxesScreen({Key? key}) : super(key: key);

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
                  // Try to find a box with this ID
                  try {
                    final boxId = int.parse(code);
                    Navigator.pop(context, boxId);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Código inválido')),
                    );
                  }
                }
              }
            },
          ),
        ),
      ),
    );

    if (result != null && result is int) {
      try {
        // Find the box with this ID
        final box = _boxes.firstWhere(
          (box) => box.id == result,
          orElse: () => throw Exception('Caixa não encontrada'),
        );

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BoxDetailScreen(box: box),
            ),
          ).then((_) => _loadBoxes());
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e')),
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

  // Lista de caixas selecionadas para impressão
  final selectedBoxes = <int>[];

  // Formato de etiqueta selecionado
  var selectedFormat = LabelFormat.nameWithBarcodeAndId;

  // Modelo Pimaco selecionado
  Etiqueta? selectedModelo = modelosPimaco.isNotEmpty ? modelosPimaco.first : null;
  bool customExpanded = false;
  Etiqueta customModelo = Etiqueta(
    nome: 'Personalizada',
    alturaCm: 5.0,
    larguraCm: 10.0,
    etiquetasPorFolha: 10,
    margemSuperiorCm: 1.0,
    margemInferiorCm: 1.0,
    margemEsquerdaCm: 1.0,
    margemDireitaCm: 1.0,
    espacoEntreEtiquetasCm: 0.2,
    personalizada: true,
  );

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Imprimir Etiquetas'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selecione as caixas para imprimir etiquetas:'),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _boxes.length,
                  itemBuilder: (context, index) {
                    final box = _boxes[index];
                    return CheckboxListTile(
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
                      value: selectedBoxes.contains(box.id),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selectedBoxes.add(box.id!);
                          } else {
                            selectedBoxes.remove(box.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Formato da etiqueta:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<LabelFormat>(
                value: selectedFormat,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  DropdownMenuItem(
                    value: LabelFormat.nameWithBarcodeAndId,
                    child: Text('Nome da caixa + código de barras + ID'),
                  ),
                  DropdownMenuItem(
                    value: LabelFormat.idWithBarcode,
                    child: Text('Somente ID + código de barras'),
                  ),
                  DropdownMenuItem(
                    value: LabelFormat.idWithBarcodeAndItems,
                    child: Text('ID + código de barras + itens da caixa'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedFormat = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Modelo de etiqueta Pimaco:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Etiqueta>(
                value: selectedModelo,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  ...modelosPimaco.map((modelo) => DropdownMenuItem(
                        value: modelo,
                        child: Text(modelo.nome),
                      )),
                  DropdownMenuItem(
                    value: customModelo,
                    child: const Text('Personalizada'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedModelo = value;
                    customExpanded = value?.personalizada ?? false;
                  });
                },
              ),
              if (selectedModelo?.personalizada ?? false)
                ExpansionTile(
                  initiallyExpanded: true,
                  title: const Text('Configurar modelo personalizado'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: TextFormField(
                                  initialValue: customModelo.alturaCm.toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Altura (cm)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (v) {
                                    setState(() {
                                      customModelo = customModelo.copyWith(
                                        alturaCm: double.tryParse(v) ?? customModelo.alturaCm,
                                      );
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: TextFormField(
                                  initialValue: customModelo.larguraCm.toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Largura (cm)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (v) {
                                    setState(() {
                                      customModelo = customModelo.copyWith(
                                        larguraCm: double.tryParse(v) ?? customModelo.larguraCm,
                                      );
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Flexible(
                                child: TextFormField(
                                  initialValue: customModelo.etiquetasPorFolha.toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Etiquetas por folha',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    setState(() {
                                      customModelo = customModelo.copyWith(
                                        etiquetasPorFolha: int.tryParse(v) ?? customModelo.etiquetasPorFolha,
                                      );
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: TextFormField(
                                  initialValue: customModelo.espacoEntreEtiquetasCm.toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Espaço entre etiquetas (cm)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (v) {
                                    setState(() {
                                      customModelo = customModelo.copyWith(
                                        espacoEntreEtiquetasCm: double.tryParse(v) ?? customModelo.espacoEntreEtiquetasCm,
                                      );
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Flexible(
                                child: TextFormField(
                                  initialValue: customModelo.margemSuperiorCm.toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Margem superior (cm)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (v) {
                                    setState(() {
                                      customModelo = customModelo.copyWith(
                                        margemSuperiorCm: double.tryParse(v) ?? customModelo.margemSuperiorCm,
                                      );
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: TextFormField(
                                  initialValue: customModelo.margemEsquerdaCm.toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Margem esquerda (cm)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (v) {
                                    setState(() {
                                      customModelo = customModelo.copyWith(
                                        margemEsquerdaCm: double.tryParse(v) ?? customModelo.margemEsquerdaCm,
                                      );
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: selectedBoxes.isEmpty || selectedModelo == null
                ? null
                : () {
                    Navigator.pop(context);
                    final etiquetaParaImpressao = (selectedModelo?.personalizada ?? false)
                        ? customModelo
                        : selectedModelo!;
                    _printLabelsComModelo(selectedBoxes, selectedFormat, etiquetaParaImpressao);
                  },
            child: const Text('Imprimir'),
          ),
        ],
      ),
    ),
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
          content: Text('${boxIds.length} etiquetas enviadas para impressão'),
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
    List<int> boxIds,
    LabelFormat format,
    LabelPaperType paperType
  ) async {
    try {
      // Mostrar mensagem de carregamento
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparando etiquetas para impressão...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Obter as caixas selecionadas
      final selectedBoxes = _boxes.where((box) => box.id != null && boxIds.contains(box.id)).toList();

      // Obter os itens de cada caixa
      final boxItems = <int, List<Item>>{};
      for (final boxId in boxIds) {
        final items = await _databaseHelper.readItemsByBoxId(boxId);
        boxItems[boxId] = items;
      }

      // Criar serviço de impressão
      final printingService = LabelPrintingService();

      // Imprimir etiquetas
      await printingService.printLabels(
        boxes: selectedBoxes,
        boxItems: boxItems,
        format: format,
        paperType: paperType,
      );

      // Mostrar mensagem de sucesso
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${boxIds.length} etiquetas enviadas para impressão'),
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
