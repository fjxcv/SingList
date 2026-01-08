import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  // 选择一组柔和的基色，白底配浅灰紫/灰蓝
  const primaryColor = Color(0xFF1A1A1A); // 接近黑但不纯黑
  const secondaryColor = Color(0xFF757575); // 次文本颜色
  const surfaceColor = Color(0xFFF5F5FA); // 非常浅的灰紫/灰蓝

  const radiusSmall = 8.0;
  const radiusMedium = 12.0;

  final baseScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFCBD3E0), // 柔和的浅蓝紫作为种子色
    brightness: Brightness.light,
  ).copyWith(
    background: surfaceColor,
    surface: surfaceColor,
    primary: primaryColor,
    onPrimary: Colors.white,
    onSurface: primaryColor,
    onSurfaceVariant: secondaryColor,
  );

  final textTheme = Typography.material2021().black.copyWith(
    bodyLarge: const TextStyle(fontSize: 16, color: primaryColor),
    bodyMedium: const TextStyle(fontSize: 14, color: primaryColor),
    bodySmall: const TextStyle(fontSize: 12, color: secondaryColor),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: baseScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: surfaceColor,
    cardTheme: const CardThemeData(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusMedium))),
      surfaceTintColor: surfaceColor,
      elevation: 0,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    dividerTheme: DividerThemeData(
      color: baseScheme.onSurface.withOpacity(0.1),
      thickness: 0.5,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: surfaceColor,
      indicatorColor: baseScheme.surfaceVariant.withOpacity(0.3),
      labelTextStyle: MaterialStateProperty.all(
        textTheme.labelMedium?.copyWith(color: primaryColor),
      ),
      iconTheme: MaterialStateProperty.resolveWith((states) {
        final selected = states.contains(MaterialState.selected);
        return IconThemeData(
          color: selected ? primaryColor : secondaryColor,
        );
      }),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
        borderSide: BorderSide(color: Colors.transparent),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      hintStyle: TextStyle(color: secondaryColor),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceColor,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.w600),
      iconTheme: IconThemeData(color: primaryColor),
    ),
  );
}
