import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Tinted information / tip banner with leading icon and text.
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final Widget? child;

  const InfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = color ?? c.primary;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: AppTheme.infoCard(color: tint),
      child: child ??
          Row(
            children: [
              Icon(icon, color: tint, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: c.textTertiary, fontSize: 12),
                ),
              ),
            ],
          ),
    );
  }
}
