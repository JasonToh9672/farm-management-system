import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../services/hive_service.dart';
import '../../services/firebase_service.dart';
import '../../services/notification_service.dart';
import '../../utils/constants.dart';
import '../../widgets/stats_card.dart';
import '../../widgets/task_card.dart';
import '../tasks/add_edit_task_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../auth/login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<TaskModel> _allTasks = [];
  bool _syncing = false;

  UserModel? get _profile =>
      FirebaseService.currentUserProfile ?? HiveService.getCachedProfile();
  bool get _isWorker => _profile?.isWorker ?? false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    final tasks = HiveService.getAllTasks();
    setState(() {
      _allTasks = _isWorker
          ? tasks.where((t) => t.assignedToId == _profile!.uid).toList()
          : tasks;
    });
    // Check overdue and notify
    NotificationService.checkAndNotifyOverdue(_allTasks);
  }

  Future<void> _syncFromCloud() async {
    if (_profile == null) return;
    setState(() => _syncing = true);
    try {
      final cloudTasks = await FirebaseService.pullCloudTasks();
      for (final task in cloudTasks) {
        await HiveService.updateTask(task);
      }
      _loadTasks();
    } catch (_) {
      // offline - silently ignore, Hive data is still shown
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  int get _totalTasks      => _allTasks.length;
  int get _pendingTasks    => _allTasks.where((t) => t.status == TaskStatus.pending).length;
  int get _inProgressTasks => _allTasks.where((t) => t.status == TaskStatus.inProgress).length;
  int get _doneTasks       => _allTasks.where((t) => t.status == TaskStatus.done).length;
  int get _overdueTasks    => _allTasks.where((t) => t.isOverdue).length;

  List<TaskModel> get _todayTasks    => _allTasks.where((t) => t.isDueToday).toList();
  List<TaskModel> get _upcomingTasks => _allTasks
      .where((t) => !t.isDueToday && !t.isOverdue && t.status != TaskStatus.done)
      .take(3)
      .toList();

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?.name.isNotEmpty == true ? _profile!.name : 'Farmer';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Good ${_greeting()}, $name! 🌾',
                      style: AppTextStyles.heading2
                          .copyWith(color: Colors.white, fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                          style: AppTextStyles.bodyGrey
                              .copyWith(color: Colors.white70),
                        ),
                        if (_isWorker) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Worker View',
                                style: AppTextStyles.label
                                    .copyWith(color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: _syncing
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.refresh, color: Colors.white),
                onPressed: _syncing
                    ? null
                    : () {
                        _loadTasks();
                        _syncFromCloud();
                      },
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Logout',
                onPressed: _confirmLogout,
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                if (_overdueTasks > 0) ...[
                  _OverdueBanner(count: _overdueTasks),
                  const SizedBox(height: 16),
                ],

                Text('Overview', style: AppTextStyles.heading2),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    StatsCard(
                      label: _isWorker ? 'My Tasks' : 'Total Tasks',
                      value: '$_totalTasks',
                      icon: Icons.task_alt,
                      color: AppColors.primary,
                    ),
                    StatsCard(
                      label: 'Pending',
                      value: '$_pendingTasks',
                      icon: Icons.pending_actions,
                      color: AppColors.pending,
                    ),
                    StatsCard(
                      label: 'In Progress',
                      value: '$_inProgressTasks',
                      icon: Icons.autorenew,
                      color: AppColors.warning,
                    ),
                    StatsCard(
                      label: 'Completed',
                      value: '$_doneTasks',
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _SectionHeader(
                  title: "Today's Tasks",
                  count: _todayTasks.length,
                  onSeeAll: _showTasksHint,
                ),
                const SizedBox(height: 12),
                if (_todayTasks.isEmpty)
                  const _EmptyState(message: 'No tasks due today 🎉')
                else
                  ..._todayTasks.map((task) => TaskCard(
                        task: task,
                        onTap: () => _goToDetail(task),
                        onMarkDone: () => _markDone(task),
                      )),
                const SizedBox(height: 24),

                _SectionHeader(
                  title: 'Upcoming Tasks',
                  count: _upcomingTasks.length,
                  onSeeAll: _showTasksHint,
                ),
                const SizedBox(height: 12),
                if (_upcomingTasks.isEmpty)
                  const _EmptyState(message: 'No upcoming tasks')
                else
                  ..._upcomingTasks.map((task) => TaskCard(
                        task: task,
                        onTap: () => _goToDetail(task),
                        onMarkDone: () => _markDone(task),
                      )),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'dashboard_fab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditTaskScreen()),
          );
          _loadTasks();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'New Task',
          style: AppTextStyles.body.copyWith(color: Colors.white),
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
    await NotificationService.cancelNotification(task.id.hashCode);
    _loadTasks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ "${task.title}" marked as done!'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  void _showTasksHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap the Tasks tab at the bottom to see all tasks'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _goToDetail(TaskModel task) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TaskDetailScreen(taskId: task.id)));
    _loadTasks();
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Logout', style: AppTextStyles.heading2),
        content: Text(
          'Are you sure you want to logout?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseService.signOut();
              await HiveService.clearProfile();
              await HiveService.clearAllTasks();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text('Logout',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

// ── Local widgets ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onSeeAll;
  const _SectionHeader(
      {required this.title, required this.count, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Text(title, style: AppTextStyles.heading2),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count',
                style: AppTextStyles.label
                    .copyWith(color: AppColors.primary)),
          ),
        ]),
        TextButton(
          onPressed: onSeeAll,
          child: Text('See All',
              style: AppTextStyles.label.copyWith(color: AppColors.primary)),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
          child: Text(message, style: AppTextStyles.bodyGrey)),
    );
  }
}

class _OverdueBanner extends StatelessWidget {
  final int count;
  const _OverdueBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'You have $count overdue task${count > 1 ? 's' : ''}! Please attend to them.',
            style: AppTextStyles.body.copyWith(color: AppColors.danger),
          ),
        ),
      ]),
    );
  }
}
