import 'package:flutter/material.dart';
import '../theme.dart';

class SpendRing extends StatelessWidget {
  final double percentage; // 0-100+
  final double size;
  /// When true, renders with light colors suited to sitting on the dark
  /// purple hero tile (used on the home screen) instead of on a plain
  /// light background.
  final bool onDark;

  const SpendRing({
    super.key,
    required this.percentage,
    this.size = 160,
    this.onDark = false,
  });

  Color get _trackColor => onDark ? AppColors.primaryDark : AppColors.divider;
  Color get _progressColor => onDark ? AppColors.primaryLight : _lightModeColor;
  Color get _textColor => onDark ? Colors.white : AppColors.textPrimary;

  Color get _lightModeColor {
    if (percentage >= 100) return AppColors.danger;
    if (percentage >= 75) return const Color(0xFFBA7517);
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
              strokeWidth: size * 0.075,
              backgroundColor: _trackColor,
              valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: size * 0.19,
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }
}
