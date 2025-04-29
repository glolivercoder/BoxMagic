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

  // Conversão de cm para pontos
  double cmToPt(double cm) => cm * 28.35;

  final alturaPt = cmToPt(etiqueta.alturaCm);
  final larguraPt = cmToPt(etiqueta.larguraCm);
  final margemSuperiorPt = cmToPt(etiqueta.margemSuperiorCm);
  final margemInferiorPt = cmToPt(etiqueta.margemInferiorCm);
  final margemEsquerdaPt = cmToPt(etiqueta.margemEsquerdaCm);
  final margemDireitaPt = cmToPt(etiqueta.margemDireitaCm);
  final espacoEntreEtiquetasPt = cmToPt(etiqueta.espacoEntreEtiquetasCm);

  final pageWidth = PdfPageFormat.a4.width;
  final pageHeight = PdfPageFormat.a4.height;

  // Cálculo de colunas e linhas
  final numColunas = ((pageWidth - margemEsquerdaPt - margemDireitaPt + espacoEntreEtiquetasPt) /
      (larguraPt + espacoEntreEtiquetasPt)).floor();
  final numLinhas = ((pageHeight - margemSuperiorPt - margemInferiorPt + espacoEntreEtiquetasPt) /
      (alturaPt + espacoEntreEtiquetasPt)).floor();
  final etiquetasPorPagina = numColunas * numLinhas;
  final numPaginas = (dadosCaixas.length / etiquetasPorPagina).ceil();

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
          final etiquetasRestantes = dadosCaixas.length - (pagina * etiquetasPorPagina);
          final etiquetasNestaPagina = etiquetasRestantes > etiquetasPorPagina
              ? etiquetasPorPagina
              : etiquetasRestantes;
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: List.generate(numLinhas, (linha) {
              return pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: List.generate(numColunas, (coluna) {
                  final index = pagina * etiquetasPorPagina + linha * numColunas + coluna;
                  if (index >= dadosCaixas.length) return pw.Container();
                  final dados = dadosCaixas[index];
                  String texto = '';
                  switch (tipo) {
                    case TipoEtiqueta.idApenas:
                      texto = dados['id'] ?? '';
                      break;
                    case TipoEtiqueta.idENome:
                      texto = '${dados['id'] ?? ''} - ${dados['nome'] ?? ''}';
                      break;
                    case TipoEtiqueta.idNomeEConteudo:
                      texto = '${dados['id'] ?? ''} - ${dados['nome'] ?? ''}\n${dados['conteudo'] ?? ''}';
                      break;
                  }
                  return pw.Container(
                    width: larguraPt,
                    height: alturaPt,
                    margin: pw.EdgeInsets.only(
                      right: coluna < numColunas - 1 ? espacoEntreEtiquetasPt : 0,
                      bottom: linha < numLinhas - 1 ? espacoEntreEtiquetasPt : 0,
                    ),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      texto,
                      style: pw.TextStyle(font: ttf, fontSize: 10),
                      textAlign: pw.TextAlign.center,
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
