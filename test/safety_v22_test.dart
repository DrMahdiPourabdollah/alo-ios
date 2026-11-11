import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:alo_simple/data/store.dart';
import 'package:alo_simple/domain/entry.dart';
import 'package:alo_simple/domain/parser.dart';
import 'widget_test.dart' show MemoryStore, LegacyApp;
import 'package:alo_simple/voice/inference_gate.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn.ttf'));
    await loader.load();
  });
  test('database rejects incomplete financial entry', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('alo_safety_');
    final store = EntryStore();
    try {
      await store.open(databasePath: '${dir.path}/db', cleanTemp: false);
      final e = NoteParser().parse('سه عدد دفتر خریدم', Space.business);
      await expectLater(store.save(e), throwsStateError);
      expect(await store.load(), isEmpty);
      final valid = NoteParser().parse(
        'پانصد هزار تومان خرج کردم',
        Space.personal,
      );
      await expectLater(store.merge([valid, e]), throwsStateError);
      expect(await store.load(), isEmpty);
      await store.save(valid);
      expect((await store.load()).single.amount, 500000);
    } finally {
      await store.close();
      await dir.delete(recursive: true);
    }
  });
  test('manual review cannot authorize missing amount or overflow', () {
    final e = NoteParser().parse('سه عدد دفتر خریدم', Space.business);
    expect(
      Entry.fromJson({...e.toJson(), 'manuallyReviewed': true}).saveBlockReason,
      isNotNull,
    );
    expect(
      Entry.fromJson({
        ...e.toJson(),
        'manuallyReviewed': true,
        'quantity': 100000000000000,
        'unitPrice': 100000000000000,
        'amount': 1,
      }).saveBlockReason,
      isNotNull,
    );
  });
  testWidgets('confirmation opens correction instead of saving unclear money', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final store = MemoryStore();
    await t.pumpWidget(LegacyApp(store: store));
    await t.pumpAndSettle();
    await t.tap(find.text('کسب‌وکار'));
    await t.pumpAndSettle();
    await t.tap(find.text('یا با نوشتن ثبت کن'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'سه عدد دفتر هرکدام پنجاه هزار');
    await t.ensureVisible(find.text('ببین چی فهمیدم'));
    await t.tap(find.text('ببین چی فهمیدم'));
    await t.pumpAndSettle();
    await t.tap(find.text('تکمیل اطلاعات'));
    await t.pumpAndSettle();
    expect(store.entries, isEmpty);
    expect(find.text('تأیید اصلاحات'), findsOneWidget);
    expect(t.takeException(), null);
  });
  testWidgets('precise financial calculation stores only after approval', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final store = MemoryStore();
    await t.pumpWidget(LegacyApp(store: store));
    await t.pumpAndSettle();
    await t.tap(find.text('کسب‌وکار'));
    await t.pumpAndSettle();
    await t.tap(find.text('یا با نوشتن ثبت کن'));
    await t.pumpAndSettle();
    await t.enterText(
      find.byType(TextField),
      '۵ کیلو برنج کیلویی ۱۲۰ هزار تومان',
    );
    await t.ensureVisible(find.text('ببین چی فهمیدم'));
    await t.tap(find.text('ببین چی فهمیدم'));
    await t.pumpAndSettle();
    expect(store.entries, isEmpty);
    expect(find.text('۶۰۰٬۰۰۰'), findsOneWidget);
    await t.tap(find.text('ثبت کن'));
    await t.pumpAndSettle();
    expect(store.entries.single.amount, 600000);
    expect(store.entries.single.intent, 'expense');
    expect(t.takeException(), null);
  });
  test('parallel inference is rejected and guard can recover', () {
    InferenceGate.enter();
    try {
      expect(InferenceGate.enter, throwsStateError);
    } finally {
      InferenceGate.leave();
    }
    expect(InferenceGate.busy, false);
  });
}
