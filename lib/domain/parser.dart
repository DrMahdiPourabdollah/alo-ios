import 'entry.dart';
import 'financial_parser.dart';
import 'persian_text_normalizer.dart';
import 'persian_number_parser.dart';
import 'legacy_math.dart';

/// Compatibility facade; financial logic lives in independent modules.
class NoteParser {
  static String normalize(String input) =>
      PersianTextNormalizer.normalize(input);
  static int? number(String input) => PersianNumberParser.integer(input);
  static double? decimalValue(String input) =>
      PersianNumberParser.parse(input)?.asDouble;
  static ({String expression, double value})? calculate(String input) =>
      LegacyMath.calculate(input);
  Entry parse(String text, Space space, {DateTime? now}) =>
      FinancialParser().parse(text, space, now: now);
}
