import '../repositories/account_repository.dart';
import '../repositories/contact_repository.dart';
import '../state/softphone_state.dart';

class SeedWorkspaceUseCase {
  const SeedWorkspaceUseCase({
    required AccountRepository accountRepository,
    required ContactRepository contactRepository,
  }) : _accountRepository = accountRepository,
       _contactRepository = contactRepository;

  final AccountRepository _accountRepository;
  final ContactRepository _contactRepository;

  SoftphoneState execute(SoftphoneState state) {
    final accounts = _accountRepository.ensureSeeded(state.accounts);
    final selectedAccountId =
        state.selectedAccountId ??
        (accounts.isEmpty ? null : accounts.first.id);
    final contacts = _contactRepository.ensureSeeded(state.contacts);
    return state.copyWith(
      accounts: accounts,
      contacts: contacts,
      selectedAccountId: selectedAccountId,
    );
  }
}
