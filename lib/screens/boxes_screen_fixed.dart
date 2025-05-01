// Este arquivo contém apenas a parte corrigida do diálogo de impressão
// Copie o conteúdo para substituir a parte correspondente no arquivo boxes_screen.dart

// Área de visualização prévia
Container(
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
                                  
                                  // Pequeno atraso para garantir que o contexto esteja estável
                                  Future.delayed(const Duration(milliseconds: 300), () async {
                                    try {
                                      if (mounted && previewPdf != null) {
                                        await Printing.layoutPdf(
                                          onLayout: (_) => previewPdf!,
                                          name: 'Etiquetas BoxMagic',
                                          format: PdfPageFormat.a4,
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Erro ao abrir visualização: ${e.toString()}')),
                                        );
                                      }
                                    }
                                  });
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
                                  
                                  try {
                                    await Printing.layoutPdf(
                                      onLayout: (_) => previewPdf!,
                                      name: 'Etiquetas BoxMagic',
                                      format: PdfPageFormat.a4,
                                      usePrinterSettings: true,
                                    );
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Erro ao imprimir: ${e.toString()}')),
                                      );
                                    }
                                  }
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
),
