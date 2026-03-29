import 'package:flutter/material.dart';

class CallKeypad extends StatelessWidget {
  const CallKeypad({super.key, required this.onSendDtmf});

  final ValueChanged<String> onSendDtmf;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final digit in const [
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9',
          '*',
          '0',
          '#',
        ])
          OutlinedButton(
            onPressed: () => onSendDtmf(digit),
            child: Text(digit),
          ),
      ],
    );
  }
}
