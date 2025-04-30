import 'dart:typed_data';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/services/log_service.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;

enum LabelFormat {
  nameWithBarcodeAndId,
  idWithBarcode,
  idWithBarcodeAndItems,
}

enum LabelPaperType {
  pimaco6180, // Pimaco 6180 - Padrão Correios (A4 com 10 etiquetas)
  pimaco6082, // Pimaco 6082 - 2 colunas, 14 linhas (A4 com 28 etiquetas)
  a4Full,     // Página A4 inteira
}

class LabelPrintingService {
  final LogService _logService = LogService();

  // Dimensões do papel Pimaco 6180 (padrão Correios)
  // Cada etiqueta tem 84.7mm x 50.8mm em uma folha A4
  static const double pimaco6180Width = 84.7 * PdfPageFormat.mm;
  static const double pimaco6180Height = 50.8 * PdfPageFormat.mm;
  static const int pimaco6180LabelsPerRow = 2;
  static const int pimaco6180LabelsPerColumn = 5;

  // Dimensões do papel Pimaco 6082
  // Cada etiqueta tem 44.4mm x 12.7mm em uma folha A4
  static const double pimaco6082Width = 44.4 * PdfPageFormat.mm;
  static const double pimaco6082Height = 12.7 * PdfPageFormat.mm;
  static const int pimaco6082LabelsPerRow = 2;
  static const int pimaco6082LabelsPerColumn = 14;

  // Gerar PDF para impressão de etiquetas
  Future<Uint8List> generateLabelsPdf({
    required List<Box> boxes,
    required Map<int, List<Item>> boxItems,
    required LabelFormat format,
    required LabelPaperType paperType,
    bool isPreview = false,
  }) async {
    _logService.info('Gerando PDF para impressão de etiquetas', category: 'printing');
    _logService.debug('Formato: $format, Tipo de papel: $paperType', category: 'printing');
    _logService.debug('Número de caixas: ${boxes.length}', category: 'printing');

    // Criar documento PDF
    final pdf = pw.Document();

    // Definir tamanho da página e margens
    final pageFormat = PdfPageFormat.a4;

    // Definir dimensões da etiqueta com base no tipo de papel
    double labelWidth;
    double labelHeight;
    int labelsPerRow;
    int labelsPerColumn;

    switch (paperType) {
      case LabelPaperType.pimaco6180:
        labelWidth = pimaco6180Width;
        labelHeight = pimaco6180Height;
        labelsPerRow = pimaco6180LabelsPerRow;
        labelsPerColumn = pimaco6180LabelsPerColumn;
        break;
      case LabelPaperType.pimaco6082:
        labelWidth = pimaco6082Width;
        labelHeight = pimaco6082Height;
        labelsPerRow = pimaco6082LabelsPerRow;
        labelsPerColumn = pimaco6082LabelsPerColumn;
        break;
      case LabelPaperType.a4Full:
        labelWidth = pageFormat.width - 40;
        labelHeight = pageFormat.height / 3 - 40;
        labelsPerRow = 1;
        labelsPerColumn = 3;
        break;
    }

    // Calcular número de etiquetas por página
    final labelsPerPage = labelsPerRow * labelsPerColumn;

    // Calcular número de páginas necessárias
    final numPages = (boxes.length / labelsPerPage).ceil();

    // Gerar QR codes para cada caixa
    final Map<int, Uint8List> qrCodes = {};
    for (final box in boxes) {
      if (box.id != null) {
        try {
          final qrCode = await _generateQrCode(box.id.toString());
          qrCodes[box.id!] = qrCode;
        } catch (e) {
          _logService.error('Erro ao gerar QR code para caixa ${box.id}', error: e, category: 'printing');
        }
      }
    }

    // Criar páginas
    for (int pageIndex = 0; pageIndex < numPages; pageIndex++) {
      final startIndex = pageIndex * labelsPerPage;
      final endIndex = (startIndex + labelsPerPage) < boxes.length
          ? startIndex + labelsPerPage
          : boxes.length;

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            // Criar grid de etiquetas
            return pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (int row = 0; row < labelsPerColumn; row++)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 5),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.start,
                        children: [
                          for (int col = 0; col < labelsPerRow; col++)
                            _buildLabelWidget(
                              row,
                              col,
                              startIndex,
                              boxes,
                              boxItems,
                              format,
                              qrCodes,
                              labelWidth,
                              labelHeight,
                              labelsPerRow,
                              isPreview: isPreview,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  // Construir widget de etiqueta
  pw.Widget _buildLabelWidget(
    int row,
    int col,
    int startIndex,
    List<Box> boxes,
    Map<int, List<Item>> boxItems,
    LabelFormat format,
    Map<int, Uint8List> qrCodes,
    double labelWidth,
    double labelHeight,
    int labelsPerRow,
    {bool isPreview = false}
  ) {
    final index = startIndex + row * labelsPerRow + col;

    // Se não houver mais caixas, retornar um container vazio ou com borda cinza no modo preview
    if (index >= boxes.length) {
      return pw.Container(
        width: labelWidth,
        height: labelHeight,
        margin: const pw.EdgeInsets.all(2),
        decoration: isPreview ? pw.BoxDecoration(
          border: pw.Border.all(width: 1, color: PdfColors.grey300),
        ) : null,
      );
    }

    final box = boxes[index];
    final items = boxItems[box.id] ?? [];

    // Definir a cor da borda baseada no modo preview
    final borderColor = isPreview ? PdfColors.red : PdfColors.black;
    final borderWidth = isPreview ? 2.0 : 1.0;
    
    return pw.Container(
      width: labelWidth,
      height: labelHeight,
      margin: const pw.EdgeInsets.all(2),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: borderWidth, color: borderColor),
      ),
      padding: const pw.EdgeInsets.all(5),
      child: _buildLabelContent(box, items, format, qrCodes),
    );
  }

  // Construir conteúdo da etiqueta com base no formato selecionado
  pw.Widget _buildLabelContent(
    Box box,
    List<Item> items,
    LabelFormat format,
    Map<int, Uint8List> qrCodes,
  ) {
    switch (format) {
      case LabelFormat.nameWithBarcodeAndId:
        return _buildNameWithBarcodeAndId(box, qrCodes);
      case LabelFormat.idWithBarcode:
        return _buildIdWithBarcode(box, qrCodes);
      case LabelFormat.idWithBarcodeAndItems:
        return _buildIdWithBarcodeAndItems(box, items, qrCodes);
    }
  }

  // Formato 1: Nome da caixa + código de barras + ID
  pw.Widget _buildNameWithBarcodeAndId(Box box, Map<int, Uint8List> qrCodes) {
    final qrCode = box.id != null ? qrCodes[box.id] : null;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                box.name,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(2),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                '#${box.formattedId}',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.blue900,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Categoria: ${box.category}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        if (box.description != null && box.description!.isNotEmpty)
          pw.Text(
            'Descrição: ${box.description}',
            style: const pw.TextStyle(fontSize: 8),
            maxLines: 2,
          ),
        pw.Expanded(
          child: pw.Center(
            child: qrCode != null
                ? pw.Image(pw.MemoryImage(qrCode), width: 80, height: 80)
                : pw.Container(),
          ),
        ),
      ],
    );
  }

  // Formato 2: Somente ID + código de barras
  pw.Widget _buildIdWithBarcode(Box box, Map<int, Uint8List> qrCodes) {
    final qrCode = box.id != null ? qrCodes[box.id] : null;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue100,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            '#${box.formattedId}',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Expanded(
          child: pw.Center(
            child: qrCode != null
                ? pw.Image(pw.MemoryImage(qrCode), width: 100, height: 100)
                : pw.Container(),
          ),
        ),
      ],
    );
  }

  // Formato 3: ID + código de barras + itens da caixa
  pw.Widget _buildIdWithBarcodeAndItems(Box box, List<Item> items, Map<int, Uint8List> qrCodes) {
    final qrCode = box.id != null ? qrCodes[box.id] : null;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(2),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                '#${box.formattedId}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ),
            qrCode != null
                ? pw.Image(pw.MemoryImage(qrCode), width: 50, height: 50)
                : pw.Container(width: 50, height: 50),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Itens:',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Container(
          height: 60,
          child: pw.ListView(
            children: [
              for (int i = 0; i < items.length; i++)
                pw.Text(
                  '• ${items[i].name}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Gerar QR code para uma caixa
  Future<Uint8List> _generateQrCode(String data) async {
    try {
      // Usar uma abordagem mais simples para gerar o QR code
      final qrCode = QrPainter(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
        // Desenhar em um fundo branco
        gapless: false,
      );

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // Desenhar o QR code em um canvas
      qrCode.paint(canvas, Size(200, 200));

      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(200, 200);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        return byteData.buffer.asUint8List();
      } else {
        throw Exception('Falha ao converter QR code para imagem');
      }
    } catch (e) {
      _logService.error('Erro ao gerar QR code', error: e, category: 'printing');
      rethrow;
    }
  }

  // Imprimir etiquetas
  Future<void> printLabels({
    required List<Box> boxes,
    required Map<int, List<Item>> boxItems,
    required LabelFormat format,
    required LabelPaperType paperType,
  }) async {
    try {
      _logService.info('Iniciando impressão de etiquetas', category: 'printing');

      final pdfData = await generateLabelsPdf(
        boxes: boxes,
        boxItems: boxItems,
        format: format,
        paperType: paperType,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        name: 'BoxMagic - Etiquetas',
      );

      _logService.info('Impressão de etiquetas concluída', category: 'printing');
    } catch (e) {
      _logService.error('Erro ao imprimir etiquetas', error: e, category: 'printing');
      rethrow;
    }
  }
}
