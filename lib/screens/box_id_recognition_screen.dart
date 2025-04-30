import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/services/database_helper.dart';
import 'package:boxmagic/services/gemini_service.dart';
import 'package:boxmagic/screens/box_detail_screen.dart';
import 'package:image_picker/image_picker.dart';

class BoxIdRecognitionScreen extends StatefulWidget {
  const BoxIdRecognitionScreen({super.key});

  @override
  _BoxIdRecognitionScreenState createState() => _BoxIdRecognitionScreenState();
}

class _BoxIdRecognitionScreenState extends State<BoxIdRecognitionScreen> {
  final GeminiService _geminiService = GeminiService();
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final ImagePicker _picker = ImagePicker();
  
  XFile? _imageFile;
  bool _isProcessing = false;
  String? _recognizedId;
  String? _errorMessage;
  Box? _foundBox;

  Future<void> _takePhoto() async {
    setState(() {
      _imageFile = null;
      _recognizedId = null;
      _errorMessage = null;
      _foundBox = null;
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

        // Reconhecer ID da caixa
        final id = await _geminiService.recognizeBoxId(photo);
        
        if (id != null) {
          setState(() {
            _recognizedId = id;
          });
          
          // Tentar encontrar a caixa com este ID
          try {
            final boxId = int.parse(id);
            final box = await _databaseHelper.readBox(boxId);
            
            setState(() {
              _foundBox = box;
              _isProcessing = false;
            });
          } catch (e) {
            setState(() {
              _errorMessage = 'Não foi possível encontrar uma caixa com o ID $id';
              _isProcessing = false;
            });
          }
        } else {
          setState(() {
            _errorMessage = 'Não foi possível reconhecer um ID de caixa na imagem';
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

  void _navigateToBoxDetail() {
    if (_foundBox != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BoxDetailScreen(box: _foundBox!),
        ),
      ).then((_) => Navigator.pop(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reconhecimento de ID'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Tire uma foto do ID da caixa para identificá-la',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Imagem capturada
              if (_imageFile != null)
                Container(
                  width: double.infinity,
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: kIsWeb
                      ? Image.network(_imageFile!.path, fit: BoxFit.cover)
                      : Image.file(File(_imageFile!.path), fit: BoxFit.cover),
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
                    Text('Processando imagem...'),
                  ],
                ),
              
              // Resultado do reconhecimento
              if (_recognizedId != null && !_isProcessing)
                Column(
                  children: [
                    Text(
                      'ID Reconhecido: $_recognizedId',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_foundBox != null)
                      Column(
                        children: [
                          Text(
                            'Caixa encontrada: ${_foundBox!.name}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _navigateToBoxDetail,
                            child: const Text('Ver Detalhes da Caixa'),
                          ),
                        ],
                      ),
                  ],
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
}
