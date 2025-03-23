import 'package:flutter/material.dart';
import 'package:scompass_07/shared/widgets/bottom_nav_bar.dart';

/// A responsive scaffold that displays content differently based on screen size.
/// For mobile/tablet: content with bottom navigation bar
/// For desktop/laptop: content with sidebar navigation
class ResponsiveScaffold extends StatelessWidget {
  /// Main content of the screen
  final Widget body;
  
  /// AppBar to display at the top
  final PreferredSizeWidget? appBar;
  
  /// Background color for the scaffold
  final Color? backgroundColor;
  
  /// Optional floating action button
  final Widget? floatingActionButton;
  
  /// Optional floating action button location
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  
  /// Key for the scaffold
  final Key? scaffoldKey;
  
  /// ResizeToAvoidBottomInset option for the scaffold
  final bool? resizeToAvoidBottomInset;

  const ResponsiveScaffold({
    Key? key,
    required this.body,
    this.appBar,
    this.backgroundColor,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.scaffoldKey,
    this.resizeToAvoidBottomInset,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Desktop/laptop layout (sidebar)
    if (screenWidth >= kDesktopBreakpoint) {
      return Scaffold(
        key: scaffoldKey,
        backgroundColor: backgroundColor,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sidebar navigation (full height)
            const SCompassBottomNavBar(),
            
            // Main content with AppBar
            Expanded(
              child: Scaffold(
                appBar: appBar,
                body: body,
                backgroundColor: Colors.transparent,
              ),
            ),
          ],
        ),
      );
    }
    
    // Mobile/tablet layout (bottom nav bar)
    return Scaffold(
      key: scaffoldKey,
      appBar: appBar,
      body: body,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      bottomNavigationBar: const SCompassBottomNavBar(),
    );
  }
}
