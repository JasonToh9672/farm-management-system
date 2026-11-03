import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../utils/constants.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;
  final VoidCallback? onMarkDone;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.onMarkDone,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: task.isOverdue
                ? AppColors.danger.withValues(alpha: 0.4)
                : Colors.grey.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top colour bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: task.priorityColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: AppTextStyles.heading2.copyWith(
                            fontSize: 15,
                            decoration: task.status == TaskStatus.done
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.status == TaskStatus.done
                                ? AppColors.textGrey
                                : AppColors.textDark,
                          ),
                        ),
                      ),
                      _StatusBadge(
                          status: task.status, color: task.statusColor),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (task.description.isNotEmpty)
                    Text(
                      task.description,
                      style: AppTextStyles.bodyGrey,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 10),

                  // Tags
                  Row(
                    children: [
                      _Tag(
                          icon: Icons.grass,
                          label: task.cropType,
                          color: AppColors.primary),
                      const SizedBox(width: 6),
                      _Tag(
                          icon: Icons.category_outlined,
                          label: task.category,
                          color: AppColors.accent),
                      const SizedBox(width: 6),
                      _Tag(
                          icon: Icons.flag_outlined,
                          label: task.priority,
                          color: task.priorityColor),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Bottom row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            task.isOverdue
                                ? Icons.warning_amber_rounded
                                : Icons.calendar_today_outlined,
                            size: 14,
                            color: task.isOverdue
                                ? AppColors.danger
                                : AppColors.textGrey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.isOverdue
                                ? 'Overdue · ${DateFormat('dd MMM').format(task.deadline)}'
                                : task.isDueToday
                                    ? 'Due Today'
                                    : DateFormat('dd MMM yyyy')
                                        .format(task.deadline),
                            style: AppTextStyles.label.copyWith(
                              color: task.isOverdue
                                  ? AppColors.danger
                                  : task.isDueToday
                                      ? AppColors.warning
                                      : AppColors.textGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 14, color: AppColors.textGrey),
                          const SizedBox(width: 4),
                          Text(task.assignedTo, style: AppTextStyles.label),
                        ],
                      ),
                    ],
                  ),

                  // Mark done button
                  if (task.status != TaskStatus.done &&
                      onMarkDone != null) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onMarkDone,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 16, color: AppColors.success),
                          const SizedBox(width: 6),
                          Text(
                            'Mark as Done',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: AppTextStyles.label.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Tag({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style:
                  AppTextStyles.label.copyWith(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}
