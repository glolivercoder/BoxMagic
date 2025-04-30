import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import '../models/etiqueta.dart';

/// Gera um PDF de etiquetas a partir de um modelo Etiqueta, lista de dados e tipo de conteúdo
Future<pw.Document> gerarPdfEtiquetas({
  required Etiqueta etiqueta,
  required List<Map<String, String>> dadosCaixas,
  required TipoEtiqueta tipo,
}) async {
  final pdf = pw.Document();
  
  // Carregar fonte padrão
  final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
  final ttf = pw.Font.ttf(fontData);

  // Conversão de cm para pontos (1 cm = 28.35 pontos)
  double cmToPt(double cm) => cm * 28.35;

  final alturaPt = cmToPt(etiqueta.alturaCm);
  final larguraPt = cmToPt(etiqueta.larguraCm);
  final margemSuperiorPt = cmToPt(etiqueta.margemSuperiorCm);
  final margemInferiorPt = cmToPt(etiqueta.margemInferiorCm);
  final margemEsquerdaPt = cmToPt(etiqueta.margemEsquerdaCm);
  final margemDireitaPt = cmToPt(etiqueta.margemDireitaCm);
  final espacoEntreEtiquetasPt = cmToPt(etiqueta.espacoEntreEtiquetasCm);

  // Dimensões da página A4
  final pageWidth = PdfPageFormat.a4.width;
  final pageHeight = PdfPageFormat.a4.height;

  // Área útil (descontando margens)
  final areaUtilWidth = pageWidth - margemEsquerdaPt - margemDireitaPt;
  final areaUtilHeight = pageHeight - margemSuperiorPt - margemInferiorPt;

  // Cálculo preciso de colunas e linhas
  final numColunas = ((areaUtilWidth + espacoEntreEtiquetasPt) / (larguraPt + espacoEntreEtiquetasPt)).floor();
  final numLinhas = ((areaUtilHeight + espacoEntreEtiquetasPt) / (alturaPt + espacoEntreEtiquetasPt)).floor();
  
  final etiquetasPorPagina = numColunas * numLinhas;
  final numPaginas = (dadosCaixas.length / etiquetasPorPagina).ceil();

  // Gerar páginas
  for (int pagina = 0; pagina < numPaginas; pagina++) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Padding(
            padding: pw.EdgeInsets.only(
              left: margemEsquerdaPt,
              top: margemSuperiorPt,
              right: margemDireitaPt,
              bottom: margemInferiorPt
            ),
            child: pw.Column(
              children: List.generate(numLinhas, (linha) {
                return pw.Row(
                  children: List.generate(numColunas, (coluna) {
                    final index = pagina * etiquetasPorPagina + linha * numColunas + coluna;
                    if (index >= dadosCaixas.length) return pw.Container(width: larguraPt, height: alturaPt);

                    final dados = dadosCaixas[index];
                    return pw.Container(
                      width: larguraPt,
                      height: alturaPt,
                      margin: pw.EdgeInsets.only(
                        right: coluna < numColunas - 1 ? espacoEntreEtiquetasPt : 0,
                        bottom: linha < numLinhas - 1 ? espacoEntreEtiquetasPt : 0,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(width: 0.5)
                      ),
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          // Código de barras
                          pw.BarcodeWidget(
                            data: dados['id'] ?? '',
                            barcode: pw.Barcode.code128(),
                            width: larguraPt * 0.8,
                            height: alturaPt * 0.2,
                          ),
                          pw.SizedBox(height: 2),
                          // ID
                          pw.Text(
                            'ID: ${dados['id']}',
                            style: pw.TextStyle(font: ttf, fontSize: 8)
                          ),
                          if (tipo != TipoEtiqueta.idApenas) ...[
                            pw.SizedBox(height: 2),
                            // Nome
                            pw.Text(
                              dados['nome'] ?? '',
                              style: pw.TextStyle(
                                font: ttf,
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                          if (tipo == TipoEtiqueta.idNomeEConteudo) ...[
                            pw.SizedBox(height: 2),
                            // Conteúdo
                            pw.Text(
                              dados['conteudo'] ?? '',
                              style: pw.TextStyle(font: ttf, fontSize: 7),
                              textAlign: pw.TextAlign.center,
                              maxLines: 2,
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                );
              }),
            ),
          );
        },
      ),
    );
  }

  return pdf;
}
