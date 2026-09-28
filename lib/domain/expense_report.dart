import 'offer_stats.dart';
import 'offer_summary.dart';
import 'vehicle_expense.dart';

enum ReportPeriod {
  month(1, 'Monthly'),
  quarter(3, 'Quarterly'),
  year(12, 'Yearly');

  const ReportPeriod(this.months, this.label);
  final int months;
  final String label;

  DateTime start(DateTime date) =>
      DateTime(date.year, ((date.month - 1) ~/ months) * months + 1);
}

/// Gross recorded payouts (including cancellation fees), not taxable profit.
class ExpenseReport {
  ExpenseReport(
    List<OfferSummary> offers,
    List<VehicleExpense> expenses,
    ReportPeriod period,
    DateTime date,
  ) {
    start = period.start(date);
    end = DateTime(start.year, start.month + period.months);
    bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);
    final selectedOffers = offers
        .where((o) => contains(o.seenAt.toLocal()))
        .toList();
    final selectedExpenses = expenses
        .where((e) => contains(e.date.toLocal()))
        .toList();
    stats = OfferStats.from(selectedOffers);
    costs = selectedExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final count = period == ReportPeriod.month
        ? DateTime(start.year, start.month + 1, 0).day
        : period.months;
    incomePoints = List.filled(count, 0.0);
    expensePoints = List.filled(count, 0.0);
    int bucket(DateTime date) => period == ReportPeriod.month
        ? date.toLocal().day - 1
        : date.toLocal().month - start.month;
    for (final offer in selectedOffers) {
      incomePoints[bucket(offer.seenAt)] += OfferStats.from([
        offer,
      ]).recordedEarnings;
    }
    for (final expense in selectedExpenses) {
      expensePoints[bucket(expense.date)] += expense.amount;
      categories.update(
        expense.category,
        (v) => v + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
  }
  late final DateTime start, end;
  late final OfferStats stats;
  late final double costs;
  late final List<double> incomePoints, expensePoints;
  final categories = <String, double>{};
  double get balance => stats.recordedEarnings - costs;
}
