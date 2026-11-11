import 'package:flutter_test/flutter_test.dart';
import 'package:alo_simple/domain/entry.dart';
import 'package:alo_simple/domain/parser.dart';

void main() {
  final parser = NoteParser();
  final now = DateTime(2026, 10, 1, 11, 30);
  group('Persian numbers', () {
    test('digits and separators', () {
      expect(NoteParser.number('۸۵۰٬۰۰۰'), 850000);
      expect(NoteParser.number('٨٥٠,٠٠٠'), 850000);
    });
    test('spoken amount', () {
      expect(NoteParser.number('هشتصد و پنجاه هزار'), 850000);
    });
    test('mixed scale', () {
      expect(NoteParser.number('۲ میلیون و ۳۵۰ هزار'), 2350000);
    });
    test('spoken quantity', () {
      expect(NoteParser.number('بیست'), 20);
    });
    test('reject invalid / decimal', () {
      expect(NoteParser.number('abc'), null);
      expect(NoteParser.number('۲.۵'), null);
      expect(NoteParser.number('منفی پنج'), null);
    });
  });
  test('personal card purchase', () {
    final e = parser.parse(
      'امروز توی فروشگاه امید ۸۵۰ هزار تومن کارت کشیدم.',
      Space.personal,
      now: now,
    );
    expect(e.amount, 850000);
    expect(e.title, 'فروشگاه امید');
    expect(e.payment, 'کارت');
    expect(e.date, DateTime(2026, 10, 1));
  });
  test('business goods and arithmetic', () {
    final e = parser.parse(
      'امروز ۲۰ کارتن آب‌معدنی از احمدی آوردم، هر کارتن ۱۸۰ هزار تومن.',
      Space.business,
      now: now,
    );
    expect(e.quantity, 20);
    expect(e.unit, 'کارتن');
    expect(e.title, 'آب معدنی');
    expect(e.person, 'احمدی');
    expect(e.unitPrice, 180000);
    expect(e.amount, 3600000);
  });
  test('do not invent missing price', () {
    final e = parser.parse('۲۰ کارتن آب معدنی آوردم', Space.business, now: now);
    expect(e.quantity, 20);
    expect(e.amount, null);
    expect(e.person, null);
  });
  test('yesterday', () {
    expect(
      parser
          .parse('دیروز ۵۰ هزار تومن خرج کردم', Space.personal, now: now)
          .date,
      DateTime(2026, 9, 30),
    );
  });
  test('unrecognized date requires review', () {
    expect(
      parser
          .parse('شنبه ۵۰ هزار تومن خرج کردم', Space.personal, now: now)
          .dateNeedsReview,
      true,
    );
  });
  test('explicit Jalali date is not currency', () {
    final e = parser.parse(
      '۱۴۰۵/۰۷/۰۹ برای نان ۳۰ هزار تومان دادم',
      Space.personal,
      now: now,
    );
    expect(e.date, DateTime(2026, 10, 1));
    expect(e.amount, 30000);
  });
  test('rial converted exactly', () {
    expect(
      parser.parse('۵۰۰۰۰۰ ریال نقد دادم', Space.personal, now: now).amount,
      50000,
    );
  });
  test('notes remain notes', () {
    final e = parser.parse('از احمدی جنس گرفتم', Space.business, now: now);
    expect(e.text, 'از احمدی جنس گرفتم');
    expect(e.amount, null);
    expect(e.quantity, null);
  });
  test('same text in different spaces stays separated', () {
    expect(parser.parse('خرید نان', Space.personal).space, Space.personal);
    expect(parser.parse('خرید نان', Space.business).space, Space.business);
  });
  test('Jalali validation', () {
    expect(parseDate('۱۴۰۵/۱۳/۰۱'), null);
    expect(parseDate('۱۴۰۵/۰۷/۰۹'), DateTime(2026, 10, 1));
  });
  test('serialization round trip', () {
    final e = parser.parse('۲۰ عدد دفتر آوردم', Space.business, now: now);
    expect(Entry.fromJson(e.toJson()).toJson(), e.toJson());
  });
}
