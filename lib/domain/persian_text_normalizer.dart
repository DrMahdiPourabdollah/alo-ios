import 'package:unorm_dart/unorm_dart.dart' as unicode;

class PersianTextNormalizer {
  static String normalize(String text) {
    var s = unicode
        .nfkc(text)
        .replaceAll('ي', 'ی')
        .replaceAll('ى', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ۀ', 'ه')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp('[\u064B-\u065F\u0670\u0640]'), '')
        .replaceAll(RegExp('[\u200c\u200d\u00a0]'), ' ')
        .replaceAll(RegExp('[\u200e\u200f\u202a-\u202e\u2066-\u2069]'), '');
    for (var i = 0; i < 10; i++) {
      s = s.replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i').replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i');
    }
    s = s
        .replaceAllMapped(
          RegExp(r'(?<![\d٬,])\d{1,3}(?:[٬,]\d{3})+(?!\d|[٬,]\d)'),
          (m) => m[0]!.replaceAll(RegExp('[٬,]'), ''),
        )
        .replaceAll('٫', '.')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    const replacements = {
      'هشت صد': 'هشتصد',
      'پان صد': 'پانصد',
      'پنج صد': 'پانصد',
      'چهار صد': 'چهارصد',
      'شش صد': 'ششصد',
      'هفت صد': 'هفتصد',
      'نه صد': 'نهصد',
      'سه صد': 'سیصد',
      'دو صد': 'دویست',
      'یک صد': 'صد',
      'پونصد': 'پانصد',
      'ملیون': 'میلیون',
    };
    for (final e in replacements.entries) {
      s = s.replaceAllMapped(
        RegExp('(^|\\s)${e.key}(?=\\s|[،؛.!؟]|\$)'),
        (m) => '${m[1]}${e.value}',
      );
    }
    return s
        .replaceAllMapped(
          RegExp(
            r'(^|\s)(هزار|میلیون|میلیارد|بیست|سی|چهل|پنجاه|شصت|هفتاد|هشتاد|نود|دویست|سیصد|پانصد)و(?=\s|$)',
          ),
          (m) => '${m[1]}${m[2]} و',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
