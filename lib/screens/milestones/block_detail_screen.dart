import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../models/block_model.dart';
import '../../models/tree_model.dart';
import '../../models/milestone_model.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';
import 'tree_detail_screen.dart';

// Aggregated view-model: a tree plus its milestone counts.
class _TreeSummary {
  final TreeModel tree;
  final int totalMilestones;
  final int completedCount;
  final int overdueCount;

  const _TreeSummary({
    required this.tree,
    required this.totalMilestones,
    required this.completedCount,
    required this.overdueCount,
  });
}

class BlockDetailScreen extends StatefulWidget {
  final BlockModel block;

  const BlockDetailScreen({super.key, required this.block});

  @override
  State<BlockDetailScreen> createState() => _BlockDetailScreenState();
}

class _BlockDetailScreenState extends State<BlockDetailScreen> {
  bool _loading = true;
  List<_TreeSummary> _summaries = [];

  @override
  void initState() {
    super.initState();
    _loadTrees();
  }

  Future<void> _loadTrees() async {
    setState(() => _loading = true);
    final trees = await FirebaseService.getTrees(widget.block.id);
    final summaries = <_TreeSummary>[];
    for (final tree in trees) {
      final milestones =
          await FirebaseService.getMilestones(widget.block.id, tree.id);
      final completed = milestones
          .where((m) => m.displayStatus == MilestoneStatus.completed)
          .length;
      final overdue = milestones
          .where((m) => m.displayStatus == MilestoneStatus.overdue)
          .length;
      summaries.add(_TreeSummary(
        tree: tree,
        totalMilestones: milestones.length,
        completedCount: completed,
        overdueCount: overdue,
      ));
    }
    summaries.sort((a, b) => a.tree.treeCode.compareTo(b.tree.treeCode));
    if (mounted) {
      setState(() {
        _summaries = summaries;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(block.name,
            style: AppTextStyles.heading2.copyWith(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTrees,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBlockInfoCard(block),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.park, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('Trees (${_summaries.length})',
                          style: AppTextStyles.heading2.copyWith(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_summaries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.park_outlined,
                                size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('No trees yet',
                                style: AppTextStyles.body
                                    .copyWith(color: AppColors.textGrey)),
                            const SizedBox(height: 4),
                            Text('Tap + to add a tree to this block',
                                style: AppTextStyles.bodyGrey),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(_summaries.length, (i) {
                      final summary = _summaries[i];
                      return _TreeCard(
                        summary: summary,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TreeDetailScreen(
                                block: block,
                                tree: summary.tree,
                              ),
                            ),
                          );
                          _loadTrees();
                        },
                        onEdit: () => _showTreeForm(tree: summary.tree),
                        onDelete: () => _confirmDelete(summary.tree),
                      );
                    }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'block_detail_fab',
        onPressed: () => _showTreeForm(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Tree',
            style: AppTextStyles.body.copyWith(color: Colors.white)),
      ),
    );
  }

  Widget _buildBlockInfoCard(BlockModel block) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.eco,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(block.cropType,
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text(block.location.isEmpty ? '—' : block.location,
                        style: AppTextStyles.bodyGrey),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 14, color: AppColors.textGrey),
              const SizedBox(width: 6),
              Text('Planted: ${_formatDate(block.plantingDate)}',
                  style: AppTextStyles.label),
            ],
          ),
          if (block.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(block.notes, style: AppTextStyles.bodyGrey),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(TreeModel tree) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Tree', style: AppTextStyles.heading2),
        content: Text(
          'Delete "${tree.treeCode}"? This also deletes all of its milestones.',
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
              await FirebaseService.deleteTree(widget.block.id, tree.id);
              _loadTrees();
            },
            child: Text('Delete',
                style: AppTextStyles.body.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _showTreeForm({TreeModel? tree}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TreeFormSheet(
        blockId: widget.block.id,
        tree: tree,
        onSaved: _loadTrees,
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

// ─── Tree Card Widget ──────────────────────────────────────────────────────

class _TreeCard extends StatelessWidget {
  final _TreeSummary summary;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TreeCard({
    required this.summary,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tree = summary.tree;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
          border: summary.overdueCount > 0
              ? Border.all(color: AppColors.danger.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.park, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tree.treeCode,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${summary.completedCount}/${summary.totalMilestones} milestones done'
                    '${summary.overdueCount > 0 ? " • ${summary.overdueCount} overdue" : ""}',
                    style: AppTextStyles.bodyGrey.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textGrey),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            const Icon(Icons.chevron_right, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom sheet form for creating/editing a tree ─────────────────────────

class _TreeFormSheet extends StatefulWidget {
  final String blockId;
  final TreeModel? tree;
  final VoidCallback onSaved;

  const _TreeFormSheet({
    required this.blockId,
    this.tree,
    required this.onSaved,
  });

  @override
  State<_TreeFormSheet> createState() => _TreeFormSheetState();
}

class _TreeFormSheetState extends State<_TreeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.tree != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _codeCtrl.text = widget.tree!.treeCode;
      _notesCtrl.text = widget.tree!.notes;
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
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
                Text(_isEdit ? 'Edit Tree' : 'Add New Tree',
                    style: AppTextStyles.heading2),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _codeCtrl,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Tree code is required'
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Tree Code',
                    hintText: 'e.g. D111',
                    filled: true,
                    fillColor: AppColors.cardBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
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
                        : Text(_isEdit ? 'Update Tree' : 'Save Tree',
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

    final tree = TreeModel(
      id: _isEdit ? widget.tree!.id : const Uuid().v4(),
      treeCode: _codeCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      createdAt: _isEdit ? widget.tree!.createdAt : DateTime.now(),
    );

    await FirebaseService.saveTree(widget.blockId, tree);

    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }
}
