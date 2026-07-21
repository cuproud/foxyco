import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/car_reminder.dart';
import '../theme/tokens.dart';
import 'reminder_controller.dart';

/// "Car reminders" Settings section: soonest-first list of dated car chores
/// (inspection, insurance, oil change…) with a days-left countdown, plus an
/// add button. Tap a row to edit, trash to delete. All in-app — no
/// notification permission; due items surface as a Home banner.
class ReminderSection extends ConsumerWidget {
  const ReminderSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(reminderProvider);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reminders.isEmpty)
            Text(
              'Inspection due? Insurance renewal? Add a date and FoxyCo '
              'reminds you on the Home screen ahead of time.',
              style: text.bodyMedium?.copyWith(
                fontSize: 12.5,
                height: 1.45,
                color: FoxColors.textSecondary,
              ),
            )
          else
            for (final r in reminders) ...[
              _ReminderRow(reminder: r),
              if (r != reminders.last)
                const Divider(color: FoxColors.border, height: Gap.md),
            ],
          const SizedBox(height: Gap.sm + Gap.xs),
          OutlinedButton.icon(
            onPressed: () => showReminderEditor(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: FoxColors.brandFox,
              side: BorderSide(
                color: FoxColors.brandFox.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.field),
              ),
              textStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add reminder'),
          ),
        ],
    );
  }
}

class _ReminderRow extends ConsumerWidget {
  const _ReminderRow({required this.reminder});
  final CarReminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = reminder;
    final days = r.daysLeft();
    final due = r.isDue();
    final overdue = days < 0;
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatMediumDate(r.date);
    final countLabel = overdue
        ? '${-days}d overdue'
        : days == 0
        ? 'today'
        : 'in ${days}d';
    final icon = ReminderPresets.titles
        .where((t) => t.$2 == r.title)
        .firstOrNull
        ?.$1;

    return InkWell(
      borderRadius: BorderRadius.circular(Radii.field),
      onTap: () => showReminderEditor(context, ref, existing: r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              icon ?? Icons.event_outlined,
              size: 20,
              color: due ? VerdictColors.ok : FoxColors.textSecondary,
            ),
            const SizedBox(width: Gap.sm + Gap.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.note.isEmpty ? dateLabel : '$dateLabel · ${r.note}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: FoxColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: overdue
                    ? VerdictColors.badBg
                    : due
                    ? VerdictColors.okBg
                    : FoxColors.bgSurface2,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Text(
                countLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: overdue
                      ? VerdictColors.bad
                      : due
                      ? VerdictColors.ok
                      : FoxColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add/edit sheet. Preset title chips + free-text title, a date picker, a
/// lead-time choice, and an optional note. Editing shows Delete.
void showReminderEditor(
  BuildContext context,
  WidgetRef ref, {
  CarReminder? existing,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // keyboard pushes the sheet up
    backgroundColor: Colors.transparent,
    builder: (_) => _ReminderEditor(existing: existing),
  );
}

class _ReminderEditor extends ConsumerStatefulWidget {
  const _ReminderEditor({this.existing});
  final CarReminder? existing;

  @override
  ConsumerState<_ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends ConsumerState<_ReminderEditor> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late DateTime? _date = widget.existing?.date;
  late int _leadDays = widget.existing?.leadDays ?? 30;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      // Past dates allowed: "inspection taken last week, remind me next year"
      // is entered as the RENEWAL date, but overdue entries must stay editable.
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  bool get _valid => _title.text.trim().isNotEmpty && _date != null;

  void _save() {
    final r = CarReminder(
      id:
          widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      date: _date!,
      leadDays: _leadDays,
      note: _note.text.trim(),
    );
    final c = ref.read(reminderProvider.notifier);
    widget.existing == null ? c.add(r) : c.update(r);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dateLabel = _date == null
        ? 'Pick a date'
        : MaterialLocalizations.of(context).formatMediumDate(_date!);

    return Padding(
      // Ride above the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(Gap.sm),
        padding: EdgeInsets.fromLTRB(
          Gap.lg,
          Gap.md,
          Gap.lg,
          Gap.lg + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: FoxColors.bgSurface,
          borderRadius: BorderRadius.circular(Radii.hero),
          border: Border.all(color: FoxColors.border),
          boxShadow: Shadows.hero,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FoxColors.border,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
              ),
              const SizedBox(height: Gap.md),
              Text(
                widget.existing == null ? 'New reminder' : 'Edit reminder',
                style: text.titleLarge,
              ),
              const SizedBox(height: Gap.md),
              // Preset chips fill the title field.
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final (icon, label) in ReminderPresets.titles)
                    _PresetChip(
                      icon: icon,
                      label: label,
                      selected: _title.text == label,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _title.text = label);
                      },
                    ),
                ],
              ),
              const SizedBox(height: Gap.md),
              TextField(
                controller: _title,
                onChanged: (_) => setState(() {}),
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  isDense: true,
                  counterText: '',
                ),
              ),
              const SizedBox(height: Gap.md),
              // Date + lead-time on one visual row.
              OutlinedButton.icon(
                onPressed: _pickDate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _date == null
                      ? FoxColors.textSecondary
                      : FoxColors.cream,
                  side: const BorderSide(color: FoxColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.field),
                  ),
                ),
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: Gap.md),
              Text('REMIND ME BEFORE', style: text.labelSmall),
              const SizedBox(height: Gap.sm),
              Row(
                children: [
                  for (final (days, label) in ReminderPresets.leads) ...[
                    Expanded(
                      child: _PresetChip(
                        label: label,
                        selected: _leadDays == days,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _leadDays = days);
                        },
                      ),
                    ),
                    if (days != ReminderPresets.leads.last.$1)
                      const SizedBox(width: Gap.sm),
                  ],
                ],
              ),
              const SizedBox(height: Gap.md),
              TextField(
                controller: _note,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Canadian Tire, ask for Mike',
                  isDense: true,
                  counterText: '',
                ),
              ),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  if (widget.existing != null) ...[
                    OutlinedButton(
                      onPressed: () {
                        ref
                            .read(reminderProvider.notifier)
                            .remove(widget.existing!.id);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VerdictColors.bad,
                        side: BorderSide(
                          color: VerdictColors.bad.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.md,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.field),
                        ),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, size: 20),
                    ),
                    const SizedBox(width: Gap.sm),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _valid ? _save : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: FoxColors.brandFox,
                        disabledBackgroundColor: FoxColors.bgSurface2,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: FoxColors.textDisabled,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.field),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Save reminder'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.base,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? FoxColors.brandFoxSoft : FoxColors.bgSurface2,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
            color: selected
                ? FoxColors.brandFox.withValues(alpha: 0.6)
                : FoxColors.borderSoft,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? FoxColors.cream : FoxColors.textSecondary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? FoxColors.cream : FoxColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
