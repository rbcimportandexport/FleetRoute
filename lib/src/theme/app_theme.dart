import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primary Green Logistics Palette
  static const primary = Color(0xFF16A34A); // Vibrant Emerald Green (#16A34A)
  static const primaryDark = Color(0xFF15803D); // Deep Emerald (#15803D)
  static const primaryLight =
      Color(0xFFDCFCE7); // Soft Mint Tint for icon badges (#DCFCE7)
  static const primarySoft =
      Color(0xFFF0FDF4); // Ultra-light Green for Card backgrounds (#F0FDF4)
  static const primaryBorder =
      Color(0xFFBBF7D0); // Gentle Green Border (#BBF7D0)

  // UNIFIED ICON PALETTE - Sabhi icons ka color EXACT SAME
  static const iconColor =
      Color(0xFF16A34A); // Har icon ka color same (#16A34A)
  static const iconBadgeBg =
      Color(0xFFDCFCE7); // Har icon badge ka background same (#DCFCE7)
  static const iconBadgeBorder =
      Color(0xFF86EFAC); // Subtle badge outline (#86EFAC)

  // Aliases mapped strictly to the Unified Green Theme
  static const blue = Color(0xFF16A34A); // Mapped to Primary Green
  static const blueSoft = Color(0xFFDCFCE7); // Mapped to Primary Light Tint
  static const green = Color(0xFF16A34A);

  // Status & Utility Colors mapped to Green palette
  static const orange = Color(0xFF16A34A);
  static const red = Color(0xFF16A34A);
  static const redSoft = Color(0xFFDCFCE7);

  // Typography & Neutrals (Strictly NO heavy black containers)
  static const navy =
      Color(0xFF0F291E); // Deep Forest Slate for readable headings
  static const slate = Color(0xFF475569); // Crisp readable body text
  static const muted = Color(0xFF94A3B8); // Secondary hint text
  static const border = Color(0xFFD1E7DD); // Crisp subtle green-slate border
  static const field = Color(0xFFFFFFFF); // Clean white input field
  static const canvas = Color(0xFFF4F7F5); // Clean light modern canvas
}

/// Centralized Reusable Icon Badge Widget
/// Enforces identical icon color, badge background, border, and radius across the app.
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    required this.icon,
    this.size = 20,
    this.padding = 8,
    this.radius = 10,
    super.key,
  });

  final IconData icon;
  final double size;
  final double padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.iconBadgeBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.iconBadgeBorder, width: 0.8),
      ),
      child: Icon(
        icon,
        color: AppColors.iconColor,
        size: size,
      ),
    );
  }
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        fontFamily: 'sans-serif',
        fontFamilyFallback: const [
          'Roboto',
          'Noto Sans',
          'Segoe UI',
          'Helvetica Neue',
          'Arial',
          'sans-serif',
        ],
        iconTheme: const IconThemeData(
          color: AppColors.iconColor,
          size: 20,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.navy,
          elevation: 0,
          scrolledUnderElevation: 1,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: AppColors.iconColor),
          titleTextStyle: TextStyle(
            color: AppColors.navy,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            fontFamily: 'sans-serif',
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 1.2),
          ),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            fontFamily: 'sans-serif',
          ),
          titleMedium: TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w700,
            fontFamily: 'sans-serif',
          ),
          bodyMedium: TextStyle(
            color: AppColors.slate,
            fontFamily: 'sans-serif',
          ),
          bodySmall: TextStyle(
            color: AppColors.muted,
            fontFamily: 'sans-serif',
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'sans-serif',
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
          ),
        ),
      );
}
