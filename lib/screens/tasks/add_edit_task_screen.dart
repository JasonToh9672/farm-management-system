import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/task_model.dart';
import '../../models/task_template_model.dart';
import '../../models/worker_model.dart';
import '../../services/hive_service.dart';
import '../../services/firebase_service.dart';
import '../../services/notification_service.dart';
import '../../utils/constants.dart';
import 'manage_templates_screen.dart';

class AddEditTaskScreen extends StatefulWidget {
  final TaskModel? task;
  const AddEditTaskScreen({super.key, this.task});

  @override
  State<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends State<AddEditTaskScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _titleCtrl       = TextEditingController();
  final _descCtrl        = TextEditingController();

  String _category = TaskCategory.list.first;
  String _crop     = CropType.list.first;
  String _priority = Priority.medium;
  String _status   = TaskStatus.pending;
  DateTime _deadline = DateTime.now().add(const Duration(days: 3));

  // Assignment - defaults to "Myself" with no worker id (matches FYP1/offline behaviour)
  String _assignedTo   = 'Myself';
  String _assignedToId = '';

  List<WorkerModel> _workers = [];
  List<TaskTemplateModel> _templates = [];
  bool _loadingOptions = true;
  bool _saving = false;

  bool get _isEdit  => widget.task != null;
  bool get _isOwner => FirebaseService.currentUserProfile?.isOwner ?? false;
  bool get _hasFarm => FirebaseService.currentUserProfile != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final t              = widget.task!;
      _titleCtrl.text       = t.title;
      _descCtrl.text        = t.description;
      _category             = t.category;
      _crop                 = t.cropType;
      _priority             = t.priority;
      _status               = t.status;
      _deadline             = t.deadline;
      _assignedTo           = t.assignedTo;
      _assignedToId         = t.assignedToId;
    }
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    if (_hasFarm) {
      final workers   = await FirebaseService.getWorkers();
      final templates = await FirebaseService.getTemplates();
      setState(() {
        _workers   = workers;
        _templates = templates;
        _loadingOptions = false;
      });
    } else {
      setState(() => _loadingOptions = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          _isEdit ? 'Edit Task' : 'New Task',
          style: AppTextStyles.heading2.copyWith(color: Colors.white),
        ),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: _loadingOptions
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Standard Task Picker (Owner with a farm only) ──────
                  if (_isOwner && _hasFarm && !_isEdit) ...[
                    _buildTemplatePicker(),
                    const SizedBox(height: 20),
                  ],

                  const _SectionTitle(title: 'Task Details'),
                  const SizedBox(height: 12),
                  _buildField(
                    ctrl: _titleCtrl,
                    label: 'Task Title *',
                    hint: 'e.g. Apply NPK fertilizer',
                    icon: Icons.title,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    ctrl: _descCtrl,
                    label: 'Description',
                    hint: 'Describe what needs to be done...',
                    icon: Icons.description_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),

                  const _SectionTitle(title: 'Classification'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: _buildDropdown(
                        label: 'Category',
                        value: _category,
                        items: TaskCategory.list,
                        icon: Icons.category_outlined,
                        onChanged: (v) => setState(() => _category = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        label: 'Crop Type',
                        value: _crop,
                        items: CropType.list,
                        icon: Icons.grass,
                        onChanged: (v) => setState(() => _crop = v!),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  const _SectionTitle(title: 'Priority & Status'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _buildPrioritySelector()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        label: 'Status',
                        value: _status,
                        items: [
                          TaskStatus.pending,
                          TaskStatus.inProgress,
                          TaskStatus.done
                        ],
                        icon: Icons.flag_outlined,
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  const _SectionTitle(title: 'Deadline'),
                  const SizedBox(height: 12),
                  _buildDeadlinePicker(),
                  const SizedBox(height: 20),

                  const _SectionTitle(title: 'Assignment'),
                  const SizedBox(height: 12),
                  _buildAssignmentPicker(),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            _isEdit ? 'Update Task' : 'Create Task',
                            style: AppTextStyles.heading2
                                .copyWith(color: Colors.white, fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // ── Standard Task Picker ────────────────────────────────────────

  Widget _buildTemplatePicker() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Text('Use a Standard Task',
                  style: AppTextStyles.body
                      .copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ManageTemplatesScreen()),
                  );
                  _loadOptions(); // refresh in case templates changed
                },
                child: Text('Manage',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.primary)),
              ),
            ],
          ),
          if (_templates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No standard tasks yet. Tap Manage to create reusable tasks.',
                style: AppTextStyles.label,
              ),
            )
          else
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _templates.length,
                itemBuilder: (context, index) {
                  final t = _templates[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade300),
                      label: Text(t.title,
                          style: const TextStyle(fontSize: 12)),
                      onPressed: () => _applyTemplate(t),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _applyTemplate(TaskTemplateModel t) {
    setState(() {
      _titleCtrl.text = t.title;
      _descCtrl.text  = t.description;
      _category       = t.category;
      _crop           = t.cropType;
      _priority       = t.priority;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loaded "${t.title}" — adjust deadline and assignee below')),
    );
  }

  // ── Assignment Picker ───────────────────────────────────────────

  Widget _buildAssignmentPicker() {
    // Offline mode / no farm yet -> fall back to FYP1 free-text-like behaviour,
    // just fixed to "Myself" since there's no worker directory without a farm.
    if (!_hasFarm) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Text('Myself (offline mode)', style: AppTextStyles.body),
            const Spacer(),
            Tooltip(
              message: 'Log in to assign tasks to workers',
              child: Icon(Icons.info_outline, color: Colors.grey.shade400, size: 18),
            ),
          ],
        ),
      );
    }

    // Worker accounts can only assign tasks to themselves
    if (!_isOwner) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.person, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Text(_assignedTo, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    // Owner: dropdown of "Myself" + all registered workers
    final options = <Map<String, String>>[
      {'id': '', 'name': 'Myself'},
      ..._workers.map((w) => {'id': w.id, 'name': w.name}),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _assignedToId,
        decoration: InputDecoration(
          labelText: 'Assigned To',
          labelStyle: AppTextStyles.label,
          prefixIcon: const Icon(Icons.person_outline,
              color: AppColors.primary, size: 18),
          border: InputBorder.none,
        ),
        items: options
            .map((o) => DropdownMenuItem(
                  value: o['id'],
                  child: Text(o['name']!,
                      style: AppTextStyles.body.copyWith(fontSize: 13)),
                ))
            .toList(),
        onChanged: (id) {
          final match = options.firstWhere((o) => o['id'] == id);
          setState(() {
            _assignedToId = id ?? '';
            _assignedTo   = match['name']!;
          });
        },
      ),
    );
  }

  // ── Form widgets ─────────────────────────────────────────────

  Widget _buildField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      validator: validator,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.cardBg,
        labelStyle: AppTextStyles.label,
        hintStyle: AppTextStyles.bodyGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTextStyles.label,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
          border: InputBorder.none,
        ),
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e,
                      style:
                          AppTextStyles.body.copyWith(fontSize: 13)),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('  Priority', style: AppTextStyles.label),
        const SizedBox(height: 6),
        Row(
          children: [Priority.high, Priority.medium, Priority.low]
              .map((p) {
            final selected = _priority == p;
            final color = p == Priority.high
                ? AppColors.danger
                : p == Priority.medium
                    ? AppColors.warning
                    : AppColors.success;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _priority = p),
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? color
                        : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    p,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.label.copyWith(
                      color: selected ? Colors.white : color,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDeadlinePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Deadline Date', style: AppTextStyles.label),
            const SizedBox(height: 2),
            Text(
              DateFormat('EEEE, dd MMMM yyyy').format(_deadline),
              style:
                  AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ]),
          const Spacer(),
          const Icon(Icons.chevron_right, color: AppColors.textGrey),
        ]),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final task = TaskModel(
      id: _isEdit ? widget.task!.id : const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _category,
      cropType: _crop,
      priority: _priority,
      status: _status,
      deadline: _deadline,
      createdAt: _isEdit ? widget.task!.createdAt : DateTime.now(),
      assignedTo: _assignedTo,
      assignedToId: _assignedToId,
    );

    // Always save locally first (offline-first)
    if (_isEdit) {
      await HiveService.updateTask(task);
    } else {
      await HiveService.saveTask(task);
    }

    // If logged in with a farm, also push to Firestore so the assigned
    // worker (or owner, if viewing from another device) can see it.
    if (_hasFarm) {
      try {
        await FirebaseService.saveTask(task);
      } catch (_) {
        // Offline or no connection right now - that's fine, Hive already has it.
        // It will sync next time syncLocalToCloud() runs (e.g. next login).
      }
    }

    // Schedule deadline notification
    if (task.status != TaskStatus.done) {
      await NotificationService.scheduleTaskReminder(task);
    } else {
      await NotificationService.cancelNotification(task.id.hashCode);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(_isEdit ? '✅ Task updated!' : '✅ Task created!'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Task', style: AppTextStyles.heading2),
        content: Text(
          'Delete "${widget.task!.title}"?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () async {
              await HiveService.deleteTask(widget.task!.id);
              if (_hasFarm) {
                try {
                  await FirebaseService.deleteTask(widget.task!.id);
                } catch (_) {}
              }
              if (mounted) {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // close edit screen
                Navigator.pop(context); // close detail screen
              }
            },
            child: Text('Delete',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(title,
          style: AppTextStyles.heading2.copyWith(fontSize: 15)),
    ]);
  }
}
