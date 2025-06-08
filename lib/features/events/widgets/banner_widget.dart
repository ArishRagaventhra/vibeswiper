import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:scompass_07/config/routes.dart';

class BannerWidget extends StatelessWidget {
  const BannerWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 900;
    final isMediumScreen = size.width > 600;
    
    // Calculate dynamic height based on screen size
    final bannerHeight = isLargeScreen 
        ? 180.0 
        : isMediumScreen 
            ? 160.0 
            : 140.0;
    
    // Main gradient colors
    final gradientColors = [
      const Color(0xFFBF953F), // Metallic gold start
      const Color(0xFFFCF6BA), // Light gold middle
      const Color(0xFFB38728), // Rich gold end
    ];

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 24 : 16,
        vertical: 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: bannerHeight,
          minHeight: 120,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gradient Background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: gradientColors,
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              
              // SVG Pattern Overlay
              Positioned(
                right: -20,
                bottom: -20,
                child: Transform.rotate(
                  angle: 0.2,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.white.withOpacity(0.15),
                      BlendMode.srcIn,
                    ),
                    child: SvgPicture.asset(
                      'assets/images/jetskeing.svg',
                      height: bannerHeight * 0.8,
                    ),
                  ),
                ),
              ),
              
              // Light Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.6],
                  ),
                ),
              ),

              // Content
              Padding(
                padding: EdgeInsets.all(isLargeScreen ? 32 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Don't Just Scroll – Join Something Real 🎫",
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: const Color(0xFF2D1810), // Rich brown color
                                fontWeight: FontWeight.bold,
                                fontSize: isLargeScreen ? 24 : 20,
                                height: 1.2,
                                shadows: [
                                  Shadow(
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: isLargeScreen ? 12 : 8),
                          Text(
                            "join for unforgettable experiences.",
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF3D2419), // Darker brown for subtitle
                              fontSize: isLargeScreen ? 16 : 14,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Action Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          debugPrint('Navigating to event search...');
                          context.goNamed('event-search');
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isLargeScreen ? 24 : 16,
                              vertical: isLargeScreen ? 12 : 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.explore_outlined,
                                  size: isLargeScreen ? 20 : 18,
                                  color: gradientColors[0],
                                ),
                                SizedBox(width: isLargeScreen ? 12 : 8),
                                Text(
                                  'Explore Now',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: gradientColors[0],
                                    fontWeight: FontWeight.w600,
                                    fontSize: isLargeScreen ? 16 : 14,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                SizedBox(width: isLargeScreen ? 8 : 6),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: isLargeScreen ? 18 : 16,
                                  color: gradientColors[0],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 