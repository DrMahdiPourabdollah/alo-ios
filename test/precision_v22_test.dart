import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:alo_simple/domain/entry.dart';
import 'package:alo_simple/domain/parser.dart';
import 'package:alo_simple/domain/persian_text_normalizer.dart';
import 'package:alo_simple/domain/persian_number_parser.dart';
import 'package:alo_simple/domain/financial_calculation_engine.dart';

void main() {
  final parser = NoteParser();
  final ns =
      jsonDecode(File('test/fixtures/numbers_v22.json').readAsStringSync())
          as List;
  for (var i = 0; i < ns.length; i++) {
    final r = ns[i] as Map;
    test(
      'exact number $i ${r['text']}',
      () =>
          expect(PersianNumberParser.integer(r['text'] as String), r['value']),
    );
  }
  final fs =
      jsonDecode(File('test/fixtures/financial_v22.json').readAsStringSync())
          as List;
  for (var i = 0; i < fs.length; i++) {
    final r = fs[i] as Map;
    test('financial entities $i ${r['text']}', () {
      for (final space in Space.values) {
        final e = parser.parse(r['text'] as String, space);
        expect(e.amount, r['amount']);
        expect(e.intent, r['intent']);
        for (final k in [
          'quantity',
          'unitPrice',
          'person',
          'merchant',
          'payment',
        ]) {
          if (r.containsKey(k)) expect(e.toJson()[k], r[k], reason: k);
        }
        expect(e.saveBlockReason, null, reason: e.reviewNote);
      }
    });
  }
  for (final r
      in <String, int>{
        'هشت صد': 800,
        'پان صد': 500,
        'دو ملیون': 2000000,
        'پونصد هزار': 500000,
        'دو و نیم میلیون': 2500000,
        'دو ممیز صفر پنج میلیون': 2050000,
        '۰٫۲۹ هزار': 290,
        'دو میلیون و نیم': 2500000,
      }.entries) {
    test(
      'ASR correction ${r.key}',
      () => expect(NoteParser.number(r.key), r.value),
    );
  }
  for (final s in [
    'یکم',
    'دو سه',
    'بیست و سی',
    'صد و صد',
    'و پنج',
    'پنج و',
    'دو و و سه',
    'منفی پنج',
    '0.0000001',
    'دو و نیم',
  ]) {
    test('reject unclear integer $s', () => expect(NoteParser.number(s), null));
  }
  for (final s in [
    '۵۰ هزار تومان نان و ۱۰۰ هزار تومان تاکسی',
    '۲۰ کارتن دفتر و ۱۰ عدد قلم آوردم',
    'سه عدد دفتر هرکدام پنجاه هزار',
    'دو و نیم کیلو برنج کیلویی صد هزار تومان',
    'من پانصد هزار تومان بدهکارم',
    'علی هشتصد هزار تومان بدهکار است',
    'حدود پانصد هزار تومان خرج کردم',
    'سه عدد دفتر هرکدام ده هزار تومان جمعا بیست هزار تومان',
    '۵ ریال پرداخت کردم',
    'درآمد پنجاه هزار تومان و پرداخت ده هزار تومان',
    '۳ عدد دفتر هر کدوم منفی پنج هزار تومان',
  ]) {
    test('unsafe financial draft blocked $s', () {
      final e = parser.parse(s, Space.business);
      expect(e.saveBlockReason, isNotNull);
    });
  }
  test(
    'Unicode presentation forms and Arabic letters',
    () => expect(PersianTextNormalizer.normalize('ﻛﻲ ۱۲۳ ة ۀ'), 'کی 123 ه ه'),
  );
  test('exact decimal has no epsilon coercion', () {
    expect(NoteParser.number('۰٫۰۰۰۰۰۰۱'), null);
    expect(
      PersianNumberParser.parse('۰٫۰۰۰۰۰۰۱')!.denominator,
      BigInt.from(10000000),
    );
  });
  test('large integer multiplication cannot wrap', () {
    expect(
      FinancialCalculationEngine.multiply(100000000000000, 100000000000000),
      null,
    );
  });
  test(
    'pinned public speech correction does not alter person word',
    () => expect(PersianTextNormalizer.normalize('هشت صدری'), 'هشت صدری'),
  );
  test('required kilos regression', () {
    final e = parser.parse('۵ کیلو برنج کیلویی ۱۲۰ هزار تومان', Space.business);
    expect(e.quantity, 5);
    expect(e.unitPrice, 120000);
    expect(e.amount, 600000);
    expect(e.saveBlockReason, null);
  });
  test('person before quantity regression', () {
    final e = parser.parse(
      'از احمد ۵ عدد محصول به قیمت دونه‌ای ۳۰۰ هزار تومان خریدم',
      Space.business,
    );
    expect(e.person, 'احمد');
    expect(e.amount, 1500000);
    expect(e.saveBlockReason, null);
  });
  test('note and old JSON stay readable', () {
    final old = {
      'id': 'old',
      'space': 'personal',
      'title': 'یادداشت',
      'text': 'یادداشت قدیمی',
      'date': '2026-10-01',
      'createdAt': '2026-10-01',
    };
    expect(Entry.fromJson(old).intent, 'note');
  });
  test('stored financial fractions never silently truncate', () {
    final e = parser.parse('پانصد هزار تومان خرج کردم', Space.personal);
    expect(
      () => Entry.fromJson({...e.toJson(), 'amount': 1.9}),
      throwsFormatException,
    );
    expect(
      () => Entry.fromJson({...e.toJson(), 'amount': 2.0}),
      throwsFormatException,
    );
  });
  test('attached per-item cue does not pollute product name', () {
    final e = parser.parse(
      'سه عدد دفتر هرکدام پنجاه هزار تومان',
      Space.business,
    );
    expect(e.title, 'دفتر');
    expect(e.amount, 150000);
    expect(e.saveBlockReason, null);
  });
}
