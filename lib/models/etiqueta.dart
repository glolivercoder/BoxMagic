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

/// Modelos Pimaco pré-definidos
final List<Etiqueta> modelosPimaco = [
  Etiqueta(
    nome: 'A4363',
    alturaCm: 3.81,
    larguraCm: 6.35,
    etiquetasPorFolha: 14,
    margemSuperiorCm: 1.27,
    margemInferiorCm: 1.27,
    margemEsquerdaCm: 0.635,
    margemDireitaCm: 0.635,
    espacoEntreEtiquetasCm: 0.0,
  ),
  Etiqueta(
    nome: 'A4204',
    alturaCm: 2.54,
    larguraCm: 6.35,
    etiquetasPorFolha: 21,
    margemSuperiorCm: 1.27,
    margemInferiorCm: 1.27,
    margemEsquerdaCm: 0.635,
    margemDireitaCm: 0.635,
    espacoEntreEtiquetasCm: 0.0,
  ),
  Etiqueta(
    nome: 'A4381',
    alturaCm: 4.0,
    larguraCm: 9.9,
    etiquetasPorFolha: 8,
    margemSuperiorCm: 1.0,
    margemInferiorCm: 1.0,
    margemEsquerdaCm: 0.8,
    margemDireitaCm: 0.8,
    espacoEntreEtiquetasCm: 0.0,
  ),
  Etiqueta(
    nome: '6080',
    alturaCm: 2.54,
    larguraCm: 6.6,
    etiquetasPorFolha: 21,
    margemSuperiorCm: 1.5,
    margemInferiorCm: 1.5,
    margemEsquerdaCm: 0.7,
    margemDireitaCm: 0.7,
    espacoEntreEtiquetasCm: 0.0,
  ),
  Etiqueta(
    nome: '6081',
    alturaCm: 3.81,
    larguraCm: 6.6,
    etiquetasPorFolha: 14,
    margemSuperiorCm: 1.27,
    margemInferiorCm: 1.27,
    margemEsquerdaCm: 0.7,
    margemDireitaCm: 0.7,
    espacoEntreEtiquetasCm: 0.0,
  ),
  Etiqueta(
    nome: '6082',
    alturaCm: 5.08,
    larguraCm: 10.15,
    etiquetasPorFolha: 10,
    margemSuperiorCm: 1.0,
    margemInferiorCm: 1.0,
    margemEsquerdaCm: 0.7,
    margemDireitaCm: 0.7,
    espacoEntreEtiquetasCm: 0.0,
  ),
  Etiqueta(
    nome: '6180',
    alturaCm: 2.54,
    larguraCm: 6.6,
    etiquetasPorFolha: 21,
    margemSuperiorCm: 1.5,
    margemInferiorCm: 1.5,
    margemEsquerdaCm: 0.7,
    margemDireitaCm: 0.7,
    espacoEntreEtiquetasCm: 0.0,
  ),
  Etiqueta(
    nome: '6185',
    alturaCm: 4.0,
    larguraCm: 9.9,
    etiquetasPorFolha: 8,
    margemSuperiorCm: 1.0,
    margemInferiorCm: 1.0,
    margemEsquerdaCm: 0.8,
    margemDireitaCm: 0.8,
    espacoEntreEtiquetasCm: 0.0,
  ),
  // Modelo personalizado é criado dinamicamente na interface
];
