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
    final c = color ?? AppTheme.primary;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: AppTheme.infoCard(color: c),
      child: child ??
          Row(
            children: [
              Icon(icon, color: c, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 12),
                ),
              ),
            ],
          ),
    );
  }
}
