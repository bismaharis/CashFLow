import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repository.dart';
import '../data/stats_repository.dart';
import '../utils/format.dart';
import '../utils/period.dart';

const _sliceColors = [
  Color(0xFF00897B), Color(0xFF1E88E5), Color(0xFF8E24AA), Color(0xFFE53935), Color(0xFFFB8C00),
  Color(0xFF43A047), Color(0xFF3949AB), Color(0xFF6D4C41), Color(0xFF00ACC1), Color(0xFFD81B60),
];

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  PeriodKind _kind = PeriodKind.month;
  int _offset = 0; // 0 = periode sekarang, -1 = sebelumnya, dst.

  PeriodTotals? _totals;
  PeriodTotals _prev = const PeriodTotals();
  List<CategorySlice> _slices = [];
  List<BucketTotal> _buckets = [];
  int _req = 0;

  @override
  void initState() {
    super.initState();
    Repo.I.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    Repo.I.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_req;
    final p = Period.of(_kind, _offset);
    final prev = Period.of(_kind, _offset - 1);
    final totals = await StatsRepo.totals(p.start, p.end);
    final prevTotals = await StatsRepo.totals(prev.start, prev.end);
    final slices = await StatsRepo.expenseByCategory(p.start, p.end);
    final buckets = await StatsRepo.buckets(p.start, p.end, monthly: p.monthlyBuckets);
    if (!mounted || id != _req) return;
    setState(() {
      _totals = totals;
      _prev = prevTotals;
      _slices = slices;
      _buckets = buckets;
    });
  }

  String _kindLabel(PeriodKind k) => switch (k) {
        PeriodKind.week => 'Minggu',
        PeriodKind.month => 'Bulan',
        PeriodKind.quarter => '3 Bulan',
        PeriodKind.half => '6 Bulan',
        PeriodKind.year => 'Tahun',
      };

  void _go(int delta) {
    setState(() => _offset += delta);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final period = Period.of(_kind, _offset);
    final t = _totals;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final k in PeriodKind.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_kindLabel(k)),
                        selected: _kind == k,
                        onSelected: (_) {
                          setState(() {
                            _kind = k;
                            _offset = 0;
                          });
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _go(-1)),
                Expanded(
                  child: Center(child: Text(period.label, style: Theme.of(context).textTheme.titleMedium)),
                ),
                // Tidak bisa maju ke periode di masa depan.
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: _offset >= 0 ? null : () => _go(1)),
              ],
            ),
            if (t == null)
              const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
            else ...[
              _summaryCard(t),
              const SizedBox(height: 12),
              _trendCard(period),
              const SizedBox(height: 12),
              _categoryCard(t),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- Ringkasan ----------

  Widget _summaryCard(PeriodTotals t) {
    final persen = t.income == 0 ? null : t.expense * 100 / t.income;
    final over = persen != null && persen > 100;
    final net = t.income - t.expense;

    String? compare;
    Color? compareColor;
    if (_prev.expense > 0) {
      final change = (t.expense - _prev.expense) * 100 / _prev.expense;
      final naik = change >= 0;
      compare = 'Pengeluaran ${naik ? 'naik' : 'turun'} ${change.abs().toStringAsFixed(0)}% '
          'dibanding periode sebelumnya (${rupiah(_prev.expense)})';
      compareColor = naik ? Colors.red.shade600 : Colors.green.shade600;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _figure('Pemasukan', rupiah(t.income), Colors.green.shade600)),
                Expanded(child: _figure('Pengeluaran', rupiah(t.expense), Colors.red.shade600)),
              ],
            ),
            const SizedBox(height: 8),
            _figure('Selisih', '${net >= 0 ? '+' : ''}${rupiah(net)}',
                net >= 0 ? Colors.green.shade600 : Colors.red.shade600),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: persen == null ? 0 : (persen / 100).clamp(0.0, 1.0),
                color: over ? Colors.red.shade600 : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              persen != null
                  ? 'Pengeluaran ${persen.toStringAsFixed(0)}% dari pemasukan'
                  : (t.expense > 0 ? 'Belum ada pemasukan di periode ini' : 'Belum ada transaksi di periode ini'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (compare != null) ...[
              const SizedBox(height: 4),
              Text(compare, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: compareColor)),
            ],
            if (t.expense > 0) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(child: _method(Icons.payments_outlined, 'Cash', t.cashExpense, t.expense)),
                  Expanded(child: _method(Icons.credit_card, 'Card', t.cardExpense, t.expense)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _figure(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ],
      );

  Widget _method(IconData icon, String label, int value, int total) {
    final pct = total == 0 ? 0 : value * 100 / total;
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label • ${pct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)),
            Text(rupiah(value), style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  // ---------- Grafik tren ----------

  String _bucketLabel(Period p, BucketTotal b) {
    if (p.monthlyBuckets) return DateFormat('MMM', 'id_ID').format(b.start);
    if (p.kind == PeriodKind.week) return DateFormat('E', 'id_ID').format(b.start);
    final d = b.start.day; // per bulan: tampilkan tanggal 1, 5, 10, 15, ...
    return (d == 1 || d % 5 == 0) ? '$d' : '';
  }

  Widget _trendCard(Period p) {
    final b = _buckets;
    final rodW = p.monthlyBuckets ? 10.0 : (p.kind == PeriodKind.week ? 12.0 : 4.0);
    final hasData = b.any((x) => x.income > 0 || x.expense > 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Tren', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                _legendDot(Colors.green.shade400, 'Masuk'),
                const SizedBox(width: 12),
                _legendDot(Colors.red.shade400, 'Keluar'),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasData)
              const SizedBox(height: 120, child: Center(child: Text('Belum ada data')))
            else
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    barTouchData: BarTouchData(enabled: false),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= b.length) return const SizedBox.shrink();
                            final label = _bucketLabel(p, b[i]);
                            if (label.isEmpty) return const SizedBox.shrink();
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(label, style: const TextStyle(fontSize: 10)),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < b.length; i++)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 2,
                          barRods: [
                            BarChartRodData(
                              toY: b[i].income.toDouble(),
                              color: Colors.green.shade400,
                              width: rodW,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            BarChartRodData(
                              toY: b[i].expense.toDouble(),
                              color: Colors.red.shade400,
                              width: rodW,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color c, String label) => Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );

  // ---------- Donat per kategori ----------

  Widget _categoryCard(PeriodTotals t) {
    final total = _slices.fold<int>(0, (s, e) => s + e.total);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pengeluaran per kategori', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (_slices.isEmpty)
              const SizedBox(height: 80, child: Center(child: Text('Belum ada pengeluaran')))
            else ...[
              SizedBox(
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 62,
                        sections: [
                          for (var i = 0; i < _slices.length; i++)
                            PieChartSectionData(
                              value: _slices[i].total.toDouble(),
                              color: _sliceColors[i % _sliceColors.length],
                              radius: 40,
                              title: _slices[i].total * 100 / total >= 6
                                  ? '${(_slices[i].total * 100 / total).toStringAsFixed(0)}%'
                                  : '',
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Total', style: TextStyle(fontSize: 12)),
                        Text(rupiah(total), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _slices.length; i++) _sliceRow(i, total),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sliceRow(int i, int total) {
    final s = _slices[i];
    final color = _sliceColors[i % _sliceColors.length];
    final pct = total == 0 ? 0.0 : s.total * 100 / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text('${s.emoji} ${s.name}', overflow: TextOverflow.ellipsis)),
              Text(rupiah(s.total), style: const TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(
                width: 52,
                child: Text('${pct.toStringAsFixed(1)}%', textAlign: TextAlign.right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct / 100, minHeight: 6, color: color),
          ),
        ],
      ),
    );
  }
}
