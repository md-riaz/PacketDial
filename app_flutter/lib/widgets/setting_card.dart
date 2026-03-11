import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Standard setting row: leading icon, title, subtitle, trailing widget.
class SettingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Color? iconColor;

  const SettingCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceCard,
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? AppTheme.primary, size: 28),
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 12,
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}
