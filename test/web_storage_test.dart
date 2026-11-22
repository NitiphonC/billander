import 'package:billandar/data/storage.dart';
import 'package:billandar/models/bill.dart';
import 'package:billandar/models/ledger_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('WebStorage: บิล CRUD ผ่าน SharedPreferences', () async {
    final storage = WebStorage();
    await storage.init();
    expect(await storage.getBills(), isEmpty);

    final bill = Bill(
      id: 'b1',
      title: 'Rent',
      amountSatang: 10000,
      dueDate: DateTime(2026, 11, 22),
      createdAtMs: 1,
      updatedAtMs: 1,
    );
    await storage.upsertBill(bill);

    final bills = await storage.getBills();
    expect(bills.length, 1);
    expect(bills.single.id, 'b1');
    expect(bills.single.amountSatang, 10000);
    expect(bills.single.dueDate, DateTime(2026, 11, 22));

    await storage.deleteBills(['b1']);
    expect(await storage.getBills(), isEmpty);
  });

  test('WebStorage: ledger + settings', () async {
    final storage = WebStorage();
    await storage.init();

    await storage.upsertEntry(LedgerEntry(
      id: 'e1',
      type: LedgerType.deposit,
      amountSatang: 5000,
      date: DateTime(2026, 11, 22),
      createdAtMs: 2,
      updatedAtMs: 2,
    ));
    final entries = await storage.getEntries();
    expect(entries.single.amountSatang, 5000);
    expect(entries.single.type, LedgerType.deposit);

    await storage.setSetting('k', 'v');
    expect((await storage.getAllSettings())['k'], 'v');

    await storage.deleteEntry('e1');
    expect(await storage.getEntries(), isEmpty);
  });
}
