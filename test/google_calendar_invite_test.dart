import 'package:flutter_test/flutter_test.dart';
import 'package:salary_tracker/services/google_calendar_invite.dart';

void main() {
  test('builds a Google Calendar template URL with UTC dates and guest', () {
    final uri = buildGoogleCalendarInviteUri(
      title: 'Team meeting',
      description: 'Discuss the project',
      startTime: DateTime.utc(2026, 10, 29, 6, 30),
      endTime: DateTime.utc(2026, 10, 29, 7, 30),
      guestEmail: 'guest@example.com',
    );

    expect(uri.host, 'calendar.google.com');
    expect(uri.path, '/calendar/render');
    expect(uri.queryParameters, {
      'action': 'TEMPLATE',
      'text': 'Team meeting',
      'details': 'Discuss the project',
      'dates': '20261029T063000Z/20261029T073000Z',
      'add': 'guest@example.com',
    });
  });

  test('rejects an end time that is not after the start time', () {
    final start = DateTime.utc(2026, 10, 29, 6);
    expect(
      () => buildGoogleCalendarInviteUri(
        title: 'Meeting',
        description: '',
        startTime: start,
        endTime: start,
        guestEmail: 'guest@example.com',
      ),
      throwsArgumentError,
    );
  });
}
