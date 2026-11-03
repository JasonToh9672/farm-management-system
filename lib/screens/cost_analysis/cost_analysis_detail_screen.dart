import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/block_model.dart';
import '../../models/finance_entry_model.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';
import 'cost_analysis_list_screen.dart';
import 'add_expense_screen.dart';

class CostAnalysisDetailScreen extends StatefulWidget {
  final BlockModel block;

  const CostAnalysisDetailScreen({super.key, required this.block});

  @override
  State<CostAnalysisDetailScreen> createState() =>
      _CostAnalysisDetailScreenState();
}

class _CostAnalysisDetailScreenState extends State<CostAnalysisDetailScreen> {
  bool _loading = true;
  List<FinanceEntryModel> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    final allEntries = await FirebaseService.getFinanceEntries();
    if (mounted) {
      setState(() {
        _entries =
            allEntries.where((e) => e.blockId == widget.block.id).toList();
        _loading = false;
      });
    }
  }

  double get _totalExpenses => _entries
      .where((e) => e.isExpense)
      .fold(0.0, (sum, e) => sum + e.amount);
  double get _totalRevenue => _entries
      .where((e) => e.isRevenue)
      .fold(0.0, (sum, e) => sum + e.amount);
  double get _profitLoss => _totalRevenue - _totalExpenses;
  bool get _isProfitable => _profitLoss >= 0;

  Future<void> _addEntry() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AddExpenseScreen(initialBlock: widget.block)),
    );
    _loadEntries();
  }

  Future<void> _editEntry(FinanceEntryModel entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddExpenseScreen(entry: entry)),
    );
    _loadEntries();
  }

  void _confirmDelete(FinanceEntryModel entry) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Entry', style: AppTextStyles.heading2),
        content: Text('Delete "${entry.description}"?',
            style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseService.deleteFinanceEntry(entry.id);
              _loadEntries();
            },
            child: Text('Delete',
                style: AppTextStyles.body.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final profitColor = _isProfitable ? AppColors.success : AppColors.danger;

    final expenses = _entries.where((e) => e.isExpense).toList();
    final revenues = _entries.where((e) => e.isRevenue).toList();

    // Group expenses by category
    final Map<String, double> expenseByCategory = {};
    for (final e in expenses) {
      expenseByCategory[e.category] =
          (expenseByCategory[e.category] ?? 0) + e.amount;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEntries,
              child: CustomScrollView(
                slivers: [
                  // ── App Bar ──────────────────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 160,
                    pinned: true,
                    backgroundColor: AppColors.primary,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: _addEntry,
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1B5E20), AppColors.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.agriculture,
                                      color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(block.name,
                                          style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white)),
                                      Text(
                                          '${block.cropType} • ${block.location.isEmpty ? "—" : block.location}',
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.white70)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Profit/Loss Summary Card ─────────────────────
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _isProfitable
                                    ? [AppColors.success, AppColors.primaryLight]
                                    : [AppColors.danger, AppColors.warning],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: profitColor.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _isProfitable
                                      ? '✅ Profitable Crop'
                                      : '❌ Running at Loss',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, color: Colors.white70),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatMyr(_profitLoss),
                                  style: GoogleFonts.poppins(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                                Text(
                                  _isProfitable ? 'Net Profit' : 'Net Loss',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, color: Colors.white),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSummaryTile(
                                          'Revenue',
                                          formatMyr(_totalRevenue),
                                          Icons.arrow_upward),
                                    ),
                                    Container(
                                        width: 1,
                                        height: 40,
                                        color: Colors.white30),
                                    Expanded(
                                      child: _buildSummaryTile(
                                          'Expenses',
                                          formatMyr(_totalExpenses),
                                          Icons.arrow_downward),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Expense Breakdown by Category ────────────────
                          if (expenseByCategory.isNotEmpty) ...[
                            Text('Expense Breakdown',
                                style: AppTextStyles.heading2),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.cardBg,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2))
                                ],
                              ),
                              child: Column(
                                children: expenseByCategory.entries.map((e) {
                                  final percent = _totalExpenses > 0
                                      ? e.value / _totalExpenses
                                      : 0.0;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: _categoryColor(e.key),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(e.key,
                                                  style: AppTextStyles.body
                                                      .copyWith(fontSize: 13)),
                                            ),
                                            Text(formatMyr(e.value),
                                                style: AppTextStyles.body
                                                    .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 13)),
                                            const SizedBox(width: 8),
                                            Text(
                                                '${(percent * 100).toStringAsFixed(0)}%',
                                                style: AppTextStyles.label),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: percent.toDouble(),
                                            backgroundColor:
                                                Colors.grey.shade200,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    _categoryColor(e.key)),
                                            minHeight: 6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // ── Transaction History ───────────────────────────
                          Text('Transaction History',
                              style: AppTextStyles.heading2),
                          const SizedBox(height: 12),

                          if (_entries.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.receipt_long_outlined,
                                        size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text('No entries yet',
                                        style: AppTextStyles.body
                                            .copyWith(color: AppColors.textGrey)),
                                    const SizedBox(height: 4),
                                    Text('Tap + to log an expense or revenue',
                                        style: AppTextStyles.bodyGrey),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            // Revenue entries
                            if (revenues.isNotEmpty) ...[
                              _buildSectionLabel('Revenue', AppColors.success),
                              const SizedBox(height: 8),
                              ...revenues.map((e) => _buildEntryTile(e)),
                              const SizedBox(height: 16),
                            ],
                            // Expense entries
                            if (expenses.isNotEmpty) ...[
                              _buildSectionLabel('Expenses', AppColors.danger),
                              const SizedBox(height: 8),
                              ...expenses.map((e) => _buildEntryTile(e)),
                            ],
                          ],

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2))
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _addEntry,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          label: Text('Log New Entry',
              style: AppTextStyles.body.copyWith(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildSummaryTile(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _buildSectionLabel(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: AppTextStyles.body
                .copyWith(fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildEntryTile(FinanceEntryModel entry) {
    final color = entry.typeColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(entry.categoryIcon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.description,
                    style: AppTextStyles.body.copyWith(fontSize: 13)),
                Row(
                  children: [
                    Text(entry.category,
                        style: AppTextStyles.label.copyWith(color: color)),
                    const SizedBox(width: 8),
                    Text('• ${_formatDate(entry.date)}',
                        style: AppTextStyles.label),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${entry.isRevenue ? '+' : '-'} ${formatMyr(entry.amount)}',
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                color: AppColors.textGrey, size: 20),
            onSelected: (v) {
              if (v == 'edit') _editEntry(entry);
              if (v == 'delete') _confirmDelete(entry);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Fertilizer':
        return const Color(0xFF8BC34A);
      case 'Labour':
        return const Color(0xFF2196F3);
      case 'Pesticide':
        return const Color(0xFFFF5722);
      case 'Equipment':
        return const Color(0xFF9C27B0);
      case 'Irrigation':
        return const Color(0xFF00BCD4);
      default:
        return AppColors.accent;
    }
  }
}

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
