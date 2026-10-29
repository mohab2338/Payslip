class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startAt;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'startAt': startAt.toIso8601String(),
      };

  factory CalendarEvent.fromMap(Map<String, dynamic> map) => CalendarEvent(
        id: map['id'] as String,
        title: map['title'] as String,
        description: map['description'] as String? ?? '',
        startAt: DateTime.parse(map['startAt'] as String),
      );
}
