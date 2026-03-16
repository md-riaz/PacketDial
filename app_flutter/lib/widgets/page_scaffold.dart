import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Wraps a [Scaffold] in the standard page gradient background with a
/// transparent app bar. Used by contacts, settings, and similar pages.
class PageScaffold extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget body;

  const PageScaffold({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(gradient: c.pageGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            title,
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          actions: actions,
          bottom: bottom,
        ),
        body: body,
      ),
    );
  }
}
