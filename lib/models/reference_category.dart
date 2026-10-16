class ReferenceCategory {
  final String id;
  final String name;
  final DateTime createdAt;

  const ReferenceCategory({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReferenceCategory.fromMap(Map<String, dynamic> map) =>
      ReferenceCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
