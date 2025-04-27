import 'package:boxmagic/models/item.dart';

class Box {
  final int? id;
  final String name;
  final String category;
  final String? description;
  final String? image;
  final List<Item> items;
  final String createdAt;
  final String? updatedAt;
  final String? barcodeDataUrl;

  Box({
    this.id,
    required this.name,
    required this.category,
    this.description,
    this.image,
    this.items = const [],
    required this.createdAt,
    this.updatedAt,
    this.barcodeDataUrl,
  });

  // Retorna o ID formatado como uma string de exatamente 4 dígitos
  String get formattedId {
    if (id == null) return '0000';

    // Converter para string
    String idStr = id.toString();

    // Se for maior que 4 dígitos, pegar apenas os últimos 4
    if (idStr.length > 4) {
      return idStr.substring(idStr.length - 4);
    }

    // Se for menor que 4 dígitos, preencher com zeros à esquerda
    return idStr.padLeft(4, '0');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'image': image,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'barcodeDataUrl': barcodeDataUrl,
    };
  }

  factory Box.fromMap(Map<String, dynamic> map) {
    return Box(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      description: map['description'],
      image: map['image'],
      items: [], // Items are loaded separately
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
      barcodeDataUrl: map['barcodeDataUrl'],
    );
  }

  Box copyWith({
    int? id,
    String? name,
    String? category,
    String? description,
    String? image,
    List<Item>? items,
    String? createdAt,
    String? updatedAt,
    String? barcodeDataUrl,
  }) {
    return Box(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      image: image ?? this.image,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      barcodeDataUrl: barcodeDataUrl ?? this.barcodeDataUrl,
    );
  }
}
