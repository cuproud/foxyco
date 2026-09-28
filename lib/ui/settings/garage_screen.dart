import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/car_reminder.dart';
import '../../domain/offer_summary.dart';
import '../../domain/vehicle_expense.dart';
import '../../services/offer_log.dart';
import 'garage_controller.dart';
import 'garage_section.dart';
import 'income_expense_report.dart';
import 'reminder_controller.dart';
import 'reminder_section.dart';
import 'settings_controller.dart';
import 'vehicle_expense_controller.dart';
import '../theme/section_label.dart';
import '../theme/tokens.dart';

const _expenseCategories = [
  'Gas',
  'Fuel charging',
  'Tolls',
  'Parking',
  'Supplies',
  'Car wash',
  'Inspection',
  'Oil change',
  'Winter tires',
  'Maintenance',
  'Other miscellaneous',
];

class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(activeVehicleProvider);
    final reminders = ref.watch(reminderProvider);
    final expenses = ref.watch(vehicleExpenseProvider);
    final offers = ref.watch(offerLogProvider);
    final total = expenses.fold<double>(0, (sum, item) => sum + item.amount);
    final currency = ref
        .watch(settingsProvider.select((s) => s.currency))
        .prefix;
    String money(double value) => '$currency${value.toStringAsFixed(2)}';

    return ListView(
      padding: EdgeInsets.fromLTRB(
        Gap.md,
        Gap.lg,
        Gap.md,
        112 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        Text('Garage', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: Gap.xs),
        Text(
          'Your vehicle, care schedule, and running costs.',
          style: TextStyle(color: FoxColors.textSecondary),
        ),
        const SizedBox(height: Gap.lg),
        const SectionLabel('Vehicles'),
        const SizedBox(height: Gap.sm),
        Container(
          padding: const EdgeInsets.all(Gap.sm),
          decoration: BoxDecoration(
            color: FoxColors.bgSurface,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: FoxColors.borderSoft),
            boxShadow: Shadows.card,
          ),
          child: Column(
            children: [
              if (vehicle != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.sm,
                    Gap.sm,
                    Gap.sm,
                    Gap.md,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.garage_rounded, color: FoxColors.brandFox),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          vehicle.title.isEmpty
                              ? 'Your vehicle'
                              : vehicle.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              const GarageList(),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),
        _IncomeExpenseSection(
          offers: offers,
          expenses: expenses,
          currency: currency,
          onAdd: () => showVehicleExpenseEditor(context, ref),
        ),
        const SizedBox(height: Gap.lg),
        Material(
          color: FoxColors.bgSurface,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card),
            side: BorderSide(color: FoxColors.borderSoft),
          ),
          child: ExpansionTile(
            key: const Key('maintenance-reminders-section'),
            tilePadding: const EdgeInsets.symmetric(horizontal: Gap.md),
            childrenPadding: const EdgeInsets.fromLTRB(
              Gap.md,
              0,
              Gap.md,
              Gap.md,
            ),
            leading: const Icon(Icons.build_circle_outlined),
            title: const Text('Maintenance reminders'),
            subtitle: Text(
              reminders.isEmpty
                  ? 'Service and upkeep schedule'
                  : '${reminders.length} scheduled',
            ),
            children: [
              if (reminders.isNotEmpty) ...[
                _NextReminder(
                  reminder:
                      ref.watch(dueRemindersProvider).firstOrNull ??
                      reminders.first,
                ),
                const SizedBox(height: Gap.sm),
              ],
              const ReminderSection(),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),
        Row(
          children: [
            const Expanded(child: SectionLabel('Vehicle expenses')),
            Text(
              money(total),
              style: TextStyle(
                color: FoxColors.brandFox,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.xs),
        Text(
          'These entries contribute to your expense summary.',
          style: TextStyle(fontSize: 12, color: FoxColors.textSecondary),
        ),
        const SizedBox(height: Gap.sm),
        if (expenses.isEmpty)
          Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: FoxColors.bgSurface,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: FoxColors.borderSoft),
            ),
            child: Text(
              'Add fuel, parking, supplies, or maintenance costs to start your ledger.',
              style: TextStyle(color: FoxColors.textSecondary),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: FoxColors.bgSurface,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: FoxColors.borderSoft),
              boxShadow: Shadows.card,
            ),
            child: Column(
              children: [
                for (var i = 0; i < expenses.length; i++) ...[
                  _ExpenseRow(
                    expense: expenses[i],
                    money: money(expenses[i].amount),
                    onTap: () => showVehicleExpenseEditor(
                      context,
                      ref,
                      existing: expenses[i],
                    ),
                  ),
                  if (i != expenses.length - 1)
                    Divider(height: 1, color: FoxColors.borderSoft),
                ],
              ],
            ),
          ),
        const SizedBox(height: Gap.sm),
        OutlinedButton.icon(
          onPressed: () => showVehicleExpenseEditor(context, ref),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add vehicle expense'),
        ),
      ],
    );
  }
}

class _IncomeExpenseSection extends StatelessWidget {
  const _IncomeExpenseSection({
    required this.offers,
    required this.expenses,
    required this.currency,
    required this.onAdd,
  });
  final List<OfferSummary> offers;
  final List<VehicleExpense> expenses;
  final String currency;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Material(
    color: FoxColors.bgSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.card),
      side: BorderSide(color: FoxColors.borderSoft),
    ),
    child: ExpansionTile(
      key: const Key('income-expenses-section'),
      tilePadding: const EdgeInsets.symmetric(horizontal: Gap.md),
      childrenPadding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
      leading: const Icon(Icons.compare_arrows_rounded),
      title: const Text('Income vs expenses'),
      subtitle: const Text('Monthly · Quarterly · Yearly'),
      children: [
        IncomeExpenseReport(
          offers: offers,
          expenses: expenses,
          currency: currency,
          onAdd: onAdd,
        ),
      ],
    ),
  );
}

class _NextReminder extends StatelessWidget {
  const _NextReminder({required this.reminder});
  final CarReminder reminder;

  @override
  Widget build(BuildContext context) {
    final days = reminder.daysLeft();
    final due = days <= 0;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: FoxColors.brandFox.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(Radii.cardSm),
      ),
      child: Row(
        children: [
          Icon(Icons.build_circle_outlined, color: FoxColors.brandFox),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT REMINDER',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  reminder.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          Text(
            due ? 'Due' : 'In ${days}d',
            style: TextStyle(
              color: due ? VerdictColors.bad : FoxColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.money,
    required this.onTap,
  });
  final VehicleExpense expense;
  final String money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: CircleAvatar(
      backgroundColor: FoxColors.brandFox.withValues(alpha: .1),
      foregroundColor: FoxColors.brandFox,
      child: Icon(_categoryIcon(expense.category), size: 19),
    ),
    title: Text(
      expense.description,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(
      '${expense.category} · ${MaterialLocalizations.of(context).formatShortDate(expense.date)}',
    ),
    trailing: Text(money, style: const TextStyle(fontWeight: FontWeight.w800)),
    minLeadingWidth: 0,
    contentPadding: const EdgeInsets.symmetric(horizontal: Gap.sm),
  );
}

IconData _categoryIcon(String category) => switch (category) {
  'Gas' || 'Fuel charging' => Icons.local_gas_station_outlined,
  'Parking' => Icons.local_parking_rounded,
  'Tolls' => Icons.toll_rounded,
  'Car wash' => Icons.local_car_wash_outlined,
  'Supplies' => Icons.inventory_2_outlined,
  _ => Icons.build_outlined,
};

void showVehicleExpenseEditor(
  BuildContext context,
  WidgetRef ref, {
  VehicleExpense? existing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _VehicleExpenseEditor(existing: existing),
);

class _VehicleExpenseEditor extends ConsumerStatefulWidget {
  const _VehicleExpenseEditor({this.existing});
  final VehicleExpense? existing;

  @override
  ConsumerState<_VehicleExpenseEditor> createState() =>
      _VehicleExpenseEditorState();
}

class _VehicleExpenseEditorState extends ConsumerState<_VehicleExpenseEditor> {
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _amount = TextEditingController(
    text: widget.existing?.amount.toStringAsFixed(2) ?? '',
  );
  late String _category = widget.existing?.category ?? _expenseCategories.first;
  late DateTime _date = widget.existing?.date ?? DateTime.now();

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final description = _description.text.trim();
    final amount = double.tryParse(_amount.text.trim());
    if (description.isEmpty || amount == null || amount <= 0) return;
    ref
        .read(vehicleExpenseProvider.notifier)
        .save(
          VehicleExpense(
            id:
                widget.existing?.id ??
                DateTime.now().microsecondsSinceEpoch.toString(),
            category: _category,
            description: description,
            amount: amount,
            date: _date,
          ),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md + keyboard),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width - Gap.lg * 2,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .78,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.existing == null
                      ? 'Add vehicle expense'
                      : 'Edit expense',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: Gap.sm),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: [
                            for (final category in _expenseCategories)
                              DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _category = value);
                            }
                          },
                        ),
                        const SizedBox(height: Gap.sm),
                        TextField(
                          controller: _description,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                          ),
                        ),
                        const SizedBox(height: Gap.sm),
                        TextField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: '\$',
                          ),
                        ),
                        const SizedBox(height: Gap.sm),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(_date),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Gap.xs),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: Gap.sm,
                  overflowSpacing: Gap.xs,
                  children: [
                    if (widget.existing != null)
                      TextButton(
                        onPressed: () {
                          ref
                              .read(vehicleExpenseProvider.notifier)
                              .remove(widget.existing!.id);
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: VerdictColors.bad,
                        ),
                        child: const Text('Delete'),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      key: const Key('save-vehicle-expense'),
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
