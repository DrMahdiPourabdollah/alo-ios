import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alo_simple/ui/home.dart';
import 'package:alo_simple/ui/theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:alo_simple/data/store.dart';
import 'package:alo_simple/domain/entry.dart';
import 'package:alo_simple/domain/parser.dart';

class MemoryStore extends EntryStore {
  final List<Entry> entries = [];
  @override
  Future<void> open({String? databasePath, bool cleanTemp = true}) async {}
  @override
  Future<List<Entry>> load() async => List.of(entries);
  @override
  Future<void> save(Entry e) async {
    entries.removeWhere((n) => n.id == e.id);
    entries.add(e);
  }

  @override
  Future<void> remove(String id) async {
    entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> merge(List<Entry> es) async {
    for (final e in es) {
      await save(e);
    }
  }
}

class LegacyApp extends StatelessWidget {
  const LegacyApp({super.key, required this.store});
  final EntryStore store;
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: aloTheme(),
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: WelcomePage(store: store),
  );
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn.ttf'));
    await loader.load();
  });
  testWidgets('welcome has two clear spaces', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(LegacyApp(store: MemoryStore()));
    await t.pumpAndSettle();
    expect(find.text('شخصی'), findsOneWidget);
    expect(find.text('کسب‌وکار'), findsOneWidget);
    expect(t.takeException(), null);
  });
  testWidgets('text entry only saves after confirmation', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final store = MemoryStore();
    await t.pumpWidget(LegacyApp(store: store));
    await t.pumpAndSettle();
    await t.tap(find.text('شخصی'));
    await t.pumpAndSettle();
    await t.tap(find.text('یا با نوشتن ثبت کن'));
    await t.pumpAndSettle();
    await t.enterText(
      find.byType(TextField),
      'امروز توی فروشگاه امید ۸۵۰ هزار تومن کارت کشیدم',
    );
    await t.ensureVisible(find.text('ببین چی فهمیدم'));
    await t.tap(find.text('ببین چی فهمیدم'));
    await t.pumpAndSettle();
    expect(store.entries, isEmpty);
    expect(find.text('۸۵۰٬۰۰۰ تومان'), findsOneWidget);
    await t.ensureVisible(find.text('ثبت کن'));
    await t.tap(find.text('ثبت کن'));
    await t.pumpAndSettle();
    expect(store.entries.length, 1);
    expect(store.entries.single.amount, 850000);
    expect(t.takeException(), null);
  });
  testWidgets('personal never displays business notes', (t) async {
    final store = MemoryStore();
    store.entries.add(NoteParser().parse('۲۰ عدد دفتر آوردم', Space.business));
    await t.pumpWidget(LegacyApp(store: store));
    await t.pumpAndSettle();
    await t.tap(find.text('شخصی'));
    await t.pumpAndSettle();
    expect(find.text('اولین یادداشتت رو ثبت کن'), findsOneWidget);
    expect(find.text('۲۰ عدد'), findsNothing);
    expect(t.takeException(), null);
  });
  testWidgets('welcome fits small phone with larger text', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: LegacyApp(store: MemoryStore()),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), null);
  });
}
