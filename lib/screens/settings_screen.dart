import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../services/hive_service.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'auth/login_screen.dart';
import 'tasks/manage_workers_screen.dart';
import 'tasks/manage_templates_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserModel? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // Prefer the live Firebase profile, fall back to the Hive cache so this
    // screen still shows correct info while offline.
    UserModel? profile = FirebaseService.currentUserProfile;
    profile ??= HiveService.getCachedProfile();
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Settings',
            style: AppTextStyles.heading2.copyWith(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? _buildOfflineNoAccount()
              : _buildSettingsContent(_profile!),
    );
  }

  Widget _buildOfflineNoAccount() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined,
              size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('You are using offline mode',
              style: AppTextStyles.body, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Log in or register to see your account and farm details here.',
            style: AppTextStyles.bodyGrey,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Go to Login',
                style: AppTextStyles.body.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent(UserModel profile) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Account Card ───────────────────────────────────────
        Container(
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
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Icon(
                  profile.isOwner ? Icons.agriculture : Icons.engineering,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name.isEmpty ? profile.email : profile.name,
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text(profile.email, style: AppTextStyles.bodyGrey),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  profile.isOwner ? 'Owner' : 'Worker',
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Text('My Farm', style: AppTextStyles.heading2),
        const SizedBox(height: 10),

        // ── Farm Code Card ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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
              Text(
                profile.isOwner
                    ? 'Share this code with your workers'
                    : 'You joined this farm using this code',
                style: AppTextStyles.label,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.farmId,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: profile.farmId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Farm code copied!')),
                      );
                    },
                    icon: const Icon(Icons.copy, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Owner-only management tools
        if (profile.isOwner) ...[
          Text('Owner Tools', style: AppTextStyles.heading2),
          const SizedBox(height: 10),
          Container(
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
              children: [
                ListTile(
                  leading: const Icon(Icons.people_outline,
                      color: AppColors.primary),
                  title: Text('My Workers', style: AppTextStyles.body),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textGrey),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ManageWorkersScreen()),
                  ),
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16))),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.checklist_outlined,
                      color: AppColors.primary),
                  title: Text('Standard Tasks', style: AppTextStyles.body),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textGrey),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ManageTemplatesScreen()),
                  ),
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(16))),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
        Text('Account', style: AppTextStyles.heading2),
        const SizedBox(height: 10),

        Container(
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
          child: ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: Text('Log Out',
                style: AppTextStyles.body.copyWith(color: AppColors.danger)),
            onTap: _logout,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  Future<void> _logout() async {
    await FirebaseService.signOut();
    await HiveService.clearProfile();
    await HiveService.clearAllTasks();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
