import 'dart:math' as math;
import 'package:flutter/material.dart';

class CompassRoseShape extends ShapeBorder {
  final double radius;
  final double pointSize;

  const CompassRoseShape({
    this.radius = 24.0,
    this.pointSize = 4.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final center = rect.center;
    final size = rect.shortestSide;
    final radius = size / 2;
    
    final path = Path();
    
    // Create points for octagonal shape
    final points = List.generate(8, (index) {
      final angle = index * (math.pi * 2 / 8);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      return Offset(x, y);
    });

    // Move to first point
    path.moveTo(points[0].dx, points[0].dy);

    // Draw curved lines between points
    for (var i = 0; i < points.length; i++) {
      final currentPoint = points[i];
      final nextPoint = points[(i + 1) % points.length];
      
      final controlPoint1 = Offset(
        currentPoint.dx + (nextPoint.dx - currentPoint.dx) / 2,
        currentPoint.dy + (nextPoint.dy - currentPoint.dy) / 2,
      );
      
      path.quadraticBezierTo(
        controlPoint1.dx,
        controlPoint1.dy,
        nextPoint.dx,
        nextPoint.dy,
      );
    }

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => CompassRoseShape(
        radius: radius * t,
        pointSize: pointSize * t,
      );
}
