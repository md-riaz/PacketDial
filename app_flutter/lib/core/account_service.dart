import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account_schema.dart';
import '../models/call_history_schema.dart';
import '../providers/engine_provider.dart';
import 'package:uuid/uuid.dart';

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

  Future<AccountSchema?> getSelectedAccount() async {
    return isar!.accountSchemas.filter().isSelectedEqualTo(true).findFirst();
  }

  Future<void> setSelectedAccount(String uuid) async {
    await isar!.writeTxn(() async {
      // Unselect all
      final accounts = await isar!.accountSchemas.where().findAll();
      for (final a in accounts) {
        a.isSelected = false;
        await isar!.accountSchemas.put(a);
      }
      // Select the new one
      final selected =
          await isar!.accountSchemas.filter().uuidEqualTo(uuid).findFirst();
      if (selected != null) {
        selected.isSelected = true;
        await isar!.accountSchemas.put(selected);
      }
    });

    // Handle registration change immediately
    final accounts = await getAllAccounts();
    for (final a in accounts) {
      if (a.uuid == uuid) {
        register(a);
      } else {
        unregister(a.uuid);
      }
    }
  }

  Future<void> saveAccount(AccountSchema account) async {
    if (account.uuid.isEmpty) {
      account.uuid = const Uuid().v4();
    }
    await isar!.writeTxn(() async {
      final count = await isar!.accountSchemas.count();
      if (count == 0) {
        account.isSelected = true;
      } else if (account.isSelected == false && account.id == null) {
        // New account, but not the first, ensure isSelected is false
        account.isSelected = false;
      }
      await isar!.accountSchemas.put(account);
    });
  }

  Future<void> deleteAccount(String uuid) async {
    await isar!.writeTxn(() async {
      await isar!.accountSchemas.filter().uuidEqualTo(uuid).deleteAll();
    });
  }

  // Registration bridge
  void register(AccountSchema schema) {
    final engine = _ref.read(engineProvider);
    engine.register(
      schema.uuid,
      schema.username,
      schema.password,
      schema.server,
    );
  }

  void unregister(String uuid) {
    final engine = _ref.read(engineProvider);
    engine.unregister(uuid);
  }

  Future<void> autoRegisterAll() async {
    final selected = await getSelectedAccount();
    if (selected != null && selected.autoRegister) {
      register(selected);
    }
  }

  // History persistence
  Future<void> saveCallHistory(CallHistorySchema entry) async {
    await isar!.writeTxn(() async {
      await isar!.callHistorySchemas.put(entry);
    });
  }
}
