import 'package:flutter/material.dart';

class CallTransferPanel extends StatelessWidget {
  const CallTransferPanel({
    super.key,
    required this.controller,
    required this.onBlindTransfer,
    required this.onBeginAttendedTransfer,
  });

  final TextEditingController controller;
  final ValueChanged<String> onBlindTransfer;
  final ValueChanged<String> onBeginAttendedTransfer;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 700;

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Transfer target',
              hintText: '2003 or sip:bob@example.com',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () => onBlindTransfer(controller.text),
                child: const Text('Blind transfer'),
              ),
              OutlinedButton(
                onPressed: () => onBeginAttendedTransfer(controller.text),
                child: const Text('Attended transfer'),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Transfer target',
              hintText: '2003 or sip:bob@example.com',
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.tonal(
          onPressed: () => onBlindTransfer(controller.text),
          child: const Text('Blind transfer'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: () => onBeginAttendedTransfer(controller.text),
          child: const Text('Attended transfer'),
        ),
      ],
    );
  }
}
