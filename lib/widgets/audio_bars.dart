import 'package:flutter/material.dart';

class AudioBars extends StatelessWidget {
  final List<double> levels; // 0..1
  final double height;
  final double barWidth;
  final double spacing;
  final double minBar;

  const AudioBars({
    Key? key,
    required this.levels,
    this.height = 56,
    this.barWidth = 3,
    this.spacing = 2,
    this.minBar = 0.1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _BarsPainter(
          levels: levels,
          color: cs.primary,
          barWidth: barWidth,
          spacing: spacing,
          minBar: minBar,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> levels;
  final Color color;
  final double barWidth;
  final double spacing;
  final double minBar;

  _BarsPainter({
    required this.levels,
    required this.color,
    required this.barWidth,
    required this.spacing,
    required this.minBar,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(0.95);
    final baseline = size.height / 2;

    double x = size.width - barWidth;
    for (int i = levels.length - 1; i >= 0; i--) {
      final lv = levels[i].clamp(0.0, 1.0);
      final h = size.height * (lv * (1 - minBar) + minBar);
      final top = baseline - h / 2;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, h),
        const Radius.circular(2),
      );
      canvas.drawRRect(r, paint);
      x -= (barWidth + spacing);
      if (x < -barWidth) break;
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.levels != levels || old.color != color;
}
