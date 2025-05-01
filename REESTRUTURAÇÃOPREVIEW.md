# Reestruturação do Código de Preview de Impressão

Este documento contém um plano detalhado para a reestruturação do código que está gerando bugs na visualização e impressão das etiquetas Pimaco no BoxMagicFlutter. Os problemas identificados estão causando loops infinitos no preview e erros de sintaxe relacionados a parênteses não fechados e indentação incorreta.

## Índice

1. [Análise dos Problemas](#análise-dos-problemas)
2. [Plano de Reestruturação](#plano-de-reestruturação)
3. [Bloco 1: Correção da Função de Geração de Preview](#bloco-1-correção-da-função-de-geração-de-preview)
4. [Bloco 2: Reestruturação da UI de Seleção de Modelos](#bloco-2-reestruturação-da-ui-de-seleção-de-modelos)
5. [Bloco 3: Correção da Área de Visualização Prévia](#bloco-3-correção-da-área-de-visualização-prévia)
6. [Bloco 4: Melhorias no Cálculo do QR Code](#bloco-4-melhorias-no-cálculo-do-qr-code)
7. [Procedimento de Aplicação](#procedimento-de-aplicação)
8. [Testes](#testes)

## Análise dos Problemas

Os principais problemas identificados são:

1. Loop infinito na geração do preview: O código atual está causando loops infinitos ao gerar o preview das etiquetas.
2. Problemas de sintaxe: Há vários erros de parênteses não fechados e indentação incorreta que impedem a compilação.
3. Seleção múltipla de modelos: A UI permite seleção múltipla quando deveria ser apenas um modelo.
4. Problemas com o posicionamento do QR code: O QR code não está sendo adequadamente posicionado dentro dos limites das etiquetas.

## Plano de Reestruturação

1. Corrigir a função de geração de preview para evitar loops infinitos
2. Reestruturar a UI de seleção de modelos para garantir seleção única
3. Corrigir a área de visualização prévia com uma estrutura de widgets clara
4. Melhorar o cálculo de tamanho e posicionamento do QR code

---

## Bloco 1: Correção da Função de Geração de Preview

### Problema
A função de geração de preview atual está causando loops infinitos, pois não há um controle adequado para evitar múltiplas chamadas recursivas.

### Solução
Implementar um mecanismo de controle para evitar múltiplas chamadas e garantir que somente uma geração de preview esteja em andamento por vez.

```dart
// Variáveis de controle
bool _isPreviewGenerationInProgress = false;
String? _lastRequestedModelName;

// Função revisada para geração de preview
Future<void> generatePreview(List<Box> boxes, LabelFormat format, LabelPaperType? paperType) async {
  // Verificar se já está gerando um preview para evitar loops
  if (_isPreviewGenerationInProgress) {
    _logService.debug('Geração de preview já em andamento, ignorando nova solicitação', category: 'preview');
    return;
  }
  
  // Se o tipo de papel for nulo, não podemos gerar a visualização
  if (paperType == null) {
    setState(() {
      previewPdf = null;
      isGeneratingPreview = false;
    });
    return;
  }
  
  // Verificar se há caixas selecionadas
  if (boxes.isEmpty) {
    setState(() {
      previewPdf = null;
      isGeneratingPreview = false;
    });
    return;
  }
  
  // Registrar o modelo atual para evitar conflitos
  final currentModelName = selectedEtiquetaModel?.nome;
  _lastRequestedModelName = currentModelName;
  
  // Marcar que está iniciando a geração
  _isPreviewGenerationInProgress = true;
  
  setState(() {
    isGeneratingPreview = true;
  });

  try {
    // Pequeno atraso para garantir que a UI seja atualizada antes de iniciar operações pesadas
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Verificar se o modelo mudou durante o atraso
    if (_lastRequestedModelName != currentModelName) {
      _logService.debug('Modelo mudou durante o atraso, cancelando geração', category: 'preview');
      _isPreviewGenerationInProgress = false;
      if (mounted) {
        setState(() {
          isGeneratingPreview = false;
        });
      }
      return;
    }
    
    final Map<int, List<Item>> boxItems = {};
    for (final box in boxes) {
      if (box.id != null) {
        boxItems[box.id!] = await _databaseHelper.readItemsByBoxId(box.id!);
      }
    }

    final pdfBytes = await _labelPrintingService.generateLabelsPdf(
      boxes: boxes,
      boxItems: boxItems,
      format: format,
      paperType: paperType,
      isPreview: true, // Ativar modo de visualização
    );

    // Verificar novamente se o modelo mudou durante a geração
    if (_lastRequestedModelName != selectedEtiquetaModel?.nome) {
      _logService.debug('Modelo mudou durante a geração, descartando resultado', category: 'preview');
      _isPreviewGenerationInProgress = false;
      if (mounted) {
        setState(() {
          isGeneratingPreview = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        previewPdf = pdfBytes;
        isGeneratingPreview = false;
      });
    }
  } catch (e) {
    _logService.error('Erro ao gerar visualização prévia', error: e);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar visualização: ${e.toString()}'))
      );
      setState(() {
        previewPdf = null;
        isGeneratingPreview = false;
      });
    }
  } finally {
    // Garantir que o flag seja resetado mesmo em caso de erro
    _isPreviewGenerationInProgress = false;
  }
}
```

---

## Bloco 2: Reestruturação da UI de Seleção de Modelos

### Problema
A UI atual de seleção de modelos está instável e permite seleção múltipla quando deveria permitir apenas uma seleção.

### Solução
Redesenhar a UI de seleção de modelos para uma implementação mais robusta que garanta seleção única e feedback visual claro.

```dart
// Lista de modelos com seleção única e visual melhorado
Container(
  decoration: BoxDecoration(
    color: Colors.grey.shade50,
    borderRadius: BorderRadius.circular(4),
  ),
  child: ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: modelosPimaco.length,
    separatorBuilder: (context, index) => const Divider(height: 1),
    itemBuilder: (context, index) {
      final modelo = modelosPimaco[index];
      // Determinar o tipo de papel para este modelo
      String paperType = '';
      LabelPaperType modelPaperType = _mapModeloToPaperType(modelo);
      switch (modelPaperType) {
        case LabelPaperType.pimaco6180:
          paperType = 'A4 (3 colunas)';
          break;
        case LabelPaperType.pimaco6082:
          paperType = 'A4 (2 colunas)';
          break;
        case LabelPaperType.a4Full:
          paperType = 'A4 (página inteira)';
          break;
      }
      
      // Verificar se este modelo está selecionado
      bool isSelected = selectedEtiquetaModel?.nome == modelo.nome;
      
      return Material(
        color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
        child: InkWell(
          onTap: () {
            // Evitar seleção do mesmo modelo ou durante geração
            if (isGeneratingPreview || selectedEtiquetaModel?.nome == modelo.nome) {
              return;
            }
            
            // Salvar último modelo usado
            _preferencesService.saveLastUsedLabelModel(modelo.nome);
            
            // Log para debug
            _logService.debug('Modelo alterado para: ${modelo.nome}, Tipo: $modelPaperType', category: 'preview');
            
            // Atualizar estado e iniciar geração de preview
            setState(() {
              selectedEtiquetaModel = modelo; // Armazenar o modelo completo
              selectedPaperType = modelPaperType; // Armazenar o tipo de papel
              previewPdf = null;
              isGeneratingPreview = true; // Indicar que está gerando preview
            });
            
            // Iniciar geração de preview diretamente sem atraso
            if (selectedBoxes.isNotEmpty) {
              generatePreview(selectedBoxes, selectedFormat, modelPaperType);
            } else {
              setState(() {
                isGeneratingPreview = false;
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Radio<String>(
                  value: modelo.nome,
                  groupValue: selectedEtiquetaModel?.nome,
                  onChanged: (_) {}, // Controlado pelo InkWell
                  activeColor: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${modelo.nome} - $paperType',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${modelo.larguraCm.toStringAsFixed(1)}x${modelo.alturaCm.toStringAsFixed(1)}cm (${modelo.etiquetasPorFolha} por folha)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).primaryColor,
                  ),
              ],
            ),
          ),
        ),
      );
    },
  ),
),
```

---

## Bloco 3: Correção da Área de Visualização Prévia

### Problema
A área de visualização prévia tem problemas de estrutura e parênteses não fechados, causando erros de compilação.

### Solução
Redesenhar a área de visualização prévia com uma estrutura clara e bem indentada.

```dart
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
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  if (previewPdf == null) return;
                                  
                                  // Código para exportar SVG (simplificado para manter o documento conciso)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Exportando SVG...')),
                                  );
                                  
                                  // Implementar função para exportar SVG
                                },
                                icon: const Icon(Icons.save_alt),
                                label: const Text('Exportar SVG'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[700],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
),
```

---

## Bloco 4: Melhorias no Cálculo do QR Code

### Problema
O QR code não está sendo corretamente posicionado e dimensionado dentro dos limites das etiquetas.

### Solução
Melhorar o cálculo de tamanho e posicionamento do QR code para garantir que fique sempre dentro dos limites da etiqueta.

```dart
// Calcular tamanho do QR code proporcional ao tamanho da etiqueta
double _calculateQrCodeSize(double labelHeight, double labelWidth) {
  // Usar o menor valor entre altura e largura para garantir que o QR code caiba
  // Reduzir para 45% da menor dimensão para garantir que fique dentro das margens
  double minDimension = labelHeight < labelWidth ? labelHeight : labelWidth;
  
  // Considerar o espaço disponível com margens
  double availableSpace = minDimension * 0.85; // Reservar 15% para margens
  
  // Limitar o tamanho máximo para garantir que caiba na etiqueta
  double maxSize = availableSpace * 0.45; // Usar no máximo 45% do espaço disponível
  
  // Garantir um tamanho mínimo para legibilidade e máximo para não ultrapassar margens
  return maxSize < 20 ? 20 : (maxSize > 70 ? 70 : maxSize);
}

// Exemplo de implementação do container do QR code
pw.Container(
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
```

## Procedimento de Aplicação

Para aplicar essas melhorias, siga os seguintes passos:

1. **Backup**: Faça um backup do arquivo original antes de qualquer alteração
   ```
   cp lib/screens/boxes_screen.dart lib/screens/boxes_screen_backup.dart
   ```

2. **Limpeza**: Execute uma limpeza no projeto para garantir que não haja resíduos
   ```
   flutter clean
   flutter pub get
   ```

3. **Aplicação das correções**:
   - Substitua a função `generatePreview` pelo código do Bloco 1
   - Substitua a UI de seleção de modelos pelo código do Bloco 2
   - Substitua a área de visualização prévia pelo código do Bloco 3
   - Atualize o cálculo do QR code no arquivo `label_printing_service.dart` conforme Bloco 4

4. **Verificação**: Certifique-se de que todas as chaves e parênteses estejam balanceados

5. **Teste**: Execute o aplicativo e teste o fluxo de impressão de etiquetas

## Testes

Após aplicar as correções, teste as seguintes funcionalidades:

1. **Seleção de modelos**: Verifique se apenas um modelo pode ser selecionado por vez
2. **Preview de impressão**: Verifique se o preview é gerado corretamente sem loops infinitos
3. **QR code**: Verifique se o QR code está corretamente posicionado dentro das etiquetas
4. **Impressão**: Verifique se a impressão funciona corretamente

Se encontrar problemas durante os testes, verifique:

1. Se há erros no console
2. Se há problemas de sincronização de estado
3. Se há problemas de parênteses não fechados ou indentação incorreta

## Conclusão

As correções propostas neste documento devem resolver os problemas de estabilidade na seleção de modelos de etiquetas Pimaco, garantir a impressão correta de QR codes e textos nas etiquetas, e eliminar bugs de interface para um fluxo de impressão confiável e visualmente adequado.

Seguindo o procedimento de aplicação passo a passo, você deve conseguir resolver todos os problemas identificados e obter um sistema de impressão de etiquetas estável e funcional.
