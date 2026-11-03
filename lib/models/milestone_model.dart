import 'package:flutter/material.dart';
import '../utils/constants.dart';

class MilestoneModel {
  String id;
  String name; // e.g. "Flowering", "Fruiting", "Harvesting"
  DateTime expectedDate;
  String status; // MilestoneStatus.upcoming / overdue / completed (see constants.dart)
  DateTime? completedDate;
  String notes;

  MilestoneModel({
    required this.id,
    required this.name,
    required this.expectedDate,
    this.status = MilestoneStatus.upcoming,
    this.completedDate,
    this.notes = '',
  });

  // The stored `status` only becomes 'Overdue' once someone reopens/saves it.
  // displayStatus recomputes it live from the date so the UI is always
  // correct without needing a background job to flip statuses at midnight.
  String get displayStatus {
    if (status == MilestoneStatus.completed) return MilestoneStatus.completed;
    if (expectedDate.isBefore(DateTime.now())) return MilestoneStatus.overdue;
    return MilestoneStatus.upcoming;
  }

  bool get isCompleted => status == MilestoneStatus.completed;
  bool get isOverdue => displayStatus == MilestoneStatus.overdue;

  Color get statusColor {
    switch (displayStatus) {
      case MilestoneStatus.completed:
        return AppColors.success;
      case MilestoneStatus.overdue:
        return AppColors.danger;
      default:
        return AppColors.pending;
    }
  }

  IconData get statusIcon {
    switch (displayStatus) {
      case MilestoneStatus.completed:
        return Icons.check_circle;
      case MilestoneStatus.overdue:
        return Icons.error;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'expectedDate': expectedDate.toIso8601String(),
        'status': status,
        'completedDate': completedDate?.toIso8601String(),
        'notes': notes,
      };

  factory MilestoneModel.fromMap(Map<String, dynamic> map) => MilestoneModel(
        id: map['id'],
        name: map['name'],
        expectedDate: DateTime.parse(map['expectedDate']),
        status: map['status'] ?? MilestoneStatus.upcoming,
        completedDate: map['completedDate'] != null
            ? DateTime.parse(map['completedDate'])
            : null,
        notes: map['notes'] ?? '',
      );

  MilestoneModel copyWith({
    String? name,
    DateTime? expectedDate,
    String? status,
    DateTime? completedDate,
    bool clearCompletedDate = false,
    String? notes,
  }) =>
      MilestoneModel(
        id: id,
        name: name ?? this.name,
        expectedDate: expectedDate ?? this.expectedDate,
        status: status ?? this.status,
        completedDate: clearCompletedDate
            ? null
            : (completedDate ?? this.completedDate),
        notes: notes ?? this.notes,
      );
}
