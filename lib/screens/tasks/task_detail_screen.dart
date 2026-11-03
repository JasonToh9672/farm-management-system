import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../../services/hive_service.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';
import 'add_edit_task_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  TaskModel? _task;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _task = HiveService.getTask(widget.taskId));
  }

  @override
  Widget build(BuildContext context) {
    if (_task == null) {
      return const Scaffold(
          body: Center(child: Text('Task not found')));
    }
    final task = _task!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      task.priorityColor.withValues(alpha: 0.8),
                      AppColors.primary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding:
                    const EdgeInsets.fromLTRB(20, 80, 20, 16),
                child: Text(
                  task.title,
                  style: AppTextStyles.heading1
                      .copyWith(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.white),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AddEditTaskScreen(task: task)),
                  );
                  _load();
                },
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Badges
                Row(children: [
                  _Badge(
                      label: task.status,
                      color: task.statusColor,
                      icon: Icons.circle),
                  const SizedBox(width: 8),
                  _Badge(
                      label: '${task.priority} Priority',
                      color: task.priorityColor,
                      icon: Icons.flag),
                  if (task.isOverdue) ...[
                    const SizedBox(width: 8),
                    const _Badge(
                        label: 'OVERDUE',
                        color: AppColors.danger,
                        icon: Icons.warning_amber_rounded),
                  ],
                ]),
                const SizedBox(height: 20),

                // Description
                _InfoCard(
                  title: 'Description',
                  child: Text(
                    task.description.isEmpty
                        ? 'No description provided.'
                        : task.description,
                    style: AppTextStyles.body.copyWith(
                      color: task.description.isEmpty
                          ? AppColors.textGrey
                          : AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Details
                _InfoCard(
                  title: 'Task Details',
                  child: Column(children: [
                    _DetailRow(
                        icon: Icons.grass,
                        label: 'Crop Type',
                        value: task.cropType,
                        color: AppColors.primary),
                    _DetailRow(
                        icon: Icons.category_outlined,
                        label: 'Category',
                        value: task.category,
                        color: AppColors.accent),
                    _DetailRow(
                        icon: Icons.person_outline,
                        label: 'Assigned To',
                        value: task.assignedTo,
                        color: AppColors.pending),
                    _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Deadline',
                        value: DateFormat('EEEE, dd MMM yyyy')
                            .format(task.deadline),
                        color: task.isOverdue
                            ? AppColors.danger
                            : AppColors.primary),
                    _DetailRow(
                        icon: Icons.access_time_outlined,
                        label: 'Created',
                        value: DateFormat('dd MMM yyyy')
                            .format(task.createdAt),
                        color: AppColors.textGrey,
                        isLast: true),
                  ]),
                ),
                const SizedBox(height: 24),

                // Action buttons
                if (task.status != TaskStatus.done)
                  _ActionButton(
                    label: task.status == TaskStatus.pending
                        ? 'Start Task'
                        : 'Mark as Done',
                    icon: task.status == TaskStatus.pending
                        ? Icons.play_circle_outline
                        : Icons.check_circle_outline,
                    color: task.status == TaskStatus.pending
                        ? AppColors.warning
                        : AppColors.success,
                    onTap: () => _advance(task),
                  ),

                if (task.status == TaskStatus.done)
                  _ActionButton(
                    label: 'Reopen Task',
                    icon: Icons.refresh,
                    color: AppColors.pending,
                    onTap: () => _reopen(task),
                  ),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _advance(TaskModel task) async {
    final next = task.status == TaskStatus.pending
        ? TaskStatus.inProgress
        : TaskStatus.done;
    final updated = task.copyWith(status: next);
    await HiveService.updateTask(updated);
    if (FirebaseService.currentUserProfile != null ||
        HiveService.getCachedProfile() != null) {
      try {
        await FirebaseService.updateTask(updated);
      } catch (_) {/* offline, will sync later */}
    }
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(next == TaskStatus.done
            ? '✅ Task completed!'
            : '🔄 Task started!'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  void _reopen(TaskModel task) async {
    final updated = task.copyWith(status: TaskStatus.pending);
    await HiveService.updateTask(updated);
    if (FirebaseService.currentUserProfile != null ||
        HiveService.getCachedProfile() != null) {
      try {
        await FirebaseService.updateTask(updated);
      } catch (_) {/* offline, will sync later */}
    }
    _load();
  }
}

// ── Helpers ───────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _Badge(
      {required this.label,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: AppTextStyles.label
                .copyWith(color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _InfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    AppTextStyles.heading2.copyWith(fontSize: 14)),
            const SizedBox(height: 12),
            child,
          ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isLast;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.bodyGrey),
          const Spacer(),
          Text(value,
              style: AppTextStyles.body
                  .copyWith(fontWeight: FontWeight.w600)),
        ]),
      ),
      if (!isLast) const Divider(height: 1),
    ]);
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(double.infinity, 0),
      ),
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(label,
          style: AppTextStyles.body.copyWith(
              color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}
