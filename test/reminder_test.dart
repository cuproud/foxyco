import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/car_reminder.dart';
import 'package:foxyco/ui/settings/reminder_controller.dart';
import 'package:foxyco/ui/settings/reminder_section.dart';
import 'package:foxyco/ui/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  CarReminder r({
    String id = '1',
    String title = 'Safety inspection',
    DateTime? date,
    int leadDays = 30,
    String note = '',
  }) => CarReminder(
    id: id,
    title: title,
    date: date ?? DateTime.now().add(const Duration(days: 60)),
    leadDays: leadDays,
    note: note,
  );

  group('CarReminder', () {
    test('daysLeft is date-granular and isDue honors leadDays', () {
      final now = DateTime(2026, 7, 20, 23, 59);
      final rem = r(date: DateTime(2026, 8, 10, 0, 1), leadDays: 14);
      expect(rem.daysLeft(now), 21);
      expect(rem.isDue(now), isFalse);
      expect(rem.isDue(DateTime(2026, 7, 28)), isTrue); // 13 days out
      expect(rem.isDue(DateTime(2026, 8, 15)), isTrue); // overdue
    });

    test('JSON round-trips; malformed blob falls back to defaults', () {
      final rem = r(note: 'ask for Mike');
      final back = CarReminder.fromJson(rem.toJson());
      expect(back.id, rem.id);
      expect(back.title, rem.title);
      expect(back.leadDays, rem.leadDays);
      expect(back.note, 'ask for Mike');

      final junk = CarReminder.fromJson(const {});
      expect(junk.title, 'Reminder');
      expect(junk.leadDays, 30);
    });
  });

  group('ReminderController', () {
    test('add/update/remove persist and keep soonest-first order', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ctl = c.read(reminderProvider.notifier);

      final far = r(
        id: 'far',
        date: DateTime.now().add(const Duration(days: 90)),
      );
      final near = r(
        id: 'near',
        date: DateTime.now().add(const Duration(days: 5)),
      );
      ctl.add(far);
      ctl.add(near);
      expect(c.read(reminderProvider).first.id, 'near');

      ctl.update(far.copyWith(title: 'Oil change'));
      expect(c.read(reminderProvider).last.title, 'Oil change');

      ctl.remove('near');
      expect(c.read(reminderProvider).length, 1);

      // Persisted: a fresh container reloads the same list.
      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      c2.read(reminderProvider);
      await Future<void>.delayed(Duration.zero);
      expect(c2.read(reminderProvider).single.id, 'far');
    });

    test('dueRemindersProvider filters to the lead window', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ctl = c.read(reminderProvider.notifier);
      ctl.add(
        r(
          id: 'soon',
          date: DateTime.now().add(const Duration(days: 3)),
          leadDays: 7,
        ),
      );
      ctl.add(
        r(id: 'far', date: DateTime.now().add(const Duration(days: 300))),
      );
      expect(c.read(dueRemindersProvider).single.id, 'soon');
    });
  });

  testWidgets('section: empty hint, editor sheet saves a preset reminder', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(child: ReminderSection()),
          ),
        ),
      ),
    );

    expect(find.textContaining('Inspection due?'), findsOneWidget);

    await tester.tap(find.text('Add reminder'));
    await tester.pumpAndSettle();

    // Preset chip fills the title; date via the picker.
    await tester.tap(find.text('Safety inspection'));
    await tester.pump();
    await tester.tap(find.text('Pick a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // accept initialDate (today)
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save reminder'));
    await tester.pumpAndSettle();

    final saved = container.read(reminderProvider).single;
    expect(saved.title, 'Safety inspection');
    expect(saved.leadDays, 30);
    expect(find.textContaining('Inspection due?'), findsNothing);
    expect(find.text('Safety inspection'), findsOneWidget);
  });

  testWidgets('shows 3 soonest, expands to all', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ctl = container.read(reminderProvider.notifier);
    for (var i = 1; i <= 5; i++) {
      ctl.add(
        r(
          id: 'R$i',
          title: 'R$i',
          date: DateTime.now().add(Duration(days: i)),
        ),
      );
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(child: ReminderSection()),
          ),
        ),
      ),
    );

    expect(find.text('R1'), findsOneWidget);
    expect(find.text('R3'), findsOneWidget);
    expect(find.text('R4'), findsNothing);
    await tester.tap(find.text('Show all (5)'));
    await tester.pumpAndSettle();
    expect(find.text('R5'), findsOneWidget);
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(find.text('R4'), findsNothing);
  });
}
