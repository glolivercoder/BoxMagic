import 'dart:typed_data';
import 'package:boxmagic/models/box.dart';
import 'package:boxmagic/models/item.dart';
import 'package:boxmagic/services/log_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Calcular tamanho de fonte proporcional ao tamanho da etiqueta
  double _calculateFontSize(double labelHeight, double baseFontSize) {
    // Altura de referência para a qual os tamanhos de fonte foram definidos
    const double referenceHeight = 50.0 * PdfPageFormat.mm; // Altura de referência em pontos
    
    // Calcular o fator de escala
    double scaleFactor = labelHeight / referenceHeight;
    
    // Aplicar o fator de escala com limites mínimos e máximos
    double scaledFontSize = baseFontSize * scaleFactor;
    
    // Garantir que o tamanho da fonte não seja muito pequeno ou muito grande
    return scaledFontSize.clamp(6.0, baseFontSize * 1.5);
  }

  // Calcular tamanho do QR code proporcional ao tamanho da etiqueta
  double _calculateQrCodeSize(double labelHeight, double labelWidth) {
    // Usar o menor valor entre altura e largura para garantir que o QR code caiba
    double minDimension = labelHeight < labelWidth ? labelHeight : labelWidth;
    
    // Considerar o espaço disponível com margens
    double availableSpace = minDimension * 0.85; // Reservar 15% para margens
    
    // Limitar o tamanho máximo para garantir que caiba na etiqueta
    double maxSize = availableSpace * 0.45; // Usar no máximo 45% do espaço disponível
    
    // Garantir um tamanho mínimo para legibilidade e máximo para não ultrapassar margens
    // Mínimo de 20 para garantir que o QR code seja legível
    // Máximo de 70 para garantir que não ultrapasse as margens em etiquetas pequenas
    return maxSize < 20 ? 20 : (maxSize > 70 ? 70 : maxSize);
  }

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
    try {
      _logService.info('Gerando PDF para impressão de etiquetas', category: 'printing');
      _logService.debug('Formato: $format, Tipo de papel: $paperType', category: 'printing');
      _logService.debug('Número de caixas: ${boxes.length}', category: 'printing');
      
      // Criar documento PDF - usamos a fonte padrão
      // Os avisos sobre Unicode são apenas informativos e não afetam a funcionalidade
      final pdf = pw.Document();
      
      // Nota: Se os avisos "Helvetica has no Unicode support" incomodarem,
      // podemos ignorar esses avisos, pois não afetam a funcionalidade básica
      // para caracteres latinos comuns usados no Brasil.

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
          // Uma etiqueta por página, tamanho A4 com margens
          labelWidth = pageFormat.availableWidth;
          labelHeight = pageFormat.availableHeight;
          labelsPerRow = 1;
          labelsPerColumn = 1;
          break;
      }

      // Calcular número de páginas necessárias
      final int labelsPerPage = labelsPerRow * labelsPerColumn;
      final int numPages = (boxes.length / labelsPerPage).ceil();

      // Gerar QR codes para todas as caixas
      Map<int, Uint8List> qrCodes = {};
      for (var box in boxes) {
        if (box.id != null) {
          qrCodes[box.id!] = await _generateQrCode(box.formattedId);
        }
      }

      // Gerar páginas do PDF
      for (int pageIndex = 0; pageIndex < numPages; pageIndex++) {
        final startIndex = pageIndex * labelsPerPage;
        final endIndex = (startIndex + labelsPerPage) < boxes.length
            ? startIndex + labelsPerPage
            : boxes.length;

        // Adicionar página ao documento
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (pw.Context context) {
              // Criar grid de etiquetas
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Informações da página (opcional, apenas para preview)
                  if (isPreview)
                    pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 5),
                      child: pw.Text(
                        'Etiquetas ${startIndex + 1} a $endIndex de ${boxes.length} - Página ${pageIndex + 1} de $numPages',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                  // Grid de etiquetas
                  pw.Expanded(
                    child: pw.GridView(
                      crossAxisCount: labelsPerRow,
                      childAspectRatio: labelWidth / labelHeight,
                      children: List.generate(
                        labelsPerPage,
                        (index) {
                          final labelIndex = startIndex + index;
                          if (labelIndex < boxes.length) {
                            // Calcular posição da etiqueta na grade
                            final row = index ~/ labelsPerRow;
                            final col = index % labelsPerRow;
                            
                            // Construir etiqueta
                            return _buildLabelWidget(
                              row,
                              col,
                              labelIndex,
                              boxes,
                              boxItems,
                              format,
                              qrCodes,
                              labelWidth,
                              labelHeight,
                              labelsPerRow,
                              isPreview: isPreview,
                            );
                          } else {
                            // Espaço vazio para etiquetas não utilizadas
                            return pw.Container();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      // Retornar PDF como bytes
      return pdf.save();
    } catch (e, stackTrace) {
      _logService.error('Erro ao gerar PDF de etiquetas: $e', category: 'printing', stackTrace: stackTrace);
      rethrow;
    }
  }

  // Construir widget de etiqueta individual
  pw.Widget _buildLabelWidget(
    int row,
    int col,
    int labelIndex,
    List<Box> boxes,
    Map<int, List<Item>> boxItems,
    LabelFormat format,
    Map<int, Uint8List> qrCodes,
    double labelWidth,
    double labelHeight,
    int labelsPerRow,
    {bool isPreview = false}
  ) {
    final box = boxes[labelIndex];
    final items = box.id != null ? (boxItems[box.id] ?? []) : [];

    // Container para a etiqueta com borda para visualização
    return pw.Container(
      width: labelWidth,
      height: labelHeight,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: isPreview ? PdfColors.grey300 : PdfColors.white,
          width: 0.5,
        ),
      ),
      padding: const pw.EdgeInsets.all(5),
      child: _buildLabelContent(
        box,
        items,
        format,
        qrCodes,
        labelWidth,
        labelHeight,
      ),
    );
  }

  // Construir conteúdo da etiqueta com base no formato selecionado
  pw.Widget _buildLabelContent(
    Box box,
    List<dynamic> items,
    LabelFormat format,
    Map<int, Uint8List> qrCodes,
    double labelWidth,
    double labelHeight,
  ) {
    // Converter a lista dinâmica para uma lista de Item
    final List<Item> itemsList = items.cast<Item>();
    switch (format) {
      case LabelFormat.nameWithBarcodeAndId:
        return _buildNameWithBarcodeAndId(box, qrCodes, labelWidth, labelHeight);
      case LabelFormat.idWithBarcode:
        return _buildIdWithBarcode(box, qrCodes, labelWidth, labelHeight);
      case LabelFormat.idWithBarcodeAndItems:
        return _buildIdWithBarcodeAndItems(box, itemsList, qrCodes, labelWidth, labelHeight);
    }
  }

  // Formato 1: Nome da caixa + código de barras + ID
  pw.Widget _buildNameWithBarcodeAndId(Box box, Map<int, Uint8List> qrCodes, double labelWidth, double labelHeight) {
    final qrCodeSize = _calculateQrCodeSize(labelHeight, labelWidth);
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
                  fontSize: _calculateFontSize(labelHeight, 14),
                  fontWeight: pw.FontWeight.bold,
                ),
                maxLines: 1,
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
                style: pw.TextStyle(
                  fontSize: _calculateFontSize(labelHeight, 12),
                  color: PdfColors.blue900,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Categoria: ${box.category}',
          style: pw.TextStyle(fontSize: _calculateFontSize(labelHeight, 10)),
          maxLines: 1,
        ),
        if (box.description != null && box.description!.isNotEmpty)
          pw.Text(
            'Descrição: ${box.description}',
            style: pw.TextStyle(fontSize: _calculateFontSize(labelHeight, 8)),
            maxLines: 2,
          ),
        pw.Expanded(
          child: pw.Center(
            child: qrCode != null
                ? pw.Container(
                    padding: const pw.EdgeInsets.all(4),
                    margin: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    constraints: pw.BoxConstraints(
                      maxWidth: labelWidth * 0.75,
                      maxHeight: labelHeight * 0.45,
                    ),
                    child: pw.Center(
                      child: pw.Image(
                        pw.MemoryImage(qrCode),
                        width: qrCodeSize,
                        height: qrCodeSize,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  )
                : pw.Container(),
          ),
        ),
      ],
    );
  }

  // Formato 2: Somente ID + código de barras
  pw.Widget _buildIdWithBarcode(Box box, Map<int, Uint8List> qrCodes, double labelWidth, double labelHeight) {
    final qrCodeSize = _calculateQrCodeSize(labelHeight, labelWidth);
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
              fontSize: _calculateFontSize(labelHeight, 18),
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Expanded(
          child: pw.Center(
            child: qrCode != null
                ? pw.Container(
                    padding: const pw.EdgeInsets.all(4),
                    margin: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    constraints: pw.BoxConstraints(
                      maxWidth: labelWidth * 0.75,
                      maxHeight: labelHeight * 0.55,
                    ),
                    child: pw.Center(
                      child: pw.Image(
                        pw.MemoryImage(qrCode),
                        width: qrCodeSize,
                        height: qrCodeSize,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  )
                : pw.Container(),
          ),
        ),
      ],
    );
  }

  // Formato 3: ID + código de barras + lista de itens
  pw.Widget _buildIdWithBarcodeAndItems(Box box, List<Item> items, Map<int, Uint8List> qrCodes, double labelWidth, double labelHeight) {
    final qrCodeSize = _calculateQrCodeSize(labelHeight, labelWidth) * 0.8; // Reduzir um pouco para dar espaço aos itens
    final qrCode = box.id != null ? qrCodes[box.id] : null;
    final fontSize = _calculateFontSize(labelHeight, 8);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                '#${box.formattedId}',
                style: pw.TextStyle(
                  fontSize: _calculateFontSize(labelHeight, 16),
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ),
            qrCode != null
                ? pw.Container(
                    padding: const pw.EdgeInsets.all(3),
                    margin: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    constraints: pw.BoxConstraints(
                      maxWidth: labelWidth * 0.38,
                      maxHeight: labelHeight * 0.38,
                    ),
                    child: pw.Center(
                      child: pw.Image(
                        pw.MemoryImage(qrCode),
                        width: qrCodeSize,
                        height: qrCodeSize,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  )
                : pw.Container(),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Itens:',
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Expanded(
          child: pw.ListView(
            children: items.isEmpty
                ? [
                    pw.Text(
                      'Nenhum item cadastrado',
                      style: pw.TextStyle(
                        fontSize: fontSize,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    )
                  ]
                : items
                    .take(10) // Limitar a 10 itens para não sobrecarregar
                    .map(
                      (item) => pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Text(
                          '- ${item.name}${item.description != null && item.description!.isNotEmpty ? ' (${item.description})' : ''}',
                          style: pw.TextStyle(fontSize: fontSize),
                          maxLines: 1,
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
        if (items.length > 10)
          pw.Text(
            '+ ${items.length - 10} mais itens...',
            style: pw.TextStyle(
              fontSize: fontSize,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
      ],
    );
  }

  // Gerar QR code para uma string
  Future<Uint8List> _generateQrCode(String data) async {
    try {
      final qrValidationResult = QrValidator.validate(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      );

      final qrCode = qrValidationResult.qrCode;
      
      if (qrCode == null) {
        throw Exception('Falha ao gerar QR code: ${qrValidationResult.error}');
      }

      final painter = QrPainter.withQr(
        qr: qrCode,
        color: Colors.black,
        gapless: false,
        embeddedImageStyle: null,
        embeddedImage: null,
      );

      final picSize = 200.0; // Tamanho fixo para geração, será redimensionado no PDF
      final image = await painter.toImage(picSize);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('Falha ao converter QR code para bytes');
      }
      
      return byteData.buffer.asUint8List();
    } catch (e, stackTrace) {
      _logService.error('Erro ao gerar QR code: $e', category: 'printing', stackTrace: stackTrace);
      // Retornar um QR code de erro ou uma imagem em branco
      return Uint8List.fromList([]);
    }
  }

  // Método para imprimir etiquetas (abre diálogo de impressão)
  Future<void> printLabels({
    required List<Box> boxes,
    required Map<int, List<Item>> boxItems,
    required LabelFormat format,
    required LabelPaperType paperType,
  }) async {
    try {
      final pdfBytes = await generateLabelsPdf(
        boxes: boxes,
        boxItems: boxItems,
        format: format,
        paperType: paperType,
      );

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'Etiquetas BoxMagic',
        format: PdfPageFormat.a4,
      );
    } catch (e, stackTrace) {
      _logService.error('Erro ao imprimir etiquetas: $e', category: 'printing', stackTrace: stackTrace);
      rethrow;
    }
  }
}
