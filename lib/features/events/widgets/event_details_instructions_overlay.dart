import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:scompass_07/config/theme.dart';

class EventDetailsInstructionsOverlay extends StatefulWidget {
  final Function onDismiss;
  final Size screenSize;

  const EventDetailsInstructionsOverlay({
    Key? key,
    required this.onDismiss,
    required this.screenSize,
  }) : super(key: key);

  @override
  State<EventDetailsInstructionsOverlay> createState() => _EventDetailsInstructionsOverlayState();
}

class _EventDetailsInstructionsOverlayState extends State<EventDetailsInstructionsOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  int _currentStep = 0;
  final int _totalSteps = 2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextInstruction() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _controller.reset();
      _controller.forward();
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    
    // Define instruction details based on current step
    String title = '';
    String description = '';
    IconData icon = Icons.touch_app;
    Alignment arrowAlignment = Alignment.bottomCenter;
    Offset arrowPosition = Offset.zero;
    
    // Target position of the UI element the instruction is pointing to
    double targetX = 0.0;
    double targetY = 0.0;
    
    switch (_currentStep) {
      case 0:
        title = 'Join Event';
        description = 'Tap the button to join and reserve your spot for the event';
        icon = Icons.group_add_rounded;
        // Position arrow at the bottom-center of screen pointing to the join button
        targetX = size.width * 0.3;
        targetY = size.height * 0.9;
        break;
      case 1:
        title = 'Confirm Your Spot';
        description = 'Secure your place instantly by confirming your spot. Chat with the organizer, get event details, and complete your payment all in one place!';
        icon = Icons.chat_bubble_rounded;
        // Position arrow at the bottom-right pointing to the chat button
        targetX = size.width * 0.85;
        targetY = size.height * 0.85;
        break;
    }

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: _nextInstruction,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withOpacity(0.7),
          child: Stack(
            children: [
              // Centered dialog box
              Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: size.width * 0.9,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Header text - large and bold
                              Text(
                                title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              // Description text
                              Text(
                                description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        // GOT IT button at the bottom with full width and gradient
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _nextInstruction,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _currentStep < _totalSteps - 1 ? 'NEXT' : 'GOT IT',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Arrow pointing to the target button (if needed)
              if (_currentStep == 1) 
                Positioned(
                  left: targetX - 15,
                  top: targetY - 100,  // Position above the target
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: child,
                      );
                    },
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 10.0),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, sin(value) * 5),
                          child: CustomPaint(
                            size: const Size(30, 30),
                            painter: ArrowPainter(AppTheme.primaryGradientStart),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArrowPainter extends CustomPainter {
  final Color color;
  
  ArrowPainter(this.color);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    
    // Main triangle - pointing down
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    
    // Add a glow effect
    final shadowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      
    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Static helper method to check if instructions should be shown
class EventDetailsInstructions {
  static const String _prefsKey = 'has_seen_event_details_instructions';
  
  static Future<bool> shouldShowInstructions() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefsKey) ?? false);
  }
  
  static Future<void> markInstructionsAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }
}
