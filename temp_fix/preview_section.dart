import 'package:flutter/material.dart';

// Este é apenas um trecho de código para corrigir a parte problemática
// Copie este trecho para substituir a parte com erro no arquivo boxes_screen.dart

Widget buildPreviewSection({
  required List<dynamic> selectedBoxes,
  required bool isGeneratingPreview,
  required dynamic selectedPaperType,
  required dynamic selectedEtiquetaModel,
  required dynamic previewPdf,
  required BuildContext context,
}) {
  return Container(
    height: 200,
    width: double.infinity,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey),
      borderRadius: BorderRadius.circular(8),
    ),
    child: selectedBoxes.isEmpty
        ? const Center(
            child: Text('Selecione pelo menos uma caixa para visualizar'),
          )
        : selectedPaperType == null
            ? const Center(
                child: Text('Selecione um modelo de etiqueta'),
              )
            : Center(
                child: isGeneratingPreview
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 10),
                          Text('Gerando visualização para ${selectedEtiquetaModel?.nome ?? ""}')
                        ],
                      )
                    : Container(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${selectedBoxes.length} etiquetas selecionadas',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    if (previewPdf == null) return;
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Abrindo visualização...')),
                                    );
                                    
                                    // Aqui vai o código original para abrir a visualização
                                  },
                                  icon: const Icon(Icons.preview),
                                  label: const Text('Visualizar'),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    if (previewPdf == null) return;
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Imprimindo...')),
                                    );
                                    
                                    // Aqui vai o código original para imprimir
                                  },
                                  icon: const Icon(Icons.print),
                                  label: const Text('Imprimir'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
  );
}
