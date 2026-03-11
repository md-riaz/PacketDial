import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Themed search text field with clear button.
class AppSearchBar extends StatelessWidget {
  final String hintText;
  final String value;
  final ValueChanged<String> onChanged;

  const AppSearchBar({
    super.key,
    this.hintText = 'Search…',
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppTheme.textTertiary),
        filled: true,
        fillColor: AppTheme.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide.none,
        ),
        prefixIcon: const Icon(Icons.search, color: AppTheme.textTertiary),
        suffixIcon: value.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: AppTheme.textTertiary),
                onPressed: () => onChanged(''),
              )
            : null,
      ),
    );
  }
}
