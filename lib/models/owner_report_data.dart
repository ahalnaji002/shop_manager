enum OwnerReportPeriod { today, last7Days, currentMonth, custom }

class OwnerReportDateRange {
  final DateTime start;
  final DateTime end;
  const OwnerReportDateRange({required this.start, required this.end});

  factory OwnerReportDateRange.forPeriod(
    OwnerReportPeriod period, {
    DateTime? now,
    OwnerReportDateRange? customRange,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    switch (period) {
      case OwnerReportPeriod.today:
        return OwnerReportDateRange(
          start: today,
          end: today.add(const Duration(days: 1)),
        );
      case OwnerReportPeriod.last7Days:
        return OwnerReportDateRange(
          start: today.subtract(const Duration(days: 6)),
          end: today.add(const Duration(days: 1)),
        );
      case OwnerReportPeriod.currentMonth:
        final end = current.month == 12
            ? DateTime(current.year + 1, 1)
            : DateTime(current.year, current.month + 1);
        return OwnerReportDateRange(
          start: DateTime(current.year, current.month),
          end: end,
        );
      case OwnerReportPeriod.custom:
        if (customRange == null) {
          throw ArgumentError('A custom report range is required.');
        }
        return customRange;
    }
  }
}

class OwnerReportData {
  final double netSales, costOfGoodsSold, grossProfit, operatingExpenses;
  final double netOperatingProfit, grossMargin, netMargin;
  final int activeInvoiceCount, cancelledInvoiceCount;
  final double averageActiveInvoiceValue, cashSales, debtSales;
  final double activeDebtCollections, netDebtMovement;
  final double currentOutstandingReceivables;

  const OwnerReportData({
    required this.netSales,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.operatingExpenses,
    required this.netOperatingProfit,
    required this.grossMargin,
    required this.netMargin,
    required this.activeInvoiceCount,
    required this.cancelledInvoiceCount,
    required this.averageActiveInvoiceValue,
    required this.cashSales,
    required this.debtSales,
    required this.activeDebtCollections,
    required this.netDebtMovement,
    required this.currentOutstandingReceivables,
  });
}
