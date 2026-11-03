import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';

class HiveService {
  static const String _taskBoxName = 'tasks';
  static const String _profileBoxName = 'profile';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(_taskBoxName);
    await Hive.openBox<Map>(_profileBoxName);
  }

  static Box<Map> get _box => Hive.box<Map>(_taskBoxName);
  static Box<Map> get _profileBox => Hive.box<Map>(_profileBoxName);

  // ── Tasks ────────────────────────────────────────────────────

  static Future<void> saveTask(TaskModel task) async {
    await _box.put(task.id, task.toMap());
  }

  static List<TaskModel> getAllTasks() {
    return _box.values
        .map((m) => TaskModel.fromMap(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
  }

  static TaskModel? getTask(String id) {
    final m = _box.get(id);
    if (m == null) return null;
    return TaskModel.fromMap(Map<String, dynamic>.from(m));
  }

  static Future<void> updateTask(TaskModel task) async {
    await _box.put(task.id, task.toMap());
  }

  static Future<void> deleteTask(String id) async {
    await _box.delete(id);
  }

  // Clears ALL tasks from local storage. Called on login/logout so that
  // a different user logging in on the same device never sees stale data.
  static Future<void> clearAllTasks() async {
    await _box.clear();
  }

  static List<TaskModel> getTasksByStatus(String status) =>
      getAllTasks().where((t) => t.status == status).toList();

  static List<TaskModel> getOverdueTasks() =>
      getAllTasks().where((t) => t.isOverdue).toList();

  static List<TaskModel> getTodayTasks() =>
      getAllTasks().where((t) => t.isDueToday).toList();

  // Worker view: only tasks assigned to a specific worker UID
  static List<TaskModel> getTasksAssignedTo(String workerId) =>
      getAllTasks().where((t) => t.assignedToId == workerId).toList();

  // ── User Profile cache (so role/farmId survive offline restarts) ──

  static Future<void> saveProfile(UserModel profile) async {
    await _profileBox.put('current', profile.toMap());
  }

  static UserModel? getCachedProfile() {
    final m = _profileBox.get('current');
    if (m == null) return null;
    return UserModel.fromMap(Map<String, dynamic>.from(m));
  }

  static Future<void> clearProfile() async {
    await _profileBox.delete('current');
  }

  static Future<void> seedDemoData() async {
    if (_box.isNotEmpty) return;
    final now = DateTime.now();
    final demos = [
      TaskModel(
        id: 'demo_1',
        title: 'Apply NPK Fertilizer',
        description: 'Apply NPK fertilizer to durian trees in Block A. Use 500g per tree.',
        category: 'Fertilizing',
        cropType: 'Durian',
        priority: 'High',
        status: 'Pending',
        deadline: now.add(const Duration(days: 1)),
        createdAt: now,
        assignedTo: 'Myself',
      ),
      TaskModel(
        id: 'demo_2',
        title: 'Pesticide Spraying',
        description: 'Spray insecticide on oil palm trees. Focus on new fronds.',
        category: 'Spraying',
        cropType: 'Oil Palm',
        priority: 'Medium',
        status: 'In Progress',
        deadline: now.add(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(days: 1)),
        assignedTo: 'Ahmad',
      ),
      TaskModel(
        id: 'demo_3',
        title: 'Prune Dead Fronds',
        description: 'Remove dead fronds from oil palm trees in Block B.',
        category: 'Pruning',
        cropType: 'Oil Palm',
        priority: 'Low',
        status: 'Pending',
        deadline: now.add(const Duration(days: 7)),
        createdAt: now,
        assignedTo: 'Myself',
      ),
      TaskModel(
        id: 'demo_4',
        title: 'Harvest Durian (Block C)',
        description: 'Collect ripe durian fruits from Block C.',
        category: 'Harvesting',
        cropType: 'Durian',
        priority: 'High',
        status: 'Done',
        deadline: now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 5)),
        assignedTo: 'Ali',
      ),
      TaskModel(
        id: 'demo_5',
        title: 'Weed Control - Block A',
        description: 'Manual weeding around durian tree bases.',
        category: 'Weeding',
        cropType: 'Durian',
        priority: 'Medium',
        status: 'Pending',
        deadline: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 3)),
        assignedTo: 'Myself',
      ),
    ];
    for (final task in demos) {
      await saveTask(task);
    }
  }
}
