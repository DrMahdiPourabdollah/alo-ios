import 'package:flutter_test/flutter_test.dart';
import 'package:alo_simple/domain/entry.dart';
import 'package:alo_simple/domain/parser.dart';
import 'package:alo_simple/speech/persian_speech.dart';

void main() {
  final parser = NoteParser();
  group('Persian speech numeric normalization', () {
    final cases = <String, int>{
      '۲٫۵ میلیون': 2500000,
      'دو و نیم میلیون': 2500000,
      'دو میلیون و نیم': 2500000,
      'نیم میلیون': 500000,
      'دو ممیز پنج میلیون': 2500000,
      '۲ میلیون و ۳۵۰ هزار': 2350000,
      'یک میلیارد و دویست میلیون و سی هزار': 1200030000,
      'دو هزار میلیون': 2000000000,
      'پونصد هزار': 500000,
      '۱٬۲۵۰٬۰۰۰': 1250000,
      '١٢٥٠٠٠٠': 1250000,
      'صفر هزار': 0,
      'هشتصد و پنجاه هزار': 850000,
    };
    for (final c in cases.entries) {
      test(c.key, () => expect(NoteParser.number(c.key), c.value));
    }
    test(
      'fractional quantity is not truncated',
      () => expect(NoteParser.number('دو و نیم'), null),
    );
    test(
      'arbitrary words are not swallowed',
      () => expect(NoteParser.number('دو دفتر سه'), null),
    );
  });
  test('spoken per-item price yields total in both spaces', () {
    for (final space in Space.values) {
      final e = parser.parse(
        'بیست عدد دفتر خریدم، هر کدوم پنجاه هزار تومان',
        space,
      );
      expect(e.quantity, 20);
      expect(e.unitPrice, 50000);
      expect(e.amount, 1000000);
    }
  });
  test(
    'spoken scale and half currency',
    () => expect(
      parser.parse('دو و نیم میلیون تومان خرج کردم', Space.personal).amount,
      2500000,
    ),
  );
  test(
    'Arabic script and digits',
    () => expect(
      parser
          .parse('دويست و پنجاه هزار تومان پرداخت كردم', Space.personal)
          .amount,
      250000,
    ),
  );
  test('missing currency is not guessed', () {
    final e = parser.parse('سه عدد دفتر هرکدام پنجاه هزار', Space.business);
    expect(e.amount, null);
    expect(e.saveBlockReason, isNotNull);
  });
  test(
    'ambiguous amounts warn rather than disappear silently',
    () => expect(
      parser
          .parse('۵۰ هزار تومان نان و ۱۰۰ هزار تومان تاکسی', Space.personal)
          .reviewNote,
      isNotNull,
    ),
  );
  group('Arithmetic outputs', () {
    final cases = <String, double>{
      'بیست ضرب در صد و هشتاد هزار': 3600000,
      '۲ + ۳ × ۴': 14,
      'صد تقسیم بر چهار': 25,
      'دو و نیم به علاوه سه': 5.5,
      'ده منهای پانزده': -5,
      '۱ ÷ ۳': 1 / 3,
    };
    for (final c in cases.entries) {
      test(
        c.key,
        () => expect(
          parser.parse(c.key, Space.personal).calculationResult,
          closeTo(c.value, 1e-9),
        ),
      );
    }
    test(
      'divide by zero is not evaluated',
      () => expect(NoteParser.calculate('پنج تقسیم بر صفر'), null),
    );
    test(
      'prose not evaluated as arithmetic',
      () => expect(NoteParser.calculate('دو دفتر به علاوه سه مداد'), null),
    );
  });
  test(
    'TTS spells grouped money in Persian',
    () => expect(
      PersianSpeech.readable('۳٬۶۰۰٬۰۰۰ تومان'),
      'سه میلیون و ششصد هزار تومان',
    ),
  );
  test(
    'TTS math has speakable operators',
    () => expect(
      PersianSpeech.readable('۲۰ × ۱۸۰٬۰۰۰ = ۳٬۶۰۰٬۰۰۰'),
      'بیست ضرب در صد و هشتاد هزار برابر است با سه میلیون و ششصد هزار',
    ),
  );
  test('new calculations survive JSON storage', () {
    final e = parser.parse('بیست ضرب در پنج', Space.personal);
    expect(Entry.fromJson(e.toJson()).calculationResult, 100);
  });
}
