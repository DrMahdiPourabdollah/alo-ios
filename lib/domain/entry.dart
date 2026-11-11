import 'package:shamsi_date/shamsi_date.dart';
import 'financial_calculation_engine.dart';

enum Space { personal, business }

extension SpaceLabel on Space {
  String get label => this == Space.personal ? 'شخصی' : 'کسب‌وکار';
}

class Entry {
  const Entry({
    required this.id,
    required this.space,
    required this.title,
    required this.text,
    required this.date,
    required this.createdAt,
    this.rawTranscript,
    this.category = 'سایر',
    this.account = 'حساب اصلی',
    this.counterAccount,
    this.relatedId,
    this.sourceId,
    this.intent = 'note',
    this.merchant,
    this.sourceCurrency,
    this.validationIssues = const [],
    this.manuallyReviewed = false,
    this.calculationResult,
    this.calculationExpression,
    this.reviewNote,
    this.amount,
    this.quantity,
    this.unit,
    this.unitPrice,
    this.person,
    this.action = 'یادداشت',
    this.payment,
    this.dateNeedsReview = false,
  });
  final String id;
  final Space space;
  final String title, text, action;
  final DateTime date, createdAt;
  final int? amount, quantity, unitPrice;
  final String? unit, person, payment, merchant, sourceCurrency;
  final String intent;
  final String category, account;
  final String? counterAccount, relatedId, sourceId;
  final String? rawTranscript;
  final List<String> validationIssues;
  final bool manuallyReviewed;
  bool get isFinancial => intent != 'note';
  String? get saveBlockReason {
    if (!isFinancial) return null;
    if (title.trim().isEmpty) return 'شرح تراکنش را وارد کنید.';
    if (![
      'expense',
      'income',
      'payable',
      'receivable',
      'transfer',
      'payable_payment',
      'receivable_collection',
    ].contains(intent)) {
      return 'نوع تراکنش مشخص نیست؛ آن را اصلاح کن.';
    }
    if (amount == null || amount! <= 0) return 'مبلغ دقیق و مثبت را وارد کن.';
    if (amount! > 100000000000000) return 'مبلغ از محدودهٔ مجاز بیشتر است.';
    if (account.trim().isEmpty) return 'حساب مرتبط را مشخص کنید.';
    if (intent == 'transfer' &&
        (counterAccount == null ||
            counterAccount!.trim().isEmpty ||
            counterAccount == account)) {
      return 'حساب مبدأ و مقصد باید مشخص و متفاوت باشند.';
    }
    if (['payable_payment', 'receivable_collection'].contains(intent) &&
        relatedId == null) {
      return 'بدهی یا مطالبه مرتبط را انتخاب کنید.';
    }
    if (dateNeedsReview) return 'تاریخ را اصلاح کن.';
    if ((intent == 'payable' || intent == 'receivable') &&
        (person ?? '').trim().isEmpty) {
      return 'نام طرف حساب را وارد کن.';
    }
    if (quantity != null &&
        (quantity! <= 0 || unitPrice == null || unitPrice! <= 0)) {
      return 'تعداد و قیمت واحد را کامل وارد کن.';
    }
    if (unitPrice != null && quantity == null) {
      return 'تعداد مشخص نیست؛ آن را کامل کن.';
    }
    if (quantity != null && unitPrice != null && calculatedTotal == null) {
      return 'نتیجهٔ محاسبه از محدودهٔ مجاز بیشتر است.';
    }
    if (calculatedTotal != null && calculatedTotal != amount) {
      return 'مبلغ کل با تعداد و قیمت واحد برابر نیست.';
    }
    if (!manuallyReviewed && validationIssues.isNotEmpty) {
      return 'اطلاعات مبهم است؛ بخش اصلاح را بررسی و تأیید کن.';
    }
    return null;
  }

  final bool dateNeedsReview;
  final double? calculationResult;
  final String? calculationExpression, reviewNote;
  int? get calculatedTotal =>
      quantity != null && unitPrice != null
          ? FinancialCalculationEngine.multiply(quantity!, unitPrice!)
          : null;
  Map<String, Object?> toJson() => {
    'rawTranscript': rawTranscript,
    'category': category,
    'account': account,
    'counterAccount': counterAccount,
    'relatedId': relatedId,
    'sourceId': sourceId,
    'intent': intent,
    'merchant': merchant,
    'sourceCurrency': sourceCurrency,
    'validationIssues': validationIssues,
    'manuallyReviewed': manuallyReviewed,
    'calculationResult': calculationResult,
    'calculationExpression': calculationExpression,
    'reviewNote': reviewNote,
    'id': id,
    'space': space.name,
    'title': title,
    'text': text,
    'date': date.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'amount': amount,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'person': person,
    'action': action,
    'payment': payment,
    'dateNeedsReview': dateNeedsReview,
  };
  factory Entry.fromJson(Map<String, dynamic> m) => Entry(
    rawTranscript: m['rawTranscript'] as String?,
    category: m['category'] as String? ?? 'سایر',
    account: m['account'] as String? ?? 'حساب اصلی',
    counterAccount: m['counterAccount'] as String?,
    relatedId: m['relatedId'] as String?,
    sourceId: m['sourceId'] as String?,
    intent:
        m['intent'] as String? ??
        (['پرداخت', 'خرید کالا'].contains(m['action'])
            ? 'expense'
            : m['action'] == 'فروش'
            ? 'income'
            : 'note'),
    merchant: m['merchant'] as String?,
    sourceCurrency: m['sourceCurrency'] as String?,
    validationIssues:
        (m['validationIssues'] as List?)?.cast<String>() ?? const [],
    manuallyReviewed: m['manuallyReviewed'] == true,
    calculationResult: (m['calculationResult'] as num?)?.toDouble(),
    calculationExpression: m['calculationExpression'] as String?,
    reviewNote: m['reviewNote'] as String?,
    id: m['id'] as String,
    space: Space.values.byName(m['space'] as String),
    title: m['title'] as String,
    text: m['text'] as String,
    date: DateTime.parse(m['date'] as String),
    createdAt: DateTime.parse(m['createdAt'] as String),
    amount: _exactStoredInteger(m['amount']),
    quantity: _exactStoredInteger(m['quantity']),
    unitPrice: _exactStoredInteger(m['unitPrice']),
    unit: m['unit'] as String?,
    person: m['person'] as String?,
    action: m['action'] as String? ?? 'یادداشت',
    payment: m['payment'] as String?,
    dateNeedsReview: m['dateNeedsReview'] == true,
  );
}

String digits(String s) =>
    s.replaceAllMapped(RegExp(r'[0-9]'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)]);
String latinDigits(String s) {
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i').replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i');
  }
  return s;
}

String money(int n) => digits(
  n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}٬',
  ),
);
String dateLabel(DateTime d) {
  final j = Jalali.fromDateTime(d).formatter;
  return '${digits(j.d)} ${j.mN} ${digits(j.y)}';
}

String editableDate(DateTime d) {
  final j = Jalali.fromDateTime(d);
  return digits(
    '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}',
  );
}

DateTime? parseDate(String input) {
  final p = latinDigits(input.trim()).split(RegExp(r'[/\-]'));
  if (p.length != 3) return null;
  try {
    final y = int.parse(p[0]), m = int.parse(p[1]), d = int.parse(p[2]);
    if (y < 1300 || y > 1499) return null;
    return Jalali(y, m, d).toDateTime();
  } catch (_) {
    return null;
  }
}

String formatNumeric(double n) {
  if (n == n.truncateToDouble()) return money(n.toInt());
  return digits(
    n.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '').replaceAll('.', '٫'),
  );
}

int? _exactStoredInteger(dynamic value) {
  if (value == null) return null;
  // App backups write monetary fields as JSON integers, never floating point.
  if (value is! int || value.abs() > 100000000000000) {
    throw const FormatException('عدد ذخیره شده باید صحیح و معتبر باشد.');
  }
  return value;
}
