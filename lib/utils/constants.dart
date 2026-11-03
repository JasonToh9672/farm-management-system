import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary      = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color accent       = Color(0xFFFFA000);
  static const Color background   = Color(0xFFF5F5F5);
  static const Color cardBg       = Color(0xFFFFFFFF);
  static const Color textDark     = Color(0xFF1B1B1B);
  static const Color textGrey     = Color(0xFF757575);
  static const Color success      = Color(0xFF43A047);
  static const Color warning      = Color(0xFFFB8C00);
  static const Color danger       = Color(0xFFE53935);
  static const Color pending      = Color(0xFF1E88E5);
}

class Priority {
  static const String high   = 'High';
  static const String medium = 'Medium';
  static const String low    = 'Low';
}

class TaskStatus {
  static const String pending    = 'Pending';
  static const String inProgress = 'In Progress';
  static const String done       = 'Done';
}

class MilestoneStatus {
  static const String upcoming  = 'Upcoming';
  static const String overdue   = 'Overdue';
  static const String completed = 'Completed';
}

class CropType {
  static const List<String> list = [
    'Durian',
    'Oil Palm',
    'Cocoa',
    'Rubber',
    'Other',
  ];
}

class TaskCategory {
  static const List<String> list = [
    'Fertilizing',
    'Spraying',
    'Pruning',
    'Harvesting',
    'Weeding',
    'Irrigation',
    'Inspection',
    'Other',
  ];
}

class EntryType {
  static const String expense = 'Expense';
  static const String revenue = 'Revenue';
}

class ExpenseCategory {
  static const List<String> list = [
    'Fertilizer',
    'Labour',
    'Pesticide',
    'Equipment',
    'Irrigation',
    'Transport',
    'Other',
  ];
}

class RevenueCategory {
  static const List<String> list = [
    'Harvest Sale',
    'By-product Sale',
    'Subsidy',
    'Other',
  ];
}

class AppTextStyles {
  static TextStyle heading1 = GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  static TextStyle heading2 = GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  static TextStyle body = GoogleFonts.poppins(
    fontSize: 14,
    color: AppColors.textDark,
  );

  static TextStyle bodyGrey = GoogleFonts.poppins(
    fontSize: 13,
    color: AppColors.textGrey,
  );

  static TextStyle label = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textGrey,
  );
}
