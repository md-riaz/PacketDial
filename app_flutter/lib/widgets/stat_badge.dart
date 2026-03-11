import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Compact colored stat chip: icon + count + label.
///
/// Two variants:
/// - [StatBadge.pill] — horizontal row (contacts screen style)
/// - [StatBadge.card] — vertical column (settings contacts tab style)
class StatBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String count;
  final String label;
  final bool _isCard;

  /// Horizontal pill layout.
  const StatBadge.pill({
    super.key,
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
  }) : _isCard = false;

  /// Vertical card layout (taller, centered).
  const StatBadge.card({
    super.key,
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
  }) : _isCard = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _isCard
          ? const EdgeInsets.symmetric(
              vertical: AppTheme.spacingMd, horizontal: 12)
          : const EdgeInsets.symmetric(
              horizontal: 12, vertical: AppTheme.spacingSm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius:
            BorderRadius.circular(_isCard ? AppTheme.radiusMd + 2 : 20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: _isCard ? _buildCardLayout() : _buildPillLayout(),
    );
  }

  Widget _buildPillLayout() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 6),
        Text(
          count,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCardLayout() {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: AppTheme.spacingSm),
        Text(
          count,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
