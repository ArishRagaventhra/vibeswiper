import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Light Theme Colors
  static const primaryColor = Color(0xFF000000); // Black for light theme
  static const secondaryColor = Color(0xFF757575);
  static const backgroundColor = Color(0xFFFFFFFF);
  static const surfaceColor = Color(0xFFF8F8F8); // Slightly lighter for better contrast
  static const errorColor = Color(0xFFE53935);
  static const successColor = Color(0xFF43A047);
  static const warningColor = Color(0xFFFFD42A);

  // Dark Theme Colors
  static const darkPrimaryColor = Color(0xFFFFFFFF); // White for dark theme
  static const darkSecondaryColor = Color(0xFF9E9E9E);
  static const darkBackgroundColor = Color(0xFF121212); // Material dark background
  static const darkSurfaceColor = Color(0xFF1E1E1E); // Material dark surface
  static const darkErrorColor = Color(0xFFCF6679);
  static const darkSuccessColor = Color(0xFF81C784);
  static const darkWarningColor = Color(0xFFFFD42A);

  // Light Theme Text Colors
  static const primaryTextColor = Color(0xFF000000);
  static const secondaryTextColor = Color(0xFF757575);
  static const backgroundTextColor = Color(0xFF000000);
  static const lightTextColor = Color(0xFFFFFFFF);

  // Dark Theme Text Colors
  static const darkPrimaryTextColor = Color(0xFFFFFFFF);
  static const darkSecondaryTextColor = Color(0xFFB0B0B0);
  static const darkBackgroundTextColor = Color(0xFFFFFFFF);
  static const darkLightTextColor = Color(0xFF121212);

  // Gradient Colors
  static const Color primaryGradientStart = Color(0xFF9333EA);
  static const Color primaryGradientEnd = Color(0xFFFF1493);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGradientStart, primaryGradientEnd],
  );

  // Spacing
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;

  // Border Radius
  static const double borderRadius4 = 4.0;
  static const double borderRadius8 = 8.0;
  static const double borderRadius12 = 12.0;
  static const double borderRadius16 = 16.0;
  static const double borderRadius24 = 24.0;
  static const double borderRadius32 = 32.0;

  // Responsive Breakpoints
  static const double mobileBreakpoint = 480.0;
  static const double tabletBreakpoint = 768.0;
  static const double desktopBreakpoint = 1024.0;

  // Border Radius Presets
  static const double borderRadiusSmall = borderRadius4;
  static const double borderRadiusMedium = borderRadius8;
  static const double borderRadiusLarge = borderRadius16;
  static const double borderRadiusXLarge = borderRadius24;

  // Text Styles
  static final TextStyle displayLarge = TextStyle(
    fontSize: 57,
    fontWeight: FontWeight.bold,
    color: primaryTextColor,
    letterSpacing: -0.25,
  );

  static final TextStyle displayMedium = TextStyle(
    fontSize: 45,
    fontWeight: FontWeight.bold,
    color: primaryTextColor,
    letterSpacing: 0,
  );

  static final TextStyle displaySmall = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: primaryTextColor,
    letterSpacing: 0,
  );

  static final TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: primaryTextColor,
    letterSpacing: 0,
  );

  static final TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: primaryTextColor,
    letterSpacing: 0,
  );

  static final TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: primaryTextColor,
    letterSpacing: 0,
  );

  static final TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: primaryTextColor,
    letterSpacing: 0,
  );

  static final TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: primaryTextColor,
    letterSpacing: 0.15,
  );

  static final TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: primaryTextColor,
    letterSpacing: 0.1,
  );

  static final TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: primaryTextColor,
    letterSpacing: 0.1,
  );

  static final TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: primaryTextColor,
    letterSpacing: 0.5,
  );

  static final TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: primaryTextColor,
    letterSpacing: 0.5,
  );

  static final TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: primaryTextColor,
    letterSpacing: 0.5,
  );

  static final TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: primaryTextColor,
    letterSpacing: 0.25,
  );

  static final TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: primaryTextColor,
    letterSpacing: 0.4,
  );

  // Theme Data
  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: surfaceColor,
        background: backgroundColor,
        onBackground: primaryTextColor,
        onSurface: primaryTextColor,
        onPrimary: lightTextColor,
        onSecondary: lightTextColor,
        shadow: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: primaryTextColor,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        iconTheme: IconThemeData(color: primaryTextColor),
        actionsIconTheme: IconThemeData(color: primaryTextColor),
      ),
      textTheme: TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displaySmall,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
      ),
    );
  }

  static ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: darkPrimaryColor,
      scaffoldBackgroundColor: darkBackgroundColor,
      colorScheme: ColorScheme.dark(
        primary: darkPrimaryColor,
        secondary: darkSecondaryColor,
        error: darkErrorColor,
        surface: darkSurfaceColor,
        background: darkBackgroundColor,
        onBackground: darkPrimaryTextColor,
        onSurface: darkPrimaryTextColor,
        onPrimary: darkLightTextColor,
        onSecondary: darkLightTextColor,
        shadow: Colors.black,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackgroundColor, // Dark background for app bar
        foregroundColor: darkPrimaryTextColor, // White text
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        iconTheme: const IconThemeData(color: darkPrimaryTextColor),
        actionsIconTheme: const IconThemeData(color: darkPrimaryTextColor),
      ),
      textTheme: TextTheme(
        displayLarge: displayLarge.copyWith(color: darkPrimaryTextColor),
        displayMedium: displayMedium.copyWith(color: darkPrimaryTextColor),
        displaySmall: displaySmall.copyWith(color: darkPrimaryTextColor),
        headlineLarge: headlineLarge.copyWith(color: darkPrimaryTextColor),
        headlineMedium: headlineMedium.copyWith(color: darkPrimaryTextColor),
        headlineSmall: headlineSmall.copyWith(color: darkPrimaryTextColor),
        titleLarge: titleLarge.copyWith(color: darkPrimaryTextColor),
        titleMedium: titleMedium.copyWith(color: darkPrimaryTextColor),
        titleSmall: titleSmall.copyWith(color: darkPrimaryTextColor),
        bodyLarge: bodyLarge.copyWith(color: darkSecondaryTextColor),
        bodyMedium: bodyMedium.copyWith(color: darkSecondaryTextColor),
        bodySmall: bodySmall.copyWith(color: darkSecondaryTextColor),
      ),
    );
  }
}
