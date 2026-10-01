class ExpenseItem {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String note;

  ExpenseItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String? ?? '',
    );
  }

  ExpenseItem copyWith({String? title, double? amount, String? note}) {
    return ExpenseItem(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date,
      note: note ?? this.note,
    );
  }
}
