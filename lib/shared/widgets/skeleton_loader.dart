import 'package:flutter/material.dart';

/// A widget that displays a skeleton loading animation.
/// 
/// Used for placeholder UI while content is loading.
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  const SkeletonLoader({
    Key? key,
    this.width = double.infinity,
    this.height = 12,
    this.borderRadius = 4,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  }) : super(key: key);

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.baseColor ??
        (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2));
    final highlightColor = widget.highlightColor ??
        (isDark ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.4));

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                0.0,
                _computeStop(_animation.value),
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }

  double _computeStop(double value) {
    // Map the animation value (-1.0 to 1.0) to a position (0.0 to 1.0)
    return (value + 1.0) / 2.0;
  }
}
