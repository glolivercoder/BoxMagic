class User {
  final int? id;
  final String name;
  final String? email;
  final String? whatsapp;
  final String createdAt;
  final String? updatedAt;

  User({
    this.id,
    required this.name,
    this.email,
    this.whatsapp,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'whatsapp': whatsapp,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      whatsapp: map['whatsapp'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? whatsapp,
    String? createdAt,
    String? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      whatsapp: whatsapp ?? this.whatsapp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
