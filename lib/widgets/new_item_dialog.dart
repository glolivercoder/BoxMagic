import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/services/preferences_service.dart';
import 'package:boxmagic/services/persistence_service.dart';
import 'package:boxmagic/services/log_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class NewItemDialog extends StatefulWidget {
  final List<Box>? boxes;
  final int? preselectedBoxId;
  final Item? editItem; // Item para edição (null para novo item)

  const NewItemDialog({
    Key? key,
    this.boxes,
    this.preselectedBoxId,
    this.editItem,
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
  final _persistenceService = PersistenceService();
  final _logService = LogService();
  final _imagePicker = ImagePicker();
  List<String> _categories = ['Diversos'];
  List<Box> _boxes = [];
  bool _isLoading = true;

  // Variáveis para gerenciar imagens
  XFile? _imageFile;
  String? _base64Image;
  bool _hasImage = false;

  @override
  void initState() {
    super.initState();

    // Verificar se estamos editando um item existente
    if (widget.editItem != null) {
      _nameController.text = widget.editItem!.name;
      _descriptionController.text = widget.editItem!.description ?? '';
      _selectedCategory = widget.editItem!.category;
      _selectedBoxId = widget.editItem!.boxId;

      // Verificar se o item tem imagem
      if (widget.editItem!.image != null && widget.editItem!.image!.isNotEmpty) {
        _base64Image = widget.editItem!.image;
        _hasImage = true;
      }
    } else {
      // Caso de novo item
      _selectedBoxId = widget.preselectedBoxId;
    }

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _logService.info('Iniciando carregamento de dados para o diálogo de novo item', category: 'new_item_dialog');

      final categories = await _preferencesService.getCategories();
      _logService.debug('Categorias carregadas: ${categories.length}', category: 'new_item_dialog');

      List<Box> boxes;

      if (widget.boxes != null) {
        boxes = widget.boxes!;
        _logService.debug('Usando caixas fornecidas externamente: ${boxes.length}', category: 'new_item_dialog');

        // Log detalhado das caixas
        for (int i = 0; i < boxes.length; i++) {
          _logService.debug('Caixa $i: ID=${boxes[i].id}, Nome=${boxes[i].name}', category: 'new_item_dialog');
        }
      } else {
        _logService.debug('Carregando caixas do banco de dados', category: 'new_item_dialog');
        boxes = await _databaseHelper.readAllBoxes();
        _logService.debug('Caixas carregadas do banco de dados: ${boxes.length}', category: 'new_item_dialog');

        // Log detalhado das caixas
        for (int i = 0; i < boxes.length; i++) {
          _logService.debug('Caixa $i: ID=${boxes[i].id}, Nome=${boxes[i].name}', category: 'new_item_dialog');
        }

        // Se não houver caixas, tentar carregar diretamente do serviço de persistência
        if (boxes.isEmpty) {
          _logService.warning('Nenhuma caixa encontrada no DatabaseHelper, tentando carregar do serviço de persistência', category: 'new_item_dialog');

          // Usar a instância de PersistenceService que já criamos
          final data = await _persistenceService.loadAllData();
          final persistedBoxes = data['boxes'] as List<Box>;

          _logService.debug('Caixas carregadas do serviço de persistência: ${persistedBoxes.length}', category: 'new_item_dialog');

          if (persistedBoxes.isNotEmpty) {
            // Atualizar o DatabaseHelper com as caixas persistidas
            for (final box in persistedBoxes) {
              await _databaseHelper.createBox(box);
              _logService.debug('Caixa adicionada ao DatabaseHelper: ID=${box.id}, Nome=${box.name}', category: 'new_item_dialog');
            }

            // Recarregar as caixas
            boxes = await _databaseHelper.readAllBoxes();
            _logService.debug('Caixas recarregadas após atualização: ${boxes.length}', category: 'new_item_dialog');
          }
        }
      }

      setState(() {
        _categories = categories;
        _boxes = boxes;
        _isLoading = false;
      });

      _logService.info('Dados carregados com sucesso para o diálogo de novo item', category: 'new_item_dialog');
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao carregar dados para o diálogo de novo item',
        error: e,
        stackTrace: stackTrace,
        category: 'new_item_dialog',
      );

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar categoria: $e')),
        );
      }
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

    try {
      Item? savedItem;

      if (widget.editItem != null) {
        // Modo de edição - atualizar item existente
        _logService.info('Atualizando item existente: ${widget.editItem!.id}', category: 'new_item_dialog');
        _logService.debug('Nome: ${_nameController.text}', category: 'new_item_dialog');
        _logService.debug('Categoria: $_selectedCategory', category: 'new_item_dialog');
        _logService.debug('Descrição: ${_descriptionController.text}', category: 'new_item_dialog');
        _logService.debug('ID da Caixa: $_selectedBoxId', category: 'new_item_dialog');
        _logService.debug('Tem imagem: $_hasImage', category: 'new_item_dialog');

        final updatedItem = Item(
          id: widget.editItem!.id,
          name: _nameController.text,
          category: _selectedCategory,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          image: _base64Image, // Incluir a imagem em base64
          boxId: _selectedBoxId!,
          createdAt: widget.editItem!.createdAt,
          updatedAt: now,
        );

        // Atualizar o item no banco de dados
        final result = await _databaseHelper.updateItem(updatedItem);

        if (result > 0) {
          savedItem = updatedItem;
          if (mounted) {
            // Mostrar mensagem de sucesso
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Objeto atualizado com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Falha ao atualizar o objeto');
        }
      } else {
        // Modo de criação - criar novo item
        _logService.info('Criando novo item', category: 'new_item_dialog');
        _logService.debug('Nome: ${_nameController.text}', category: 'new_item_dialog');
        _logService.debug('Categoria: $_selectedCategory', category: 'new_item_dialog');
        _logService.debug('Descrição: ${_descriptionController.text}', category: 'new_item_dialog');
        _logService.debug('ID da Caixa: $_selectedBoxId', category: 'new_item_dialog');
        _logService.debug('Tem imagem: $_hasImage', category: 'new_item_dialog');

        final newItem = Item(
          name: _nameController.text,
          category: _selectedCategory,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          image: _base64Image, // Incluir a imagem em base64
          boxId: _selectedBoxId!,
          createdAt: now,
        );

        // Criar o item no banco de dados
        savedItem = await _databaseHelper.createItem(newItem);

        if (mounted) {
          // Mostrar mensagem de sucesso
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Objeto criado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, savedItem);
      }
    } catch (e, stackTrace) {
      // Registrar o erro
      _logService.error(
        'Erro ao salvar objeto',
        error: e,
        stackTrace: stackTrace,
        category: 'new_item_dialog',
      );

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
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(widget.editItem != null ? 'Editar Objeto' : 'Novo Objeto'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botão de câmera
              IconButton(
                icon: const Icon(Icons.camera_alt),
                tooltip: 'Tirar foto',
                onPressed: _takePicture,
              ),
              // Botão de galeria
              IconButton(
                icon: const Icon(Icons.photo_library),
                tooltip: 'Escolher da galeria',
                onPressed: _pickImage,
              ),
            ],
          ),
        ],
      ),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Visualização da imagem (se houver)
                    if (_hasImage)
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Container(
                            height: 150,
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb
                                  ? Image.memory(
                                      base64Decode(_base64Image!),
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(_imageFile!.path),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: _removeImage,
                          ),
                        ],
                      ),

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
          child: Text(widget.editItem != null ? 'Atualizar' : 'Salvar'),
        ),
      ],
    );
  }

  // Método para capturar imagem da câmera
  Future<void> _takePicture() async {
    _logService.info('Iniciando captura de imagem da câmera', category: 'new_item_dialog');

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        _processImage(image);
      } else {
        _logService.info('Captura de imagem cancelada pelo usuário', category: 'new_item_dialog');
      }
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao capturar imagem da câmera',
        error: e,
        stackTrace: stackTrace,
        category: 'new_item_dialog',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar imagem: $e')),
        );
      }
    }
  }

  // Método para selecionar imagem da galeria
  Future<void> _pickImage() async {
    _logService.info('Iniciando seleção de imagem da galeria', category: 'new_item_dialog');

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        _processImage(image);
      } else {
        _logService.info('Seleção de imagem cancelada pelo usuário', category: 'new_item_dialog');
      }
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao selecionar imagem da galeria',
        error: e,
        stackTrace: stackTrace,
        category: 'new_item_dialog',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
    }
  }

  // Método para processar a imagem selecionada
  Future<void> _processImage(XFile image) async {
    _logService.info('Processando imagem: ${image.path}', category: 'new_item_dialog');

    try {
      // Ler a imagem como bytes
      final bytes = await image.readAsBytes();

      // Converter para base64
      final base64Image = base64Encode(bytes);

      setState(() {
        _imageFile = image;
        _base64Image = base64Image;
        _hasImage = true;
      });

      _logService.info('Imagem processada com sucesso', category: 'new_item_dialog');
    } catch (e, stackTrace) {
      _logService.error(
        'Erro ao processar imagem',
        error: e,
        stackTrace: stackTrace,
        category: 'new_item_dialog',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao processar imagem: $e')),
        );
      }
    }
  }

  // Método para remover a imagem
  void _removeImage() {
    _logService.info('Removendo imagem', category: 'new_item_dialog');

    setState(() {
      _imageFile = null;
      _base64Image = null;
      _hasImage = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
