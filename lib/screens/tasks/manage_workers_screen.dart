import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/worker_model.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';

class ManageWorkersScreen extends StatefulWidget {
  const ManageWorkersScreen({super.key});

  @override
  State<ManageWorkersScreen> createState() => _ManageWorkersScreenState();
}

class _ManageWorkersScreenState extends State<ManageWorkersScreen> {
  List<WorkerModel> _workers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    setState(() => _loading = true);
    final workers = await FirebaseService.getWorkers();
    setState(() {
      _workers = workers;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final farmCode = FirebaseService.currentUserProfile?.farmId ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('My Workers',
            style: AppTextStyles.heading2.copyWith(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWorkers,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Invite card ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Invite a new worker',
                                  style: AppTextStyles.body
                                      .copyWith(fontWeight: FontWeight.w600)),
                              Text('Share your farm code: $farmCode',
                                  style: AppTextStyles.bodyGrey),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy,
                              color: AppColors.primary, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: farmCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Farm code copied!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text('${_workers.length} Worker(s)',
                      style: AppTextStyles.heading2.copyWith(fontSize: 15)),
                  const SizedBox(height: 12),

                  if (_workers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.people_outline,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('No workers have joined yet',
                                style: AppTextStyles.bodyGrey),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._workers.map(_buildWorkerCard),
                ],
              ),
            ),
    );
  }

  Widget _buildWorkerCard(WorkerModel worker) {
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
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(worker.name,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(worker.email, style: AppTextStyles.bodyGrey),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Active',
                style: AppTextStyles.label
                    .copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
