import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/month_data.dart';
import '../models/expense_item.dart';
import '../models/external_saving.dart';
import '../models/note_item.dart';
import '../models/saving_goal.dart';

/// All Firestore reads/writes live here.
///
/// Structure:
///   users/{uid}                            -> { monthStartDay: int, setupDone: bool }
///   users/{uid}/months/{cycleId}           -> { periodStart, salary, savingGoal, items: [...] }
///   users/{uid}/external_savings/{itemId}  -> { id, title, amount, date }
///   users/{uid}/goals/{goalId}             -> named savings goals and progress
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _monthsCol(String uid) =>
      _userDoc(uid).collection('months');

  CollectionReference<Map<String, dynamic>> _externalSavingsCol(String uid) =>
      _userDoc(uid).collection('external_savings');

  CollectionReference<Map<String, dynamic>> _notesCol(String uid) =>
      _userDoc(uid).collection('notes');

  CollectionReference<Map<String, dynamic>> _goalsCol(String uid) =>
      _userDoc(uid).collection('goals');

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
    final monthRef = _monthsCol(uid).doc(monthId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(monthRef);
      final data = snapshot.data();
      if (data == null) return;
      final items = List<Map<String, dynamic>>.from(
        (data['items'] as List<dynamic>? ?? []).map((value) => Map<String, dynamic>.from(value as Map)),
      );
      items.removeWhere((value) => value['id'] == item.id);
      transaction.update(monthRef, {'items': items});
    });
  }

  Future<void> updateItem(String uid, String monthId, ExpenseItem item) async {
    final monthRef = _monthsCol(uid).doc(monthId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(monthRef);
      final data = snapshot.data();
      if (data == null) return;
      final items = List<Map<String, dynamic>>.from(
        (data['items'] as List<dynamic>? ?? []).map((value) => Map<String, dynamic>.from(value as Map)),
      );
      final index = items.indexWhere((value) => value['id'] == item.id);
      if (index < 0) return;
      items[index] = item.toMap();
      transaction.update(monthRef, {'items': items});
    });
  }

  // ---------- external (manually added) savings ----------

  Future<void> addExternalSaving(String uid, ExternalSaving item) async {
    await _externalSavingsCol(uid).doc(item.id).set(item.toMap());
  }

  Future<void> removeExternalSaving(String uid, String itemId) async {
    await _externalSavingsCol(uid).doc(itemId).delete();
  }

  Stream<List<ExternalSaving>> watchExternalSavings(String uid) {
    return _externalSavingsCol(uid).orderBy('date', descending: true).snapshots().map(
        (snap) => snap.docs.map((d) => ExternalSaving.fromMap(d.data())).toList());
  }

  Future<void> saveNote(String uid, NoteItem note) async {
    await _notesCol(uid).doc(note.id).set(note.toMap());
  }

  Future<void> removeNote(String uid, String noteId) async {
    await _notesCol(uid).doc(noteId).delete();
  }

  Stream<List<NoteItem>> watchNotes(String uid) {
    return _notesCol(uid).snapshots().map((snap) {
      final notes = snap.docs.map((doc) => NoteItem.fromMap(doc.data())).toList();
      notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return notes;
    });
  }

  // ---------- named saving goals ----------

  Stream<List<SavingGoal>> watchGoals(String uid) => _goalsCol(uid)
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => SavingGoal.fromMap(doc.data())).toList());

  Stream<double> watchTotalGoalWithdrawals(String uid) => _userDoc(uid).snapshots().map(
        (snapshot) => (snapshot.data()?['totalGoalWithdrawals'] as num?)?.toDouble() ?? 0,
      );

  Future<List<SavingGoal>> getAllGoals(String uid) async {
    final snap = await _goalsCol(uid).orderBy('createdAt').get();
    return snap.docs.map((doc) => SavingGoal.fromMap(doc.data())).toList();
  }

  Future<void> saveGoal(String uid, SavingGoal goal) async {
    await _goalsCol(uid).doc(goal.id).set(goal.toMap());
  }

  Future<void> removeGoal(String uid, String goalId) async {
    await _goalsCol(uid).doc(goalId).delete();
  }

  Future<double> addManualGoalContribution(String uid, String goalId, double amount) async {
    final goalRef = _goalsCol(uid).doc(goalId);
    final userRef = _userDoc(uid);
    return _db.runTransaction<double>((transaction) async {
      final snapshot = await transaction.get(goalRef);
      final userSnapshot = await transaction.get(userRef);
      final data = snapshot.data();
      if (data == null) return 0;
      final target = (data['targetAmount'] as num).toDouble();
      final saved = (data['savedAmount'] as num? ?? 0).toDouble();
      final credited = amount.clamp(0, (target - saved).clamp(0, target)).toDouble();
      if (credited > 0) {
        final priorAdjustments =
            (userSnapshot.data()?['totalGoalWithdrawals'] as num?)?.toDouble() ?? 0;
        transaction.update(goalRef, {'savedAmount': saved + credited});
        transaction.set(userRef, {
          'totalGoalWithdrawals': priorAdjustments + credited,
        }, SetOptions(merge: true));
      }
      return credited;
    });
  }

  Future<double> withdrawFromGoal(String uid, String goalId, double amount) async {
    final goalRef = _goalsCol(uid).doc(goalId);
    final userRef = _userDoc(uid);
    return _db.runTransaction<double>((transaction) async {
      final goalSnapshot = await transaction.get(goalRef);
      final userSnapshot = await transaction.get(userRef);
      final goalData = goalSnapshot.data();
      if (goalData == null) return 0;

      final saved = (goalData['savedAmount'] as num? ?? 0).toDouble();
      final requested = amount.clamp(0, saved).toDouble();
      if (requested <= 0) return 0;
      final priorWithdrawals =
          (userSnapshot.data()?['totalGoalWithdrawals'] as num?)?.toDouble() ?? 0;
      transaction.update(goalRef, {'savedAmount': saved - requested});
      transaction.set(userRef, {
        'totalGoalWithdrawals': priorWithdrawals + requested,
      }, SetOptions(merge: true));
      return requested;
    });
  }

  Future<double> applyCycleGoalContribution(
    String uid,
    String goalId,
    String cycleId,
    double cycleSavings,
  ) async {
    final goalRef = _goalsCol(uid).doc(goalId);
    final userRef = _userDoc(uid);
    return _db.runTransaction<double>((transaction) async {
      final snapshot = await transaction.get(goalRef);
      final userSnapshot = await transaction.get(userRef);
      final data = snapshot.data();
      if (data == null) return 0;
      final processed = List<String>.from(data['processedCycleIds'] as List<dynamic>? ?? const []);
      if (processed.contains(cycleId)) return 0;

      final target = (data['targetAmount'] as num).toDouble();
      final scheduled = (data['contributionPerCycle'] as num).toDouble();
      final saved = (data['savedAmount'] as num? ?? 0).toDouble();
      final remaining = (target - saved).clamp(0, target).toDouble();
      processed.add(cycleId);
      var credited = 0.0;
      if (scheduled > 0 && cycleSavings >= scheduled && remaining > 0) {
        credited = scheduled < remaining ? scheduled : remaining;
      }
      transaction.update(goalRef, {
        'savedAmount': saved + credited,
        'processedCycleIds': processed,
      });
      if (credited > 0) {
        final priorAdjustments =
            (userSnapshot.data()?['totalGoalWithdrawals'] as num?)?.toDouble() ?? 0;
        transaction.set(userRef, {
          'totalGoalWithdrawals': priorAdjustments + credited,
        }, SetOptions(merge: true));
      }
      return credited;
    });
  }
}
