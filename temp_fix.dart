  Future<void> _showBarcodeScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Escanear código de barras'),
          ),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  final String code = barcode.rawValue!;
                  // Tenta converter o código para int (ID da caixa)
                  try {
                    final boxId = int.parse(code);
                    Navigator.pop(context, boxId);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Código inválido: $code')),
                    );
                  }
                }
              }
            },
          ),
        ),
      ),
    );

    if (result != null) {
      await _loadBoxes();
      // Se o resultado for um ID de caixa, tente abrir automaticamente
      try {
        final int boxId = int.parse(result.toString());
        final box = _boxes.firstWhere((b) => b.id == boxId, orElse: () => throw Exception('Caixa não encontrada'));
        if (mounted) {
          // Usar pushAndRemoveUntil para substituir a tela atual pela tela de detalhes da caixa
          // Isso evita que a tela de detalhes seja fechada ao pressionar o botão voltar
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => BoxDetailScreen(box: box),
            ),
            // Manter apenas a tela principal na pilha de navegação
            (route) => route.isFirst,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao abrir caixa automaticamente: $e')),
          );
        }
      }
    }
  }
