import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/widgets/edit_item_dialog.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ItemDetailScreen extends StatefulWidget {
  final Item item;
  final String boxName;

  const ItemDetailScreen({
    Key? key,
    required this.item,
    required this.boxName,
  }) : super(key: key);

  @override
  _ItemDetailScreenState createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  late Item _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  Future<void> _showEditItemDialog() async {
    final result = await showDialog<Item>(
      context: context,
      builder: (context) => EditItemDialog(item: _item),
    );

    if (result != null) {
      setState(() {
        _item = result;
      });
    }
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Tem certeza que deseja excluir o objeto ${_item.name}?'),
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
        await _databaseHelper.deleteItem(_item.id!);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Objeto excluído com sucesso')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir objeto: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditItemDialog,
            tooltip: 'Editar objeto',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteItem,
            tooltip: 'Excluir objeto',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item image (if available)
            if (_item.image != null && _item.image!.isNotEmpty)
              Container(
                width: double.infinity,
                height: 200,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(
                  base64Decode(_item.image!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 64,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Item details card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _item.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Category
                    if (_item.category != null && _item.category!.isNotEmpty) ...[
                      const Text(
                        'Categoria:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(_item.category!),
                      const SizedBox(height: 8),
                    ],

                    // Box
                    const Text(
                      'Caixa:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Text(widget.boxName),
                        const SizedBox(width: 8),
                        Text(
                          '(ID: ${_item.boxId})',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Description
                    if (_item.description != null && _item.description!.isNotEmpty) ...[
                      const Text(
                        'Descrição:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(_item.description!),
                      const SizedBox(height: 8),
                    ],

                    // Dates
                    const Divider(),
                    Text(
                      'Criado em: ${DateTime.parse(_item.createdAt).toLocal().toString().split('.')[0]}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    if (_item.updatedAt != null) ...[
                      Text(
                        'Atualizado em: ${DateTime.parse(_item.updatedAt!).toLocal().toString().split('.')[0]}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
