import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:alo_simple/domain/entry.dart';
import 'package:alo_simple/domain/parser.dart';
import 'package:alo_simple/ui/review.dart';
import 'package:alo_simple/ui/settings.dart';
import 'package:alo_simple/ui/theme.dart';
import 'widget_test.dart' show MemoryStore;

void main() {
  setUpAll(() async {
    for (final f
        in {
          'Vazirmatn': 'assets/fonts/Vazirmatn.ttf',
          'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
        }.entries) {
      await (FontLoader(f.key)..addFont(rootBundle.load(f.value))).load();
    }
  });
  Future<void> screen(
    WidgetTester t,
    Widget home,
    String filename, {
    double width = 390,
    double height = 844,
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
          home: home,
        ),
      ),
    );
    await t.pumpAndSettle();
    if (filename.contains('edit')) {
      await t.tap(find.text('تکمیل اطلاعات'));
      await t.pumpAndSettle();
    }
    expect(t.takeException(), null);
    final dir = Platform.environment['ALO_QA_DIR'];
    if (dir != null) {
      await t.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(dir).create(recursive: true);
        await File('$dir/$filename').writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  }

  testWidgets(
    'unclear financial editing fits phone',
    (t) async => screen(
      t,
      ReviewPage(
        entry: NoteParser().parse(
          'سه عدد دفتر هرکدام پنجاه هزار',
          Space.business,
        ),
        store: MemoryStore(),
        isNew: true,
      ),
      'v22-edit-verified.png',
    ),
  );
  testWidgets(
    'unclear editing fits narrow phone',
    (t) async => screen(
      t,
      ReviewPage(
        entry: NoteParser().parse(
          'سه عدد دفتر هرکدام پنجاه هزار',
          Space.business,
        ),
        store: MemoryStore(),
        isNew: true,
      ),
      'v22-small-edit-verified.png',
      width: 320,
      height: 568,
    ),
  );
  testWidgets(
    'model setup readable on phone',
    (t) async => screen(
      t,
      SettingsPage(store: MemoryStore()),
      'v22-settings-verified.png',
    ),
  );
}
