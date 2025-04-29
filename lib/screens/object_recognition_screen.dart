import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/services/gemini_service.dart';
import 'package:image_picker/image_picker.dart';

class ObjectRecognitionScreen extends StatefulWidget {
  final List<Box> boxes;
  
  const ObjectRecognitionScreen({
    Key? key,
    required this.boxes,
  }) : super(key: key);

  @override
  _ObjectRecognitionScreenState createState() => _ObjectRecognitionScreenState();
}

class _ObjectRecognitionScreenState extends State<ObjectRecognitionScreen> {
  final GeminiService _geminiService = GeminiService();
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final ImagePicker _picker = ImagePicker();
  
  XFile? _imageFile;
  bool _isProcessing = false;
  String? _errorMessage;
  Map<String, String>? _objectInfo;
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  int? _selectedBoxId;

  @override
  void initState() {
    super.initState();
    if (widget.boxes.isNotEmpty) {
      _selectedBoxId = widget.boxes.first.id;
    }
  }

  Future<void> _takePhoto() async {
    setState(() {
      _imageFile = null;
      _objectInfo = null;
      _errorMessage = null;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 800,
      );

      if (photo != null) {
        setState(() {
          _imageFile = photo;
          _isProcessing = true;
        });

        // Analisar objeto
        final objectInfo = await _geminiService.analyzeObject(photo);
        
        if (objectInfo != null) {
          setState(() {
            _objectInfo = objectInfo;
            _nameController.text = objectInfo['name'] ?? '';
            _descriptionController.text = objectInfo['description'] ?? '';
            _selectedCategory = objectInfo['category'];
            _isProcessing = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Não foi possível analisar o objeto na imagem';
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao capturar ou processar a imagem: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveObject() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBoxId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma caixa')),
      );
      return;
    }

    final now = DateTime.now().toIso8601String();

    final newItem = Item(
      name: _nameController.text,
      category: _selectedCategory,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      boxId: _selectedBoxId!,
      createdAt: now,
      // Em uma implementação completa, você salvaria a imagem e armazenaria o caminho aqui
      // image: savedImagePath,
    );

    try {
      final savedItem = await _databaseHelper.createItem(newItem);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Objeto salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, savedItem);
      }
    } catch (e) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reconhecimento de Objeto'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Tire uma foto do objeto para identificá-lo automaticamente',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Imagem capturada
              if (_imageFile != null)
                AspectRatio(
                  aspectRatio: 16 / 9, // Proporção widescreen, pode ajustar conforme preferir
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: kIsWeb
                          ? Image.network(_imageFile!.path, fit: BoxFit.contain)
                          : Image.file(File(_imageFile!.path), fit: BoxFit.contain),
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Botão para tirar foto
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Tirar Foto'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Indicador de processamento
              if (_isProcessing)
                Column(
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analisando objeto...'),
                  ],
                ),
              
              // Formulário para editar e salvar o objeto
              if (_objectInfo != null && !_isProcessing)
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informações do Objeto',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome do objeto',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, insira um nome para o objeto';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          'Eletrônicos',
                          'Ferramentas manuais',
                          'Ferramentas elétricas',
                          'Equipamentos de áudio',
                          'Informática',
                          'Itens de escritório',
                          'Outros',
                        ].map((category) {
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
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _selectedBoxId,
                        decoration: const InputDecoration(
                          labelText: 'Caixa',
                          border: OutlineInputBorder(),
                        ),
                        items: widget.boxes.map((box) {
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
                      const SizedBox(height: 24),
                      Center(
                        child: ElevatedButton(
                          onPressed: _saveObject,
                          child: const Text('Salvar Objeto'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Mensagem de erro
              if (_errorMessage != null && !_isProcessing)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
