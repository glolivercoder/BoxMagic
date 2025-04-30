import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode/barcode.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/etiqueta.dart';
import '../data/modelos_pimaco.dart';
import '../services/preferences_service.dart';

// Tipo de conteúdo da etiqueta
enum TipoEtiqueta { idApenas, idENome, idNomeEConteudo }

class EtiquetasScreen extends StatefulWidget {
  const EtiquetasScreen({Key? key}) : super(key: key);

  @override
  _EtiquetasScreenState createState() => _EtiquetasScreenState();
}

class _EtiquetasScreenState extends State<EtiquetasScreen> {
  String _barcodeValue = '';
  bool _showBarcode = false;
  bool _memorizeLastModel = false;

  Etiqueta? _selectedEtiqueta;
  bool _modoPersonalizado = false;
  TipoEtiqueta _tipoEtiqueta = TipoEtiqueta.idENome;
  final PreferencesService _preferencesService = PreferencesService();

  // Controladores para os campos de texto
  final _alturaController = TextEditingController();
  final _larguraController = TextEditingController();
  final _margemSuperiorController = TextEditingController();
  final _margemInferiorController = TextEditingController();
  final _margemEsquerdaController = TextEditingController();
  final _margemDireitaController = TextEditingController();
  final _espacoEntreEtiquetasController = TextEditingController();
  final _etiquetasPorFolhaController = TextEditingController();

  int _previewKey = 0; // Adicionar controle de versão do preview

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final lastModelName = await _preferencesService.getLastUsedModel();
    if (lastModelName != null) {
      final model = modelosPimaco.firstWhere(
        (e) => e.nome == lastModelName,
        orElse: () => modelosPimaco.first,
      );
      setState(() {
        _selectedEtiqueta = model;
        _memorizeLastModel = true;
      });
    } else if (modelosPimaco.isNotEmpty) {
      setState(() {
        _selectedEtiqueta = modelosPimaco.first;
      });
    }
    _atualizarControladores();
  }

  Future<void> _saveLastUsedModel() async {
    if (_memorizeLastModel && _selectedEtiqueta != null) {
      await _preferencesService.saveLastUsedModel(_selectedEtiqueta!.nome);
    }
  }

  @override
  void dispose() {
    _alturaController.dispose();
    _larguraController.dispose();
    _margemSuperiorController.dispose();
    _margemInferiorController.dispose();
    _margemEsquerdaController.dispose();
    _margemDireitaController.dispose();
    _espacoEntreEtiquetasController.dispose();
    _etiquetasPorFolhaController.dispose();
    super.dispose();
  }

  void _atualizarControladores() {
    if (_selectedEtiqueta == null) return;

    _alturaController.text = _selectedEtiqueta!.alturaCm.toString();
    _larguraController.text = _selectedEtiqueta!.larguraCm.toString();
    _margemSuperiorController.text = _selectedEtiqueta!.margemSuperiorCm.toString();
    _margemInferiorController.text = _selectedEtiqueta!.margemInferiorCm.toString();
    _margemEsquerdaController.text = _selectedEtiqueta!.margemEsquerdaCm.toString();
    _margemDireitaController.text = _selectedEtiqueta!.margemDireitaCm.toString();
    _espacoEntreEtiquetasController.text = _selectedEtiqueta!.espacoEntreEtiquetasCm.toString();
    _etiquetasPorFolhaController.text = _selectedEtiqueta!.etiquetasPorFolha.toString();
  }

  void _atualizarEtiquetaPersonalizada() {
    if (_selectedEtiqueta == null) return;

    try {
      final altura = double.parse(_alturaController.text);
      final largura = double.parse(_larguraController.text);
      final margemSuperior = double.parse(_margemSuperiorController.text);
      final margemInferior = double.parse(_margemInferiorController.text);
      final margemEsquerda = double.parse(_margemEsquerdaController.text);
      final margemDireita = double.parse(_margemDireitaController.text);
      final espacoEntreEtiquetas = double.parse(_espacoEntreEtiquetasController.text);
      final etiquetasPorFolha = int.parse(_etiquetasPorFolhaController.text);

      setState(() {
        _selectedEtiqueta = Etiqueta(
          nome: "Personalizada",
          alturaCm: altura,
          larguraCm: largura,
          etiquetasPorFolha: etiquetasPorFolha,
          margemSuperiorCm: margemSuperior,
          margemInferiorCm: margemInferior,
          margemEsquerdaCm: margemEsquerda,
          margemDireitaCm: margemDireita,
          espacoEntreEtiquetasCm: espacoEntreEtiquetas,
          personalizada: true,
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, insira valores numéricos válidos'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Método para limpar cache e forçar atualização
  void _forcePreviewUpdate() {
    setState(() {
      _previewKey++;
    });
    Printing.clearCache(); // Limpar cache do PDF
  }

  // Método para visualizar o PDF
  Future<void> _previewPdf() async {
    if (_selectedEtiqueta == null) return;

    try {
      _forcePreviewUpdate(); // Força atualização antes de mostrar preview
      // Mostrar diálogo de carregamento
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Gerando preview...'),
            ],
          ),
        ),
      );

      // Gerar o PDF
      final pdf = await _gerarPdf(mostrarBordasPreview: true);
      final bytes = await pdf.save();

      // Fechar o diálogo de carregamento
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Mostrar o preview em tela cheia
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text('Preview - ${_selectedEtiqueta!.nome}'),
                actions: [
                  // Botão para imprimir
                  IconButton(
                    icon: const Icon(Icons.print),
                    tooltip: 'Imprimir',
                    onPressed: () async {
                      try {
                        final result = await Printing.layoutPdf(
                          onLayout: (format) => Future.value(bytes),
                          name: 'Etiquetas_${_selectedEtiqueta!.nome}.pdf',
                        );

                        if (mounted) {
                          if (result) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Documento enviado para impressão'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Impressão cancelada'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao imprimir: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  // Botão para compartilhar
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Compartilhar',
                    onPressed: () async {
                      try {
                        final result = await Printing.sharePdf(
                          bytes: bytes,
                          filename: 'Etiquetas_${_selectedEtiqueta!.nome}.pdf',
                        );

                        if (mounted) {
                          if (result) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('PDF compartilhado com sucesso'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Compartilhamento cancelado'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao compartilhar: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'O preview abaixo respeita o tamanho real do papel A4 e das etiquetas.\n'
                      'Se as etiquetas parecerem pequenas, é porque o modelo selecionado realmente possui dimensões menores.',
                      style: TextStyle(color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: _buildPdfPreview(context),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      // Fechar o diálogo de carregamento se ainda estiver aberto
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar preview: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Método para imprimir o PDF
  Future<void> _imprimirPdf() async {
    if (_selectedEtiqueta == null) return;

    try {
      // Mostrar diálogo de carregamento
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Gerando PDF...'),
            ],
          ),
        ),
      );

      final pdf = await _gerarPdf(mostrarBordasPreview: false);
      final bytes = await pdf.save();

      // Fechar o diálogo de carregamento
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Mostrar diálogo com opções
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Exportar Etiquetas'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Escolha uma opção:'),
                const SizedBox(height: 16),

                // Opção 1: Imprimir
                ListTile(
                  leading: const Icon(Icons.print),
                  title: const Text('Imprimir'),
                  subtitle: const Text('Enviar para impressora'),
                  onTap: () async {
                    Navigator.pop(dialogContext);

                    try {
                      final result = await Printing.layoutPdf(
                        onLayout: (PdfPageFormat format) => Future.value(bytes),
                        name: 'Etiquetas_${_selectedEtiqueta!.nome}.pdf',
                      );

                      if (mounted) {
                        if (result) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Documento enviado para impressão'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Impressão cancelada'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erro ao imprimir: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),

                // Opção 2: Visualizar e Imprimir
                ListTile(
                  leading: const Icon(Icons.preview),
                  title: const Text('Visualizar e Imprimir'),
                  subtitle: const Text('Ver o PDF antes de imprimir'),
                  onTap: () async {
                    Navigator.pop(dialogContext);

                    // Mostrar o preview em tela cheia
                    if (mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              title: Text('Preview - ${_selectedEtiqueta!.nome}'),
                              actions: [
                                // Botão para imprimir
                                IconButton(
                                  icon: const Icon(Icons.print),
                                  tooltip: 'Imprimir',
                                  onPressed: () async {
                                    try {
                                      final result = await Printing.layoutPdf(
                                        onLayout: (format) => Future.value(bytes),
                                        name: 'Etiquetas_${_selectedEtiqueta!.nome}.pdf',
                                      );

                                      if (mounted) {
                                        if (result) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Documento enviado para impressão'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Impressão cancelada'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Erro ao imprimir: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                                // Botão para compartilhar
                                IconButton(
                                  icon: const Icon(Icons.share),
                                  tooltip: 'Compartilhar',
                                  onPressed: () async {
                                    try {
                                      final result = await Printing.sharePdf(
                                        bytes: bytes,
                                        filename: 'Etiquetas_${_selectedEtiqueta!.nome}.pdf',
                                      );

                                      if (mounted) {
                                        if (result) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('PDF compartilhado com sucesso'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Compartilhamento cancelado'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Erro ao compartilhar: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            body: PdfPreview(
                              build: (format) => Future.value(bytes),
                              allowPrinting: true,
                              allowSharing: true,
                              canChangePageFormat: false,
                              canChangeOrientation: false,
                              initialPageFormat: PdfPageFormat.a4,
                              pdfFileName: 'Etiquetas_${_selectedEtiqueta!.nome}.pdf',
                              previewPageMargin: const EdgeInsets.all(10),
                              scrollViewDecoration: BoxDecoration(
                                color: Colors.grey.shade200,
                              ),
                              maxPageWidth: 700,
                              actions: const [],
                              useActions: false,  // Desabilitar botões padrão para usar nossos próprios botões
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),

                // Opção 3: Compartilhar
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Compartilhar'),
                  subtitle: const Text('Enviar por e-mail, WhatsApp, etc.'),
                  onTap: () async {
                    Navigator.pop(dialogContext);

                    try {
                      // Compartilhar PDF usando o plugin printing
                      final result = await Printing.sharePdf(
                        bytes: bytes,
                        filename: 'Etiquetas_${_selectedEtiqueta!.nome}.pdf',
                      );

                      if (mounted) {
                        if (result) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PDF compartilhado com sucesso'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Compartilhamento cancelado'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    } catch (shareError) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erro ao compartilhar: $shareError'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Fechar o diálogo de carregamento se ainda estiver aberto
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Método para gerar o PDF com base nas configurações da etiqueta
  Future<pw.Document> _gerarPdf({bool mostrarBordasPreview = false}) async {
    final pdf = pw.Document();
    final etiqueta = _selectedEtiqueta!;

    // Carregar a fonte para o código de barras
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    // Converter cm para pontos (1 cm = 28.35 pontos)
    final alturaPt = etiqueta.alturaCm * 28.35;
    final larguraPt = etiqueta.larguraCm * 28.35;
    final margemSuperiorPt = etiqueta.margemSuperiorCm * 28.35;
    final margemInferiorPt = etiqueta.margemInferiorCm * 28.35;
    final margemEsquerdaPt = etiqueta.margemEsquerdaCm * 28.35;
    final margemDireitaPt = etiqueta.margemDireitaCm * 28.35;
    final espacoEntreEtiquetasPt = etiqueta.espacoEntreEtiquetasCm * 28.35;

    // Calcular o número de colunas e linhas na área útil
    final pageWidth = PdfPageFormat.a4.width;
    final pageHeight = PdfPageFormat.a4.height;

    final areaUtilWidth = pageWidth - margemEsquerdaPt - margemDireitaPt;
    final areaUtilHeight = pageHeight - margemSuperiorPt - margemInferiorPt;

    // Calcular número de etiquetas que cabem na horizontal e vertical
    final numColunas = ((areaUtilWidth + espacoEntreEtiquetasPt) / (larguraPt + espacoEntreEtiquetasPt)).floor();
    final numLinhas = ((areaUtilHeight + espacoEntreEtiquetasPt) / (alturaPt + espacoEntreEtiquetasPt)).floor();

    // Calcular o número de etiquetas por página
    final etiquetasPorPagina = numColunas * numLinhas;

    // Simular dados de caixas para demonstração
    final caixas = List.generate(
      etiqueta.etiquetasPorFolha,
      (index) => {
        'id': (1000 + index).toString().padLeft(4, '0'),
        'nome': 'Caixa ${(1000 + index).toString().padLeft(4, '0')}',
        'conteudo': 'Livros, documentos, fotos',
      },
    );

    // Calcular o número de páginas necessárias
    final numPaginas = (caixas.length / etiquetasPorPagina).ceil();

    // Gerar as páginas
    for (int pagina = 0; pagina < numPaginas; pagina++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Stack(
              children: [
                if (mostrarBordasPreview) ...[
                  // Área total da página
                  pw.Container(
                    width: pageWidth,
                    height: pageHeight,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey.shade(0.3)),
                    ),
                  ),
                  // Área útil (dentro das margens)
                  pw.Positioned(
                    left: margemEsquerdaPt,
                    top: margemSuperiorPt,
                    child: pw.Container(
                      width: areaUtilWidth,
                      height: areaUtilHeight,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.blue.shade(0.3),
                          width: 0.5,
                          style: pw.BorderStyle.dashed,
                        ),
                      ),
                    ),
                  ),
                ],

                // Grade de etiquetas
                pw.Positioned(
                  left: margemEsquerdaPt,
                  top: margemSuperiorPt,
                  child: pw.Column(
                    children: List.generate(numLinhas, (linha) {
                      return pw.Row(
                        children: List.generate(numColunas, (coluna) {
                          final index = pagina * etiquetasPorPagina + linha * numColunas + coluna;
                          if (index >= caixas.length) {
                            // Etiqueta vazia (não será impressa)
                            return pw.Container(
                              width: larguraPt,
                              height: alturaPt,
                              margin: pw.EdgeInsets.only(
                                right: coluna < numColunas - 1 ? espacoEntreEtiquetasPt : 0,
                                bottom: linha < numLinhas - 1 ? espacoEntreEtiquetasPt : 0,
                              ),
                              decoration: mostrarBordasPreview ? pw.BoxDecoration(
                                border: pw.Border.all(
                                  color: PdfColors.grey.shade(0.3),
                                  width: 0.5,
                                  style: pw.BorderStyle.dashed,
                                ),
                              ) : null,
                            );
                          }

                          // Etiqueta com conteúdo (será impressa)
                          final dados = caixas[index];
                          return pw.Container(
                            width: larguraPt,
                            height: alturaPt,
                            margin: pw.EdgeInsets.only(
                              right: coluna < numColunas - 1 ? espacoEntreEtiquetasPt : 0,
                              bottom: linha < numLinhas - 1 ? espacoEntreEtiquetasPt : 0,
                            ),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(
                                color: mostrarBordasPreview ? PdfColors.blue : PdfColors.transparent,
                                width: 0.5,
                              ),
                            ),
                            child: pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  // Código de barras
                                  pw.BarcodeWidget(
                                    barcode: pw.Barcode.code128(),
                                    data: dados['id']!,
                                    width: larguraPt * 0.8,
                                    height: larguraPt * 0.2,
                                    textStyle: pw.TextStyle(font: ttf, fontSize: 8),
                                  ),
                                  pw.SizedBox(height: 2),
                                  // ID
                                  pw.Text(
                                    'ID: ${dados['id']}',
                                    style: pw.TextStyle(font: ttf, fontSize: 8),
                                  ),
                                  if (_tipoEtiqueta != TipoEtiqueta.idApenas) ...[
                                    pw.SizedBox(height: 2),
                                    // Nome
                                    pw.Text(
                                      dados['nome']!,
                                      style: pw.TextStyle(
                                        font: ttf,
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                      textAlign: pw.TextAlign.center,
                                    ),
                                  ],
                                  if (_tipoEtiqueta == TipoEtiqueta.idNomeEConteudo) ...[
                                    pw.SizedBox(height: 2),
                                    // Conteúdo
                                    pw.Text(
                                      dados['conteudo']!,
                                      style: pw.TextStyle(font: ttf, fontSize: 7),
                                      textAlign: pw.TextAlign.center,
                                      maxLines: 2,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf;
  }

  Widget _buildPdfPreview(BuildContext context) {
    final pageWidth = PdfPageFormat.a4.width;
    final scaleFactor = MediaQuery.of(context).size.width / pageWidth;
    
    return PdfPreview(
      key: ValueKey('preview_${_selectedEtiqueta?.nome}_${_tipoEtiqueta}_${_previewKey}'),
      build: (format) => _gerarPdf(mostrarBordasPreview: true),
      initialPageFormat: PdfPageFormat.a4,
      maxPageWidth: pageWidth * scaleFactor,
      canChangeOrientation: false,
      canChangePageFormat: false,
      dynamicLayout: true,
      useActions: false,
      padding: EdgeInsets.zero,
      pdfPreviewPageDecoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      onError: (context, error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar preview: $error'),
            backgroundColor: Colors.red,
          ),
        );
        return const Center(child: Text('Erro ao gerar preview'));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Etiquetas')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dropdown de modelo de etiqueta no topo
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Modelo de Etiqueta',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Etiqueta>(
                        value: _selectedEtiqueta,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Modelo de Etiqueta',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                        items: modelosPimaco.map((modelo) {
                          return DropdownMenuItem<Etiqueta>(
                            value: modelo,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  modelo.nome,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${modelo.larguraCm.toStringAsFixed(1)}x${modelo.alturaCm.toStringAsFixed(1)}cm - ${modelo.etiquetasPorFolha} por folha',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedEtiqueta = value;
                            _modoPersonalizado = value?.personalizada ?? false;
                            _atualizarControladores();
                            if (_memorizeLastModel) {
                              _saveLastUsedModel();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _memorizeLastModel,
                            onChanged: (value) {
                              setState(() {
                                _memorizeLastModel = value ?? false;
                                if (_memorizeLastModel) {
                                  _saveLastUsedModel();
                                }
                              });
                            },
                          ),
                          const Text('Memorizar último modelo usado'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Campo para digitar o valor do código de barras
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Valor do Código de Barras',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _barcodeValue = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code),
                label: const Text('Gerar Código de Barras'),
                onPressed: _barcodeValue.isNotEmpty
                    ? () {
                        setState(() {
                          _showBarcode = true;
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 24),
              if (_showBarcode && _barcodeValue.isNotEmpty)
                Center(
                  child: BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: _barcodeValue,
                    width: 280,
                    height: 80,
                    drawText: true,
                  ),
                ),
              const SizedBox(height: 24),
              Scaffold(
                appBar: AppBar(
                  title: const Text('Impressão de Etiquetas'),
                ),
                const SizedBox(width: 16),
                Switch(
                  value: _modoPersonalizado,
                  onChanged: (value) {
                    setState(() {
                      _modoPersonalizado = value;
                      if (value) {
                        // Selecionar o modelo personalizado
                        _selectedEtiqueta = modelosPimaco.lastWhere(
                          (e) => e.personalizada,
                          orElse: () => modelosPimaco.last,
                        );
                      } else {
                        // Selecionar o primeiro modelo padrão
                        _selectedEtiqueta = modelosPimaco.firstWhere(
                          (e) => !e.personalizada,
                          orElse: () => modelosPimaco.first,
                        );
                      }
                      _atualizarControladores();
                    });
                  },
                ),
                const Text('Personalizar'),
              ],
            ),

            const SizedBox(height: 24),

            // Informações do modelo selecionado
            if (_selectedEtiqueta != null && !_modoPersonalizado)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modelo: ${_selectedEtiqueta!.nome}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Altura: ${_selectedEtiqueta!.alturaCm} cm'),
                      Text('Largura: ${_selectedEtiqueta!.larguraCm} cm'),
                      Text('Etiquetas por folha: ${_selectedEtiqueta!.etiquetasPorFolha}'),
                      Text('Margem superior: ${_selectedEtiqueta!.margemSuperiorCm} cm'),
                      Text('Margem inferior: ${_selectedEtiqueta!.margemInferiorCm} cm'),
                      Text('Margem esquerda: ${_selectedEtiqueta!.margemEsquerdaCm} cm'),
                      Text('Margem direita: ${_selectedEtiqueta!.margemDireitaCm} cm'),
                      Text('Espaço entre etiquetas: ${_selectedEtiqueta!.espacoEntreEtiquetasCm} cm'),
                    ],
                  ),
                ),
              ),

            // Campos para personalização
            if (_modoPersonalizado)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Personalizar Etiqueta',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dimensões da etiqueta
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _alturaController,
                              decoration: const InputDecoration(
                                labelText: 'Altura (cm)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _larguraController,
                              decoration: const InputDecoration(
                                labelText: 'Largura (cm)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Margens
                      const Text(
                        'Margens (cm)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _margemSuperiorController,
                              decoration: const InputDecoration(
                                labelText: 'Superior',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _margemInferiorController,
                              decoration: const InputDecoration(
                                labelText: 'Inferior',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _margemEsquerdaController,
                              decoration: const InputDecoration(
                                labelText: 'Esquerda',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _margemDireitaController,
                              decoration: const InputDecoration(
                                labelText: 'Direita',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Espaçamento e quantidade
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _espacoEntreEtiquetasController,
                              decoration: const InputDecoration(
                                labelText: 'Espaço entre etiquetas (cm)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _etiquetasPorFolhaController,
                              decoration: const InputDecoration(
                                labelText: 'Etiquetas por folha',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Center(
                        child: ElevatedButton(
                          onPressed: _atualizarEtiquetaPersonalizada,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Aplicar Alterações'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Opções de conteúdo da etiqueta
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Conteúdo da Etiqueta',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Opções de tipo de etiqueta
                    RadioListTile<TipoEtiqueta>(
                      title: const Text('Apenas ID e código de barras'),
                      value: TipoEtiqueta.idApenas,
                      groupValue: _tipoEtiqueta,
                      onChanged: (value) {
                        setState(() {
                          _tipoEtiqueta = value!;
                        });
                      },
                    ),
                    RadioListTile<TipoEtiqueta>(
                      title: const Text('ID, código de barras e nome da caixa'),
                      value: TipoEtiqueta.idENome,
                      groupValue: _tipoEtiqueta,
                      onChanged: (value) {
                        setState(() {
                          _tipoEtiqueta = value!;
                        });
                      },
                    ),
                    RadioListTile<TipoEtiqueta>(
                      title: const Text('ID, código de barras, nome e conteúdo da caixa'),
                      value: TipoEtiqueta.idNomeEConteudo,
                      groupValue: _tipoEtiqueta,
                      onChanged: (value) {
                        setState(() {
                          _tipoEtiqueta = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botões de ação
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _previewPdf,
                  icon: const Icon(Icons.preview),
                  label: const Text('Visualizar PDF'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _imprimirPdf,
                  icon: const Icon(Icons.print),
                  label: const Text('Imprimir'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton.icon(
                onPressed: _previewPdf,
                icon: const Icon(Icons.preview),
                label: const Text('Visualizar'),
              ),
              ElevatedButton.icon(
                onPressed: _imprimirPdf,
                icon: const Icon(Icons.print),
                label: const Text('Imprimir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}