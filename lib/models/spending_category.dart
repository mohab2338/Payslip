class SpendingCategory {
  final String id;
  final String name;
  final double budgetAmount;

  const SpendingCategory({
    required this.id,
    required this.name,
    required this.budgetAmount,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'budgetAmount': budgetAmount,
      };

  factory SpendingCategory.fromMap(Map<String, dynamic> map) => SpendingCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        budgetAmount: (map['budgetAmount'] as num).toDouble(),
      );
}
