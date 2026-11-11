import 'entry.dart';
import 'financial_parser.dart';
import 'persian_text_normalizer.dart';
import 'package:uuid/uuid.dart';
import 'package:shamsi_date/shamsi_date.dart';

const financialKinds = {
  'expense': 'هزینه',
  'income': 'درآمد',
  'receivable': 'مطالبات',
  'payable': 'بدهی',
  'transfer': 'انتقال بین حساب‌ها',
  'payable_payment': 'پرداخت بدهی',
  'receivable_collection': 'وصول مطالبات',
  'unknown': 'نیازمند بررسی',
};
const financialCategories = [
  'سایر',
  'خوراک',
  'خرید',
  'رفت‌وآمد',
  'خانه',
  'سلامت',
  'آموزش',
  'قبوض',
  'تفریح',
  'حقوق',
  'فروش',
];
Entry revise(Entry e, Map<String, Object?> fields) =>
    Entry.fromJson({...e.toJson(), ...fields});
String inferCategory(String text, String intent) {
  if (intent == 'income') {
    if (text.contains('حقوق')) return 'حقوق';
    if (text.contains('فروش')) return 'فروش';
  }
  for (final pair
      in <String, List<String>>{
        'خوراک': ['برنج', 'نان', 'غذا', 'میوه', 'تخم مرغ', 'آب معدنی'],
        'رفت‌وآمد': ['تاکسی', 'اسنپ', 'بنزین', 'اتوبوس'],
        'سلامت': ['دارو', 'پزشک', 'درمان'],
        'خانه': ['اجاره', 'خانه'],
        'قبوض': ['قبض'],
        'آموزش': ['کتاب', 'کلاس'],
        'تفریح': ['سینما', 'سفر'],
      }.entries) {
    if (pair.value.any(text.contains)) return pair.key;
  }
  return intent == 'expense' && RegExp('خرید|خریدم').hasMatch(text)
      ? 'خرید'
      : 'سایر';
}

class FinancialBatch {
  static List<Entry> parse(
    String text,
    Space space, {
    DateTime? now,
    String? rawTranscript,
  }) {
    now ??= DateTime.now();
    final parser = FinancialParser();
    final normalized = PersianTextNormalizer.normalize(text);
    final parts = <String>[];
    void segment(String input, int depth) {
      if (depth > 20) {
        parts.add(input);
        return;
      }
      final candidates = RegExp(
        r'[؛;\n!?؟]+|[،,]\s*|\s+و\s+|\.\s+(?=[^\d])',
      ).allMatches(input);
      for (final m in candidates) {
        final left = input.substring(0, m.start).trim(),
            right = input.substring(m.end).trim();
        if (left.isEmpty ||
            right.isEmpty ||
            RegExp(
              r'^(?:هر|دونه|دانه|کیلویی|کارتنی|جمعا|جمعاً|مبلغ کل|قیمت)',
            ).hasMatch(right)) {
          continue;
        }
        final a = parser.parse(left, space, now: now);
        final b = parser.parse(right, space, now: now);
        if (a.isFinancial &&
            a.saveBlockReason == null &&
            b.isFinancial &&
            RegExp(
              r'خریدم|خرید کردم|خرج|پرداخت|درآمد|درامد|حقوق|فروختم|بدهکار|طلب|کارت کشیدم|دریافت کردم',
            ).hasMatch(right)) {
          parts.add(left);
          segment(right, depth + 1);
          return;
        }
      }
      parts.add(input.trim());
    }

    segment(normalized, 0);
    final source = const Uuid().v4();
    return parts.map((part) {
      final sharedDate =
          RegExp(r'^(امروز|دیروز|پریروز)(?=\s)').firstMatch(normalized)?[1];
      final hasOwnDate = RegExp(
        r'امروز|دیروز|پریروز|تاریخ|\d{4}[/\-]',
      ).hasMatch(part);
      final e = parser.parse(
        sharedDate != null && !hasOwnDate ? '$sharedDate $part' : part,
        space,
        now: now,
      );
      final extra = <String>[];
      var kind = e.intent;
      if (kind == 'note') {
        kind = 'unknown';
        extra.add('رویداد مالی روشن نیست. نوع و مبلغ تراکنش را مشخص کنید.');
      }
      if (RegExp(
        r'نخریدم|نپرداختم|خرج نکردم|پرداخت نکردم|بدهکار نیست|درآمد نداشتم',
      ).hasMatch(part)) {
        kind = 'unknown';
        extra.add('جمله دارای نفی است. ثبت مالی به بررسی دستی نیاز دارد.');
      }
      if (RegExp(
        r'وام گرفتم|دریافت وام|تسویه|انتقال بین حساب|حساب خودم.*حساب',
      ).hasMatch(part)) {
        kind = 'unknown';
        extra.add(
          'برای انتقال یا تسویه، نوع و حساب‌های مرتبط را دستی انتخاب کنید.',
        );
      }
      final explicitExpense =
          RegExp(
            r'خریدم|خرید کردم|خرید|خرج|پرداخت|دادم|کارت کشیدم|کارت زدم|آوردم|اوردم',
          ).hasMatch(part) ||
          (e.quantity != null &&
              e.unitPrice != null &&
              RegExp(r'گرفتم|آوردم|اوردم').hasMatch(part));
      final explicitIncome = RegExp(
        r'درآمد|درامد|فروختم|از فروش|حقوق گرفتم|حقوق واریز|حقوقم واریز|دریافت کردم',
      ).hasMatch(part);
      final debtSignal = RegExp(r'بدهکار|طلب').hasMatch(part);
      if (!explicitExpense && !explicitIncome && !debtSignal) {
        kind = 'unknown';
        extra.add(
          'مبلغ به‌تنهایی نوع رویداد مالی را مشخص نمی‌کند. نوع تراکنش را انتخاب کنید.',
        );
      }
      if (RegExp(
        r'(?:^|\s)(?:وام|قرض|اقساط|قسط|بودجه|برآورد|اگر|شاید)(?:\s|$)|می خواهم|میخواهم|میخوام|قرار است',
      ).hasMatch(part)) {
        kind = 'unknown';
        extra.add(
          'وام، برنامه یا مبلغ فرضی، درآمد یا هزینه قطعی محسوب نمی‌شود. جزئیات را بررسی کنید.',
        );
      }
      if (e.person != null &&
          RegExp(r'(?:به|از)\s').hasMatch(part) &&
          RegExp(r'دادم|گرفتم|دریافت کردم').hasMatch(part) &&
          !RegExp(
            r'بابت|برای|خریدم|خرید|فروش|حقوق|بدهکار|طلب|خرج',
          ).hasMatch(part)) {
        kind = 'unknown';
        extra.add(
          'نوع پرداخت یا دریافت از شخص روشن نیست؛ احتمال قرض یا تسویه را بررسی کنید.',
        );
      }
      final issues = [...e.validationIssues, ...extra];
      return revise(e, {
        'intent': kind,
        'category': inferCategory(part, kind),
        'sourceId': source,
        'rawTranscript': rawTranscript ?? text,
        'validationIssues': issues,
        'reviewNote': issues.isEmpty ? null : issues.join('\n'),
      });
    }).toList();
  }
}

class ReportWindow {
  const ReportWindow(this.start, this.end, this.label);
  final DateTime start, end;
  final String label;
  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
  static ReportWindow make(String kind, DateTime reference) {
    final d = DateTime(reference.year, reference.month, reference.day);
    final j = Jalali.fromDateTime(d);
    if (kind == 'روز') {
      return ReportWindow(
        d,
        DateTime(d.year, d.month, d.day + 1),
        'گزارش روزانه',
      );
    }
    if (kind == 'هفته') {
      final s = DateTime(d.year, d.month, d.day - (d.weekday + 1) % 7);
      return ReportWindow(
        s,
        DateTime(s.year, s.month, s.day + 7),
        'گزارش هفتگی',
      );
    }
    if (kind == 'سال') {
      return ReportWindow(
        Jalali(j.year, 1, 1).toDateTime(),
        Jalali(j.year + 1, 1, 1).toDateTime(),
        'گزارش سالانه',
      );
    }
    if (kind == 'همه') {
      return ReportWindow(DateTime(1900), DateTime(2200), 'تمام تراکنش‌ها');
    }
    return ReportWindow(
      Jalali(j.year, j.month, 1).toDateTime(),
      (j.month == 12
              ? Jalali(j.year + 1, 1, 1)
              : Jalali(j.year, j.month + 1, 1))
          .toDateTime(),
      'گزارش ماهانه',
    );
  }
}

class FinancialReport {
  FinancialReport(List<Entry> all, this.window, {Space? space})
    : rows =
          all
              .where(
                (e) =>
                    e.isFinancial &&
                    e.intent != 'unknown' &&
                    e.saveBlockReason == null &&
                    (space == null || e.space == space),
              )
              .toList();
  final ReportWindow window;
  final List<Entry> rows;
  List<Entry> get period =>
      rows.where((e) => window.contains(e.date)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  BigInt total(String kind) => period
      .where((e) => e.intent == kind)
      .fold(BigInt.zero, (a, e) => a + BigInt.from(e.amount!));
  BigInt get income => total('income');
  BigInt get expense => total('expense');
  BigInt get net => income - expense;
  BigInt get cashIn => income + total('receivable_collection');
  BigInt get cashOut => expense + total('payable_payment');
  BigInt outstanding(String kind) {
    final asOf = rows.where((e) => e.date.isBefore(window.end));
    final principal = asOf
        .where((e) => e.intent == kind)
        .fold(BigInt.zero, (a, e) => a + BigInt.from(e.amount!));
    final paid = asOf
        .where(
          (e) =>
              e.intent ==
              (kind == 'payable' ? 'payable_payment' : 'receivable_collection'),
        )
        .fold(BigInt.zero, (a, e) => a + BigInt.from(e.amount!));
    return principal - paid;
  }

  Map<String, BigInt> get categories {
    final result = <String, BigInt>{};
    for (final e in period.where((e) => e.intent == 'expense')) {
      result[e.category] =
          (result[e.category] ?? BigInt.zero) + BigInt.from(e.amount!);
    }
    return result;
  }

  Map<DateTime, ({BigInt income, BigInt expense})> get daily {
    final result = <DateTime, ({BigInt income, BigInt expense})>{};
    for (final e in period.where(
      (e) => ['expense', 'income'].contains(e.intent),
    )) {
      final d = DateTime(e.date.year, e.date.month, e.date.day),
          old = result[d] ?? (income: BigInt.zero, expense: BigInt.zero);
      result[d] = (
        income:
            old.income +
            (e.intent == 'income' ? BigInt.from(e.amount!) : BigInt.zero),
        expense:
            old.expense +
            (e.intent == 'expense' ? BigInt.from(e.amount!) : BigInt.zero),
      );
    }
    return result;
  }
}

class FinancialBook {
  static int remaining(Entry debt, List<Entry> all, {String? excluding}) {
    final paid = all
        .where(
          (e) =>
              e.relatedId == debt.id &&
              e.id != excluding &&
              e.intent ==
                  (debt.intent == 'payable'
                      ? 'payable_payment'
                      : 'receivable_collection'),
        )
        .fold(BigInt.zero, (a, e) => a + BigInt.from(e.amount ?? 0));
    return (BigInt.from(debt.amount ?? 0) - paid).toInt();
  }

  static String? validateRelations(List<Entry> all) {
    for (final e in all) {
      if (e.relatedId != null &&
          !['payable_payment', 'receivable_collection'].contains(e.intent)) {
        return 'ارتباط تسویه فقط برای پرداخت بدهی یا وصول مطالبه مجاز است.';
      }
      if (!['payable_payment', 'receivable_collection'].contains(e.intent)) {
        continue;
      }
      final matches = all.where((d) => d.id == e.relatedId).toList();
      if (matches.length != 1) return 'بدهی یا مطالبه مرتبط موجود نیست.';
      final d = matches.single;
      if (d.intent !=
              (e.intent == 'payable_payment' ? 'payable' : 'receivable') ||
          d.space != e.space ||
          d.person != e.person) {
        return 'نوع یا طرف حساب تسویه با تراکنش اصلی مطابقت ندارد.';
      }
      if (e.date.isBefore(d.date)) {
        return 'تاریخ تسویه نمی‌تواند پیش از تاریخ بدهی یا مطالبه باشد.';
      }
      if (remaining(d, all) < 0) {
        return 'مبلغ تسویه از مانده بدهی یا مطالبه بیشتر است.';
      }
    }
    return null;
  }
}

String bigMoney(BigInt value) => digits(
  value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}٬',
  ),
);
