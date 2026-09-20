import 'package:flutter/material.dart';
import '../theme.dart';

/// A bento-style tile. Two layouts:
/// - Default (vertical): label above a large value — used for square-ish
///   grid tiles like "Salary" / "Saved".
/// - Row (horizontal): label on the left, value on the right — used for
///   full-width tiles like "Remaining".
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Color? labelColor;

  /// Solid background color for this tile (e.g. the green "Salary" tile).
  /// Leave null for a plain white tile.
  final Color? fillColor;

  /// Horizontal (label left, value right) instead of the default vertical
  /// stack. Used for full-width rows like "Remaining".
  final bool row;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.labelColor,
    this.fillColor,
    this.row = false,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = fillColor != null;
    final resolvedLabelColor =
        labelColor ?? (isFilled ? Colors.white.withOpacity(0.75) : AppColors.textSecondary);
    final resolvedValueColor = valueColor ?? (isFilled ? Colors.white : AppColors.textPrimary);

    final content = row
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: resolvedLabelColor, fontSize: 14)),
              Text(
                value,
                style: TextStyle(color: resolvedValueColor, fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: TextStyle(color: resolvedLabelColor, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(color: resolvedValueColor, fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ],
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fillColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: content,
    );
  }
}
