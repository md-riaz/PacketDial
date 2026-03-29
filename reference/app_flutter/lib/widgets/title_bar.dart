import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:window_manager/window_manager.dart';
import '../core/app_theme.dart';

class TitleBar extends StatelessWidget {
  final String? title;
  final bool alwaysOnTop;
  final VoidCallback onToggleAlwaysOnTop;
  final bool showBackButton;
  final bool showWindowButtons;

  const TitleBar({
    super.key,
    this.title,
    required this.alwaysOnTop,
    required this.onToggleAlwaysOnTop,
    this.showBackButton = false,
    this.showWindowButtons = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return WindowTitleBarBox(
      child: Container(
        height: 34,
        decoration: BoxDecoration(gradient: c.titleBarGradient),
        child: Row(
          children: [
            if (showBackButton)
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 16),
                color: c.textSecondary,
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 34, maxWidth: 34, minHeight: 34, maxHeight: 34),
              )
            else
              const SizedBox(width: 12),
            if (!showBackButton) ...[
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: c.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Image.asset('assets/app_icon.png', width: 16, height: 16),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              title ?? 'PacketDial',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textPrimary.withValues(alpha: 0.9),
                letterSpacing: 0.5,
              ),
            ),
            Expanded(child: MoveWindow()),
            Tooltip(
              message: alwaysOnTop ? 'Unpin from top' : 'Pin on top',
              child: InkWell(
                onTap: onToggleAlwaysOnTop,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    alwaysOnTop ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 14,
                    color: alwaysOnTop ? c.primary : c.textTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (showWindowButtons) const WindowButtons(),
          ],
        ),
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final buttonColors = WindowButtonColors(
      iconNormal: c.textSecondary,
      mouseOver: c.primary.withValues(alpha: 0.15),
      mouseDown: c.primary.withValues(alpha: 0.25),
      iconMouseOver: c.textPrimary,
      iconMouseDown: c.textPrimary,
    );

    final closeButtonColors = WindowButtonColors(
      mouseOver: const Color(0xFFD32F2F),
      mouseDown: const Color(0xFFB71C1C),
      iconNormal: c.textSecondary,
      iconMouseOver: Colors.white,
    );

    return Row(
      children: [
        MinimizeWindowButton(colors: buttonColors),
        MaximizeWindowButton(colors: buttonColors),
        CloseWindowButton(
          colors: closeButtonColors,
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}
