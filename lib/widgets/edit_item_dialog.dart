import 'package:flutter/material.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/services/preferences_service.dart';

class EditItemDialog extends StatefulWidget {
  final Item item;

  const EditItemDialog({super.key, required this.item});

  @override
  _EditItemDialogState createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<EditItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  String? _selectedCategory;
  int? _selectedBoxId;
  final _databaseHelper = DatabaseHelper.instance;
  final _preferencesService = PreferencesService();
  List<String> _categories = [];
  List<Box> _boxes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _descriptionController = TextEditingController(text: widget.item.description ?? '');
    _selectedCategory = widget.item.category;
    _selectedBoxId = widget.item.boxId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await _preferencesService.getCategories();
      final boxes = await _databaseHelper.readAllBoxes();
      
      setState(() {
        _categories = categories;
        _boxes = boxes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: $e')),
      );
    }
  }

  Future<void> _addNewCategory(String category) async {
    if (category.isEmpty) return;

    try {
      await _preferencesService.addCategory(category);
      await _loadData();
      setState(() {
        _selectedCategory = category;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao adicionar categoria: $e')),
      );
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final textController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova Categoria'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            labelText: 'Nome da categoria',
            hintText: 'Ex: Eletrônicos, Ferramentas, etc.',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _addNewCategory(result);
    }
  }

  Future<void> _updateItem() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now().toIso8601String();

    final updatedItem = widget.item.copyWith(
      name: _nameController.text,
      category: _selectedCategory,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      boxId: _selectedBoxId,
      updatedAt: now,
    );

    try {
      await _databaseHelper.updateItem(updatedItem);
      if (mounted) {
        Navigator.pop(context, updatedItem);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Objeto atualizado com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar objeto: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Objeto'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do objeto',
                        hintText: 'Ex: Martelo, Furadeira, etc.',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira um nome para o objeto';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Categoria (opcional)',
                        hintText: 'Selecione uma categoria',
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _showAddCategoryDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Nova categoria'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedBoxId,
                      decoration: const InputDecoration(
                        labelText: 'Caixa',
                        hintText: 'Selecione uma caixa',
                      ),
                      items: _boxes.map((box) {
                        return DropdownMenuItem<int>(
                          value: box.id,
                          child: Text('${box.name} (ID: ${box.id})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBoxId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor, selecione uma caixa';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição (opcional)',
                        hintText: 'Ex: Martelo de carpinteiro com cabo de madeira',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateItem,
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
