import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/bill.dart';
import '../models/ledger_entry.dart';
import 'sync_service.dart';

/// เปิดใช้งานเมื่อพร้อม:
///  1) flutterfire configure  (ได้ firebase_options.dart)
///  2) main() {
///       final sync = FirebaseSyncService(DefaultFirebaseOptions.currentPlatform);
///       runApp(BillandarApp(sync: sync));
///     }
class FirebaseSyncService implements SyncService {
  FirebaseSyncService(this._options);

  final FirebaseOptions _options;

  @override
  bool get isConfigured => true;

  DocumentReference<Map<String, dynamic>>? _userDoc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  @override
  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: _options);
    }
  }

  @override
  Future<void> signIn() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  @override
  Future<void> push({
    required List<Bill> bills,
    required List<LedgerEntry> entries,
    required Map<String, String> settings,
  }) async {
    final user = _userDoc();
    if (user == null) return;
    final batch = FirebaseFirestore.instance.batch();

    for (final bill in bills) {
      batch.set(user.collection('bills').doc(bill.id), bill.toMap(),
          SetOptions(merge: true));
    }
    for (final entry in entries) {
      batch.set(user.collection('ledger').doc(entry.id), entry.toMap(),
          SetOptions(merge: true));
    }
    settings.forEach((key, value) {
      batch.set(user.collection('settings').doc(key), {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    });
    await batch.commit();
  }

  @override
  Future<SyncSnapshot?> pull() async {
    final user = _userDoc();
    if (user == null) return null;

    final billDocs = await user.collection('bills').get();
    final entryDocs = await user.collection('ledger').get();
    final settingDocs = await user.collection('settings').get();

    return SyncSnapshot(
      bills: billDocs.docs
          .map((d) => Bill.fromMap(Map<String, dynamic>.from(d.data())))
          .toList(),
      entries: entryDocs.docs
          .map((d) =>
              LedgerEntry.fromMap(Map<String, dynamic>.from(d.data())))
          .toList(),
      settings: {
        for (final d in settingDocs.docs)
          d.data()['key'] as String: d.data()['value'] as String,
      },
    );
  }
}
