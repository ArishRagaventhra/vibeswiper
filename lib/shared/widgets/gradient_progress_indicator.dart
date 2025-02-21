import 'package:flutter/material.dart';
import '../../config/theme.dart';

class GradientProgressIndicator extends StatelessWidget {
  final double progress;
  final double height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final bool animate;

  const GradientProgressIndicator({
    super.key,
    required this.progress,
    this.height = 8.0,
    this.borderRadius,
    this.backgroundColor,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: animate ? const Duration(milliseconds: 500) : Duration.zero,
                curve: Curves.easeInOut,
                width: constraints.maxWidth * progress,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: borderRadius ?? BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGradientEnd.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              // Shimmer effect
              if (animate)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeInOut,
                  left: -100,
                  right: -100,
                  top: 0,
                  bottom: 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 1500),
                    opacity: 0.2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.white.withOpacity(0),
                            Colors.white.withOpacity(0.5),
                            Colors.white.withOpacity(0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
