import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

class SwipeInstructionsOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final Size screenSize;

  const SwipeInstructionsOverlay({
    Key? key,
    required this.onDismiss,
    required this.screenSize,
  }) : super(key: key);

  @override
  State<SwipeInstructionsOverlay> createState() => _SwipeInstructionsOverlayState();
}

class _SwipeInstructionsOverlayState extends State<SwipeInstructionsOverlay> with TickerProviderStateMixin {
  late AnimationController _leftSwipeController;
  late AnimationController _rightSwipeController;
  late AnimationController _tapController;
  late Animation<Offset> _leftSwipeAnimation;
  late Animation<Offset> _rightSwipeAnimation;
  late Animation<double> _leftOpacityAnimation;
  late Animation<double> _rightOpacityAnimation;
  late Animation<double> _tapAnimation;
  late Animation<double> _overlayOpacityAnimation;
  late AnimationController _overlayController;
  
  int _currentStep = 0;
  final int _totalSteps = 3;

  @override
  void initState() {
    super.initState();
    
    // Initialize overlay fade controller
    _overlayController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _overlayOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _overlayController,
      curve: Curves.easeInOut,
    ));
    
    // Initialize left swipe controller
    _leftSwipeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _leftSwipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(-widget.screenSize.width * 0.4, 0),
    ).animate(CurvedAnimation(
      parent: _leftSwipeController,
      curve: Curves.easeInOut,
    ));
    
    _leftOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 80,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 10,
      ),
    ]).animate(_leftSwipeController);
    
    // Initialize right swipe controller
    _rightSwipeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _rightSwipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(widget.screenSize.width * 0.4, 0),
    ).animate(CurvedAnimation(
      parent: _rightSwipeController,
      curve: Curves.easeInOut,
    ));
    
    _rightOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 80,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 10,
      ),
    ]).animate(_rightSwipeController);
    
    // Initialize tap controller
    _tapController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _tapAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.7),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.7, end: 1.0),
        weight: 60,
      ),
    ]).animate(CurvedAnimation(
      parent: _tapController,
      curve: Curves.easeInOut,
    ));
    
    // Start the animation sequence
    _overlayController.forward().then((_) => _startNextAnimation());
  }

  void _startNextAnimation() {
    if (!mounted) return;
    
    setState(() {
      _currentStep = (_currentStep + 1) % (_totalSteps + 1);
    });
    
    if (_currentStep == 0) {
      // Finished all animations, dismiss overlay
      _overlayController.reverse().then((_) {
        widget.onDismiss();
        _markInstructionsAsShown();
      });
      return;
    }
    
    switch(_currentStep) {
      case 1:
        // Right swipe animation
        _rightSwipeController.forward().then((_) {
          _rightSwipeController.reset();
          Future.delayed(const Duration(milliseconds: 500), _startNextAnimation);
        });
        break;
      case 2:
        // Left swipe animation
        _leftSwipeController.forward().then((_) {
          _leftSwipeController.reset();
          Future.delayed(const Duration(milliseconds: 500), _startNextAnimation);
        });
        break;
      case 3:
        // Tap animation
        _tapController.forward().then((_) {
          _tapController.reset();
          Future.delayed(const Duration(milliseconds: 500), _startNextAnimation);
        });
        break;
    }
  }
  
  Future<void> _markInstructionsAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_swipe_instructions', true);
  }

  String _getInstructionText() {
    switch(_currentStep) {
      case 1:
        return 'Swipe right to favorite events';
      case 2:
        return 'Swipe left to skip events';
      case 3:
        return 'Tap to view event details';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _leftSwipeController.dispose();
    _rightSwipeController.dispose();
    _tapController.dispose();
    _overlayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: _overlayOpacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _overlayOpacityAnimation.value,
          child: Container(
            color: Colors.black.withOpacity(0.7),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Instruction text
                Positioned(
                  top: widget.screenSize.height * 0.2,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        _getInstructionText(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                
                // Hand gesture visualization
                Positioned(
                  top: widget.screenSize.height * 0.45,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Stack(
                      children: [
                        // Right swipe animation
                        if (_currentStep == 1)
                          AnimatedBuilder(
                            animation: _rightSwipeController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _rightOpacityAnimation.value,
                                child: Transform.translate(
                                  offset: _rightSwipeAnimation.value,
                                  child: _buildHandIcon(
                                    angle: -0.3,
                                    color: Colors.green,
                                  ),
                                ),
                              );
                            },
                          ),
                        
                        // Left swipe animation
                        if (_currentStep == 2)
                          AnimatedBuilder(
                            animation: _leftSwipeController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _leftOpacityAnimation.value,
                                child: Transform.translate(
                                  offset: _leftSwipeAnimation.value,
                                  child: _buildHandIcon(
                                    angle: 0.3,
                                    color: Colors.red,
                                  ),
                                ),
                              );
                            },
                          ),
                        
                        // Tap animation
                        if (_currentStep == 3)
                          AnimatedBuilder(
                            animation: _tapController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _tapAnimation.value,
                                child: _buildHandIcon(
                                  angle: 0,
                                  color: Colors.blue,
                                  isTap: true,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Skip button
                Positioned(
                  bottom: widget.screenSize.height * 0.1,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: TextButton(
                      onPressed: () {
                        // Stop all animations and dismiss
                        _leftSwipeController.stop();
                        _rightSwipeController.stop();
                        _tapController.stop();
                        _overlayController.reverse().then((_) {
                          widget.onDismiss();
                          _markInstructionsAsShown();
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black.withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: const BorderSide(color: Colors.white30, width: 1),
                        ),
                      ),
                      child: const Text('GOT IT'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildHandIcon({
    required double angle, 
    required Color color,
    bool isTap = false,
  }) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isTap ? Icons.touch_app : Icons.swipe,
          color: Colors.white,
          size: 64,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to check if user has seen instructions before
Future<bool> hasSeenSwipeInstructions() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('has_seen_swipe_instructions') ?? false;
}
