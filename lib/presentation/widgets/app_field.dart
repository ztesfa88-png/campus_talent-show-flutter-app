import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Shared text form field used across auth screens.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.validator,
    this.maxLines = 1,
    this.label,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final int maxLines;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textMain, fontSize: 15),
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        hintText: hint,
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, color: AppColors.textHint, size: 20),
        ),
        suffixIcon: suffixIcon != null
            ? Padding(padding: const EdgeInsets.all(14), child: suffixIcon)
            : null,
      ),
    );
  }
}
