import 'entry.dart';
import 'persian_text_normalizer.dart';
import 'persian_number_parser.dart';

/// Existing non-financial calculator, retained for compatibility only.
class LegacyMath {
  /// Only a complete arithmetic utterance is evaluated, with normal precedence.
  static ({String expression, double value})? calculate(String input) {
    var s =
        PersianTextNormalizer.normalize(input)
            .replaceAll(RegExp(r'^(?:حاصل|محاسبه|حساب کن)\s+'), '')
            .replaceAll(
              RegExp(
                r'\s*(?:چقدر (?:می شود|میشه)|برابر است با|مساوی|حساب کن)[؟?!.]*$',
              ),
              '',
            )
            .replaceAll(RegExp(r'[؟?!]+$'), '')
            .trim();
    for (final item
        in <String, String>{
          'ضرب در': '*',
          'ضربدر': '*',
          'تقسیم بر': '/',
          'تقسیم': '/',
          'به علاوه': '+',
          'بعلاوه': '+',
          'جمع با': '+',
          'منهای': '-',
          '×': '*',
          '÷': '/',
          '−': '-',
        }.entries) {
      s = s.replaceAll(item.key, item.value);
    }
    if (!RegExp(r'[+*/-]').hasMatch(s)) return null;
    final parts = s.split(RegExp(r'([+*/-])'));
    final ops = RegExp(r'[+*/-]').allMatches(s).map((m) => m[0]!).toList();
    if (parts.length < 2 || parts.length != ops.length + 1) return null;
    final values = <double>[];
    for (final part in parts) {
      final n = PersianNumberParser.parse(part.trim())?.asDouble;
      if (n == null) return null;
      values.add(n);
    }
    final display = <String>[];
    for (var i = 0; i < values.length; i++) {
      display.add(formatNumeric(values[i]));
      if (i < ops.length) {
        display.add({'*': '×', '/': '÷', '+': '+', '-': '−'}[ops[i]]!);
      }
    }
    for (var i = 0; i < ops.length;) {
      if (ops[i] == '*' || ops[i] == '/') {
        if (ops[i] == '/' && values[i + 1] == 0) return null;
        values[i] =
            ops[i] == '*'
                ? values[i] * values[i + 1]
                : values[i] / values[i + 1];
        values.removeAt(i + 1);
        ops.removeAt(i);
      } else {
        i++;
      }
    }
    var result = values.first;
    for (var i = 0; i < ops.length; i++) {
      result += ops[i] == '+' ? values[i + 1] : -values[i + 1];
    }
    if (!result.isFinite || result.abs() > 100000000000000) return null;
    return (expression: display.join(' '), value: result);
  }
}
