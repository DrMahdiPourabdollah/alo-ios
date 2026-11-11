import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alo_simple/ui/theme.dart';
import 'package:alo_simple/ui/premium_effects.dart';
import 'package:alo_simple/ui/finance_desk.dart';
import 'package:alo_simple/ui/compose.dart';
import 'package:alo_simple/domain/entry.dart';
import 'package:alo_simple/domain/financial_book.dart';
import 'widget_test.dart' show MemoryStore;
import 'finance_v24_test.dart' show sample;

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (call) async => null,
        );
  });
  setUpAll(() async {
    for (final f
        in {
          'Vazirmatn': 'assets/fonts/Vazirmatn.ttf',
          'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
        }.entries) {
      await (FontLoader(f.key)..addFont(rootBundle.load(f.value))).load();
    }
  });
  Future<GlobalKey> show(
    WidgetTester t,
    Widget child, {
    double width = 393,
    double height = 852,
    double scale = 1,
    bool reduced = false,
    bool safe = true,
  }) async {
    t.view.physicalSize = Size(width, height);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: aloTheme().copyWith(platform: TargetPlatform.iOS),
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder:
              (c, w) => MediaQuery(
                data: MediaQuery.of(c).copyWith(
                  disableAnimations: reduced,
                  textScaler: TextScaler.linear(scale),
                  padding:
                      safe
                          ? const EdgeInsets.only(top: 59, bottom: 34)
                          : EdgeInsets.zero,
                ),
                child: w!,
              ),
          home: child,
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
    expect(t.takeException(), null);
    final dir = Platform.environment['ALO_QA_DIR'];
    if (dir == null) return;
    await t.runAsync(() async {
      final img = await (key.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 1);
      final b = await img.toByteData(format: ui.ImageByteFormat.png);
      await Directory(dir).create(recursive: true);
      await File('$dir/$name.png').writeAsBytes(b!.buffer.asUint8List());
      img.dispose();
    });
  }

  List<Entry> rows() => [
    revise(sample('salary', 'income', 5000000, DateTime(2026, 10, 1)), {
      'title': 'دریافت حقوق',
      'category': 'حقوق',
    }),
    revise(sample('buy', 'expense', 750000, DateTime(2026, 10, 4)), {
      'title': 'خرید دفتر',
      'quantity': 3,
      'unitPrice': 250000,
      'category': 'خرید',
    }),
  ];
  testWidgets('iOS finance keeps exact accounting and bottom safe area', (
    t,
  ) async {
    final key = await show(
      t,
      FinanceDesk(
        store: MemoryStore(),
        initialEntries: rows(),
        today: DateTime(2026, 10, 4),
      ),
    );
    expect(find.text('۴٬۲۵۰٬۰۰۰ تومان'), findsOneWidget);
    expect(find.byType(AloGlassNavigation), findsOneWidget);
    final nav = t.getRect(find.byType(AloGlassNavigation)),
        body = t.getRect(find.byType(ListView).first);
    expect(body.bottom, lessThanOrEqualTo(nav.top + 1));
    await capture(t, key, 'ios-dashboard');
  });
  testWidgets('iOS small screen with enlarged text has no overflow', (t) async {
    final key = await show(
      t,
      FinanceDesk(
        store: MemoryStore(),
        initialEntries: const [],
        today: DateTime(2026, 10, 4),
      ),
      width: 375,
      height: 667,
      scale: 1.3,
    );
    await capture(t, key, 'ios-small-large-text');
  });
  testWidgets('reduce motion renders entrance immediately', (t) async {
    await show(
      t,
      const Scaffold(body: AloReveal(child: Text('آماده'))),
      reduced: true,
    );
    expect(
      find.descendant(
        of: find.byType(AloReveal),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    expect(t.binding.hasScheduledFrame, false);
  });
  testWidgets('disabled microphone does not scale or trigger an action', (
    t,
  ) async {
    await show(
      t,
      const Scaffold(
        body: Center(
          child: AloPress(
            enabled: false,
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );
    final gesture = await t.startGesture(t.getCenter(find.byType(AloPress)));
    await t.pump();
    expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await gesture.up();
    await t.pumpAndSettle();
    expect(t.takeException(), null);
  });
  testWidgets('microphone returns to rest after finite press', (t) async {
    await show(
      t,
      const Scaffold(
        body: Center(child: AloPress(child: SizedBox(width: 100, height: 100))),
      ),
    );
    final gesture = await t.startGesture(t.getCenter(find.byType(AloPress)));
    await t.pump();
    expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, .965);
    await gesture.up();
    await t.pumpAndSettle();
    expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });
  testWidgets('iOS compose retains transcript and microphone semantics', (
    t,
  ) async {
    final key = await show(
      t,
      const ComposePage(space: Space.personal, financialBatch: true),
    );
    await t.enterText(
      find.byType(TextField),
      'سه عدد دفتر خریدم هرکدام دویست و پنجاه هزار تومان',
    );
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('شروع ضبط'), findsOneWidget);
    expect(find.text('استخراج اطلاعات مالی'), findsOneWidget);
    await capture(t, key, 'ios-compose');
    await t.ensureVisible(find.text('استخراج اطلاعات مالی'));
    await t.pumpAndSettle();
    await capture(t, key, 'ios-compose-bottom');
  });
}
