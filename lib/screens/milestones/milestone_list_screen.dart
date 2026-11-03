import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../models/block_model.dart';
import '../../models/milestone_model.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';
import 'block_detail_screen.dart';

// Aggregated view-model: a block plus its tree/milestone counts, computed
// by walking Firestore (blocks → trees → milestones) after each load.
class _BlockSummary {
  final BlockModel block;
  final int treeCount;
  final int totalMilestones;
  final int completedCount;
  final int overdueCount;
  final int upcomingCount;

  const _BlockSummary({
    required this.block,
    required this.treeCount,
    required this.totalMilestones,
    required this.completedCount,
    required this.overdueCount,
    required this.upcomingCount,
  });
}

class MilestoneListScreen extends StatefulWidget {
  const MilestoneListScreen({super.key});

  @override
  State<MilestoneListScreen> createState() => _MilestoneListScreenState();
}

class _MilestoneListScreenState extends State<MilestoneListScreen> {
  bool _loading = true;
  List<_BlockSummary> _summaries = [];
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Overdue', 'Upcoming', 'Completed'];

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  Future<void> _loadBlocks() async {
    setState(() => _loading = true);
    final blocks = await FirebaseService.getBlocks();
    final summaries = <_BlockSummary>[];
    for (final block in blocks) {
      final trees = await FirebaseService.getTrees(block.id);
      int total = 0, completed = 0, overdue = 0, upcoming = 0;
      for (final tree in trees) {
        final milestones = await FirebaseService.getMilestones(
            block.id, tree.id);
        total += milestones.length;
        for (final m in milestones) {
          switch (m.displayStatus) {
            case MilestoneStatus.completed:
              completed++;
              break;
            case MilestoneStatus.overdue:
              overdue++;
              break;
            default:
              upcoming++;
          }
        }
      }
      summaries.add(_BlockSummary(
        block: block,
        treeCount: trees.length,
        totalMilestones: total,
        completedCount: completed,
        overdueCount: overdue,
        upcomingCount: upcoming,
      ));
    }
    summaries.sort((a, b) => a.block.name.compareTo(b.block.name));
    if (mounted) {
      setState(() {
        _summaries = summaries;
        _loading = false;
      });
    }
  }

  List<_BlockSummary> get _filtered {
    if (_selectedFilter == 'All') return _summaries;
    return _summaries.where((s) {
      if (_selectedFilter == 'Overdue') return s.overdueCount > 0;
      if (_selectedFilter == 'Upcoming') return s.upcomingCount > 0;
      if (_selectedFilter == 'Completed') {
        return s.totalMilestones > 0 && s.completedCount == s.totalMilestones;
      }
      return true;
    }).toList();
  }

  int get _totalOverdue =>
      _summaries.fold(0, (sum, s) => sum + s.overdueCount);
  int get _totalUpcoming =>
      _summaries.fold(0, (sum, s) => sum + s.upcomingCount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBlocks,
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
                            colors: [
                              AppColors.primary,
                              AppColors.primaryLight
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('🌱 Plantation Milestones',
                                style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            const SizedBox(height: 4),
                            Text('Track crop growth stages & get reminders',
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
                        // ── Overdue Banner ─────────────────────────────────
                        if (_totalOverdue > 0)
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.danger
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: AppColors.danger, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$_totalOverdue milestone(s) are past expected date!',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ── Summary Stats ──────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Row(
                            children: [
                              _buildStatChip('${_summaries.length}', 'Blocks',
                                  AppColors.primary, Icons.eco),
                              const SizedBox(width: 10),
                              _buildStatChip('$_totalOverdue', 'Overdue',
                                  AppColors.danger, Icons.schedule),
                              const SizedBox(width: 10),
                              _buildStatChip('$_totalUpcoming', 'Upcoming',
                                  AppColors.pending, Icons.upcoming),
                            ],
                          ),
                        ),

                        // ── Filter Tabs ─────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _filters.map((f) {
                                final isSelected = _selectedFilter == f;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedFilter = f),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
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
                        ),

                        // ── Block Cards ─────────────────────────────────────
                        if (_filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.eco_outlined,
                                      size: 60, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    _summaries.isEmpty
                                        ? 'No blocks yet'
                                        : 'No blocks match this filter',
                                    style: AppTextStyles.body
                                        .copyWith(color: AppColors.textGrey),
                                  ),
                                  const SizedBox(height: 4),
                                  if (_summaries.isEmpty)
                                    Text(
                                      'Tap + to add your first block',
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
                              final summary = _filtered[index];
                              return _BlockCard(
                                summary: summary,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BlockDetailScreen(
                                          block: summary.block),
                                    ),
                                  );
                                  _loadBlocks();
                                },
                                onEdit: () => _showBlockForm(block: summary.block),
                                onDelete: () => _confirmDelete(summary.block),
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
        heroTag: 'milestone_fab',
        onPressed: () => _showBlockForm(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Block',
            style: AppTextStyles.body.copyWith(color: Colors.white)),
      ),
    );
  }

  Widget _buildStatChip(
      String value, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(label,
                    style: GoogleFonts.poppins(fontSize: 11, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BlockModel block) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Block', style: AppTextStyles.heading2),
        content: Text(
          'Delete "${block.name}"? This also deletes all of its trees and milestones.',
          style: AppTextStyles.body,
        ),
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
              await FirebaseService.deleteBlock(block.id);
              _loadBlocks();
            },
            child: Text('Delete',
                style: AppTextStyles.body.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _showBlockForm({BlockModel? block}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BlockFormSheet(block: block, onSaved: _loadBlocks),
    );
  }
}

// ─── Block Card Widget ───────────────────────────────────────────────────────

class _BlockCard extends StatelessWidget {
  final _BlockSummary summary;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BlockCard({
    required this.summary,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final block = summary.block;
    final progress = summary.totalMilestones == 0
        ? 0.0
        : summary.completedCount / summary.totalMilestones;

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
          border: summary.overdueCount > 0
              ? Border.all(color: AppColors.danger.withValues(alpha: 0.4))
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.eco,
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
                  if (summary.overdueCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${summary.overdueCount} overdue',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: AppColors.textGrey, size: 20),
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress bar
              Row(
                children: [
                  Text('Progress', style: AppTextStyles.label),
                  const Spacer(),
                  Text(
                      '${summary.completedCount}/${summary.totalMilestones} milestones',
                      style: AppTextStyles.label),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(progress == 1.0
                      ? AppColors.success
                      : AppColors.primary),
                  minHeight: 8,
                ),
              ),

              const SizedBox(height: 12),

              // Footer
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 13, color: AppColors.textGrey),
                  const SizedBox(width: 4),
                  Text('Planted: ${_formatDate(block.plantingDate)}',
                      style: AppTextStyles.label),
                  const Spacer(),
                  const Icon(Icons.park, size: 13, color: AppColors.textGrey),
                  const SizedBox(width: 4),
                  Text('${summary.treeCount} trees',
                      style: AppTextStyles.label),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

// ─── Bottom sheet form for creating/editing a block ────────────────────────

class _BlockFormSheet extends StatefulWidget {
  final BlockModel? block;
  final VoidCallback onSaved;

  const _BlockFormSheet({this.block, required this.onSaved});

  @override
  State<_BlockFormSheet> createState() => _BlockFormSheetState();
}

class _BlockFormSheetState extends State<_BlockFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _cropType = CropType.list.first;
  DateTime _plantingDate = DateTime.now();
  bool _saving = false;

  bool get _isEdit => widget.block != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.block!.name;
      _locationCtrl.text = widget.block!.location;
      _notesCtrl.text = widget.block!.notes;
      _cropType = widget.block!.cropType;
      _plantingDate = widget.block!.plantingDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPlantingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plantingDate,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _plantingDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(_isEdit ? 'Edit Block' : 'Add New Block',
                    style: AppTextStyles.heading2),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  decoration: InputDecoration(
                    labelText: 'Block Name',
                    hintText: 'e.g. Block A',
                    filled: true,
                    fillColor: AppColors.cardBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _cropType,
                  decoration: InputDecoration(
                    labelText: 'Crop Type',
                    filled: true,
                    fillColor: AppColors.cardBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  items: CropType.list
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _cropType = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationCtrl,
                  decoration: InputDecoration(
                    labelText: 'Location / Field',
                    hintText: 'e.g. North Field',
                    filled: true,
                    fillColor: AppColors.cardBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickPlantingDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Planting Date', style: AppTextStyles.label),
                            const SizedBox(height: 2),
                            Text(_formatDate(_plantingDate),
                                style: AppTextStyles.body),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right,
                            color: AppColors.textGrey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    filled: true,
                    fillColor: AppColors.cardBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(_isEdit ? 'Update Block' : 'Save Block',
                            style: AppTextStyles.body.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final block = BlockModel(
      id: _isEdit ? widget.block!.id : const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      cropType: _cropType,
      location: _locationCtrl.text.trim(),
      plantingDate: _plantingDate,
      notes: _notesCtrl.text.trim(),
    );

    await FirebaseService.saveBlock(block);

    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }
}
