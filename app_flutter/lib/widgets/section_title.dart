import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Consistent section header used across settings tabs, contacts, etc.
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );
  }
}
