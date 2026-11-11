import 'package:flutter_test/flutter_test.dart';
import 'package:alo_simple/domain/entry.dart';
import 'package:alo_simple/domain/financial_book.dart';
import 'finance_v24_test.dart' show sample;

void main() {
  for (final text in [
    'پانصد هزار تومان',
    'بودجه خرید پنج میلیون تومان',
    'اگر پنج میلیون تومان درآمد داشتم',
    'پنج میلیون تومان وام دریافت کردم',
    'پنج میلیون تومان قرض گرفتم',
    'پانصد هزار تومان قسط پرداخت کردم',
    'میخواهم پانصد هزار تومان خرید کنم',
  ]) {
    test('no guessing financial type: $text', () {
      final e = FinancialBatch.parse(text, Space.personal).single;
      expect(e.intent, 'unknown');
      expect(e.saveBlockReason, isNotNull);
    });
  }
  test('unrelated money cannot reduce debt', () {
    final now = DateTime(2026, 10, 4),
        d = sample('d', 'payable', 800, DateTime(2026, 10, 1), person: 'علی'),
        wrong = sample('w', 'expense', 100, now, related: 'd');
    expect(FinancialBook.remaining(d, [d, wrong]), 800);
    expect(FinancialBook.validateRelations([d, wrong]), isNotNull);
  });
}
