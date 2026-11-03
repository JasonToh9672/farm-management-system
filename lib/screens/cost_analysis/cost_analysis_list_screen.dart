import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/block_model.dart';
import '../../models/finance_entry_model.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';
import 'cost_analysis_detail_screen.dart';
import 'add_expense_screen.dart';

// Aggregated view-model: a block plus the finance entries logged against it.
class BlockFinancial {
  final BlockModel block;
  final List<FinanceEntryModel> entries;

  const BlockFinancial({required this.block, required this.entries});

  double get totalExpenses => entries
      .where((e) => e.isExpense)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get totalRevenue => entries
      .where((e) => e.isRevenue)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get profitLoss => totalRevenue - totalExpenses;

  bool get isProfitable => profitLoss >= 0;
}

String formatMyr(double amount) =>
    'RM ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

class CostAnalysisListScreen extends StatefulWidget {
  const CostAnalysisListScreen({super.key});

  @override
  State<CostAnalysisListScreen> createState() =>
      _CostAnalysisListScreenState();
}

class _CostAnalysisListScreenState extends State<CostAnalysisListScreen> {
  bool _loading = true;
  List<BlockFinancial> _financials = [];
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Profitable', 'Loss'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      FirebaseService.getBlocks(),
      FirebaseService.getFinanceEntries(),
    ]);
    final blocks = results[0] as List<BlockModel>;
    final entries = results[1] as List<FinanceEntryModel>;

    final financials = blocks
        .map((block) => BlockFinancial(
              block: block,
              entries: entries.where((e) => e.blockId == block.id).toList(),
            ))
        .toList()
      ..sort((a, b) => a.block.name.compareTo(b.block.name));

    if (mounted) {
      setState(() {
        _financials = financials;
        _loading = false;
      });
    }
  }

  List<BlockFinancial> get _filtered {
    if (_selectedFilter == 'Profitable') {
      return _financials.where((c) => c.isProfitable).toList();
    } else if (_selectedFilter == 'Loss') {
      return _financials.where((c) => !c.isProfitable).toList();
    }
    return _financials;
  }

  double get _totalRevenue =>
      _financials.fold(0.0, (sum, c) => sum + c.totalRevenue);
  double get _totalExpenses =>
      _financials.fold(0.0, (sum, c) => sum + c.totalExpenses);
  double get _totalProfit => _totalRevenue - _totalExpenses;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // ── App Bar ──────────────────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 140,
                    floating: false,
                    pinned: true,
                    backgroundColor: AppColors.primary,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1B5E20), AppColors.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('💰 Cost & Profit Analysis',
                                style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            const SizedBox(height: 4),
                            Text('Track expenses & profitability per crop',
                                style: GoogleFonts.poppins(
                                    fontSize: 13, color: Colors.white70)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Summary Banner ───────────────────────────────
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _totalProfit >= 0
                                  ? [AppColors.success, AppColors.primaryLight]
                                  : [AppColors.danger, AppColors.warning],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Overall Farm Performance',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text(
                                formatMyr(_totalProfit),
                                style: GoogleFonts.poppins(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              Text(
                                _totalProfit >= 0
                                    ? '✅ Net Profit this season'
                                    : '❌ Net Loss this season',
                                style: GoogleFonts.poppins(
                                    fontSize: 13, color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSummaryItem(
                                        'Total Revenue',
                                        formatMyr(_totalRevenue),
                                        Icons.trending_up),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildSummaryItem(
                                        'Total Expenses',
                                        formatMyr(_totalExpenses),
                                        Icons.trending_down),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ── Filter Tabs ───────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: _filters.map((f) {
                              final isSelected = _selectedFilter == f;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedFilter = f),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.cardBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.grey.shade300),
                                  ),
                                  child: Text(f,
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.textGrey)),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // ── Block Financial Cards ─────────────────────────
                        if (_filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long_outlined,
                                      size: 60, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    _financials.isEmpty
                                        ? 'No blocks yet'
                                        : 'No blocks match this filter',
                                    style: AppTextStyles.body
                                        .copyWith(color: AppColors.textGrey),
                                  ),
                                  const SizedBox(height: 4),
                                  if (_financials.isEmpty)
                                    Text(
                                      'Add a block in the Milestones tab first',
                                      style: AppTextStyles.bodyGrey,
                                    ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              return _BlockFinancialCard(
                                financial: _filtered[index],
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CostAnalysisDetailScreen(
                                          block: _filtered[index].block),
                                    ),
                                  );
                                  _loadData();
                                },
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'cost_fab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );
          _loadData();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Log Entry',
            style: AppTextStyles.body.copyWith(color: Colors.white)),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: Colors.white70)),
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Block Financial Card ─────────────────────────────────────────────────

class _BlockFinancialCard extends StatelessWidget {
  final BlockFinancial financial;
  final VoidCallback onTap;

  const _BlockFinancialCard({required this.financial, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final block = financial.block;
    final isProfit = financial.isProfitable;
    final profitColor = isProfit ? AppColors.success : AppColors.danger;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
          border: Border(left: BorderSide(color: profitColor, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.agriculture,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(block.name,
                            style: AppTextStyles.body
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text('${block.cropType} • ${block.location}',
                            style:
                                AppTextStyles.bodyGrey.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatMyr(financial.profitLoss),
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: profitColor),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: profitColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isProfit ? '▲ Profit' : '▼ Loss',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: profitColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Revenue vs Expense row
              Row(
                children: [
                  Expanded(
                      child: _buildFinanceRow(
                          Icons.arrow_upward,
                          'Revenue',
                          formatMyr(financial.totalRevenue),
                          AppColors.success)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildFinanceRow(
                          Icons.arrow_downward,
                          'Expenses',
                          formatMyr(financial.totalExpenses),
                          AppColors.danger)),
                ],
              ),

              const SizedBox(height: 12),

              // Progress bar showing expense vs revenue ratio
              Row(
                children: [
                  Text('Expense ratio', style: AppTextStyles.label),
                  const Spacer(),
                  Text(
                    financial.totalRevenue > 0
                        ? '${((financial.totalExpenses / financial.totalRevenue) * 100).toStringAsFixed(0)}%'
                        : 'N/A',
                    style: AppTextStyles.label,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: financial.totalRevenue > 0
                      ? (financial.totalExpenses / financial.totalRevenue)
                          .clamp(0.0, 1.0)
                      : 0,
                  backgroundColor: AppColors.success.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      financial.totalExpenses > financial.totalRevenue
                          ? AppColors.danger
                          : AppColors.warning),
                  minHeight: 8,
                ),
              ),

              const SizedBox(height: 10),

              // Footer
              Row(
                children: [
                  const Icon(Icons.receipt_long,
                      size: 13, color: AppColors.textGrey),
                  const SizedBox(width: 4),
                  Text('${financial.entries.length} entries',
                      style: AppTextStyles.label),
                  const Spacer(),
                  const Icon(Icons.location_on,
                      size: 13, color: AppColors.textGrey),
                  const SizedBox(width: 4),
                  Text(block.location.isEmpty ? '—' : block.location,
                      style: AppTextStyles.label),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinanceRow(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 10, color: color)),
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
