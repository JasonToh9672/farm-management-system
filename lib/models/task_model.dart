import 'package:flutter/material.dart';
import '../utils/constants.dart';

class TaskModel {
  String id;
  String title;
  String description;
  String category;
  String cropType;
  String priority;
  String status;
  DateTime deadline;
  DateTime createdAt;
  String assignedTo; // worker display name (kept for easy display)
  String assignedToId; // worker UID (empty string if unassigned / "Myself")
  String templateId; // links to a TaskTemplateModel, empty if custom one-off task

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.cropType,
    required this.priority,
    required this.status,
    required this.deadline,
    required this.createdAt,
    required this.assignedTo,
    this.assignedToId = '',
    this.templateId = '',
  });

  bool get isOverdue =>
      deadline.isBefore(DateTime.now()) && status != TaskStatus.done;

  bool get isDueToday {
    final now = DateTime.now();
    return deadline.year == now.year &&
        deadline.month == now.month &&
        deadline.day == now.day;
  }

  Color get priorityColor {
    switch (priority) {
      case Priority.high:
        return AppColors.danger;
      case Priority.medium:
        return AppColors.warning;
      case Priority.low:
        return AppColors.success;
      default:
        return AppColors.textGrey;
    }
  }

  Color get statusColor {
    switch (status) {
      case TaskStatus.done:
        return AppColors.success;
      case TaskStatus.inProgress:
        return AppColors.warning;
      case TaskStatus.pending:
        return AppColors.pending;
      default:
        return AppColors.textGrey;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'cropType': cropType,
        'priority': priority,
        'status': status,
        'deadline': deadline.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'assignedTo': assignedTo,
        'assignedToId': assignedToId,
        'templateId': templateId,
      };

  factory TaskModel.fromMap(Map<String, dynamic> map) => TaskModel(
        id: map['id'],
        title: map['title'],
        description: map['description'],
        category: map['category'],
        cropType: map['cropType'],
        priority: map['priority'],
        status: map['status'],
        deadline: DateTime.parse(map['deadline']),
        createdAt: DateTime.parse(map['createdAt']),
        assignedTo: map['assignedTo'],
        // Defaults below make this safe for tasks saved before this update (FYP1 data)
        assignedToId: map['assignedToId'] ?? '',
        templateId: map['templateId'] ?? '',
      );

  TaskModel copyWith({
    String? title,
    String? description,
    String? category,
    String? cropType,
    String? priority,
    String? status,
    DateTime? deadline,
    String? assignedTo,
    String? assignedToId,
    String? templateId,
  }) =>
      TaskModel(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        cropType: cropType ?? this.cropType,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        deadline: deadline ?? this.deadline,
        createdAt: createdAt,
        assignedTo: assignedTo ?? this.assignedTo,
        assignedToId: assignedToId ?? this.assignedToId,
        templateId: templateId ?? this.templateId,
      );
}
