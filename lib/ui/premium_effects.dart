import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Finite entrance motion; never changes financial data or creates a perpetual ticker.
class AloReveal extends StatefulWidget {
  const AloReveal({super.key, required this.child});
  final Widget child;
  @override
  State<AloReveal> createState() => _AloRevealState();
}

class _AloRevealState extends State<AloReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> curve = CurvedAnimation(
    parent: controller,
    curve: Curves.easeOutCubic,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = 1;
    } else {
      controller.forward();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .025),
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}

/// A small tactile response on the microphone. Semantic button remains in the child.
class AloPress extends StatefulWidget {
  const AloPress({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<AloPress> createState() => _AloPressState();
}

class _AloPressState extends State<AloPress> {
  bool pressed = false;
  void change(bool value) {
    if (mounted && pressed != value) setState(() => pressed = value);
  }

  @override
  void didUpdateWidget(AloPress old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown:
          widget.enabled
              ? (_) {
                change(true);
                if (defaultTargetPlatform == TargetPlatform.iOS) {
                  HapticFeedback.selectionClick();
                }
              }
              : null,
      onPointerUp: (_) => change(false),
      onPointerCancel: (_) => change(false),
      child: AnimatedScale(
        scale: pressed && !reduced ? 0.965 : 1,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Frosted tab bar stays in Scaffold's layout, not over ledger rows or form controls.
class AloGlassNavigation extends StatelessWidget {
  const AloGlassNavigation({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D0C3024),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .86),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD8E8DF)),
              ),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

class AloHero extends StatelessWidget {
  const AloHero({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1415573D),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: CustomPaint(foregroundPainter: const _HeroWaves(), child: child),
    ),
  );
}

class _HeroWaves extends CustomPainter {
  const _HeroWaves();
  @override
  void paint(Canvas canvas, Size size) {
    final line =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = const Color(0x0DDBFFEA);
    for (var i = 0; i < 6; i++) {
      final y = size.height * (.48 + i * .1);
      final p =
          Path()
            ..moveTo(-20, y)
            ..cubicTo(
              size.width * .25,
              y - 38,
              size.width * .7,
              y + 34,
              size.width + 20,
              y - 50,
            );
      canvas.drawPath(p, line);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x24D5FFDF),
    );
  }

  @override
  bool shouldRepaint(_HeroWaves old) => false;
}
