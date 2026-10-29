import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/calendar_event.dart';
import '../models/expense_item.dart';
import '../models/month_data.dart';
import '../services/app_state.dart';
import '../services/google_calendar_invite.dart';
import '../theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static final _currency = NumberFormat.currency(symbol: 'E£', decimalDigits: 2);
  static const _purchaseColor = Color(0xFF3155A6);
  static const _eventColor = Color(0xFFB7791F);

  DateTime _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _focusedDate = DateUtils.dateOnly(DateTime.now());
  final Set<DateTime> _selectedDates = {DateUtils.dateOnly(DateTime.now())};

  bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  double _spentOn(DateTime date, List<MonthData> months) => months
      .expand((month) => month.items)
      .where((item) => _isSameDay(item.date, date))
      .fold(0, (total, item) => total + item.amount);

  List<ExpenseItem> _purchasesOn(DateTime date, List<MonthData> months) {
    final purchases = months
        .expand((month) => month.items)
        .where((item) => _isSameDay(item.date, date))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return purchases;
  }

  List<CalendarEvent> _eventsOn(DateTime date, List<CalendarEvent> events) =>
      events.where((event) => _isSameDay(event.startAt, date)).toList();

  Future<void> _editEvent(
    BuildContext context, {
    CalendarEvent? event,
    required DateTime initialDate,
  }) async {
    final titleController = TextEditingController(text: event?.title ?? '');
    final descriptionController =
        TextEditingController(text: event?.description ?? '');
    var eventDate = event?.startAt ?? initialDate;
    var eventTime = TimeOfDay.fromDateTime(eventDate);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<CalendarEvent>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(event == null ? 'Schedule event' : 'Edit event'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter an event title'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(DateFormat.yMMMd().format(eventDate)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: dialogContext,
                                initialDate: eventDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  eventDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    eventTime.hour,
                                    eventTime.minute,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.schedule),
                          label: Text(eventTime.format(dialogContext)),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: dialogContext,
                              initialTime: eventTime,
                            );
                            if (picked != null) {
                              setDialogState(() {
                                eventTime = picked;
                                eventDate = DateTime(
                                  eventDate.year,
                                  eventDate.month,
                                  eventDate.day,
                                  eventTime.hour,
                                  eventTime.minute,
                                );
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(
                  dialogContext,
                  CalendarEvent(
                    id: event?.id ??
                        DateTime.now().microsecondsSinceEpoch.toString(),
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    startAt: eventDate,
                  ),
                );
              },
              child: const Text('Save event'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    descriptionController.dispose();

    if (result != null && context.mounted) {
      try {
        await context.read<AppState>().saveCalendarEvent(result);
        if (mounted) {
          setState(() {
            _focusedDate = DateUtils.dateOnly(result.startAt);
            _displayedMonth =
                DateTime(result.startAt.year, result.startAt.month);
            _selectedDates
              ..clear()
              ..add(_focusedDate);
          });
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save event: $error')),
          );
        }
      }
    }
  }

  Future<void> _removeEvent(CalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${event.title}?'),
        content: const Text('This scheduled event will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AppState>().removeCalendarEvent(event.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete event: $error')),
        );
      }
    }
  }

  Future<void> _inviteGuest(CalendarEvent event) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final guestEmail = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invite a guest'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Guest email',
              hintText: 'name@example.com',
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                  ? null
                  : 'Enter a valid email address';
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Continue to Google Calendar'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (guestEmail == null || !mounted) return;
    try {
      await launchGoogleCalendarInvite(
        title: event.title,
        description: event.description,
        startTime: event.startAt,
        endTime: event.startAt.add(const Duration(hours: 1)),
        guestEmail: guestEmail,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Google Calendar: $error')),
        );
      }
    }
  }

  void _moveMonth(int offset) {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month + offset);
      _focusedDate = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
      _selectedDates
        ..clear()
        ..add(_focusedDate);
    });
  }

  void _toggleDate(DateTime date) {
    final day = DateUtils.dateOnly(date);
    setState(() {
      _focusedDate = day;
      if (!_selectedDates.add(day)) {
        _selectedDates.remove(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _moveMonth(-1),
          ),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _moveMonth(1),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editEvent(context, initialDate: _focusedDate),
        icon: const Icon(Icons.event),
        label: const Text('Schedule event'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<MonthData>>(
          stream: state.watchHistory(),
          builder: (context, monthSnapshot) {
            if (monthSnapshot.hasError) {
              return const Center(child: Text('Could not load purchases.'));
            }
            if (!monthSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<List<CalendarEvent>>(
              stream: state.watchCalendarEvents(),
              builder: (context, eventSnapshot) {
                if (eventSnapshot.hasError) {
                  final error = eventSnapshot.error;
                  final permissionDenied = error is FirebaseException &&
                      error.code == 'permission-denied';
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event_busy_outlined, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            permissionDenied
                                ? 'Firestore denied access to calendar events.'
                                : 'Could not load events: $error',
                            textAlign: TextAlign.center,
                          ),
                          if (permissionDenied) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'In Firebase Console → Firestore Database → Rules, '
                              'add a calendar_events rule inside '
                              'match /users/{userId}, then publish the rules.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                if (!eventSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final months = monthSnapshot.data!;
                final events = eventSnapshot.data!;
                final selectedTotal = _selectedDates.fold<double>(
                  0,
                  (total, date) => total + _spentOn(date, months),
                );
                final visiblePurchases = _purchasesOn(_focusedDate, months);
                final visibleEvents = _eventsOn(_focusedDate, events);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    _buildSelectionSummary(selectedTotal),
                    const SizedBox(height: 12),
                    _buildMonthGrid(months, events),
                    const SizedBox(height: 16),
                    _buildLegend(),
                    const SizedBox(height: 18),
                    _buildSelectedDay(
                      _focusedDate,
                      visiblePurchases,
                      visibleEvents,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSelectionSummary(double total) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.calculate_outlined, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedDates.isEmpty
                        ? 'Select days to total spending'
                        : '${_selectedDates.length} selected ${_selectedDates.length == 1 ? 'day' : 'days'}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _currency.format(total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedDates.isNotEmpty)
              IconButton(
                tooltip: 'Clear selected days',
                onPressed: () => setState(_selectedDates.clear),
                icon: const Icon(Icons.clear, color: Colors.white),
              ),
          ],
        ),
      );

  Widget _buildMonthGrid(
    List<MonthData> months,
    List<CalendarEvent> events,
  ) {
    final firstOfMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final daysInMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final leadingDays = firstOfMonth.weekday % 7;
    final weekCount = ((leadingDays + daysInMonth) / 7).ceil();
    final cells = <DateTime?>[
      ...List<DateTime?>.filled(leadingDays, null),
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(_displayedMonth.year, _displayedMonth.month, day),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat.yMMMM().format(_displayedMonth),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final today = DateUtils.dateOnly(DateTime.now());
                    setState(() {
                      _displayedMonth = DateTime(today.year, today.month);
                      _focusedDate = today;
                      _selectedDates
                        ..clear()
                        ..add(today);
                    });
                  },
                  child: const Text('Today'),
                ),
              ],
            ),
          ),
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((day) => Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            day,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: weekCount * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 56,
            ),
            itemBuilder: (context, index) {
              final date = index < cells.length ? cells[index] : null;
              if (date == null) return const SizedBox.shrink();
              final purchaseCount =
                  _purchasesOn(date, months).length;
              final eventCount = _eventsOn(date, events).length;
              final dateOnly = DateUtils.dateOnly(date);
              final selected = _selectedDates.contains(dateOnly);
              final focused = _isSameDay(_focusedDate, date);
              final today = _isSameDay(DateTime.now(), date);
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _toggleDate(date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    border: focused
                        ? Border.all(color: AppColors.primary, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 25,
                        height: 25,
                        alignment: Alignment.center,
                        decoration: today
                            ? const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            color: today ? Colors.white : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight:
                                today ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (purchaseCount > 0)
                            _marker(_purchaseColor, purchaseCount),
                          if (purchaseCount > 0 && eventCount > 0)
                            const SizedBox(width: 3),
                          if (eventCount > 0) _marker(_eventColor, eventCount),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _marker(Color color, int count) => Container(
        width: count > 1 ? 14 : 6,
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      );

  Widget _buildLegend() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem(_purchaseColor, 'Purchases'),
          const SizedBox(width: 18),
          _legendItem(_eventColor, 'Scheduled events'),
        ],
      );

  Widget _legendItem(Color color, String label) => Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );

  Widget _buildSelectedDay(
    DateTime date,
    List<ExpenseItem> purchases,
    List<CalendarEvent> events,
  ) {
    final entries = <Widget>[];
    for (final event in events) {
      entries.add(_eventTile(event));
    }
    for (final item in purchases) {
      entries.add(_purchaseTile(item));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat.yMMMMEEEEd().format(date),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Nothing scheduled or purchased on this day.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          ...entries,
      ],
    );
  }

  Widget _eventTile(CalendarEvent event) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _eventColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: _eventColor, width: 4),
          ),
        ),
        child: ListTile(
          onTap: () => _editEvent(
            context,
            event: event,
            initialDate: event.startAt,
          ),
          leading: const Icon(Icons.event, color: _eventColor),
          title: Text(event.title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${DateFormat.jm().format(event.startAt)}'
            '${event.description.isEmpty ? '' : '\n${event.description}'}',
          ),
          isThreeLine: event.description.isNotEmpty,
          trailing: PopupMenuButton<String>(
            tooltip: 'Event actions',
            onSelected: (action) {
              if (action == 'invite') _inviteGuest(event);
              if (action == 'delete') _removeEvent(event);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'invite',
                child: ListTile(
                  leading: Icon(Icons.person_add_alt_1_outlined),
                  title: Text('Invite guest'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete event'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _purchaseTile(ExpenseItem item) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: const Border(
            left: BorderSide(color: _purchaseColor, width: 4),
          ),
        ),
        child: ListTile(
          leading: const Icon(Icons.shopping_bag_outlined,
              color: _purchaseColor),
          title: Text(item.title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: item.note.isEmpty
              ? Text(DateFormat.jm().format(item.date))
              : Text(
                  '${DateFormat.jm().format(item.date)} · ${item.note}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: Text(
            _currency.format(item.amount),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
}
