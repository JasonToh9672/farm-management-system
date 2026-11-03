import 'package:flutter/material.dart';
import '../utils/constants.dart';

class FinanceEntryModel {
  String id;
  String blockId; // links to a BlockModel (see models/block_model.dart)
  String blockName; // denormalized for easy display without an extra lookup
  String type; // EntryType.expense or EntryType.revenue
  String category;
  String description;
  double amount;
  DateTime date;
  String notes;
  DateTime createdAt;

  FinanceEntryModel({
    required this.id,
    required this.blockId,
    required this.blockName,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    this.notes = '',
    required this.createdAt,
  });

  bool get isExpense => type == EntryType.expense;
  bool get isRevenue => type == EntryType.revenue;

  Color get typeColor => isRevenue ? AppColors.success : AppColors.danger;

  IconData get categoryIcon {
    switch (category) {
      case 'Fertilizer':
        return Icons.grass;
      case 'Labour':
        return Icons.people;
      case 'Pesticide':
        return Icons.bug_report;
      case 'Equipment':
        return Icons.build;
      case 'Irrigation':
        return Icons.water_drop;
      case 'Transport':
        return Icons.local_shipping;
      case 'Harvest Sale':
        return Icons.sell;
      case 'By-product Sale':
        return Icons.recycling;
      case 'Subsidy':
        return Icons.account_balance;
      default:
        return Icons.receipt;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'blockId': blockId,
        'blockName': blockName,
        'type': type,
        'category': category,
        'description': description,
        'amount': amount,
        'date': date.toIso8601String(),
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FinanceEntryModel.fromMap(Map<String, dynamic> map) =>
      FinanceEntryModel(
        id: map['id'],
        blockId: map['blockId'],
        blockName: map['blockName'] ?? '',
        type: map['type'],
        category: map['category'],
        description: map['description'],
        amount: (map['amount'] as num).toDouble(),
        date: DateTime.parse(map['date']),
        notes: map['notes'] ?? '',
        createdAt: DateTime.parse(map['createdAt']),
      );

  FinanceEntryModel copyWith({
    String? blockId,
    String? blockName,
    String? type,
    String? category,
    String? description,
    double? amount,
    DateTime? date,
    String? notes,
  }) =>
      FinanceEntryModel(
        id: id,
        blockId: blockId ?? this.blockId,
        blockName: blockName ?? this.blockName,
        type: type ?? this.type,
        category: category ?? this.category,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}
