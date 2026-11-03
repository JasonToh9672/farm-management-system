import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/task_template_model.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';

class ManageTemplatesScreen extends StatefulWidget {
  const ManageTemplatesScreen({super.key});

  @override
  State<ManageTemplatesScreen> createState() => _ManageTemplatesScreenState();
}

class _ManageTemplatesScreenState extends State<ManageTemplatesScreen> {
  List<TaskTemplateModel> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _loading = true);
    final templates = await FirebaseService.getTemplates();
    setState(() {
      _templates = templates;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Standard Tasks',
            style: AppTextStyles.heading2.copyWith(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTemplates,
              child: _templates.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _templates.length,
                      itemBuilder: (context, index) =>
                          _buildTemplateCard(_templates[index]),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'template_fab',
        onPressed: () => _showTemplateForm(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('New Standard Task',
            style: AppTextStyles.body.copyWith(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checklist_rtl, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No standard tasks yet',
                style: AppTextStyles.body, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Create standard tasks here for jobs you repeat often, like '
              '"Apply NPK Fertilizer". You can pick them instantly next time '
              'instead of typing everything again.',
              style: AppTextStyles.bodyGrey,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(TaskTemplateModel template) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.checklist, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.title,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${template.category} • ${template.cropType} • ${template.priority} priority',
                  style: AppTextStyles.bodyGrey.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textGrey),
            onSelected: (value) {
              if (value == 'edit') _showTemplateForm(template: template);
              if (value == 'delete') _confirmDelete(template);
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

  void _confirmDelete(TaskTemplateModel template) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Standard Task', style: AppTextStyles.heading2),
        content: Text('Delete "${template.title}"?', style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: AppTextStyles.body.copyWith(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseService.deleteTemplate(template.id);
              if (mounted) {
                Navigator.pop(context);
                _loadTemplates();
              }
            },
            child: Text('Delete',
                style: AppTextStyles.body.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _showTemplateForm({TaskTemplateModel? template}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplateFormSheet(
        template: template,
        onSaved: _loadTemplates,
      ),
    );
  }
}

// ── Bottom sheet form for creating/editing a template ──────────────────────

class _TemplateFormSheet extends StatefulWidget {
  final TaskTemplateModel? template;
  final VoidCallback onSaved;

  const _TemplateFormSheet({this.template, required this.onSaved});

  @override
  State<_TemplateFormSheet> createState() => _TemplateFormSheetState();
}

class _TemplateFormSheetState extends State<_TemplateFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = TaskCategory.list.first;
  String _crop = CropType.list.first;
  String _priority = Priority.medium;
  bool _saving = false;

  bool get _isEdit => widget.template != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _titleCtrl.text = widget.template!.title;
      _descCtrl.text = widget.template!.description;
      _category = widget.template!.category;
      _crop = widget.template!.cropType;
      _priority = widget.template!.priority;
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
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
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
                Text(
                  _isEdit ? 'Edit Standard Task' : 'New Standard Task',
                  style: AppTextStyles.heading2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleCtrl,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Title is required' : null,
                  decoration: InputDecoration(
                    labelText: 'Task Title',
                    hintText: 'e.g. Apply NPK Fertilizer',
                    filled: true,
                    fillColor: AppColors.cardBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Default Description (optional)',
                    filled: true,
                    fillColor: AppColors.cardBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          filled: true,
                          fillColor: AppColors.cardBg,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                        items: TaskCategory.list
                            .map((e) => DropdownMenuItem(
                                value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _category = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _crop,
                        decoration: InputDecoration(
                          labelText: 'Crop Type',
                          filled: true,
                          fillColor: AppColors.cardBg,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                        items: CropType.list
                            .map((e) => DropdownMenuItem(
                                value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _crop = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: InputDecoration(
                    labelText: 'Default Priority',
                    filled: true,
                    fillColor: AppColors.cardBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  items: [Priority.high, Priority.medium, Priority.low]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _priority = v!),
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
                        : Text(_isEdit ? 'Update' : 'Save Standard Task',
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

    final template = TaskTemplateModel(
      id: _isEdit ? widget.template!.id : const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _category,
      cropType: _crop,
      priority: _priority,
    );

    await FirebaseService.saveTemplate(template);

    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }
}
