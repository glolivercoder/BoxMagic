class Etiqueta {
  final String nome;
  final double alturaCm;
  final double larguraCm;
  final int etiquetasPorFolha;
  final double margemSuperiorCm;
  final double margemInferiorCm;
  final double margemEsquerdaCm;
  final double margemDireitaCm;
  final double espacoEntreEtiquetasCm;
  final bool personalizada;

  Etiqueta({
    required this.nome,
    required this.alturaCm,
    required this.larguraCm,
    required this.etiquetasPorFolha,
    this.margemSuperiorCm = 0.5,
    this.margemInferiorCm = 0.5,
    this.margemEsquerdaCm = 0.5,
    this.margemDireitaCm = 0.5,
    this.espacoEntreEtiquetasCm = 0.2,
    this.personalizada = false,
  });

  // Cria uma cópia da etiqueta com valores atualizados
  Etiqueta copyWith({
    String? nome,
    double? alturaCm,
    double? larguraCm,
    int? etiquetasPorFolha,
    double? margemSuperiorCm,
    double? margemInferiorCm,
    double? margemEsquerdaCm,
    double? margemDireitaCm,
    double? espacoEntreEtiquetasCm,
    bool? personalizada,
  }) {
    return Etiqueta(
      nome: nome ?? this.nome,
      alturaCm: alturaCm ?? this.alturaCm,
      larguraCm: larguraCm ?? this.larguraCm,
      etiquetasPorFolha: etiquetasPorFolha ?? this.etiquetasPorFolha,
      margemSuperiorCm: margemSuperiorCm ?? this.margemSuperiorCm,
      margemInferiorCm: margemInferiorCm ?? this.margemInferiorCm,
      margemEsquerdaCm: margemEsquerdaCm ?? this.margemEsquerdaCm,
      margemDireitaCm: margemDireitaCm ?? this.margemDireitaCm,
      espacoEntreEtiquetasCm: espacoEntreEtiquetasCm ?? this.espacoEntreEtiquetasCm,
      personalizada: personalizada ?? this.personalizada,
    );
  }
}

/// Tipos de conteúdo das etiquetas
enum TipoEtiqueta {
  idApenas,
  idENome,
  idNomeEConteudo,
}
