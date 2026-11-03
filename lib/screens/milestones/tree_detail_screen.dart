import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../models/block_model.dart';
import '../../models/tree_model.dart';
import '../../models/milestone_model.dart';
import '../../models/fruit_count_model.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';
import 'fruit_count_screen.dart';

// Common milestone names offered as quick-pick suggestions in the form.
// Farmers can still type any custom name for milestones outside this list.
const List<String> _suggestedMilestoneNames = [
  'Flowering',
  'Fruit Set',
  'Fruiting',
  'Ripening',
  'Harvesting',
  'Pollination',
  'Bunch Formation',
  'Pod Formation',
];

class TreeDetailScreen extends StatefulWidget {
  final BlockModel block;
  final TreeModel tree;

  const TreeDetailScreen({super.key, required this.block, required this.tree});

  @override
  State<TreeDetailScreen> createState() => _TreeDetailScreenState();
}

class _TreeDetailScreenState extends State<TreeDetailScreen> {
  bool _loading = true;
  List<MilestoneModel> _milestones = [];
  List<FruitCountModel> _fruitCounts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      FirebaseService.getMilestones(widget.block.id, widget.tree.id),
      FirebaseService.getFruitCounts(widget.block.id, widget.tree.id),
    ]);
    if (mounted) {
      setState(() {
        _milestones = results[0] as List<MilestoneModel>;
        _fruitCounts = results[1] as List<FruitCountModel>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tree = widget.tree;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(tree.treeCode,
            style: AppTextStyles.heading2.copyWith(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTreeInfoCard(tree),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.timeline, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('Milestones (${_milestones.length})',
                          style: AppTextStyles.heading2.copyWith(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_milestones.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.timeline_outlined,
                                size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('No milestones yet',
                                style: AppTextStyles.body
                                    .copyWith(color: AppColors.textGrey)),
                            const SizedBox(height: 4),
                            Text('Tap + to track a growth stage for this tree',
                                style: AppTextStyles.bodyGrey),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(_milestones.length, (i) {
                      final milestone = _milestones[i];
                      return _MilestoneCard(
                        milestone: milestone,
                        onEdit: () => _showMilestoneForm(milestone: milestone),
                        onDelete: () => _confirmDelete(milestone),
                        onToggleComplete: () => _toggleComplete(milestone),
                        onCountFruits: milestone.name.toLowerCase().contains('fruit')
                            ? _openFruitCountScreen
                            : null,
                      );
                    }),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Icon(Icons.filter_vintage,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('Fruit Counts (${_fruitCounts.length})',
                          style: AppTextStyles.heading2.copyWith(fontSize: 16)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _openFruitCountScreen,
                        icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                        label: const Text('New Count'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_fruitCounts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.filter_vintage_outlined,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text('No fruit counts yet',
                                style: AppTextStyles.body
                                    .copyWith(color: AppColors.textGrey)),
                            const SizedBox(height: 4),
                            Text('Tap "New Count" to photograph & count fruit',
                                style: AppTextStyles.bodyGrey),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(_fruitCounts.length, (i) {
                      return _FruitCountCard(
                        entry: _fruitCounts[i],
                        onDelete: () => _confirmDeleteFruitCount(_fruitCounts[i]),
                      );
                    }),

                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'tree_detail_fab',
        onPressed: () => _showMilestoneForm(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Milestone',
            style: AppTextStyles.body.copyWith(color: Colors.white)),
      ),
    );
  }

  Widget _buildTreeInfoCard(TreeModel tree) {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.park, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.block.name} • ${widget.block.cropType}',
                    style: AppTextStyles.bodyGrey.copyWith(fontSize: 12)),
                const SizedBox(height: 2),
                if (tree.notes.isNotEmpty)
                  Text(tree.notes, style: AppTextStyles.body)
                else
                  Text('No notes for this tree', style: AppTextStyles.bodyGrey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(MilestoneModel milestone) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Milestone', style: AppTextStyles.heading2),
        content: Text('Delete "${milestone.name}"?', style: AppTextStyles.body),
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
              await FirebaseService.deleteMilestone(
                  widget.block.id, widget.tree.id, milestone.id);
              _loadData();
            },
            child: Text('Delete',
                style: AppTextStyles.body.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleComplete(MilestoneModel milestone) async {
    final updated = milestone.isCompleted
        ? milestone.copyWith(
            status: MilestoneStatus.upcoming, clearCompletedDate: true)
        : milestone.copyWith(
            status: MilestoneStatus.completed, completedDate: DateTime.now());
    await FirebaseService.saveMilestone(
        widget.block.id, widget.tree.id, updated);
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(updated.isCompleted
            ? '✅ "${milestone.name}" marked as completed!'
            : '"${milestone.name}" reopened'),
        backgroundColor:
            updated.isCompleted ? AppColors.success : AppColors.pending,
      ));
    }
  }

  void _showMilestoneForm({MilestoneModel? milestone}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MilestoneFormSheet(
        blockId: widget.block.id,
        treeId: widget.tree.id,
        milestone: milestone,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _openFruitCountScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FruitCountScreen(block: widget.block, tree: widget.tree),
      ),
    );
    _loadData();
  }

  void _confirmDeleteFruitCount(FruitCountModel entry) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Fruit Count', style: AppTextStyles.heading2),
        content: Text('Delete this record (${entry.count} fruit)?',
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
              await FirebaseService.deleteFruitCount(
                  widget.block.id, widget.tree.id, entry.id);
              _loadData();
            },
            child: Text('Delete',
                style: AppTextStyles.body.copyWith(color: AppColors.danger)),
          ),
        ],
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

// ─── Milestone Card Widget ─────────────────────────────────────────────────

class _MilestoneCard extends StatelessWidget {
  final MilestoneModel milestone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleComplete;
  final VoidCallback? onCountFruits;

  const _MilestoneCard({
    required this.milestone,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleComplete,
    this.onCountFruits,
  });

  @override
  Widget build(BuildContext context) {
    final color = milestone.statusColor;
    return Container(
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
        border: milestone.isOverdue
            ? Border.all(color: AppColors.danger.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggleComplete,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(milestone.statusIcon, color: color, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(milestone.name,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  milestone.isCompleted && milestone.completedDate != null
                      ? 'Completed ${_formatDate(milestone.completedDate!)}'
                      : 'Expected ${_formatDate(milestone.expectedDate)}',
                  style: AppTextStyles.bodyGrey.copyWith(fontSize: 12),
                ),
                if (milestone.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(milestone.notes,
                      style: AppTextStyles.label, maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        milestone.displayStatus,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (onCountFruits != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onCountFruits,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.camera_alt,
                                  size: 11, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Text('Count Fruits',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textGrey),
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
              if (v == 'toggle') onToggleComplete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'toggle',
                  child: Text(milestone.isCompleted
                      ? 'Reopen'
                      : 'Mark as Completed')),
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Bottom sheet form for creating/editing a milestone ────────────────────

class _MilestoneFormSheet extends StatefulWidget {
  final String blockId;
  final String treeId;
  final MilestoneModel? milestone;
  final VoidCallback onSaved;

  const _MilestoneFormSheet({
    required this.blockId,
    required this.treeId,
    this.milestone,
    required this.onSaved,
  });

  @override
  State<_MilestoneFormSheet> createState() => _MilestoneFormSheetState();
}

class _MilestoneFormSheetState extends State<_MilestoneFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _expectedDate = DateTime.now().add(const Duration(days: 30));
  bool _markCompleted = false;
  DateTime? _completedDate;
  bool _saving = false;

  bool get _isEdit => widget.milestone != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.milestone!.name;
      _notesCtrl.text = widget.milestone!.notes;
      _expectedDate = widget.milestone!.expectedDate;
      _markCompleted = widget.milestone!.isCompleted;
      _completedDate = widget.milestone!.completedDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpectedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedDate,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expectedDate = picked);
  }

  Future<void> _pickCompletedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _completedDate ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _completedDate = picked);
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
                Text(_isEdit ? 'Edit Milestone' : 'Add New Milestone',
                    style: AppTextStyles.heading2),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Milestone name is required'
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Milestone Name',
                    hintText: 'e.g. Flowering',
                    filled: true,
                    fillColor: AppColors.cardBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _suggestedMilestoneNames
                      .map((name) => GestureDetector(
                            onTap: () => setState(() => _nameCtrl.text = name),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(name,
                                  style: AppTextStyles.label
                                      .copyWith(color: AppColors.primary)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickExpectedDate,
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
                            Text('Expected Date', style: AppTextStyles.label),
                            const SizedBox(height: 2),
                            Text(_formatDate(_expectedDate),
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    value: _markCompleted,
                    onChanged: (v) => setState(() {
                      _markCompleted = v;
                      if (v) _completedDate ??= DateTime.now();
                    }),
                    title: Text('Mark as completed',
                        style: AppTextStyles.body.copyWith(fontSize: 14)),
                    activeColor: AppColors.primary,
                  ),
                ),
                if (_markCompleted) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickCompletedDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: AppColors.success, size: 20),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Completed Date', style: AppTextStyles.label),
                              const SizedBox(height: 2),
                              Text(
                                  _formatDate(
                                      _completedDate ?? DateTime.now()),
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
                ],
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
                        : Text(_isEdit ? 'Update Milestone' : 'Save Milestone',
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

    final milestone = MilestoneModel(
      id: _isEdit ? widget.milestone!.id : const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      expectedDate: _expectedDate,
      status: _markCompleted
          ? MilestoneStatus.completed
          : MilestoneStatus.upcoming,
      completedDate: _markCompleted ? (_completedDate ?? DateTime.now()) : null,
      notes: _notesCtrl.text.trim(),
    );

    await FirebaseService.saveMilestone(
        widget.blockId, widget.treeId, milestone);

    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }
}

// ─── Fruit Count Card Widget ────────────────────────────────────────────────

class _FruitCountCard extends StatelessWidget {
  final FruitCountModel entry;
  final VoidCallback onDelete;

  const _FruitCountCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: entry.imageUrl.isEmpty
                ? Container(
                    width: 56,
                    height: 56,
                    color: AppColors.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.filter_vintage,
                        color: AppColors.primary),
                  )
                : Image.network(
                    entry.imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : Container(
                                width: 56,
                                height: 56,
                                color: Colors.grey.shade200,
                                child: const Center(
                                    child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))),
                              ),
                    errorBuilder: (context, error, stack) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image_outlined,
                          color: AppColors.textGrey),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${entry.count} fruit',
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_formatDate(entry.capturedAt),
                    style: AppTextStyles.bodyGrey.copyWith(fontSize: 12)),
                if (entry.wasAdjusted) ...[
                  const SizedBox(height: 2),
                  Text('Model detected ${entry.detectedCount}, adjusted to ${entry.count}',
                      style: AppTextStyles.label),
                ],
                if (entry.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(entry.notes,
                      style: AppTextStyles.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.danger, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
