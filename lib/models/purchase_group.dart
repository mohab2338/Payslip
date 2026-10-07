class PurchaseGroup {
  final String id;
  final String name;

  const PurchaseGroup({required this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory PurchaseGroup.fromMap(Map<String, dynamic> map) => PurchaseGroup(
        id: map['id'] as String,
        name: map['name'] as String,
      );
}
