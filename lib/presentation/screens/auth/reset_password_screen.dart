import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/app_field.dart';

/// Shown when the user arrives via the password-reset deep-link from their email.
/// Supabase sets an active session automatically when the link is opened, so we
/// just need to call updateUser with the new password.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  bool _done = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passCtrl.text.trim()),
      );
      if (mounted) setState(() { _done = true; _submitting = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _done ? _SuccessView() : _FormView(
                formKey: _formKey,
                passCtrl: _passCtrl,
                confirmCtrl: _confirmCtrl,
                obscurePass: _obscurePass,
                obscureConfirm: _obscureConfirm,
                submitting: _submitting,
                onTogglePass: () => setState(() => _obscurePass = !_obscurePass),
                onToggleConfirm: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                onSubmit: _submit,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.formKey,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.obscurePass,
    required this.obscureConfirm,
    required this.submitting,
    required this.onTogglePass,
    required this.onToggleConfirm,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final bool obscurePass;
  final bool obscureConfirm;
  final bool submitting;
  final VoidCallback onTogglePass;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppColors.primaryShadow,
            ),
            child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 38),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Set new password',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textMain,
              fontSize: 26,
              fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose a strong password for your account',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSub, fontSize: 14),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AppField(
              controller: passCtrl,
              hint: 'New password',
              icon: Icons.lock_outline_rounded,
              obscureText: obscurePass,
              textInputAction: TextInputAction.next,
              suffixIcon: GestureDetector(
                onTap: onTogglePass,
                child: Icon(
                  obscurePass
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textHint,
                  size: 20,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter a new password';
                if (v.trim().length < 6) return 'At least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 14),
            AppField(
              controller: confirmCtrl,
              hint: 'Confirm new password',
              icon: Icons.lock_outline_rounded,
              obscureText: obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
              suffixIcon: GestureDetector(
                onTap: onToggleConfirm,
                child: Icon(
                  obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textHint,
                  size: 20,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Confirm your password';
                if (v.trim() != passCtrl.text.trim()) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: submitting ? null : onSubmit,
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Update Password'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Back to Sign In',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.accent, size: 44),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Password updated!',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textMain,
              fontSize: 26,
              fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your password has been changed successfully.\nYou can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSub, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign In'),
          ),
        ),
      ],
    );
  }
}
