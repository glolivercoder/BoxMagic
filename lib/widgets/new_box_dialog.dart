import 'package:flutter/material.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/services/preferences_service.dart';

class NewBoxDialog extends StatefulWidget {
  final Function(Box)? onBoxCreated;

  const NewBoxDialog({Key? key, this.onBoxCreated}) : super(key: key);

  @override
  _NewBoxDialogState createState() => _NewBoxDialogState();
}

class _NewBoxDialogState extends State<NewBoxDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  final _databaseHelper = DatabaseHelper.instance;
  final _preferencesService = PreferencesService();
  List<String> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await _preferencesService.getCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar categorias: $e')),
      );
    }
  }

  Future<void> _addNewCategory(String category) async {
    if (category.isEmpty) return;

    try {
      await _preferencesService.addCategory(category);
      await _loadCategories();
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

  Future<void> _saveBox() async {
    if (!_formKey.currentState!.validate()) return;

    final nextId = await _preferencesService.incrementAndGetNextBoxId();
    final now = DateTime.now().toIso8601String();

    final newBox = Box(
      id: nextId,
      name: _nameController.text,
      category: _selectedCategory!,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      createdAt: now,
      items: [], // Initialize with empty items list
    );

    try {
      final savedBox = await _databaseHelper.createBox(newBox);

      // Chamar o callback se existir
      if (widget.onBoxCreated != null) {
        widget.onBoxCreated!(savedBox);
      }

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caixa criada com sucesso!')),
        );
        Navigator.pop(context, savedBox);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar caixa: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova Caixa'),
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
                        labelText: 'Nome da caixa',
                        hintText: 'Ex: Ferramentas de Marcenaria',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira um nome para a caixa';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, selecione uma categoria';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _showAddCategoryDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Nova categoria'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição (opcional)',
                        hintText: 'Ex: Caixa com ferramentas para trabalhos em madeira',
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
          onPressed: _isLoading ? null : _saveBox,
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
