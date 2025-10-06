import 'package:flutter/material.dart';

class VuMeter extends StatelessWidget {
  final double db; // -160..0
  const VuMeter({super.key, required this.db});

  double _level(double db) {
    final c = db.clamp(-60.0, 0.0);
    return (c + 60.0) / 60.0; // 0..1
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LinearProgressIndicator(value: _level(db), minHeight: 18),
    );
  }
}
