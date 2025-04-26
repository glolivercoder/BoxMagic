import 'package:flutter/material.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/widgets/new_item_dialog.dart';
import 'package:boxmagic/widgets/edit_box_dialog.dart';
import 'package:boxmagic/screens/item_detail_screen.dart';
import 'package:boxmagic/screens/object_recognition_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BoxDetailScreen extends StatefulWidget {
  final Box box;

  const BoxDetailScreen({Key? key, required this.box}) : super(key: key);

  @override
  _BoxDetailScreenState createState() => _BoxDetailScreenState();
}

class _BoxDetailScreenState extends State<BoxDetailScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  late Box _box;
  List<Item> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _box = widget.box;
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final items = await _databaseHelper.readItemsByBoxId(_box.id!);
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar objetos: $e')),
      );
    }
  }

  Future<void> _showEditBoxDialog() async {
    final result = await showDialog<Box>(
      context: context,
      builder: (context) => EditBoxDialog(box: _box),
    );

    if (result != null) {
      setState(() {
        _box = result;
      });
    }
  }

  Future<void> _showNewItemDialog() async {
    // Verificar se o ID da caixa é válido
    if (_box.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: ID da caixa é nulo')),
      );
      return;
    }

    // Criar uma lista com apenas esta caixa
    final boxesList = [_box];

    final result = await showDialog<Item>(
      context: context,
      builder: (context) => NewItemDialog(
        preselectedBoxId: _box.id,
        boxes: boxesList,
      ),
    );

    if (result != null) {
      await _loadItems();
    }
  }

  Future<void> _showObjectRecognition() async {
    // Verificar se o ID da caixa é válido
    if (_box.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: ID da caixa é nulo')),
      );
      return;
    }

    // Criar uma lista com apenas esta caixa
    final boxesList = [_box];

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ObjectRecognitionScreen(
          boxes: boxesList,
        ),
      ),
    );

    if (result != null) {
      await _loadItems();
    }
  }

  Future<void> _deleteBox() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text(
          'Tem certeza que deseja excluir a caixa ${_box.name}?\n\n'
          'Todos os objetos dentro desta caixa também serão excluídos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete all items in the box first
        for (final item in _items) {
          await _databaseHelper.deleteItem(item.id!);
        }

        // Then delete the box
        await _databaseHelper.deleteBox(_box.id!);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Caixa excluída com sucesso')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir caixa: $e')),
          );
        }
      }
    }
  }

  void _showQRCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Código QR da Caixa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: _box.id.toString(),
              version: QrVersions.auto,
              size: 200.0,
            ),
            const SizedBox(height: 16),
            Text(
              'ID: ${_box.id}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _box.name,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_box.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: _showQRCode,
            tooltip: 'Mostrar código QR',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditBoxDialog,
            tooltip: 'Editar caixa',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteBox,
            tooltip: 'Excluir caixa',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Box details card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ID: ${_box.id}',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Categoria: ${_box.category}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_box.description != null && _box.description!.isNotEmpty) ...[
                    const Text(
                      'Descrição:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(_box.description!),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'Criada em: ${DateTime.parse(_box.createdAt).toLocal().toString().split('.')[0]}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Items list header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Objetos (${_items.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showObjectRecognition,
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Identificar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showNewItemDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Adicionar'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Items list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.inventory_2,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Nenhum objeto nesta caixa',
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
                                  onPressed: _showObjectRecognition,
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Identificar com câmera'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: _showNewItemDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Adicionar manualmente'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadItems,
                        child: ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
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
                                subtitle: item.category != null && item.category!.isNotEmpty
                                    ? Text(item.category!)
                                    : null,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ItemDetailScreen(
                                        item: item,
                                        boxName: _box.name,
                                      ),
                                    ),
                                  ).then((_) => _loadItems());
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
            heroTag: 'box_detail_camera_fab',
            backgroundColor: Colors.green,
            child: const Icon(Icons.camera_enhance),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: _showNewItemDialog,
            tooltip: 'Adicionar novo objeto',
            heroTag: 'box_detail_add_fab',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
