import 'package:flutter/material.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/services/preferences_service.dart';
import 'package:boxmagic/widgets/new_box_dialog.dart';
import 'package:boxmagic/screens/box_detail_screen.dart';
import 'package:boxmagic/screens/box_id_recognition_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BoxesScreen extends StatefulWidget {
  const BoxesScreen({Key? key}) : super(key: key);

  @override
  _BoxesScreenState createState() => _BoxesScreenState();
}

class _BoxesScreenState extends State<BoxesScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final PreferencesService _preferencesService = PreferencesService();
  List<Box> _boxes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
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
      final boxes = await _databaseHelper.readAllBoxes();
      setState(() {
        _boxes = boxes;
        _filteredBoxes = boxes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar caixas: $e')),
      );
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
    final result = await showDialog<Box>(
      context: context,
      builder: (context) => const NewBoxDialog(),
    );

    if (result != null) {
      await _loadBoxes();
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
                        title: Text(box.name),
                        subtitle: Text('ID: ${box.id}'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Caixas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _showBarcodeScanner,
            tooltip: 'Escanear código de barras',
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _showBoxIdRecognition,
            tooltip: 'Reconhecer ID com IA',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _showPrintLabelsDialog,
            tooltip: 'Imprimir etiquetas',
          ),
        ],
      ),
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
                                title: Text(box.name),
                                subtitle: Text(box.category),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '#${box.id}',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
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
