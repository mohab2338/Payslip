class ExternalSaving {
  final String id;
  final String title;
  final double amount;
  final DateTime date;

  ExternalSaving({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  factory ExternalSaving.fromMap(Map<String, dynamic> map) {
    return ExternalSaving(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
    );
  }
}
