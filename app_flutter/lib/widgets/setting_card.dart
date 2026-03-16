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
    final c = context.colors;
    return Card(
      color: c.surfaceCard,
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? c.primary, size: 28),
        title: Text(
          title,
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: c.textTertiary, fontSize: 12),
        ),
        trailing: trailing,
      ),
    );
  }
}
