class Item {
  final int? id;
  final String name;
  final String? category;
  final String? description;
  final String? image;
  final int boxId;
  final String createdAt;
  final String? updatedAt;

  Item({
    this.id,
    required this.name,
    this.category,
    this.description,
    this.image,
    required this.boxId,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'image': image,
      'boxId': boxId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      description: map['description'],
      image: map['image'],
      boxId: map['boxId'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  Item copyWith({
    int? id,
    String? name,
    String? category,
    String? description,
    String? image,
    int? boxId,
    String? createdAt,
    String? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      image: image ?? this.image,
      boxId: boxId ?? this.boxId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
