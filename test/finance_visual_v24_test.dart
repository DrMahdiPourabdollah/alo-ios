import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:alo_simple/main.dart';
import 'package:alo_simple/domain/entry.dart';
import 'package:alo_simple/domain/financial_book.dart';
import 'package:alo_simple/ui/finance_desk.dart';
import 'package:alo_simple/ui/finance_review.dart';
import 'package:alo_simple/ui/compose.dart';
import 'package:alo_simple/ui/theme.dart';
import 'widget_test.dart' show MemoryStore;
import 'finance_v24_test.dart' show sample;

void main() {
  final today = DateTime(2026, 10, 4);
  List<Entry> rows() => [
    revise(sample('salary', 'income', 5000000, DateTime(2026, 10, 1)), {
      'title': 'دریافت حقوق',
      'category': 'حقوق',
      'account': 'بانک',
    }),
    revise(sample('buy', 'expense', 750000, today), {
      'title': 'خرید دفتر',
      'quantity': 3,
      'unitPrice': 250000,
      'category': 'خرید',
      'person': 'احمد',
      'payment': 'کارت',
      'account': 'بانک',
    }),
    revise(sample('food', 'expense', 600000, DateTime(2026, 10, 3)), {
      'title': 'خرید برنج',
      'category': 'خوراک',
    }),
    revise(sample('ride', 'expense', 80000, DateTime(2026, 10, 2)), {
      'title': 'رفت‌وآمد',
      'category': 'رفت‌وآمد',
    }),
    revise(
      sample('debt', 'payable', 800000, DateTime(2026, 9, 29), person: 'رضا'),
      {'title': 'بدهی به رضا'},
    ),
    revise(
      sample(
        'claim',
        'receivable',
        1200000,
        DateTime(2026, 9, 30),
        person: 'علی',
      ),
      {'title': 'مطالبه از علی'},
    ),
    sample(
      'settle',
      'payable_payment',
      300000,
      today,
      person: 'رضا',
      related: 'debt',
    ),
  ];
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
    double width = 390,
    double height = 844,
    double scale = 1,
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
          theme: aloTheme(),
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder:
              (c, w) => MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: TextScaler.linear(scale)),
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
      final image = await (key.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(dir).create(recursive: true);
      await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('dashboard exact totals and no overflow', (t) async {
    final key = await show(
      t,
      FinanceDesk(store: MemoryStore(), initialEntries: rows(), today: today),
    );
    expect(find.text('۳٬۵۷۰٬۰۰۰ تومان'), findsOneWidget);
    await capture(t, key, 'dashboard');
  });
  testWidgets('chart renders and precise table opens', (t) async {
    final key = await show(
      t,
      FinanceDesk(store: MemoryStore(), initialEntries: rows(), today: today),
    );
    await t.drag(find.byType(ListView).first, const Offset(0, -640));
    await t.pumpAndSettle();
    await capture(t, key, 'dashboard-chart');
  });
  testWidgets('ledger has exact columns', (t) async {
    final key = await show(
      t,
      FinanceDesk(store: MemoryStore(), initialEntries: rows(), today: today),
    );
    await t.tap(find.text('دفتر مالی'));
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView).first, const Offset(0, -390));
    await t.pumpAndSettle();
    expect(find.text('قیمت واحد'), findsOneWidget);
    await capture(t, key, 'ledger-table');
  });
  testWidgets('debt excludes repayments from expense', (t) async {
    final key = await show(
      t,
      FinanceDesk(store: MemoryStore(), initialEntries: rows(), today: today),
    );
    await t.tap(find.text('بدهی و مطالبات'));
    await t.pumpAndSettle();
    expect(find.text('مانده: ۵۰۰٬۰۰۰ تومان'), findsOneWidget);
    await capture(t, key, 'debts');
  });
  testWidgets('editor fits and requires valid amount', (t) async {
    final key = await show(t, FinanceEditor(entry: rows()[1], all: rows()));
    await capture(t, key, 'editor');
    await t.drag(find.byType(ListView).first, const Offset(0, -1400));
    await t.pumpAndSettle();
    await capture(t, key, 'editor-bottom');
  });
  testWidgets('batch cannot save without row review', (t) async {
    final drafts = FinancialBatch.parse(
      'سه عدد دفتر خریدم هرکدام دویست و پنجاه هزار تومان و پنج میلیون تومان درآمد داشتم',
      Space.personal,
      now: today,
    );
    final key = await show(t, BatchReview(entries: drafts, existing: const []));
    await capture(t, key, 'batch-review');
    await t.ensureVisible(find.text('ثبت نهایی ۲ تراکنش'));
    await t.tap(find.text('ثبت نهایی ۲ تراکنش'));
    await t.pumpAndSettle();
    expect(
      find.text('ابتدا تمام ردیف‌های باقی‌مانده را بررسی و تأیید کنید.'),
      findsOneWidget,
    );
  });
  testWidgets('empty and large text screen', (t) async {
    final key = await show(
      t,
      FinanceDesk(store: MemoryStore(), initialEntries: const [], today: today),
      width: 320,
      height: 568,
      scale: 1.3,
    );
    await capture(t, key, 'small-empty');
  });
  testWidgets('compose retains local voice and separate label', (t) async {
    final key = await show(
      t,
      const ComposePage(space: Space.personal, financialBatch: true),
    );
    await t.enterText(
      find.byType(TextField),
      'سه عدد دفتر خریدم هرکدام دویست و پنجاه هزار تومان',
    );
    await t.pumpAndSettle();
    await capture(t, key, 'compose');
  });
  testWidgets('app main is financial dashboard not notebook', (t) async {
    await show(t, AloApp(store: MemoryStore()));
    expect(find.text('دفتر مالی'), findsOneWidget);
    expect(find.text('داشبورد'), findsOneWidget);
    expect(find.text('حسابداری شخصی صوتی'), findsOneWidget);
  });
  testWidgets('approved multi-row review commits both financial entries', (
    t,
  ) async {
    final store = MemoryStore();
    final drafts = FinancialBatch.parse(
      'سه عدد دفتر خریدم هرکدام دویست و پنجاه هزار تومان و پنج میلیون تومان درآمد داشتم',
      Space.personal,
      now: today,
    );
    await show(
      t,
      Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final confirmed = await Navigator.push<List<Entry>>(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) =>
                              BatchReview(entries: drafts, existing: const []),
                    ),
                  );
                  if (confirmed != null) await store.merge(confirmed);
                },
                child: const Text('start review'),
              ),
            ),
      ),
    );
    await t.tap(find.text('start review'));
    await t.pumpAndSettle();
    for (var index = 0; index < 2; index++) {
      final open = find.text('بررسی و تأیید ردیف').first;
      await t.ensureVisible(open);
      await t.tap(open);
      await t.pumpAndSettle();
      final check = find.byType(Checkbox);
      for (var scroll = 0; scroll < 7; scroll++) {
        await t.drag(find.byType(ListView).last, const Offset(0, -600));
        await t.pumpAndSettle();
      }
      await t.ensureVisible(check);
      await t.tap(check);
      await t.pumpAndSettle();
      final confirm = find.text('تأیید این ردیف');
      await t.ensureVisible(confirm);
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(store.entries, isEmpty);
    }
    final save = find.text('ثبت نهایی ۲ تراکنش');
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();
    expect(store.entries.length, 2);
    expect(
      store.entries.every(
        (e) => e.isFinancial && e.manuallyReviewed && e.saveBlockReason == null,
      ),
      true,
    );
    expect(
      store.entries.singleWhere((e) => e.intent == 'expense').amount,
      750000,
    );
    expect(
      store.entries.singleWhere((e) => e.intent == 'income').amount,
      5000000,
    );
    expect(t.takeException(), null);
  });
}
