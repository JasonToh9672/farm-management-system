import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../services/hive_service.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';
import '../../widgets/task_card.dart';
import 'add_edit_task_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TaskModel> _allTasks = [];
  String _searchQuery = '';
  bool _syncing = false;

  final List<String> _tabs = [
    'All',
    'Pending',
    'In Progress',
    'Done',
    'Overdue'
  ];

  // Current logged-in profile (Owner/Worker), null if offline mode
  UserModel? get _profile =>
      FirebaseService.currentUserProfile ?? HiveService.getCachedProfile();
  bool get _isWorker => _profile?.isWorker ?? false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Reads from Hive (always available, offline-first) and applies the
  // Worker-only visibility filter on top when relevant.
  void _loadTasks() {
    final tasks = HiveService.getAllTasks();
    setState(() {
      _allTasks = _isWorker
          ? tasks.where((t) => t.assignedToId == _profile!.uid).toList()
          : tasks;
    });
  }

  // Pulls the latest tasks from Firestore into Hive, then reloads the view.
  // This is how a Worker sees newly assigned tasks from their Owner, and how
  // an Owner sees status updates a Worker made on another device.
  Future<void> _syncFromCloud() async {
    if (_profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Log in to sync tasks with your farm.'),
      ));
      return;
    }
    setState(() => _syncing = true);
    try {
      final cloudTasks = await FirebaseService.pullCloudTasks();
      for (final task in cloudTasks) {
        await HiveService.updateTask(task);
      }
      _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Synced ${cloudTasks.length} task(s) from your farm'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not sync — check your internet connection'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  List<TaskModel> _filtered(String tab) {
    List<TaskModel> base;
    switch (tab) {
      case 'Pending':
        base = _allTasks
            .where((t) => t.status == TaskStatus.pending)
            .toList();
        break;
      case 'In Progress':
        base = _allTasks
            .where((t) => t.status == TaskStatus.inProgress)
            .toList();
        break;
      case 'Done':
        base =
            _allTasks.where((t) => t.status == TaskStatus.done).toList();
        break;
      case 'Overdue':
        base = _allTasks.where((t) => t.isOverdue).toList();
        break;
      default:
        base = _allTasks;
    }
    if (_searchQuery.isNotEmpty) {
      base = base
          .where((t) =>
              t.title
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              t.cropType
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              t.category
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          _isWorker ? 'My Assigned Tasks' : 'All Tasks',
          style: AppTextStyles.heading2.copyWith(color: Colors.white),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined, color: Colors.white),
            tooltip: 'Sync with farm',
            onPressed: _syncing ? null : _syncFromCloud,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w700, color: Colors.white),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          // Worker hint banner explaining filtered view
          if (_isWorker)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Showing only tasks assigned to you. Pull to sync new assignments.',
                    style: AppTextStyles.label,
                  ),
                ),
              ]),
            ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                hintStyle: AppTextStyles.bodyGrey,
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textGrey),
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) {
                final tasks = _filtered(tab);
                if (tasks.isEmpty) return _buildEmpty(tab);
                return RefreshIndicator(
                  onRefresh: _syncFromCloud,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: tasks.length,
                    itemBuilder: (_, i) => TaskCard(
                      task: tasks[i],
                      onTap: () => _goToDetail(tasks[i]),
                      onMarkDone: tasks[i].status != TaskStatus.done
                          ? () => _markDone(tasks[i])
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'tasklist_fab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AddEditTaskScreen()),
          );
          _loadTasks();
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmpty(String tab) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 64,
                color: AppColors.textGrey.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              tab == 'All' ? 'No tasks yet' : 'No $tab tasks',
              style: AppTextStyles.heading2
                  .copyWith(color: AppColors.textGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isWorker
                  ? 'Tasks assigned to you by your farm owner will appear here'
                  : 'Tap + to create a new task',
              style: AppTextStyles.bodyGrey,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _markDone(TaskModel task) async {
    final updated = task.copyWith(status: TaskStatus.done);
    await HiveService.updateTask(updated);
    if (_profile != null) {
      try {
        await FirebaseService.updateTask(updated);
      } catch (_) {/* offline, will sync later */}
    }
    _loadTasks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ "${task.title}" marked as done!'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  void _goToDetail(TaskModel task) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TaskDetailScreen(taskId: task.id)));
    _loadTasks();
  }
}
