import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/investment.dart';
import '../models/models.dart';
import '../utils/format.dart';
import 'investment_detail_screen.dart';
import 'pocket_form_screen.dart';

class PocketsScreen extends StatefulWidget {
  const PocketsScreen({super.key});

  @override
  State<PocketsScreen> createState() => _PocketsScreenState();
}

class _PocketsScreenState extends State<PocketsScreen> {
  List<Pocket> _pockets = [];
  Map<int, InvestmentSummary> _inv = {};

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
    final p = await Repo.I.pockets();
    final inv = await Repo.I.investments();
    if (!mounted) return;
    setState(() {
      _pockets = p;
      _inv = {for (final i in inv) i.pocket.id!: i};
    });
  }

  void _open(Pocket? p) {
    // Pocket investasi punya halaman detail sendiri; pocket biasa langsung ke form.
    final Widget page = (p != null && p.isInvestment)
        ? InvestmentDetailScreen(pocketId: p.id!)
        : PocketFormScreen(pocket: p);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocket'),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline), tooltip: 'Pocket baru', onPressed: () => _open(null)),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: _pockets.length,
        itemBuilder: (_, i) {
          final p = _pockets[i];
          return _PocketCard(pocket: p, summary: _inv[p.id], onTap: () => _open(p));
        },
      ),
    );
  }
}

class _PocketCard extends StatelessWidget {
  final Pocket pocket;
  final InvestmentSummary? summary; // hanya untuk pocket investasi
  final VoidCallback onTap;
  const _PocketCard({required this.pocket, required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(pocket.color);
    final s = summary;
    final amount = s?.currentValue ?? pocket.balance;
    final target = pocket.targetAmount;
    final progress = target == null || target == 0 ? null : (amount / target).clamp(0.0, 1.0);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.2),
                    child: Text(pocket.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(pocket.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                            if (pocket.isInvestment) ...[
                              const SizedBox(width: 6),
                              const Chip(
                                label: Text('Investasi', style: TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ],
                        ),
                        Text(rupiah(amount), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                        if (s != null) _profitLine(context, s),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: progress, minHeight: 8, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% dari ${rupiah(target!)}'
                  '${pocket.targetDate != null ? ' • sampai ${tanggalPendek(pocket.targetDate!)}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _profitLine(BuildContext context, InvestmentSummary s) {
    final up = s.profit >= 0;
    final c = up ? Colors.green.shade600 : Colors.red.shade600;
    final pct = s.profitPct == null ? '' : ' (${up ? '+' : ''}${s.profitPct!.toStringAsFixed(1)}%)';
    return Text.rich(
      TextSpan(
        style: Theme.of(context).textTheme.bodySmall,
        children: [
          TextSpan(text: 'Modal ${rupiah(s.modal)} • '),
          TextSpan(
            text: '${up ? '+' : ''}${rupiah(s.profit)}$pct',
            style: TextStyle(color: c, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
