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

  Etiqueta? _selectedEtiqueta;
  bool _modoPersonalizado = false;

  // Tipo de conteúdo da etiqueta
  TipoEtiqueta _tipoEtiqueta = TipoEtiqueta.idENome;

  // Controladores para os campos de texto
  final _alturaController = TextEditingController();
  final _larguraController = TextEditingController();
  final _margemSuperiorController = TextEditingController();
  final _margemInferiorController = TextEditingController();
  final _margemEsquerdaController = TextEditingController();
  final _margemDireitaController = TextEditingController();
  final _espacoEntreEtiquetasController = TextEditingController();
  final _etiquetasPorFolhaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Selecionar o primeiro modelo por padrão
    if (modelosPimaco.isNotEmpty) {
      _selectedEtiqueta = modelosPimaco.first;
      _atualizarControladores();
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

  // Método para visualizar o PDF
  Future<void> _previewPdf() async {
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
              Text('Gerando preview...'),
            ],
          ),
        ),
      );

      // Gerar o PDF
      final pdf = await _gerarPdf();
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

      final pdf = await _gerarPdf();
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
  Future<pw.Document> _gerarPdf() async {
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

    // Calcular o número de colunas e linhas
    final pageWidth = PdfPageFormat.a4.width;
    final pageHeight = PdfPageFormat.a4.height;

    final areaUtilWidth = pageWidth - margemEsquerdaPt - margemDireitaPt;
    final areaUtilHeight = pageHeight - margemSuperiorPt - margemInferiorPt;

    final numColunas = (areaUtilWidth / (larguraPt + espacoEntreEtiquetasPt)).floor();
    final numLinhas = (areaUtilHeight / (alturaPt + espacoEntreEtiquetasPt)).floor();

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
          margin: pw.EdgeInsets.only(
            top: margemSuperiorPt,
            bottom: margemInferiorPt,
            left: margemEsquerdaPt,
            right: margemDireitaPt,
          ),
          build: (context) {
            // Calcular o número de etiquetas nesta página
            final etiquetasRestantes = caixas.length - (pagina * etiquetasPorPagina);
            final etiquetasNestaPagina = etiquetasRestantes > etiquetasPorPagina
                ? etiquetasPorPagina
                : etiquetasRestantes;

            // Criar uma grade de etiquetas
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: List.generate(numLinhas, (linha) {
                return pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: List.generate(numColunas, (coluna) {
                    final index = linha * numColunas + coluna;

                    // Verificar se ainda há etiquetas para mostrar
                    if (index >= etiquetasNestaPagina) {
                      return pw.SizedBox(
                        width: larguraPt,
                        height: alturaPt,
                      );
                    }

                    // Obter os dados da caixa
                    final caixaIndex = pagina * etiquetasPorPagina + index;
                    if (caixaIndex >= caixas.length) {
                      return pw.SizedBox(
                        width: larguraPt,
                        height: alturaPt,
                      );
                    }

                    final caixa = caixas[caixaIndex];
                    final caixaId = caixa['id'] as String;
                    final caixaNome = caixa['nome'] as String;
                    final caixaConteudo = caixa['conteudo'] as String;

                    return pw.Padding(
                      padding: pw.EdgeInsets.only(
                        right: coluna < numColunas - 1 ? espacoEntreEtiquetasPt : 0,
                        bottom: linha < numLinhas - 1 ? espacoEntreEtiquetasPt : 0,
                      ),
                      child: pw.Container(
                        width: larguraPt,
                        height: alturaPt,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black),
                        ),
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              // Código de barras (sempre presente)
                              pw.BarcodeWidget(
                                barcode: pw.Barcode.code128(),
                                data: caixaId,
                                width: larguraPt * 0.8,
                                height: 30,
                                drawText: true,
                                textStyle: pw.TextStyle(
                                  font: ttf,
                                  fontSize: 8,
                                ),
                              ),

                              pw.SizedBox(height: 5),

                              // ID da caixa (sempre presente)
                              pw.Text(
                                'ID: $caixaId',
                                style: pw.TextStyle(
                                  font: ttf,
                                  fontSize: 10,
                                ),
                              ),

                              // Nome da caixa (presente em idENome e idNomeEConteudo)
                              if (_tipoEtiqueta == TipoEtiqueta.idENome ||
                                  _tipoEtiqueta == TipoEtiqueta.idNomeEConteudo) ...[
                                pw.SizedBox(height: 5),
                                pw.Text(
                                  caixaNome,
                                  style: pw.TextStyle(
                                    font: ttf,
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ],

                              // Conteúdo da caixa (apenas em idNomeEConteudo)
                              if (_tipoEtiqueta == TipoEtiqueta.idNomeEConteudo && alturaPt > 100) ...[
                                pw.SizedBox(height: 5),
                                pw.Container(
                                  width: larguraPt * 0.9,
                                  child: pw.Text(
                                    'Conteúdo: $caixaConteudo',
                                    style: pw.TextStyle(
                                      font: ttf,
                                      fontSize: 8,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                );
              }),
            );
          },
        ),
      );
    }

    return pdf;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impressão de Etiquetas'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seleção de modelo ou personalizado
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Etiqueta>(
                    decoration: const InputDecoration(
                      labelText: 'Modelo de Etiqueta',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedEtiqueta,
                    onChanged: (value) {
                      setState(() {
                        _selectedEtiqueta = value;
                        _modoPersonalizado = value?.personalizada ?? false;
                        _atualizarControladores();
                      });
                    },
                    items: modelosPimaco.map((e) {
                      return DropdownMenuItem<Etiqueta>(
                        value: e,
                        child: Text(e.nome),
                      );
                    }).toList(),
                  ),
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
    );
  }
}