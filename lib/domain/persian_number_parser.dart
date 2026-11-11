import 'persian_text_normalizer.dart';

/// Exact rational arithmetic; no floating point in financial number conversion.
class ExactNumber {
  ExactNumber(BigInt n, [BigInt? d])
    : numerator = n,
      denominator = d ?? BigInt.one;
  final BigInt numerator, denominator;
  ExactNumber operator +(ExactNumber other) => ExactNumber(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );
  ExactNumber operator *(int value) =>
      ExactNumber(numerator * BigInt.from(value), denominator);
  int? get integer => numerator % denominator == BigInt.zero
      ? (numerator ~/ denominator).toInt()
      : null;
  bool get valid =>
      numerator >= BigInt.zero &&
      numerator <= BigInt.from(100000000000000) * denominator;
  double get asDouble =>
      numerator.toDouble() /
      denominator.toDouble(); // Legacy non-financial calculator only.
}

class PersianNumberParser {
  static const words = {
    'صفر': 0,
    'یک': 1,
    'یه': 1,
    'دو': 2,
    'سه': 3,
    'چهار': 4,
    'چار': 4,
    'پنج': 5,
    'شش': 6,
    'شیش': 6,
    'هفت': 7,
    'هشت': 8,
    'نه': 9,
    'ده': 10,
    'یازده': 11,
    'دوازده': 12,
    'سیزده': 13,
    'چهارده': 14,
    'پانزده': 15,
    'پونزده': 15,
    'شانزده': 16,
    'شونزده': 16,
    'هفده': 17,
    'هیفده': 17,
    'هجده': 18,
    'هیجده': 18,
    'نوزده': 19,
    'بیست': 20,
    'سی': 30,
    'چهل': 40,
    'پنجاه': 50,
    'شصت': 60,
    'هفتاد': 70,
    'هشتاد': 80,
    'نود': 90,
    'صد': 100,
    'یکصد': 100,
    'دویست': 200,
    'سیصد': 300,
    'چهارصد': 400,
    'پانصد': 500,
    'ششصد': 600,
    'هفتصد': 700,
    'هشتصد': 800,
    'نهصد': 900,
  };
  static const scales = {
    'هزار': 1000,
    'میلیون': 1000000,
    'میلیارد': 1000000000,
  };
  static bool isToken(String token) =>
      words.containsKey(token) ||
      scales.containsKey(token) ||
      token == 'نیم' ||
      token == 'ممیز' ||
      RegExp(r'^\d+(?:\.\d+)?$').hasMatch(token);
  static ExactNumber? parse(String input) {
    final s = PersianTextNormalizer.normalize(input);
    if (s.isEmpty) return null;
    final tokens = s.split(' ');
    if (tokens.first == 'و' ||
        tokens.last == 'و' ||
        List.generate(
          tokens.length - 1,
          (i) => tokens[i] == 'و' && tokens[i + 1] == 'و',
        ).contains(true)) {
      return null;
    }
    if (tokens.any((t) => t != 'و' && !isToken(t))) return null;
    var total = ExactNumber(BigInt.zero), lastScale = 0;
    var group = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      final scale = scales[t];
      if (scale == null) {
        group.add(t);
        continue;
      }
      if (group.isNotEmpty && group.first == 'و') group.removeAt(0);
      final g = group.isEmpty
          ? ExactNumber(
              lastScale > 0 && scale > lastScale ? BigInt.zero : BigInt.one,
            )
          : _group(group);
      if (g == null) return null;
      // Repeating a scale without a new explicit group is ambiguous,
      // e.g. "هزار هزار" must not silently become two thousand.
      if (lastScale == scale && group.isEmpty) return null;
      if (lastScale > 0 && scale > lastScale) {
        total = (total + g) * scale;
      } else {
        total = total + g * scale;
      }
      lastScale = scale;
      group = [];
    }
    if (group.isNotEmpty && group.first == 'و') group.removeAt(0);
    if (group.length == 1 && group.single == 'نیم' && lastScale > 0) {
      total = total + ExactNumber(BigInt.from(lastScale), BigInt.two);
    } else if (group.isNotEmpty) {
      final g = _group(group);
      if (g == null) return null;
      total = total + g;
    }
    return total.valid ? total : null;
  }

  static int? integer(String text) => parse(text)?.integer;
  static ExactNumber? _group(List<String> input) {
    final ts = List<String>.of(input);
    if (ts.isEmpty || ts.last == 'و' || ts.first == 'و') return null;
    final decimal = ts.indexOf('ممیز');
    if (decimal >= 0) {
      if (decimal == 0 ||
          decimal == ts.length - 1 ||
          ts.lastIndexOf('ممیز') != decimal) {
        return null;
      }
      final whole = _group(ts.sublist(0, decimal));
      final right = ts.sublist(decimal + 1);
      if (whole?.integer == null) return null;
      String raw;
      if (right.every(
        (t) =>
            RegExp(r'^\d$').hasMatch(t) ||
            (words[t] != null && words[t]! >= 0 && words[t]! < 10),
      )) {
        raw = right.map((t) => words.containsKey(t) ? '${words[t]}' : t).join();
      } else {
        final fraction = _group(right);
        if (fraction?.integer == null) return null;
        raw = right.length == 1 && RegExp(r'^\d+$').hasMatch(right.single)
            ? right.single
            : '${fraction!.integer}';
      }
      return whole! +
          ExactNumber(BigInt.parse(raw), BigInt.from(10).pow(raw.length));
    }
    if (ts.last == 'نیم') {
      if (ts.length == 1) return ExactNumber(BigInt.one, BigInt.two);
      if (ts[ts.length - 2] != 'و') return null;
      final whole = _group(ts.sublist(0, ts.length - 2));
      if (whole?.integer == null) return null;
      return whole! + ExactNumber(BigInt.one, BigInt.two);
    }
    if (ts.length == 1 && RegExp(r'^\d+(?:\.\d+)?$').hasMatch(ts.single)) {
      final p = ts.single.split('.');
      return ExactNumber(
        BigInt.parse(p.join()),
        p.length == 1 ? BigInt.one : BigInt.from(10).pow(p[1].length),
      );
    }
    var value = 0, previousCategory = 4;
    for (var i = 0; i < ts.length; i++) {
      if (i.isOdd) {
        if (ts[i] != 'و') return null;
        continue;
      }
      final n = words[ts[i]];
      if (n == null) return null;
      final category = n >= 100
          ? 3
          : n >= 20
          ? 2
          : 1;
      if (category >= previousCategory || n == 0 && ts.length > 1) return null;
      previousCategory = category;
      value += n;
    }
    if (ts.length.isEven) return null;
    return ExactNumber(BigInt.from(value));
  }
}
