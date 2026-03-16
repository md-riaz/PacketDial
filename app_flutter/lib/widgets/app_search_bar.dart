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
    final c = context.colors;
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: c.textTertiary),
        filled: true,
        fillColor: c.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(Icons.search, color: c.textTertiary),
        suffixIcon: value.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: c.textTertiary),
                onPressed: () => onChanged(''),
              )
            : null,
      ),
    );
  }
}
