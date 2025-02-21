import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EdgeToEdgeContainer extends StatelessWidget {
  final Widget child;
  final Color? statusBarColor;
  final Color? navigationBarColor;
  final Brightness? statusBarBrightness;
  final Brightness? statusBarIconBrightness;
  final Brightness? navigationBarIconBrightness;

  const EdgeToEdgeContainer({
    Key? key,
    required this.child,
    this.statusBarColor,
    this.navigationBarColor,
    this.statusBarBrightness,
    this.statusBarIconBrightness,
    this.navigationBarIconBrightness,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: statusBarColor ?? Colors.transparent,
        systemNavigationBarColor: navigationBarColor ?? Colors.transparent,
        statusBarBrightness: statusBarBrightness ?? (isDark ? Brightness.dark : Brightness.light),
        statusBarIconBrightness: statusBarIconBrightness ?? (isDark ? Brightness.light : Brightness.dark),
        systemNavigationBarIconBrightness: navigationBarIconBrightness ?? (isDark ? Brightness.light : Brightness.dark),
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: child,
    );
  }
}
