import 'package:url_launcher/url_launcher.dart';

String _googleCalendarDateTime(DateTime dateTime) {
  final utc = dateTime.toUtc();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}'
      '${twoDigits(utc.month)}'
      '${twoDigits(utc.day)}T'
      '${twoDigits(utc.hour)}'
      '${twoDigits(utc.minute)}'
      '${twoDigits(utc.second)}Z';
}

Uri buildGoogleCalendarInviteUri({
  required String title,
  required String description,
  required DateTime startTime,
  required DateTime endTime,
  required String guestEmail,
}) {
  if (!endTime.isAfter(startTime)) {
    throw ArgumentError.value(endTime, 'endTime', 'Must be after startTime');
  }
  final dates =
      '${_googleCalendarDateTime(startTime)}/${_googleCalendarDateTime(endTime)}';
  return Uri.https(
    'calendar.google.com',
    '/calendar/render',
    {
      'action': 'TEMPLATE',
      'text': title,
      'details': description,
      'dates': dates,
      'add': guestEmail.trim(),
    },
  );
}

Future<void> launchGoogleCalendarInvite({
  required String title,
  required String description,
  required DateTime startTime,
  required DateTime endTime,
  required String guestEmail,
}) async {
  final uri = buildGoogleCalendarInviteUri(
    title: title,
    description: description,
    startTime: startTime,
    endTime: endTime,
    guestEmail: guestEmail,
  );
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched) {
    throw StateError('Could not open Google Calendar.');
  }
}
