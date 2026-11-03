import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../models/block_model.dart';
import '../../models/tree_model.dart';
import '../../models/fruit_count_model.dart';
import '../../services/firebase_service.dart';
import '../../services/fruit_detection_service.dart';
import '../../utils/constants.dart';

class FruitCountScreen extends StatefulWidget {
  final BlockModel block;
  final TreeModel tree;

  const FruitCountScreen({super.key, required this.block, required this.tree});

  @override
  State<FruitCountScreen> createState() => _FruitCountScreenState();
}

class _FruitCountScreenState extends State<FruitCountScreen> {
  File? _image;
  bool _detecting = false;
  bool _modelChecked = false;
  bool _modelAvailable = false;
  FruitDetectionResult? _result;
  final _countCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _countCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600, // keep uploads reasonable — full camera resolution isn't needed
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _result = null;
      _countCtrl.text = '';
    });
    await _runDetection();
  }

  Future<void> _runDetection() async {
    if (_image == null) return;
    setState(() => _detecting = true);

    final result = await FruitDetectionService.detectFruits(_image!);
    _modelChecked = true;
    _modelAvailable = FruitDetectionService.modelAvailable;

    if (mounted) {
      setState(() {
        _result = result;
        _countCtrl.text = (result?.count ?? 0).toString();
        _detecting = false;
      });
    }
  }

  Future<void> _save() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Take or choose a photo first'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    final count = int.tryParse(_countCtrl.text.trim());
    if (count == null || count < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a valid fruit count'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }

    setState(() => _saving = true);

    final imageUrl =
        await FirebaseService.uploadFruitPhoto(_image!, widget.tree.id);
    if (imageUrl == null) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Photo upload failed — check Firebase Storage is enabled for this project'),
          backgroundColor: AppColors.danger,
        ));
      }
      return;
    }

    final entry = FruitCountModel(
      id: const Uuid().v4(),
      blockId: widget.block.id,
      treeId: widget.tree.id,
      imageUrl: imageUrl,
      detectedCount: _result?.count ?? 0,
      count: count,
      notes: _notesCtrl.text.trim(),
      capturedAt: DateTime.now(),
    );

    await FirebaseService.saveFruitCount(widget.block.id, widget.tree.id, entry);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Count Fruits — ${widget.tree.treeCode}',
            style: AppTextStyles.heading2.copyWith(
                color: Colors.white, fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo preview / picker ─────────────────────────────
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _image == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('Take or choose a photo of the tree',
                                style: AppTextStyles.bodyGrey),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(_image!, fit: BoxFit.cover,
                            width: double.infinity),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _detecting ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _detecting
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (_detecting)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Text('Running on-device detection…',
                        style: AppTextStyles.body),
                  ],
                ),
              ),

            if (!_detecting && _modelChecked && !_modelAvailable)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Auto-detect isn\'t available yet (no trained model bundled, or running on web). Enter the count manually below — see ML_TRAINING_GUIDE.md.',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),

            if (!_detecting && _result != null && _result!.detections.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detected ${_result!.count} fruit(s)',
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ..._result!.detections.take(10).map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.circle,
                                  size: 6, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(d.label, style: AppTextStyles.bodyGrey),
                              const Spacer(),
                              Text('${(d.confidence * 100).toStringAsFixed(0)}%',
                                  style: AppTextStyles.label),
                            ],
                          ),
                        )),
                    if (_result!.detections.length > 10)
                      Text('+ ${_result!.detections.length - 10} more',
                          style: AppTextStyles.label),
                  ],
                ),
              ),

            // ── Count field (editable, defaults to detected count) ────
            TextFormField(
              controller: _countCtrl,
              keyboardType: TextInputType.number,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                labelText: 'Fruit Count',
                hintText: '0',
                prefixIcon:
                    const Icon(Icons.numbers, color: AppColors.primary, size: 20),
                filled: true,
                fillColor: AppColors.cardBg,
                labelStyle: AppTextStyles.label,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. some fruit hidden behind leaves',
                filled: true,
                fillColor: AppColors.cardBg,
                labelStyle: AppTextStyles.label,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_outlined, color: Colors.white),
                label: Text(
                  _saving ? 'Uploading…' : 'Save Fruit Count',
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
    );
  }
}
