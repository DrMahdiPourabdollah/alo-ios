import 'package:uuid/uuid.dart';
import 'entry.dart';
import 'persian_text_normalizer.dart';
import 'persian_number_parser.dart';
import 'financial_calculation_engine.dart';
import 'legacy_math.dart';

class _NumberSpan {
  const _NumberSpan(this.start, this.end, this.value);
  final int start, end;
  final ExactNumber? value;
}

/// Conservative rules, not sentence lookup. Unclear fields block financial save.
class FinancialParser {
  static const units =
      r'کارتن|بسته|عدد|تا|دونه|دانه|جفت|کیلوگرم|کیلو|متر|لیتر|جعبه|دستگاه|کیسه|محصول';
  static const currency = r'تومان|تومن|ریال';
  static final unitPattern = RegExp('^($units)(?=\\s|\$)');
  static final currencyPattern = RegExp('^($currency)(?=\\s|\$)');
  static final pricePattern = RegExp(
    '(?:هر\\s+(?:$units)(?:\\s+(?:به قیمت|به مبلغ))?|دونه ای|دانه ای|واحدی|تکی|هر کدام|هرکدام|هر کدوم|هرکدوم|هر یک|کیلویی|کیلویى|کیلویی به قیمت|کیلوگرمی|متری|لیتری|کارتنی|بسته ای)(?:\\s+(?:به قیمت|به مبلغ))?\\s*\$',
  );
  List<_NumberSpan> _spans(String s) {
    final tokens = RegExp(r'\S+').allMatches(s).toList();
    final out = <_NumberSpan>[];
    for (var i = 0; i < tokens.length; i++) {
      if (!PersianNumberParser.isToken(tokens[i][0]!)) continue;
      final begin = i;
      while (i + 1 < tokens.length &&
          (PersianNumberParser.isToken(tokens[i + 1][0]!) ||
              tokens[i + 1][0] == 'و' &&
                  i + 2 < tokens.length &&
                  PersianNumberParser.isToken(tokens[i + 2][0]!))) {
        i++;
      }
      out.add(
        _NumberSpan(
          tokens[begin].start,
          tokens[i].end,
          PersianNumberParser.parse(
            s.substring(tokens[begin].start, tokens[i].end),
          ),
        ),
      );
    }
    return out;
  }

  Entry parse(String original, Space space, {DateTime? now}) {
    now ??= DateTime.now();
    final normalized = PersianTextNormalizer.normalize(original);
    final s =
        normalized
            .replaceAll(RegExp(r'(?<!\d)\.|\.(?!\d)|[،؛!؟?,]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    final issues = <String>[];
    var date = DateTime(now.year, now.month, now.day), dateNeedsReview = false;
    if (s.contains('پریروز')) {
      date = date.subtract(const Duration(days: 2));
    } else if (s.contains('دیروز')) {
      date = date.subtract(const Duration(days: 1));
    }
    final explicit = RegExp(
      r'(?<!\d)(1[34]\d{2}[/\-]\d{1,2}[/\-]\d{1,2})(?!\d)',
    ).firstMatch(s);
    if (explicit != null) {
      final d = parseDate(explicit[1]!);
      if (d == null) {
        dateNeedsReview = true;
      } else {
        date = d;
      }
    } else if (RegExp(
      r'(?:^|\s)(?:روز|هفته|ماه|شنبه|یکشنبه|دوشنبه|سه شنبه|چهارشنبه|پنجشنبه|جمعه|تاریخ|فردا|پس فردا|پسفردا)(?:\s|$)',
    ).hasMatch(
      s
          .replaceAll(
            RegExp(r'(?:فروشگاه|مغازه|رستوران|کافه|داروخانه|نانوایی)\s+\S+'),
            '',
          )
          .replaceAll('امروز', '')
          .replaceAll('دیروز', '')
          .replaceAll('پریروز', ''),
    )) {
      dateNeedsReview = true;
    }
    final safe = s.replaceAll(
      RegExp(r'1[34]\d{2}[/\-]\d{1,2}[/\-]\d{1,2}'),
      ' ',
    );
    final spans = _spans(safe);
    int? qty, price, amount;
    String? unit, person, merchant, merchantLabel, payment, sourceCurrency;
    String item = '';
    var amountCount = 0, quantityCount = 0, priceCount = 0;
    var hasMoneySignal = false;
    var unassignedNumbers = 0;
    for (final span in spans) {
      final before = safe.substring(0, span.start),
          tail = safe.substring(span.end).trimLeft();
      final u = unitPattern.firstMatch(tail),
          c = currencyPattern.firstMatch(tail);
      final perUnit = pricePattern.hasMatch(before);
      if (u == null && c == null && !perUnit) unassignedNumbers++;
      if (u != null) {
        quantityCount++;
        if (span.value?.integer == null || span.value!.integer! <= 0) {
          issues.add(
            'تعداد یا وزن گفته شده عدد صحیح و روشن نیست؛ آن را اصلاح کن.',
          );
        } else {
          qty = span.value!.integer;
          unit = ['تا', 'دونه', 'دانه', 'محصول'].contains(u[1]) ? 'عدد' : u[1];
        }
        item =
            tail
                .substring(u.end)
                .trim()
                .split(
                  RegExp(
                    r'\s+(?:از|هرکدام|هرکدوم|هر|به|آوردم|اوردم|خریدم|فروختم|گرفتم|خرید کردم|دونه ای|دانه ای|کیلویی|متری|لیتری|کارتنی|واحدی|تکی|بسته ای|جمعا|جمعاً)(?=\s|$)',
                  ),
                )
                .first
                .trim();
      }
      if (c != null || perUnit) {
        hasMoneySignal = true;
        if (perUnit) {
          priceCount++;
        } else {
          amountCount++;
        }
        final n = span.value?.integer;
        if (n == null || n <= 0) {
          issues.add('مبلغ باید دقیق، مثبت و به تومان صحیح قابل تبدیل باشد.');
          continue;
        }
        final curr = c?[1];
        if (curr == null) {
          issues.add('واحد پولِ قیمت مشخص نیست؛ تومان یا ریال را صریح بنویس.');
          continue;
        }
        if (sourceCurrency != null &&
            sourceCurrency != curr &&
            !(sourceCurrency != 'ریال' && curr != 'ریال')) {
          issues.add('واحدهای پول متفاوت‌اند؛ مبلغ‌ها را بررسی کن.');
        }
        sourceCurrency = curr == 'تومن' ? 'تومان' : curr;
        final v =
            curr == 'ریال' ? FinancialCalculationEngine.rialToToman(n) : n;
        if (v == null || v <= 0) {
          issues.add(
            'مبلغ ریالی به تومان صحیح تبدیل نمی‌شود؛ مبلغ را اصلاح کن.',
          );
          continue;
        }
        if (perUnit) {
          price = v;
        } else {
          amount = v;
        }
      }
    }
    if (quantityCount > 1 || priceCount > 1 || amountCount > 1) {
      issues.add(
        'این جمله چند تعداد یا چند مبلغ دارد؛ هر تراکنش را جدا ثبت کن.',
      );
      if (quantityCount > 1) qty = null;
      price = null;
      amount = null;
    }
    if (RegExp(r'منفی|[-−]\s*\d|یکم|حدود|تقریبا|تقریباً|شاید').hasMatch(safe)) {
      issues.add('مبلغ یا عبارت تقریبی/مبهم است؛ مقدار دقیق را مشخص کن.');
      amount = null;
      price = null;
    }
    final calculated =
        qty != null && price != null
            ? FinancialCalculationEngine.multiply(qty, price)
            : null;
    if (qty != null && price != null && calculated == null) {
      issues.add('مبلغ محاسبه شده از محدودهٔ مجاز بیشتر است.');
    }
    if (amount == null && amountCount == 0) amount = calculated;
    if (amount != null && calculated != null && amount != calculated) {
      issues.add(
        'مبلغ کل با تعداد ضرب در قیمت واحد برابر نیست؛ آن را اصلاح کن.',
      );
    }
    if (issues.isNotEmpty &&
        issues.any(
          (x) =>
              x.contains('تعداد یا وزن') ||
              x.contains('عدد صحیح') ||
              x.contains('چند تعداد'),
        )) {
      amount = null;
    }

    var intent = 'note';
    final payable = RegExp(
      r'(?:^|\s)(?:بدهکارم|بدهکاریم|(?:من|ما).*بدهکار (?:هستم|هستیم))(?=\s|$)',
    ).hasMatch(safe);
    final receivable = RegExp(
      r'(?:^|\s)(?:به (?:من|ما) بدهکار(?:ه| است| هست| هستند|ند)?|طلب (?:دارم|داریم)|از .+ طلب دارم)(?=\s|$)',
    ).hasMatch(safe);
    final income = RegExp(
      r'(?:^|\s)(?:درآمد|درامد|فروختم|فروش (?:داشتم|کردم)|از فروش|حقوق (?:گرفتم|واریز)|دریافت کردم)(?=\s|$)',
    ).hasMatch(safe);
    final expense = RegExp(
      r'(?:^|\s)(?:خرج|خریدم|خرید کردم|پرداخت|دادم|کارت (?:کشیدم|زدم)|آوردم|اوردم)(?=\s|$)',
    ).hasMatch(safe);
    if (payable) {
      intent = 'payable';
    } else if (receivable) {
      intent = 'receivable';
    } else if (income) {
      intent = 'income';
    } else if (expense ||
        quantityCount > 0 ||
        hasMoneySignal ||
        RegExp(currency).hasMatch(safe)) {
      intent = 'expense';
    }
    if (intent != 'note' && unassignedNumbers > 0) {
      issues.add('نقش بعضی عددهای جمله روشن نیست؛ آن ها را بررسی کن.');
    }
    if (income && expense) {
      issues.add('جمله هم دریافت و هم پرداخت دارد؛ تراکنش‌ها را جدا کن.');
    }
    if (RegExp(r'بدهکار|بدهکاره|بدهکاری|طلب').hasMatch(safe) &&
        !payable &&
        !receivable) {
      issues.add('جهت بدهی مشخص نیست؛ نوع تراکنش و طرف حساب را اصلاح کن.');
      intent = 'unknown';
    }
    final first = spans.isEmpty ? safe.length : spans.first.start;
    final leading = safe.substring(0, first).trim();
    String? cleanName(String? value) {
      if (value == null) return null;
      final n =
          value
              .replaceFirst(RegExp(r'^(?:امروز|دیروز|پریروز)\s+'), '')
              .replaceFirst(RegExp(r'^(?:آقای|خانم)\s+'), '')
              .trim();
      if (n.isEmpty ||
          n.length > 70 ||
          RegExp(
            r'\d|تومان|تومن|ریال|بدهکار|پرداخت|خرید|درآمد|هزار|میلیون|کالا|جنس|به قیمت',
          ).hasMatch(n) ||
          n == 'من' ||
          n == 'ما') {
        return null;
      }
      return n;
    }

    if (intent == 'payable') {
      person = cleanName(
        RegExp(r'به\s+(.+?)(?=\s+بدهکار)').firstMatch(safe)?[1],
      );
    } else if (intent == 'receivable') {
      person = cleanName(leading.replaceFirst(RegExp(r'^از\s+'), ''));
      person ??= cleanName(
        RegExp(r'از\s+(.+?)(?=\s+طلب|$)').firstMatch(leading)?[1],
      );
    }
    final merchantMatch = RegExp(
      r'(?:از|توی|تو|در)\s+((?:فروشگاه|مغازه|سوپرمارکت|سوپر|رستوران|داروخانه|نانوایی|کافه)\s+.+?)(?=\s+(?:خرید|با|به مبلغ|به قیمت|کارت)|$)',
    ).firstMatch(leading);
    if (merchantMatch != null) {
      merchantLabel = cleanName(merchantMatch[1]);
      merchant = merchantLabel?.replaceFirst(
        RegExp(
          r'^(?:فروشگاه|مغازه|سوپرمارکت|سوپر|رستوران|داروخانه|نانوایی|کافه)\s+',
        ),
        '',
      );
    }
    final from = RegExp(
      r'(?:از|به)\s+(.+?)(?=\s+(?:آوردم|اوردم|خریدم|خرید کردم|فروختم|گرفتم|دادم|هر|به مبلغ|به قیمت)|$)',
    ).firstMatch(leading);
    person ??= cleanName(from?[1]);
    // After quantity/item: "۲۰ کارتن ... از احمدی آوردم".
    if (person == null && intent != 'payable' && intent != 'receivable') {
      final masked = StringBuffer();
      var cursor = 0;
      for (final span in spans) {
        masked.write(safe.substring(cursor, span.start));
        masked.write(' # ');
        cursor = span.end;
      }
      masked.write(safe.substring(cursor));
      final m = RegExp(
        r'از\s+([^#]+?)(?=\s+(?:آوردم|اوردم|خریدم|خرید کردم|فروختم|گرفتم|هر|به قیمت)|#|$)',
      ).firstMatch(masked.toString());
      person = cleanName(m?[1]);
    }
    if (merchant != null) person = null;
    if ((intent == 'payable' || intent == 'receivable') && person == null) {
      issues.add('طرف حساب بدهی یا طلب روشن نیست؛ نام را اصلاح کن.');
    }
    if (RegExp(r'کارت\s*(?:کشیدم|زدم)|با کارت|کارت به کارت').hasMatch(safe)) {
      payment = 'کارت';
    } else if (safe.contains('نقد')) {
      payment = 'نقد';
    }
    String action;
    if (intent == 'payable') {
      action = 'بدهی';
    } else if (intent == 'receivable') {
      action = 'طلب';
    } else if (intent == 'income') {
      action = 'درآمد';
    } else if (intent == 'expense') {
      action =
          space == Space.business &&
                  (quantityCount > 0 ||
                      RegExp(r'خریدم|خرید کردم|آوردم|اوردم').hasMatch(safe))
              ? 'خرید کالا'
              : 'پرداخت';
    } else {
      action = 'یادداشت';
    }
    final legacy = LegacyMath.calculate(original);
    if (legacy != null && intent == 'note') issues.clear();
    if (intent != 'note' && (amount == null || amount <= 0)) {
      issues.add('مبلغ تراکنش کامل نیست؛ مبلغ دقیق را اصلاح کن.');
    }
    if (qty != null && price == null && intent != 'note') {
      issues.add('قیمت هر واحد مشخص نیست؛ آن را وارد کن.');
    }
    if (dateNeedsReview) issues.add('تاریخ گفته شده نیاز به بررسی دارد.');
    var title = merchantLabel ?? item;
    if (title.isEmpty) {
      title =
          RegExp(
            r'(?:بابت|برای)\s+(.+?)(?=\s+(?:خرج|پرداخت|دادم)|$)',
          ).firstMatch(safe)?[1]?.trim() ??
          '';
    }
    if (title.isEmpty) title = person == null ? action : '$action $person';
    if (title == 'یادداشت' || title.length > 100) title = 'یادداشت جدید';
    if (legacy != null && intent == 'note') title = 'محاسبهٔ عددی';
    final unique = issues.toSet().toList();
    return Entry(
      id: const Uuid().v4(),
      space: space,
      title: title,
      text: original.trim(),
      date: date,
      createdAt: now,
      amount: amount,
      quantity: qty,
      unit: unit,
      unitPrice: price,
      person: person,
      merchant: merchant,
      action: action,
      payment: payment,
      intent: intent,
      sourceCurrency: sourceCurrency,
      validationIssues: unique,
      dateNeedsReview: dateNeedsReview,
      reviewNote: unique.isEmpty ? null : unique.join('\n'),
      calculationResult: intent == 'note' ? legacy?.value : null,
      calculationExpression: intent == 'note' ? legacy?.expression : null,
    );
  }
}
