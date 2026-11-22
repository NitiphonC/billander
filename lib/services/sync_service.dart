import '../models/bill.dart';
import '../models/ledger_entry.dart';

class SyncSnapshot {
  final List<Bill> bills;
  final List<LedgerEntry> entries;
  final Map<String, String> settings;

  const SyncSnapshot({
    required this.bills,
    required this.entries,
    required this.settings,
  });
}

abstract class SyncService {
  bool get isConfigured;
  Future<void> initialize();
  Future<void> signIn();
  Future<void> push({
    required List<Bill> bills,
    required List<LedgerEntry> entries,
    required Map<String, String> settings,
  });
  Future<SyncSnapshot?> pull();
}

/// ค่าเริ่มต้น: เก็บในเครื่องก่อน ยังไม่ต่อ Firebase
class NoopSyncService implements SyncService {
  @override
  bool get isConfigured => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> signIn() async {}

  @override
  Future<void> push({
    required List<Bill> bills,
    required List<LedgerEntry> entries,
    required Map<String, String> settings,
  }) async {}

  @override
  Future<SyncSnapshot?> pull() async => null;
}
