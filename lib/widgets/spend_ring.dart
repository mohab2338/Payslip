import 'package:flutter/material.dart';
import '../theme.dart';

class SpendRing extends StatelessWidget {
  final double percentage; // 0-100+
  final double size;

  const SpendRing({super.key, required this.percentage, this.size = 160});

  Color get _color {
    if (percentage >= 100) return AppColors.danger;
    if (percentage >= 75) return const Color(0xFFFFA94D);
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    final clamped = percentage.clamp(0, 100) / 100;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: clamped.toDouble(),
              strokeWidth: 12,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(_color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text(
                'spent',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
