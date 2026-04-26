import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.applyBlur = true,
  });

  final Widget child;
  final bool applyBlur;

  @override
  Widget build(BuildContext context) {
    final overlayColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.20)
        : Colors.white.withValues(alpha: 0.10);

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(decoration: const BoxDecoration(gradient: AppColors.heroGradient)),
        if (applyBlur)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: const SizedBox.expand(),
          ),
        ColoredBox(color: overlayColor),
        SafeArea(child: child),
      ],
    );
  }
}
