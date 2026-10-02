import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/format.dart';

class TxTile extends StatelessWidget {
  final TxRecord tx;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TxTile({super.key, required this.tx, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final isTransfer = tx.type == 'transfer';
    final isIncome = tx.type == 'income';

    final emoji = isTransfer ? '🔁' : (tx.categoryEmoji ?? '❔');
    final title = isTransfer ? 'Transfer' : (tx.categoryName ?? '-');

    final parts = <String>[
      isTransfer ? '${tx.pocketName} → ${tx.toPocketName}' : tx.pocketName ?? '',
      if (tx.method != null) (tx.method == 'card' ? 'Card' : 'Cash'),
      if (tx.note.isNotEmpty) tx.note,
    ];

    final Color color;
    final String sign;
    if (isTransfer) {
      color = Theme.of(context).colorScheme.onSurfaceVariant;
      sign = '';
    } else if (isIncome) {
      color = Colors.green.shade600;
      sign = '+';
    } else {
      color = Colors.red.shade600;
      sign = '-';
    }

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: CircleAvatar(child: Text(emoji, style: const TextStyle(fontSize: 20))),
      title: Text(title),
      subtitle: Text(parts.join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '$sign${rupiah(tx.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
