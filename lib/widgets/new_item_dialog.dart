import 'package:flutter/material.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/services/preferences_service.dart';

class NewItemDialog extends StatefulWidget {
  final List<Box>? boxes;
  final int? preselectedBoxId;

  const NewItemDialog({
    Key? key,
    this.boxes,
    this.preselectedBoxId,
  }) : super(key: key);

  @override
  _NewItemDialogState createState() => _NewItemDialogState();
}

class _NewItemDialogState extends State<NewItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
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
    _selectedBoxId = widget.preselectedBoxId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await _preferencesService.getCategories();
      List<Box> boxes;

      if (widget.boxes != null) {
        boxes = widget.boxes!;
      } else {
        boxes = await _databaseHelper.readAllBoxes();
      }

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

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now().toIso8601String();

    // Verificar se temos uma caixa selecionada
    if (_selectedBoxId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma caixa')),
      );
      return;
    }

    // Mostrar informações de debug
    print('Criando item:');
    print('Nome: ${_nameController.text}');
    print('Categoria: $_selectedCategory');
    print('Descrição: ${_descriptionController.text}');
    print('ID da Caixa: $_selectedBoxId');

    final newItem = Item(
      name: _nameController.text,
      category: _selectedCategory,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      boxId: _selectedBoxId!,
      createdAt: now,
    );

    try {
      final savedItem = await _databaseHelper.createItem(newItem);
      if (mounted) {
        // Mostrar mensagem de sucesso
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Objeto criado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, savedItem);
      }
    } catch (e, stackTrace) {
      // Mostrar mais informações sobre o erro
      print('Erro ao salvar objeto: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar objeto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo Objeto'),
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
          onPressed: _isLoading ? null : _saveItem,
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
