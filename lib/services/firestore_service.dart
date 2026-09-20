import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/month_data.dart';
import '../models/expense_item.dart';

/// All Firestore reads/writes live here.
///
/// Structure:
///   users/{uid}                       -> { monthStartDay: int, setupDone: bool }
///   users/{uid}/months/{cycleId}      -> { periodStart, salary, savingGoal, items: [...] }
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _monthsCol(String uid) =>
      _userDoc(uid).collection('months');

  // ---------- user settings ----------

  Future<void> saveUserSettings(String uid, {required int monthStartDay}) async {
    await _userDoc(uid).set({
      'monthStartDay': monthStartDay,
      'setupDone': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserSettings(String uid) async {
    final snap = await _userDoc(uid).get();
    return snap.data();
  }

  // ---------- months ----------

  Future<void> upsertMonth(String uid, MonthData month) async {
    await _monthsCol(uid).doc(month.id).set(month.toMap());
  }

  Future<MonthData?> getMonth(String uid, String monthId) async {
    final snap = await _monthsCol(uid).doc(monthId).get();
    if (!snap.exists || snap.data() == null) return null;
    return MonthData.fromMap(snap.data()!);
  }

  Stream<MonthData?> watchMonth(String uid, String monthId) {
    return _monthsCol(uid).doc(monthId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return MonthData.fromMap(snap.data()!);
    });
  }

  /// All previous months, newest first.
  Stream<List<MonthData>> watchAllMonths(String uid) {
    return _monthsCol(uid)
        .orderBy('periodStart', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MonthData.fromMap(d.data())).toList());
  }

  Future<List<MonthData>> getAllMonths(String uid) async {
    final snap = await _monthsCol(uid).orderBy('periodStart', descending: true).get();
    return snap.docs.map((d) => MonthData.fromMap(d.data())).toList();
  }

  Future<void> addItem(String uid, String monthId, ExpenseItem item) async {
    await _monthsCol(uid).doc(monthId).update({
      'items': FieldValue.arrayUnion([item.toMap()]),
    });
  }

  Future<void> removeItem(String uid, String monthId, ExpenseItem item) async {
    await _monthsCol(uid).doc(monthId).update({
      'items': FieldValue.arrayRemove([item.toMap()]),
    });
  }
}
