import 'package:flutter/material.dart';

import '../services/file_output.dart';

/// Lembar bawah berisi pilihan "Simpan ke HP" dan "Bagikan" untuk file yang baru dibuat.
/// [onDone] dipanggil setelah file berhasil disimpan atau dibagikan.
Future<void> showOutputSheet(BuildContext context, OutputFile file, {Future<void> Function()? onDone}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _OutputSheet(file: file, onDone: onDone),
  );
}

class _OutputSheet extends StatefulWidget {
  final OutputFile file;
  final Future<void> Function()? onDone;
  const _OutputSheet({required this.file, this.onDone});

  @override
  State<_OutputSheet> createState() => _OutputSheetState();
}

class _OutputSheetState extends State<_OutputSheet> {
  bool _busy = false;

  Future<void> _run(Future<bool> Function() action, String successMsg) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final ok = await action();
      if (ok) {
        await widget.onDone?.call();
        nav.pop();
        messenger.showSnackBar(SnackBar(content: Text(successMsg)));
      } else if (mounted) {
        setState(() => _busy = false);
      }
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle_outline, size: 40),
            const SizedBox(height: 8),
            Text('File siap', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(widget.file.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : () => _run(() => FileOutput.saveToDevice(widget.file), 'File tersimpan'),
              icon: const Icon(Icons.save_alt),
              label: const Text('Simpan ke HP'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(() => FileOutput.share(widget.file), 'File dibagikan'),
              icon: const Icon(Icons.share),
              label: const Text('Bagikan (Drive, WhatsApp, email, ...)'),
            ),
          ],
        ),
      ),
    );
  }
}
