import 'dart:math';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import '../models/worker_model.dart';
import '../models/task_template_model.dart';
import '../models/block_model.dart';
import '../models/tree_model.dart';
import '../models/milestone_model.dart';
import '../models/finance_entry_model.dart';
import '../models/fruit_count_model.dart';

class FirebaseService {
  static final _auth = FirebaseAuth.instance;
  static final _db   = FirebaseFirestore.instance;

  // ── Auth ─────────────────────────────────────────────────────

  static User? get currentUser => _auth.currentUser;
  static String? get userId    => _auth.currentUser?.uid;
  static bool get isLoggedIn   => _auth.currentUser != null;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Cached after login/register/app-start so we don't re-fetch on every screen
  static UserModel? currentUserProfile;

  static Future<UserCredential?> _createAccount(
      String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _authError(e.code);
    }
  }

  /// Registers a new OWNER account. Generates a unique, human-shareable farm code.
  static Future<UserModel> registerOwner({
    required String email,
    required String password,
    required String name,
  }) async {
    final cred = await _createAccount(email, password);
    final uid = cred!.user!.uid;
    final farmId = _generateFarmCode();

    final profile = UserModel(
      uid: uid,
      email: email,
      name: name,
      role: UserRole.owner,
      farmId: farmId,
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(uid).set(profile.toMap());
    // Owner record also stored inside the farm doc for easy lookup
    await _db.collection('farms').doc(farmId).set({
      'ownerId': uid,
      'ownerName': name,
      'createdAt': DateTime.now().toIso8601String(),
    });
    currentUserProfile = profile;
    return profile;
  }

  /// Registers a new WORKER account and joins them to an existing farm via farmCode.
  /// Throws if the farm code does not exist.
  static Future<UserModel> registerWorker({
    required String email,
    required String password,
    required String name,
    required String farmCode,
  }) async {
    // IMPORTANT: the Auth account must be created FIRST. Our Firestore rules
    // require request.auth != null to even read the farms collection, so
    // checking the farm code before signing in would always be denied.
    final cred = await _createAccount(email, password);
    final uid = cred!.user!.uid;

    final farmDoc = await _db.collection('farms').doc(farmCode).get();
    if (!farmDoc.exists) {
      // Roll back the just-created auth account so the user isn't left with
      // a dangling login that has no profile or farm.
      await cred.user!.delete();
      throw 'Farm code not found. Please check the code with your farm owner.';
    }

    final profile = UserModel(
      uid: uid,
      email: email,
      name: name,
      role: UserRole.worker,
      farmId: farmCode,
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(uid).set(profile.toMap());

    // Add this worker into the owner's worker directory
    final worker = WorkerModel(
      id: uid,
      name: name,
      email: email,
      joinedAt: DateTime.now(),
    );
    await _db
        .collection('farms')
        .doc(farmCode)
        .collection('workers')
        .doc(uid)
        .set(worker.toMap());

    currentUserProfile = profile;
    return profile;
  }

  static Future<UserModel?> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final profile = await fetchUserProfile(cred.user!.uid);
      currentUserProfile = profile;
      return profile;
    } on FirebaseAuthException catch (e) {
      throw _authError(e.code);
    }
  }

  static Future<UserModel?> fetchUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  static Future<void> signOut() async {
    currentUserProfile = null;
    await _auth.signOut();
  }

  static String _generateFarmCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0/I/1 to avoid confusion
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static String _authError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  // ── Firestore Tasks (now scoped to FARM, not individual user) ──
  // This is the key change: tasks live under farms/{farmId}/tasks so
  // both the owner and all their workers read/write the same task list.

  static String? get _farmId => currentUserProfile?.farmId;

  static CollectionReference<Map<String, dynamic>>? _tasksRef() {
    if (_farmId == null) return null;
    return _db.collection('farms').doc(_farmId).collection('tasks');
  }

  static Future<void> saveTask(TaskModel task) async {
    final ref = _tasksRef();
    if (ref == null) return;
    await ref.doc(task.id).set(task.toMap());
  }

  static Future<void> updateTask(TaskModel task) async {
    await saveTask(task);
  }

  static Future<void> deleteTask(String id) async {
    final ref = _tasksRef();
    if (ref == null) return;
    await ref.doc(id).delete();
  }

  static Future<List<TaskModel>> getAllTasks() async {
    final ref = _tasksRef();
    if (ref == null) return [];
    final snapshot = await ref.get();
    return snapshot.docs
        .map((doc) => TaskModel.fromMap(doc.data()))
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
  }

  // ── Sync: Hive → Firestore ────────────────────────────────────
  static Future<void> syncLocalToCloud(List<TaskModel> localTasks) async {
    if (_farmId == null) return;
    for (final task in localTasks) {
      await saveTask(task);
    }
  }

  // ── Sync: Firestore → Hive (pull) ───────────────────────────────
  // Call this after login (and pull-to-refresh) so a Worker's device picks up
  // tasks the Owner assigned to them from Firestore into local Hive storage.
  static Future<List<TaskModel>> pullCloudTasks() async {
    return getAllTasks();
  }

  // ── Workers Directory (Owner only) ──────────────────────────────

  static CollectionReference<Map<String, dynamic>>? _workersRef() {
    if (_farmId == null) return null;
    return _db.collection('farms').doc(_farmId).collection('workers');
  }

  static Future<List<WorkerModel>> getWorkers() async {
    final ref = _workersRef();
    if (ref == null) return [];
    final snapshot = await ref.get();
    return snapshot.docs
        .map((doc) => WorkerModel.fromMap(doc.data()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  // ── Standard Task Templates ─────────────────────────────────────

  static CollectionReference<Map<String, dynamic>>? _templatesRef() {
    if (_farmId == null) return null;
    return _db.collection('farms').doc(_farmId).collection('taskTemplates');
  }

  static Future<void> saveTemplate(TaskTemplateModel template) async {
    final ref = _templatesRef();
    if (ref == null) return;
    await ref.doc(template.id).set(template.toMap());
  }

  static Future<void> deleteTemplate(String id) async {
    final ref = _templatesRef();
    if (ref == null) return;
    await ref.doc(id).delete();
  }

  static Future<List<TaskTemplateModel>> getTemplates() async {
    final ref = _templatesRef();
    if (ref == null) return [];
    final snapshot = await ref.get();
    return snapshot.docs
        .map((doc) => TaskTemplateModel.fromMap(doc.data()))
        .toList();
  }

  // ── Milestone Module: Blocks → Trees → Milestones ───────────────
  // farms/{farmId}/blocks/{blockId}/trees/{treeId}/milestones/{milestoneId}
  // Same farm-scoped access pattern as tasks/workers/taskTemplates above.

  static CollectionReference<Map<String, dynamic>>? _blocksRef() {
    if (_farmId == null) return null;
    return _db.collection('farms').doc(_farmId).collection('blocks');
  }

  static CollectionReference<Map<String, dynamic>>? _treesRef(
      String blockId) {
    final blocks = _blocksRef();
    if (blocks == null) return null;
    return blocks.doc(blockId).collection('trees');
  }

  static CollectionReference<Map<String, dynamic>>? _milestonesRef(
      String blockId, String treeId) {
    final trees = _treesRef(blockId);
    if (trees == null) return null;
    return trees.doc(treeId).collection('milestones');
  }

  // ── Blocks ───────────────────────────────────────────────────────

  static Future<List<BlockModel>> getBlocks() async {
    final ref = _blocksRef();
    if (ref == null) return [];
    final snapshot = await ref.get();
    return snapshot.docs
        .map((doc) => BlockModel.fromMap(doc.data()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  static Future<void> saveBlock(BlockModel block) async {
    final ref = _blocksRef();
    if (ref == null) return;
    await ref.doc(block.id).set(block.toMap());
  }

  // Deletes the block along with all of its trees and their milestones,
  // since Firestore does not cascade-delete subcollections automatically.
  static Future<void> deleteBlock(String blockId) async {
    final blocksRef = _blocksRef();
    if (blocksRef == null) return;
    final treesRef = _treesRef(blockId);
    if (treesRef != null) {
      final treeDocs = await treesRef.get();
      for (final treeDoc in treeDocs.docs) {
        await deleteTree(blockId, treeDoc.id);
      }
    }
    await blocksRef.doc(blockId).delete();
  }

  // ── Trees ────────────────────────────────────────────────────────

  static Future<List<TreeModel>> getTrees(String blockId) async {
    final ref = _treesRef(blockId);
    if (ref == null) return [];
    final snapshot = await ref.get();
    return snapshot.docs
        .map((doc) => TreeModel.fromMap(doc.data()))
        .toList()
      ..sort((a, b) => a.treeCode.compareTo(b.treeCode));
  }

  static Future<void> saveTree(String blockId, TreeModel tree) async {
    final ref = _treesRef(blockId);
    if (ref == null) return;
    await ref.doc(tree.id).set(tree.toMap());
  }

  // Deletes the tree along with all of its milestones.
  static Future<void> deleteTree(String blockId, String treeId) async {
    final treesRef = _treesRef(blockId);
    if (treesRef == null) return;
    final milestonesRef = _milestonesRef(blockId, treeId);
    if (milestonesRef != null) {
      final milestoneDocs = await milestonesRef.get();
      for (final milestoneDoc in milestoneDocs.docs) {
        await milestoneDoc.reference.delete();
      }
    }
    await treesRef.doc(treeId).delete();
  }

  // ── Milestones ───────────────────────────────────────────────────

  static Future<List<MilestoneModel>> getMilestones(
      String blockId, String treeId) async {
    final ref = _milestonesRef(blockId, treeId);
    if (ref == null) return [];
    final snapshot = await ref.get();
    return snapshot.docs
        .map((doc) => MilestoneModel.fromMap(doc.data()))
        .toList()
      ..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));
  }

  static Future<void> saveMilestone(
      String blockId, String treeId, MilestoneModel milestone) async {
    final ref = _milestonesRef(blockId, treeId);
    if (ref == null) return;
    await ref.doc(milestone.id).set(milestone.toMap());
  }

  static Future<void> deleteMilestone(
      String blockId, String treeId, String milestoneId) async {
    final ref = _milestonesRef(blockId, treeId);
    if (ref == null) return;
    await ref.doc(milestoneId).delete();
  }

  // ── Cost Analysis: Finance Entries ──────────────────────────────
  // farms/{farmId}/financeEntries/{entryId} — a flat, farm-scoped collection
  // (like tasks/workers/taskTemplates) rather than nested under blocks, so the
  // farm-wide profit/loss totals can be read with a single query. Each entry
  // carries a blockId to link it back to a BlockModel from the Milestone module.

  static CollectionReference<Map<String, dynamic>>? _financeEntriesRef() {
    if (_farmId == null) return null;
    return _db.collection('farms').doc(_farmId).collection('financeEntries');
  }

  static Future<List<FinanceEntryModel>> getFinanceEntries() async {
    final ref = _financeEntriesRef();
    if (ref == null) return [];
    final snapshot = await ref.get();
    return snapshot.docs
        .map((doc) => FinanceEntryModel.fromMap(doc.data()))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<void> saveFinanceEntry(FinanceEntryModel entry) async {
    final ref = _financeEntriesRef();
    if (ref == null) return;
    await ref.doc(entry.id).set(entry.toMap());
  }

  static Future<void> deleteFinanceEntry(String id) async {
    final ref = _financeEntriesRef();
    if (ref == null) return;
    await ref.doc(id).delete();
  }

  // ── Fruit Counting (on-device YOLO) ─────────────────────────────
  // farms/{farmId}/blocks/{blockId}/trees/{treeId}/fruitCounts/{countId}
  // Same nested pattern as milestones — a fruit count belongs to one tree.

  static CollectionReference<Map<String, dynamic>>? _fruitCountsRef(
      String blockId, String treeId) {
    final trees = _treesRef(blockId);
    if (trees == null) return null;
    return trees.doc(treeId).collection('fruitCounts');
  }

  static Future<List<FruitCountModel>> getFruitCounts(
      String blockId, String treeId) async {
    final ref = _fruitCountsRef(blockId, treeId);
    if (ref == null) return [];
    final snapshot = await ref.get();
    return snapshot.docs
        .map((doc) => FruitCountModel.fromMap(doc.data()))
        .toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
  }

  static Future<void> saveFruitCount(
      String blockId, String treeId, FruitCountModel entry) async {
    final ref = _fruitCountsRef(blockId, treeId);
    if (ref == null) return;
    await ref.doc(entry.id).set(entry.toMap());
  }

  static Future<void> deleteFruitCount(
      String blockId, String treeId, String id) async {
    final ref = _fruitCountsRef(blockId, treeId);
    if (ref == null) return;
    await ref.doc(id).delete();
  }

  // Uploads a fruit-count photo to Firebase Storage and returns its download
  // URL. Requires the firebase_storage package and a Storage bucket enabled
  // in the Firebase console (see PROJECT_SUMMARY notes) — this is separate
  // from Firestore and needs its own one-time setup step.
  static Future<String?> uploadFruitPhoto(
      File imageFile, String treeId) async {
    if (_farmId == null) return null;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${imageFile.uri.pathSegments.last}';
    final ref = FirebaseStorage.instance
        .ref()
        .child('farms/$_farmId/fruit_photos/$treeId/$fileName');
    final task = await ref.putFile(imageFile);
    return task.ref.getDownloadURL();
  }
}
