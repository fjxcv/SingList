import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/widgets/ios_components.dart';

// ThemeData buildTheme(WidgetRef ref) {
//   final seed = Colors.indigo;
//   return ThemeData(
//     useMaterial3: true,
//     colorSchemeSeed: seed,
//     brightness: Brightness.light,
//     inputDecorationTheme: const InputDecorationTheme(
//       border: OutlineInputBorder(),
//     ),
//     appBarTheme: const AppBarTheme(centerTitle: true),
//   );
// }

ThemeData buildTheme(WidgetRef ref) {
  const colorScheme = ColorScheme.light(
    primary: AppColors.systemBlue,
    onPrimary: AppColors.surface,
    secondary: AppColors.systemBlue,
    onSecondary: AppColors.surface,
    surface: AppColors.surface,
    onSurface: AppColors.label,
    error: AppColors.destructive,
    onError: AppColors.surface,
    outline: AppColors.separator,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.groupedBackground,
    dividerColor: AppColors.separator,
    dividerTheme: const DividerThemeData(color: AppColors.separator, thickness: 0.5),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: AppColors.label),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.label),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.label),
      bodyLarge: TextStyle(fontSize: 17, color: AppColors.label),
      bodyMedium: TextStyle(fontSize: 15, color: AppColors.label),
      bodySmall: TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
      labelSmall: TextStyle(fontSize: 10, color: AppColors.secondaryLabel),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.groupedBackground,
      foregroundColor: AppColors.label,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.label,
      ),
      iconTheme: IconThemeData(color: AppColors.systemBlue, size: 22),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.small)),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      iconColor: AppColors.systemBlue,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 83,
      backgroundColor: AppColors.surface,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: selected ? AppColors.systemBlue : AppColors.secondaryLabel,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.systemBlue : AppColors.secondaryLabel,
          size: 24,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.searchBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.small),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.small),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.small),
        borderSide: const BorderSide(color: AppColors.systemBlue, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: const TextStyle(fontSize: 17, color: AppColors.secondaryLabel),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.systemBlue,
        foregroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.medium)),
        minimumSize: const Size.fromHeight(50),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.systemBlue),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.label,
      unselectedLabelColor: AppColors.secondaryLabel,
      indicatorColor: AppColors.systemBlue,
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.groupedBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.large)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium))),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.systemBlue;
        return Colors.transparent;
      }),
      side: const BorderSide(color: AppColors.separator, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.systemBlue),
  );
}
