import 'package:flutter/material.dart';

import '../models/owner_report_data.dart';
import '../services/owner_report_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const navy = Color(0xFF0B1F3A),
      gold = Color(0xFFF4B942),
      background = Color(0xFFF6F7F9);
  final _service = OwnerReportService();
  OwnerReportPeriod _period = OwnerReportPeriod.today;
  OwnerReportDateRange? _customRange;
  OwnerReportDateRange get _range =>
      OwnerReportDateRange.forPeriod(_period, customRange: _customRange);

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: const Text(
          'تقرير المالك',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _periodSelector(),
          Expanded(
            child: StreamBuilder<OwnerReportData>(
              stream: _service.watchReport(_range),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _message(
                    'تعذر تحميل بيانات التقرير',
                    Icons.error_outline,
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _report(snapshot.data!);
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _periodSelector() => Container(
    color: navy,
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 15),
    child: Column(
      children: [
        Row(
          children: [
            _periodButton('اليوم', OwnerReportPeriod.today),
            _periodButton('آخر 7 أيام', OwnerReportPeriod.last7Days),
            _periodButton('الشهر الحالي', OwnerReportPeriod.currentMonth),
            _periodButton('مخصص', OwnerReportPeriod.custom),
          ],
        ),
        if (_period == OwnerReportPeriod.custom && _customRange != null) ...[
          const SizedBox(height: 9),
          Text(
            '${_date(_customRange!.start)} — ${_date(_customRange!.end.subtract(const Duration(days: 1)))}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ],
    ),
  );

  Widget _periodButton(String label, OwnerReportPeriod value) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectPeriod(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          decoration: BoxDecoration(
            color: _period == value ? gold : Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _period == value ? navy : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _selectPeriod(OwnerReportPeriod value) async {
    if (value != OwnerReportPeriod.custom) {
      setState(() => _period = value);
      return;
    }
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: _customRange?.start ?? DateTime(now.year, now.month, 1),
        end: _customRange?.end.subtract(const Duration(days: 1)) ?? now,
      ),
      helpText: 'اختر فترة التقرير',
      cancelText: 'إلغاء',
      confirmText: 'تطبيق',
      saveText: 'تطبيق',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _customRange = OwnerReportDateRange(
        start: DateTime(
          selected.start.year,
          selected.start.month,
          selected.start.day,
        ),
        end: DateTime(
          selected.end.year,
          selected.end.month,
          selected.end.day,
        ).add(const Duration(days: 1)),
      );
      _period = OwnerReportPeriod.custom;
    });
  }

  Widget _report(OwnerReportData data) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
    children: [
      _section('الأرباح'),
      _grid([
        _Metric('صافي المبيعات', _money(data.netSales), Icons.point_of_sale),
        _Metric(
          'تكلفة البضاعة المباعة',
          _money(data.costOfGoodsSold),
          Icons.inventory_2_outlined,
        ),
        _Metric('إجمالي الربح', _money(data.grossProfit), Icons.trending_up),
        _Metric(
          'المصاريف التشغيلية',
          _money(data.operatingExpenses),
          Icons.money_off_outlined,
        ),
        _Metric(
          'صافي الربح التشغيلي',
          _money(data.netOperatingProfit),
          Icons.account_balance_wallet_outlined,
          highlight: true,
        ),
        _Metric(
          'هامش الربح الإجمالي',
          _percent(data.grossMargin),
          Icons.percent,
        ),
        _Metric(
          'هامش الربح الصافي',
          _percent(data.netMargin),
          Icons.pie_chart_outline,
        ),
      ]),
      const SizedBox(height: 24),
      _section('المبيعات'),
      _grid([
        _Metric(
          'الفواتير النشطة',
          '${data.activeInvoiceCount}',
          Icons.receipt_long_outlined,
        ),
        _Metric(
          'الفواتير الملغاة',
          '${data.cancelledInvoiceCount}',
          Icons.cancel_outlined,
        ),
        _Metric(
          'متوسط الفاتورة النشطة',
          _money(data.averageActiveInvoiceValue),
          Icons.calculate_outlined,
        ),
        _Metric(
          'المبيعات النقدية',
          _money(data.cashSales),
          Icons.payments_outlined,
        ),
        _Metric(
          'المبيعات بالدين',
          _money(data.debtSales),
          Icons.credit_score_outlined,
        ),
      ]),
      const SizedBox(height: 24),
      _section('الديون'),
      _grid([
        _Metric(
          'ديون جديدة خلال الفترة',
          _money(data.debtSales),
          Icons.add_card_outlined,
        ),
        _Metric(
          'تحصيلات نشطة خلال الفترة',
          _money(data.activeDebtCollections),
          Icons.price_check_outlined,
        ),
        _Metric(
          'صافي حركة الدين',
          _signedMoney(data.netDebtMovement),
          Icons.compare_arrows_outlined,
        ),
        _Metric(
          'إجمالي الذمم الحالية',
          _money(data.currentOutstandingReceivables),
          Icons.account_balance_outlined,
          highlight: true,
        ),
      ]),
      const SizedBox(height: 10),
      const Text(
        'إجمالي الذمم الحالية هو رصيد لحظي لجميع فواتير الدين النشطة، ولا يتقيد بفترة التقرير.',
        style: TextStyle(color: Color(0xFF7C8796), fontSize: 12),
      ),
    ],
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        color: navy,
        fontSize: 19,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
  Widget _grid(List<_Metric> metrics) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth >= 700
          ? (box.maxWidth - 24) / 3
          : (box.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: metrics.map((m) => _card(m, width)).toList(),
      );
    },
  );
  Widget _card(_Metric metric, double width) => Container(
    width: width,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: metric.highlight ? navy : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: metric.highlight ? navy : const Color(0xFFE9ECF1),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(metric.icon, color: metric.highlight ? gold : navy, size: 22),
        const SizedBox(height: 12),
        Text(
          metric.value,
          style: TextStyle(
            color: metric.highlight ? Colors.white : navy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          metric.label,
          style: TextStyle(
            color: metric.highlight ? Colors.white70 : const Color(0xFF7C8796),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
  Widget _message(String text, IconData icon) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42),
        const SizedBox(height: 10),
        Text(text),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => setState(() {}),
          child: const Text('إعادة المحاولة'),
        ),
      ],
    ),
  );
  String _money(double value) => '${value.toStringAsFixed(2)} ₪';
  String _signedMoney(double value) =>
      '${value >= 0 ? '+' : ''}${_money(value)}';
  String _percent(double value) => '${value.toStringAsFixed(1)}%';
  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
}

class _Metric {
  final String label, value;
  final IconData icon;
  final bool highlight;
  const _Metric(this.label, this.value, this.icon, {this.highlight = false});
}
