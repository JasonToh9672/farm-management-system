import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../services/hive_service.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import '../main_navigation.dart';
import 'farm_code_success_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey    = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginEmailCtrl     = TextEditingController();
  final _loginPasswordCtrl  = TextEditingController();
  final _regNameCtrl        = TextEditingController();
  final _regEmailCtrl       = TextEditingController();
  final _regPasswordCtrl    = TextEditingController();
  final _regConfirmCtrl     = TextEditingController();
  final _regFarmCodeCtrl    = TextEditingController();

  bool _loginObscure = true;
  bool _regObscure   = true;
  bool _loading      = false;

  // 'owner' or 'worker' - chosen during registration
  String _selectedRole = UserRole.owner;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regConfirmCtrl.dispose();
    _regFarmCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.agriculture,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Farm Management\nSystem',
                    style: AppTextStyles.heading1.copyWith(
                      color: Colors.white,
                      fontSize: 28,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your farm smarter 🌾',
                    style: AppTextStyles.bodyGrey
                        .copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),

            // ── Tab bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      padding: const EdgeInsets.all(4),
                      labelPadding: EdgeInsets.zero,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppColors.textGrey,
                      dividerColor: Colors.transparent,
                      labelStyle: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600),
                      tabs: const [
                        Tab(text: 'Login'),
                        Tab(text: 'Register'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Using a fixed-but-generous height since Register form
                  // now has more fields (name, role toggle, farm code).
                  SizedBox(
                    height: _tabController.index == 0 ? 380 : 560,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLoginForm(),
                        _buildRegisterForm(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Login Form ───────────────────────────────────────────────
  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        children: [
          _buildField(
            ctrl: _loginEmailCtrl,
            label: 'Email',
            hint: 'your@email.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          _buildField(
            ctrl: _loginPasswordCtrl,
            label: 'Password',
            hint: '••••••••',
            icon: Icons.lock_outlined,
            obscure: _loginObscure,
            toggleObscure: () =>
                setState(() => _loginObscure = !_loginObscure),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Min 6 characters' : null,
          ),
          const SizedBox(height: 24),
          _buildButton(
            label: 'Login',
            onTap: _login,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _skipLogin,
            child: Text(
              'Skip for now (offline mode)',
              style: AppTextStyles.label
                  .copyWith(color: AppColors.textGrey),
            ),
          ),
        ],
      ),
    );
  }

  // ── Register Form ────────────────────────────────────────────
  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        children: [
          // Role selector
          Row(
            children: [
              Expanded(child: _buildRoleCard(UserRole.owner, 'Owner',
                  'I manage the farm', Icons.agriculture)),
              const SizedBox(width: 10),
              Expanded(child: _buildRoleCard(UserRole.worker, 'Worker',
                  'I work on the farm', Icons.engineering)),
            ],
          ),
          const SizedBox(height: 16),
          _buildField(
            ctrl: _regNameCtrl,
            label: 'Full Name',
            hint: 'e.g. Ahmad bin Ali',
            icon: Icons.person_outline,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
          ),
          const SizedBox(height: 12),
          _buildField(
            ctrl: _regEmailCtrl,
            label: 'Email',
            hint: 'your@email.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          _buildField(
            ctrl: _regPasswordCtrl,
            label: 'Password',
            hint: '••••••••',
            icon: Icons.lock_outlined,
            obscure: _regObscure,
            toggleObscure: () =>
                setState(() => _regObscure = !_regObscure),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Min 6 characters' : null,
          ),
          const SizedBox(height: 12),
          _buildField(
            ctrl: _regConfirmCtrl,
            label: 'Confirm Password',
            hint: '••••••••',
            icon: Icons.lock_outlined,
            obscure: _regObscure,
            validator: (v) => v != _regPasswordCtrl.text
                ? 'Passwords do not match'
                : null,
          ),
          // Farm code field only appears for Worker role
          if (_selectedRole == UserRole.worker) ...[
            const SizedBox(height: 12),
            _buildField(
              ctrl: _regFarmCodeCtrl,
              label: 'Farm Code',
              hint: 'Ask your farm owner for this code',
              icon: Icons.qr_code,
              validator: (v) => (_selectedRole == UserRole.worker &&
                      (v == null || v.trim().isEmpty))
                  ? 'Enter the farm code given by your owner'
                  : null,
            ),
          ],
          const SizedBox(height: 24),
          _buildButton(
            label: 'Create Account',
            onTap: _register,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(
      String role, String label, String subtitle, IconData icon) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? AppColors.primary : AppColors.textGrey,
                size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.primary : AppColors.textDark)),
            Text(subtitle,
                style: AppTextStyles.label.copyWith(fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── Shared Widgets ───────────────────────────────────────────
  Widget _buildField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? toggleObscure,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textGrey,
                  size: 20,
                ),
                onPressed: toggleObscure,
              )
            : null,
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

  Widget _buildButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(
                label,
                style: AppTextStyles.body.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final profile = await FirebaseService.signIn(
        _loginEmailCtrl.text.trim(),
        _loginPasswordCtrl.text.trim(),
      );
      if (profile != null) {
        await HiveService.saveProfile(profile);

        // Clear any tasks left over from a previous user on this device,
        // then pull only this user's farm tasks from Firestore into Hive.
        // This ensures workers only ever see their own farm's data locally.
        await HiveService.clearAllTasks();
        try {
          final farmTasks = await FirebaseService.pullCloudTasks();
          for (final task in farmTasks) {
            await HiveService.saveTask(task);
          }
        } catch (_) {
          // Offline at login time — Hive stays empty, data loads when
          // the user manually syncs from the Tasks screen later.
        }
      }
      _goToHome();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (!_registerFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      UserModel profile;
      if (_selectedRole == UserRole.owner) {
        profile = await FirebaseService.registerOwner(
          email: _regEmailCtrl.text.trim(),
          password: _regPasswordCtrl.text.trim(),
          name: _regNameCtrl.text.trim(),
        );
      } else {
        profile = await FirebaseService.registerWorker(
          email: _regEmailCtrl.text.trim(),
          password: _regPasswordCtrl.text.trim(),
          name: _regNameCtrl.text.trim(),
          farmCode: _regFarmCodeCtrl.text.trim().toUpperCase(),
        );
      }
      await HiveService.saveProfile(profile);

      // Clear any leftover tasks from a previous user on this device.
      // New accounts start with a clean local slate; the owner's tasks
      // will be pulled from Firestore if they already exist, otherwise
      // Hive stays empty ready for fresh task creation.
      await HiveService.clearAllTasks();
      try {
        final farmTasks = await FirebaseService.pullCloudTasks();
        for (final task in farmTasks) {
          await HiveService.saveTask(task);
        }
      } catch (_) {/* offline at registration time, ignore */}

      if (!mounted) return;
      // Owners see their farm code once at signup so they can share it
      if (profile.isOwner) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FarmCodeSuccessScreen(farmCode: profile.farmId),
          ),
        );
      } else {
        _goToHome();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _skipLogin() {
    _goToHome();
  }

  void _goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.danger,
    ));
  }
}
