class ExtraIncome {
  final String id;
  final double amount;
  final DateTime date;
  final String description;

  const ExtraIncome({
    required this.id,
    required this.amount,
    required this.date,
    this.description = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'description': description,
      };

  factory ExtraIncome.fromMap(Map<String, dynamic> map) => ExtraIncome(
        id: map['id'] as String,
        amount: (map['amount'] as num).toDouble(),
        date: DateTime.parse(map['date'] as String),
        description: map['description'] as String? ?? '',
      );
}
