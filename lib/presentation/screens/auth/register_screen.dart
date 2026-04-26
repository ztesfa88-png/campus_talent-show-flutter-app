import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/user.dart';
import '../../widgets/app_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  UserRole _role = UserRole.student;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(authStateProvider.notifier).signUp(
        _emailCtrl.text.trim(), _passCtrl.text,
        _nameCtrl.text.trim(), _role,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authStateProvider, (prev, next) {
      if (next.hasError) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(next.error!, style: const TextStyle(fontSize: 13))),
          ]),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 5),
        ));
        return;
      }
      if (next.isAuthenticated && next.user != null &&
          (prev == null || !prev.isAuthenticated)) {
        if (!mounted) return;
        final name = next.user!.name ?? next.user!.email;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('Welcome, $name! Account created 🎉', style: const TextStyle(fontSize: 13))),
          ]),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ));
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          if (next.user!.role.value == 'performer') { context.go('/performer'); }
          else { context.go('/student'); }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Center(
                      child: Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          gradient: AppColors.heroGradient,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: AppColors.primaryShadow,
                        ),
                        child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 36),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Create Account 🎉',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMain, fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text('Join the campus talent community',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSub, fontSize: 14)),
                    const SizedBox(height: 32),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppField(
                            controller: _nameCtrl,
                            hint: 'Full name',
                            icon: Icons.person_outline_rounded,
                            textInputAction: TextInputAction.next,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                          ),
                          const SizedBox(height: 14),
                          AppField(
                            controller: _emailCtrl,
                            hint: 'Email address',
                            icon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter your email';
                              if (!v.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          // Role selector
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<UserRole>(
                                value: _role,
                                isExpanded: true,
                                style: const TextStyle(color: AppColors.textMain, fontSize: 15),
                                dropdownColor: AppColors.surface,
                                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textHint),
                                items: [UserRole.student, UserRole.performer].map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Row(children: [
                                    Icon(r == UserRole.student ? Icons.school_rounded : Icons.mic_rounded,
                                        color: AppColors.primary, size: 20),
                                    const SizedBox(width: 10),
                                    Text(r.value[0].toUpperCase() + r.value.substring(1),
                                        style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w500)),
                                  ]),
                                )).toList(),
                                onChanged: (v) => setState(() => _role = v!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          AppField(
                            controller: _passCtrl,
                            hint: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePass,
                            textInputAction: TextInputAction.next,
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => _obscurePass = !_obscurePass),
                              child: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppColors.textHint, size: 20),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter a password';
                              if (v.length < 6) return 'At least 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          AppField(
                            controller: _confirmCtrl,
                            hint: 'Confirm password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _signUp(),
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              child: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppColors.textHint, size: 20),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Confirm your password';
                              if (v != _passCtrl.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _submitting ? null : _signUp,
                              child: _submitting
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                  : const Text('Create Account'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('Already have an account? ', style: TextStyle(color: AppColors.textSub, fontSize: 14)),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: const Text('Sign In',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ]),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
