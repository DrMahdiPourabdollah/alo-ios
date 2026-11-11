import 'tts_engine_stub.dart' if (dart.library.io) 'tts_engine_native.dart';
import '../domain/entry.dart';

/// Bundled Persian Piper voice, with spoken number expansion.
class PersianSpeech {
  final _engine = TtsEngine();
  Future<void> speak(String text) => _engine.speak(readable(text));
  Future<void> stop() => _engine.stop();
  Future<void> dispose() => _engine.dispose();

  static String readable(String text) {
    var s = latinDigits(text)
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('\u200c', ' ')
        .replaceAllMapped(RegExp(r'\d[\d٬,]*(?:[٫.]\d+)?'), (m) {
          final value = m[0]!
              .replaceAll(RegExp('[٬,]'), '')
              .replaceAll('٫', '.');
          final parts = value.split('.');
          final n = int.tryParse(parts.first);
          if (n == null || n > 100000000000000) return m[0]!;
          final integer = words(n);
          if (parts.length == 1) return integer;
          return '$integer ممیز ${parts[1].split('').map((d) => words(int.parse(d))).join(' ')}';
        });
    s = s
        .replaceAll('×', ' ضرب در ')
        .replaceAll('÷', ' تقسیم بر ')
        .replaceAll('=', ' برابر است با ')
        .replaceAll('+', ' به علاوه ')
        .replaceAll('−', ' منهای ')
        .replaceAll('٪', ' درصد ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String words(int n) {
    const small = [
      'صفر',
      'یک',
      'دو',
      'سه',
      'چهار',
      'پنج',
      'شش',
      'هفت',
      'هشت',
      'نه',
      'ده',
      'یازده',
      'دوازده',
      'سیزده',
      'چهارده',
      'پانزده',
      'شانزده',
      'هفده',
      'هجده',
      'نوزده',
    ];
    const tens = [
      '',
      '',
      'بیست',
      'سی',
      'چهل',
      'پنجاه',
      'شصت',
      'هفتاد',
      'هشتاد',
      'نود',
    ];
    const hundreds = [
      '',
      'صد',
      'دویست',
      'سیصد',
      'چهارصد',
      'پانصد',
      'ششصد',
      'هفتصد',
      'هشتصد',
      'نهصد',
    ];
    if (n < 0) return 'منفی ${words(-n)}';
    if (n < 20) return small[n];
    for (final scale
        in <int, String>{
          1000000000000: 'تریلیون',
          1000000000: 'میلیارد',
          1000000: 'میلیون',
          1000: 'هزار',
        }.entries) {
      if (n >= scale.key) {
        return '${words(n ~/ scale.key)} ${scale.value}${n % scale.key == 0 ? '' : ' و ${words(n % scale.key)}'}';
      }
    }
    if (n >= 100) {
      return '${hundreds[n ~/ 100]}${n % 100 == 0 ? '' : ' و ${words(n % 100)}'}';
    }
    return '${tens[n ~/ 10]}${n % 10 == 0 ? '' : ' و ${words(n % 10)}'}';
  }
}
