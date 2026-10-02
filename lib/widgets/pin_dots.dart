import 'package:flutter/material.dart';

/// Deretan titik untuk menunjukkan progres PIN yang sudah diketik.
class PinDots extends StatelessWidget {
  final int length;
  final int filled;
  final bool error;
  const PinDots({super.key, required this.length, required this.filled, this.error = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = error ? Colors.red.shade400 : cs.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final on = i < filled;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
        );
      }),
    );
  }
}

/// Keypad angka 0-9 + hapus. onDigit(null) berarti tombol hapus ditekan.
class PinKeypad extends StatelessWidget {
  final ValueChanged<String?> onDigit;
  const PinKeypad({super.key, required this.onDigit});

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {Widget? child, VoidCallback? onTap}) => Expanded(
          child: AspectRatio(
            aspectRatio: 1.4,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap ?? (label.isEmpty ? null : () => onDigit(label)),
                  child: Center(
                    child: child ?? Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ),
          ),
        );

    return Column(
      children: [
        Row(children: [key('1'), key('2'), key('3')]),
        Row(children: [key('4'), key('5'), key('6')]),
        Row(children: [key('7'), key('8'), key('9')]),
        Row(children: [
          key(''),
          key('0'),
          key('', child: const Icon(Icons.backspace_outlined), onTap: () => onDigit(null)),
        ]),
      ],
    );
  }
}
