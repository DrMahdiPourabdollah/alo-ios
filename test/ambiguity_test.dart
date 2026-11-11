import 'package:flutter_test/flutter_test.dart';
import 'package:alo_simple/domain/entry.dart';
import 'package:alo_simple/domain/parser.dart';

void main() {
  test('scaled decimal money produces exact integer tomans', () {
    expect(
      NoteParser().parse('۲.۵ میلیون تومان پرداخت کردم', Space.personal).amount,
      2500000,
    );
  });
  test('spoken half with explicit currency scale is supported', () {
    expect(
      NoteParser().parse('یک و نیم میلیون تومان دادم', Space.personal).amount,
      1500000,
    );
  });
  test('does not choose one of two totals', () {
    expect(
      NoteParser()
          .parse('۵۰ هزار تومان نان و ۱۰۰ هزار تومان تاکسی', Space.personal)
          .amount,
      null,
    );
  });
  test('negative amount remains in original note', () {
    final e = NoteParser().parse('منفی پنج هزار تومان', Space.personal);
    expect(e.amount, null);
    expect(e.text, 'منفی پنج هزار تومان');
  });
  test('tomorrow requires explicit date review', () {
    expect(
      NoteParser()
          .parse('فردا ۵۰ هزار تومان پرداخت می‌کنم', Space.personal)
          .dateNeedsReview,
      true,
    );
  });
  test('product name is not mistaken for a date', () {
    expect(
      NoteParser().parse('ماهیتابه خریدم', Space.personal).dateNeedsReview,
      false,
    );
  });
  test('zero is never converted into one thousand', () {
    expect(NoteParser.number('صفر هزار'), 0);
  });
  test('multiple quantities are not silently merged', () {
    final e = NoteParser().parse(
      '۲۰ کارتن دفتر و ۱۰ عدد قلم آوردم',
      Space.business,
    );
    expect(e.quantity, null);
    expect(e.amount, null);
  });
}
