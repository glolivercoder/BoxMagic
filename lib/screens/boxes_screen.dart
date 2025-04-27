import 'package:flutter/material.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/services/preferences_service.dart';
import 'package:boxmagic/services/log_service.dart';
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

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Imprimir Etiquetas'),
          content: SizedBox(
            width: double.maxFinite,
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: selectedBoxes.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      _printLabels(selectedBoxes);
                    },
              child: const Text('Imprimir'),
            ),
          ],
        ),
      ),
    );
  }

  void _printLabels(List<int> boxIds) {
    // Em um aplicativo real, isso enviaria os dados para uma impressora
    // ou geraria um PDF para impressão

    // Mostrar mensagem de simulação
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Simulando impressão de etiquetas...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Após 2 segundos, mostrar mensagem de sucesso
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${boxIds.length} etiquetas enviadas para impressão'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
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
