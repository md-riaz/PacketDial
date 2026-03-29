import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

class AccountTile extends StatelessWidget {
  const AccountTile({
    super.key,
    required this.account,
    required this.selected,
    required this.onTap,
    required this.onToggleRegistration,
  });

  final SipAccount account;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggleRegistration;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        selected: selected,
        title: Text(account.label),
        subtitle: Text(
          '${account.addressOfRecord} - ${account.transport.name.toUpperCase()} - ${account.registrationState.name}',
        ),
        trailing: FilledButton.tonal(
          onPressed: onToggleRegistration,
          child: Text(
            account.registrationState == RegistrationState.registered
                ? 'Unregister'
                : 'Register',
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
