import 'package:flutter/material.dart';

const ink = Color(0xFF15573D);
const pine = Color(0xFF0C3024);
const cream = Color(0xFFF5F7F8);
const sage = Color(0xFFE4F1EF);
const muted = Color(0xFF58665E);
const gold = Color(0xFFB69A64);
ThemeData aloTheme() => ThemeData(
  useMaterial3: true,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    },
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.transparent,
    indicatorColor: Color(0xFFCDE8D7),
    surfaceTintColor: Colors.transparent,
    height: 80,
  ),

  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFD8E5DC)),
    ),
  ),
  fontFamily: 'Vazirmatn',
  scaffoldBackgroundColor: cream,
  colorScheme: ColorScheme.fromSeed(
    seedColor: ink,
    primary: ink,
    surface: cream,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      height: 1.5,
      color: ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.5,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: ink,
      height: 1.5,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: ink,
      height: 1.5,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: ink, height: 1.7),
    bodyMedium: TextStyle(fontSize: 16, color: ink, height: 1.7),
    bodySmall: TextStyle(fontSize: 14, color: muted, height: 1.6),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: cream,
    surfaceTintColor: Colors.transparent,
    foregroundColor: ink,
    centerTitle: false,
    elevation: 0,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: ink,
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(
        fontFamily: 'Vazirmatn',
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ink,
      minimumSize: const Size(48, 52),
      side: const BorderSide(color: Color(0xFFCED8CF)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFCED8CF)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFCED8CF)),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: ink,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  dividerColor: const Color(0xFFDFE4DA),
);

class Brand extends StatelessWidget {
  const Brand({super.key, this.light = false, this.size = 36});
  final bool light;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'الو',
    child: ExcludeSemantics(
      child: Text(
        'alo',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: size,
          letterSpacing: -2,
          fontWeight: FontWeight.w800,
          color: light ? cream : ink,
          height: 1.2,
        ),
      ),
    ),
  );
}

class AmbientPainter extends CustomPainter {
  const AmbientPainter({this.dark = false});
  final bool dark;
  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    c.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.8, -0.7),
          radius: 1.5,
          colors:
              dark
                  ? [const Color(0xFF226344), pine]
                  : [const Color(0xFFE1F1EF), cream],
        ).createShader(rect),
    );
    final paint =
        Paint()
          ..color = (dark ? Colors.white : ink).withValues(
            alpha: dark ? 0.045 : 0.035,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    for (var i = 0; i < 9; i++) {
      final y = s.height * (0.62 + i * 0.06);
      final path =
          Path()
            ..moveTo(-80, y)
            ..cubicTo(
              s.width * .4,
              y - 140,
              s.width * .6,
              y + 70,
              s.width + 80,
              y - 100,
            );
      c.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(AmbientPainter old) => old.dark != dark;
}
