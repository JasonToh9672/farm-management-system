import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../models/block_model.dart';
import '../../models/finance_entry_model.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';

class AddExpenseScreen extends StatefulWidget {
  // Preselects a block when navigating in from a block's own finance page.
  final BlockModel? initialBlock;
  // When set, the screen edits this entry instead of creating a new one.
  final FinanceEntryModel? entry;

  const AddExpenseScreen({super.key, this.initialBlock, this.entry});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _entryType = EntryType.expense;
  String _selectedCategory = ExpenseCategory.list.first;
  DateTime? _entryDate;

  bool get _isEdit => widget.entry != null;

  List<BlockModel> _blocks = [];
  BlockModel? _selectedBlock;
  bool _loadingBlocks = true;
  bool _saving = false;

  List<String> get _categories => _entryType == EntryType.expense
      ? ExpenseCategory.list
      : RevenueCategory.list;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final e = widget.entry!;
      _entryType = e.type;
      _selectedCategory = e.category;
      _descriptionController.text = e.description;
      _amountController.text = e.amount.toStringAsFixed(2);
      _notesController.text = e.notes;
      _entryDate = e.date;
    }
    _loadBlocks();
  }

  BlockModel? _findById(List<BlockModel> blocks, String id) {
    for (final b in blocks) {
      if (b.id == id) return b;
    }
    return null;
  }

  Future<void> _loadBlocks() async {
    final blocks = await FirebaseService.getBlocks();
    // Always resolve to the instance inside `blocks`, not the object passed
    // in from another screen — DropdownButtonFormField matches by identity
    // (==), and a freshly-fetched BlockModel is a different instance even
    // with the same id, which would otherwise throw an assertion error.
    BlockModel? selected;
    if (_isEdit) {
      selected = _findById(blocks, widget.entry!.blockId);
    } else if (widget.initialBlock != null) {
      selected = _findById(blocks, widget.initialBlock!.id);
    }
    selected ??= blocks.isNotEmpty ? blocks.first : null;

    setState(() {
      _blocks = blocks;
      _selectedBlock = selected;
      _loadingBlocks = false;
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _entryDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _entryType == EntryType.expense;
    final typeColor = isExpense ? AppColors.danger : AppColors.success;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEdit ? 'Edit Entry' : 'Log New Entry',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        elevation: 0,
      ),
      body: _loadingBlocks
          ? const Center(child: CircularProgressIndicator())
          : _blocks.isEmpty
              ? _buildNoBlocksState()
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Entry Type Toggle ─────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [EntryType.expense, EntryType.revenue]
                                .map((type) {
                              final isSelected = _entryType == type;
                              final color = type == EntryType.expense
                                  ? AppColors.danger
                                  : AppColors.success;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _entryType = type;
                                    _selectedCategory = _categories.first;
                                  }),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? color
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                  color: color.withValues(
                                                      alpha: 0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2))
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          type == EntryType.expense
                                              ? Icons.arrow_downward
                                              : Icons.arrow_upward,
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.textGrey,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          type,
                                          style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? Colors.white
                                                  : AppColors.textGrey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Entry Details ─────────────────────────────────
                        _buildSectionHeader(
                            isExpense
                                ? '💸 Expense Details'
                                : '💵 Revenue Details',
                            isExpense
                                ? Icons.money_off
                                : Icons.attach_money),
                        const SizedBox(height: 12),

                        // Block dropdown
                        DropdownButtonFormField<BlockModel>(
                          initialValue: _selectedBlock,
                          decoration: InputDecoration(
                            labelText: 'Crop / Block',
                            prefixIcon: const Icon(Icons.agriculture,
                                color: AppColors.primary, size: 20),
                            filled: true,
                            fillColor: AppColors.cardBg,
                            labelStyle: AppTextStyles.label,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          style: AppTextStyles.body,
                          items: _blocks
                              .map((b) => DropdownMenuItem(
                                    value: b,
                                    child: Text('${b.name} — ${b.cropType}',
                                        style: AppTextStyles.body,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedBlock = val),
                          validator: (v) =>
                              v == null ? 'Select a block' : null,
                        ),
                        const SizedBox(height: 12),

                        // Category dropdown
                        _buildDropdownField(
                          label: 'Category',
                          value: _selectedCategory,
                          items: _categories,
                          icon: Icons.category_outlined,
                          onChanged: (val) => setState(() =>
                              _selectedCategory = val ?? _selectedCategory),
                        ),
                        const SizedBox(height: 12),

                        // Description field
                        _buildTextField(
                          controller: _descriptionController,
                          label: 'Description',
                          hint: isExpense
                              ? 'e.g. NPK compound fertilizer 50kg'
                              : 'e.g. Durian harvest sale 200kg',
                          icon: Icons.description_outlined,
                        ),
                        const SizedBox(height: 12),

                        // Amount field
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: AppTextStyles.body,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Amount is required';
                            }
                            final parsed = double.tryParse(v.trim());
                            if (parsed == null || parsed <= 0) {
                              return 'Enter a valid amount';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'Amount (RM)',
                            hintText: '0.00',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              child: Text('RM',
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary)),
                            ),
                            filled: true,
                            fillColor: AppColors.cardBg,
                            labelStyle: AppTextStyles.label,
                            hintStyle: AppTextStyles.bodyGrey,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.primary, width: 2),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),

                        // Date picker
                        GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 16),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Date', style: AppTextStyles.label),
                                    const SizedBox(height: 2),
                                    Text(
                                      _entryDate == null
                                          ? 'Tap to select date'
                                          : '${_entryDate!.day}/${_entryDate!.month}/${_entryDate!.year}',
                                      style: AppTextStyles.body.copyWith(
                                        color: _entryDate == null
                                            ? AppColors.textGrey
                                            : AppColors.textDark,
                                      ),
                                    ),
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

                        // Notes field
                        _buildTextField(
                          controller: _notesController,
                          label: 'Notes (optional)',
                          hint: 'Any additional notes...',
                          icon: Icons.notes_outlined,
                          maxLines: 3,
                        ),

                        const SizedBox(height: 24),

                        // ── Preview Card ───────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: typeColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isExpense
                                    ? Icons.money_off
                                    : Icons.attach_money,
                                color: typeColor,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _entryType,
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: typeColor),
                                  ),
                                  Text(
                                    _amountController.text.isEmpty
                                        ? 'RM 0.00'
                                        : 'RM ${_amountController.text}',
                                    style: GoogleFonts.poppins(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: typeColor),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_selectedBlock?.name ?? '—',
                                      style: AppTextStyles.label),
                                  Text(_selectedCategory,
                                      style: AppTextStyles.body
                                          .copyWith(fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Save Button ────────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: typeColor,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.save_outlined,
                                    color: Colors.white),
                            label: Text(
                              _isEdit ? 'Update $_entryType' : 'Save $_entryType',
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildNoBlocksState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No blocks yet', style: AppTextStyles.body),
            const SizedBox(height: 8),
            Text(
              'Add a block in the Milestones tab first, then come back here to log expenses and revenue against it.',
              style: AppTextStyles.bodyGrey,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.heading2.copyWith(fontSize: 16)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: maxLines == 1
            ? Icon(icon, color: AppColors.primary, size: 20)
            : null,
        filled: true,
        fillColor: AppColors.cardBg,
        labelStyle: AppTextStyles.label,
        hintStyle: AppTextStyles.bodyGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.cardBg,
        labelStyle: AppTextStyles.label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item,
                    style: AppTextStyles.body,
                    overflow: TextOverflow.ellipsis),
              ))
          .toList(),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_entryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a date'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    setState(() => _saving = true);

    final entry = FinanceEntryModel(
      id: _isEdit ? widget.entry!.id : const Uuid().v4(),
      blockId: _selectedBlock!.id,
      blockName: _selectedBlock!.name,
      type: _entryType,
      category: _selectedCategory,
      description: _descriptionController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      date: _entryDate!,
      notes: _notesController.text.trim(),
      createdAt: _isEdit ? widget.entry!.createdAt : DateTime.now(),
    );

    await FirebaseService.saveFinanceEntry(entry);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? '✅ Entry updated!' : '✅ $_entryType logged!'),
        backgroundColor:
            _entryType == EntryType.expense ? AppColors.warning : AppColors.success,
      ));
      Navigator.pop(context, true);
    }
  }
}
