import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account_schema.dart';
import '../models/call_history_schema.dart';
import '../providers/engine_provider.dart';

final accountServiceProvider = Provider((ref) => AccountService(ref));

class AccountService {
  final Ref _ref;
  Isar? isar;

  AccountService(this._ref);

  Future<void> init(Isar isar) async {
    this.isar = isar;
  }

  Future<List<AccountSchema>> getAllAccounts() async {
    return isar!.accountSchemas.where().findAll();
  }

  Future<void> saveAccount(AccountSchema account) async {
    await isar!.writeTxn(() async {
      await isar!.accountSchemas.put(account);
    });
  }

  Future<void> deleteAccount(String accountId) async {
    await isar!.writeTxn(() async {
      await isar!.accountSchemas
          .filter()
          .accountIdEqualTo(accountId)
          .deleteAll();
    });
  }

  // Registration bridge
  void register(AccountSchema schema) {
    final engine = _ref.read(engineProvider);
    engine.register(
      schema.accountId,
      schema.username,
      schema.password,
      schema.server,
    );
  }

  void unregister(String accountId) {
    final engine = _ref.read(engineProvider);
    engine.unregister(accountId);
  }

  Future<void> autoRegisterAll() async {
    final accounts = await getAllAccounts();
    for (final a in accounts) {
      if (a.autoRegister) {
        register(a);
      }
    }
  }

  // History persistence
  Future<void> saveCallHistory(CallHistorySchema entry) async {
    await isar!.writeTxn(() async {
      await isar!.callHistorySchemas.put(entry);
    });
  }
}
