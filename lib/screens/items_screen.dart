import 'package:flutter/material.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/widgets/new_item_dialog.dart';
import 'package:boxmagic/screens/item_detail_screen.dart';
import 'package:boxmagic/screens/object_recognition_screen.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({Key? key}) : super(key: key);

  @override
  _ItemsScreenState createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  List<Item> _items = [];
  List<Box> _boxes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  List<Item> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Primeiro carregamos as caixas
      final boxes = await _databaseHelper.readAllBoxes();
      print('Caixas carregadas: ${boxes.length}');

      // Depois carregamos os itens
      final items = await _databaseHelper.readAllItems();
      print('Itens carregados: ${items.length}');

      setState(() {
        _boxes = boxes;
        _items = items;
        _filteredItems = items;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('Erro ao carregar dados: $e');
      print('Stack trace: $stackTrace');

      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar objetos: $e')),
        );
      }
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _items;
      } else {
        _filteredItems = _items
            .where((item) =>
                item.name.toLowerCase().contains(query.toLowerCase()) ||
                (item.category?.toLowerCase() ?? '').contains(query.toLowerCase()) ||
                (item.id?.toString() ?? '').contains(query))
            .toList();
      }
    });
  }

  String _getBoxName(int boxId) {
    final box = _boxes.firstWhere(
      (box) => box.id == boxId,
      orElse: () => Box(
        name: 'Desconhecida',
        category: 'Desconhecida',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    return box.name;
  }

  Future<void> _showNewItemDialog() async {
    if (_boxes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa criar uma caixa antes de adicionar objetos.'),
        ),
      );
      return;
    }

    final result = await showDialog<Item>(
      context: context,
      builder: (context) => NewItemDialog(boxes: _boxes),
    );

    if (result != null) {
      await _loadData();
    }
  }

  Future<void> _showObjectRecognition() async {
    if (_boxes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa criar uma caixa antes de adicionar objetos.'),
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ObjectRecognitionScreen(boxes: _boxes),
      ),
    );

    if (result != null) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Objetos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _showObjectRecognition,
            tooltip: 'Identificar objeto com IA',
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
                labelText: 'Pesquisar objetos',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterItems('');
                  },
                ),
              ),
              onChanged: _filterItems,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.category,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Nenhum objeto encontrado',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _showNewItemDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Adicionar manualmente'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: _showObjectRecognition,
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Identificar com câmera'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  child: const Icon(Icons.inventory_2, color: Colors.white),
                                ),
                                title: Text(item.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.category != null && item.category!.isNotEmpty)
                                      Text(item.category!),
                                    Text('Caixa: ${_getBoxName(item.boxId)}'),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ItemDetailScreen(
                                        item: item,
                                        boxName: _getBoxName(item.boxId),
                                      ),
                                    ),
                                  ).then((_) => _loadData());
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _showObjectRecognition,
            tooltip: 'Identificar objeto com câmera',
            heroTag: 'items_camera_fab',
            backgroundColor: Colors.green,
            child: const Icon(Icons.camera_enhance),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: _showNewItemDialog,
            tooltip: 'Adicionar novo objeto',
            heroTag: 'items_add_fab',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
