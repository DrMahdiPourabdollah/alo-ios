import 'package:flutter/material.dart';
import '../domain/entry.dart';
import '../domain/financial_book.dart';
import '../domain/persian_number_parser.dart';
import '../speech/persian_speech.dart';
import 'theme.dart';

class FinanceEditor extends StatefulWidget {
  const FinanceEditor({super.key, required this.entry, this.all = const []});
  final Entry entry;
  final List<Entry> all;
  @override
  State<FinanceEditor> createState() => _FinanceEditorState();
}

class _FinanceEditorState extends State<FinanceEditor> {
  final form = GlobalKey<FormState>();
  final speech = PersianSpeech();
  late TextEditingController title,
      amount,
      quantity,
      price,
      person,
      merchant,
      account,
      counter,
      date,
      unit;
  late String kind, category, payment;
  String? related, error;
  bool checked = false, speaking = false;
  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    title = TextEditingController(
      text: e.title == 'یادداشت جدید' ? '' : e.title,
    );
    amount = TextEditingController(
      text: e.amount == null ? '' : money(e.amount!),
    );
    quantity = TextEditingController(
      text: e.quantity == null ? '' : money(e.quantity!),
    );
    price = TextEditingController(
      text: e.unitPrice == null ? '' : money(e.unitPrice!),
    );
    person = TextEditingController(text: e.person);
    merchant = TextEditingController(text: e.merchant);
    account = TextEditingController(text: e.account);
    counter = TextEditingController(text: e.counterAccount);
    date = TextEditingController(text: editableDate(e.date));
    unit = TextEditingController(text: e.unit ?? 'عدد');
    kind = e.intent;
    category = e.category;
    payment = e.payment ?? '';
    related = e.relatedId;
  }

  @override
  void dispose() {
    for (final c in [
      title,
      amount,
      quantity,
      price,
      person,
      merchant,
      account,
      counter,
      date,
      unit,
    ]) {
      c.dispose();
    }
    speech.dispose();
    super.dispose();
  }

  int? number(String s) =>
      s.trim().isEmpty ? null : PersianNumberParser.integer(s);
  Entry buildEntry() => revise(widget.entry, {
    'intent': kind,
    'action': financialKinds[kind] ?? 'نیازمند بررسی',
    'title': title.text.trim(),
    'amount': number(amount.text),
    'quantity': number(quantity.text),
    'unitPrice': number(price.text),
    'unit': unit.text.trim(),
    'person': person.text.trim().isEmpty ? null : person.text.trim(),
    'merchant': merchant.text.trim().isEmpty ? null : merchant.text.trim(),
    'payment': payment.isEmpty ? null : payment,
    'account': account.text.trim(),
    'counterAccount': counter.text.trim().isEmpty ? null : counter.text.trim(),
    'category': category,
    'date': (parseDate(date.text) ?? widget.entry.date).toIso8601String(),
    'dateNeedsReview': parseDate(date.text) == null,
    'manuallyReviewed': checked,
    'validationIssues': checked ? [] : widget.entry.validationIssues,
    'reviewNote': checked ? null : widget.entry.reviewNote,
    'relatedId': related,
  });
  void confirm() {
    if (!form.currentState!.validate()) return;
    final e = buildEntry();
    final reason =
        e.title.isEmpty ? 'شرح تراکنش را وارد کنید.' : e.saveBlockReason;
    if (reason != null) {
      setState(() => error = reason);
      return;
    }
    final ids = widget.all.where((n) => n.id != e.id).toList();
    final relation = FinancialBook.validateRelations([...ids, e]);
    if (relation != null) {
      setState(() => error = relation);
      return;
    }
    Navigator.pop(context, e);
  }

  void calculate() {
    final q = number(quantity.text), v = number(price.text);
    final n = q != null && v != null ? BigInt.from(q) * BigInt.from(v) : null;
    if (n == null || n <= BigInt.zero || n > BigInt.from(100000000000000)) {
      setState(
        () =>
            error = 'تعداد و قیمت واحد باید صحیح، مثبت و در محدوده مجاز باشند.',
      );
      return;
    }
    setState(() {
      amount.text = money(n.toInt());
      error = null;
    });
  }

  Future<void> read() async {
    if (speaking) return;
    setState(() => speaking = true);
    try {
      final e = buildEntry();
      await speech.speak(
        '${financialKinds[kind] ?? 'تراکنش'}. ${title.text}. ${e.amount == null ? 'مبلغ مشخص نشده است' : 'مبلغ ${money(e.amount!)} تومان'}.',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error = 'خواندن خلاصه انجام نشد. فضای خالی دستگاه را بررسی کنید.',
        );
      }
    } finally {
      if (mounted) setState(() => speaking = false);
    }
  }

  Widget field(
    TextEditingController c,
    String label, {
    bool numeric = false,
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      keyboardType: numeric ? TextInputType.text : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (s) {
        if (required && (s ?? '').trim().isEmpty) {
          return 'این مقدار را وارد کنید.';
        }
        if (numeric &&
            (s ?? '').trim().isNotEmpty &&
            (number(s!) == null || number(s)! <= 0)) {
          return 'عدد صحیح و مثبت، با رقم یا حروف وارد کنید.';
        }
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final debts =
        widget.all
            .where(
              (d) =>
                  d.intent ==
                      (kind == 'payable_payment' ? 'payable' : 'receivable') &&
                  d.space == e.space,
            )
            .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('بررسی و تکمیل تراکنش')),
      body: SafeArea(
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'اطلاعات مالی را بررسی کنید. هنوز چیزی ذخیره نشده است.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 16),
              if (e.reviewNote != null) notice(e.reviewNote!),
              if (error != null) notice(error!),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    financialKinds.entries
                        .where(
                          (x) =>
                              ![
                                'unknown',
                                'payable_payment',
                                'receivable_collection',
                              ].contains(x.key) ||
                              x.key == kind,
                        )
                        .map(
                          (x) => ChoiceChip(
                            label: Text(x.value),
                            selected: kind == x.key,
                            onSelected: (_) => setState(() => kind = x.key),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 24),
              field(title, 'شرح تراکنش / نام کالا', required: true),
              field(amount, 'مبلغ کل (تومان)', numeric: true),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sage,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'محاسبه تعداد × قیمت واحد',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    field(quantity, 'تعداد صحیح (اختیاری)', numeric: true),
                    field(unit, 'واحد کالا'),
                    field(price, 'قیمت واحد (تومان؛ اختیاری)', numeric: true),
                    OutlinedButton.icon(
                      onPressed: calculate,
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text('محاسبه مبلغ کل'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              field(date, 'تاریخ وقوع (شمسی؛ مثال ۱۴۰۵/۰۷/۱۲)', required: true),
              DropdownButtonFormField<String>(
                initialValue:
                    financialCategories.contains(category) ? category : 'سایر',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'دسته‌بندی'),
                items:
                    financialCategories
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                onChanged: (v) => setState(() => category = v!),
              ),
              const SizedBox(height: 16),
              field(
                account,
                kind == 'transfer' ? 'حساب مبدأ' : 'حساب مرتبط',
                required: true,
              ),
              if (kind == 'transfer')
                field(counter, 'حساب مقصد', required: true),
              field(person, 'طرف حساب (برای بدهی و مطالبات ضروری)'),
              field(merchant, 'فروشگاه (اختیاری)'),
              Wrap(
                spacing: 8,
                children:
                    ['', 'نقد', 'کارت', 'انتقال']
                        .map(
                          (x) => ChoiceChip(
                            label: Text(x.isEmpty ? 'نامشخص' : x),
                            selected: payment == x,
                            onSelected: (_) => setState(() => payment = x),
                          ),
                        )
                        .toList(),
              ),
              if ([
                'payable_payment',
                'receivable_collection',
              ].contains(kind)) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue:
                      debts.any((d) => d.id == related) ? related : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'تراکنش اصلی مرتبط',
                  ),
                  items:
                      debts
                          .map(
                            (d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(
                                '${d.title} · ${money(FinancialBook.remaining(d, widget.all, excluding: e.id))} تومان',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) {
                    final d = debts.firstWhere((d) => d.id == v);
                    setState(() {
                      related = v;
                      person.text = d.person ?? '';
                    });
                  },
                ),
              ],
              const SizedBox(height: 24),
              ExpansionTile(
                title: const Text('متن و شواهد استخراج'),
                children: [
                  SelectableText(e.text),
                  const SizedBox(height: 8),
                  if (e.rawTranscript != null && e.rawTranscript != e.text)
                    SelectableText('متن کامل صوت: ${e.rawTranscript}'),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: checked,
                onChanged: (v) => setState(() => checked = v!),
                title: const Text(
                  'نوع، مبلغ، تاریخ و طرف حساب را بررسی و تأیید کردم.',
                ),
              ),
              if (!checked && e.validationIssues.isNotEmpty)
                const Text(
                  'به‌علت ابهام استخراج، تأیید بررسی اطلاعات ضروری است.',
                  style: TextStyle(color: Color(0xFF8B4527)),
                ),
              OutlinedButton.icon(
                onPressed: speaking ? null : read,
                icon: const Icon(Icons.volume_up_outlined),
                label: Text(
                  speaking ? 'در حال خواندن…' : 'بازخوانی خلاصه تراکنش',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: checked ? confirm : null,
                icon: const Icon(Icons.check),
                label: const Text('تأیید این ردیف'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget notice(String s) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF2DF),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      s,
      style: const TextStyle(color: Color(0xFF75421E), fontSize: 14),
    ),
  );
}

class BatchReview extends StatefulWidget {
  const BatchReview({super.key, required this.entries, required this.existing});
  final List<Entry> entries, existing;
  @override
  State<BatchReview> createState() => _BatchReviewState();
}

class _BatchReviewState extends State<BatchReview> {
  late List<Entry> entries;
  final approved = <String>{};
  String? error;
  @override
  void initState() {
    super.initState();
    entries = List.of(widget.entries);
  }

  Future<void> edit(Entry e) async {
    final result = await Navigator.push<Entry>(
      context,
      MaterialPageRoute(
        builder:
            (_) => FinanceEditor(
              entry: e,
              all: [...widget.existing, ...entries.where((n) => n.id != e.id)],
            ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        entries[entries.indexWhere((n) => n.id == e.id)] = result;
        approved.add(e.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تراکنش‌های استخراج‌شده')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'هر ردیف را باز کنید و تأیید کنید. فقط ردیف‌های تأییدشده و معتبر ذخیره می‌شوند.',
          ),
          const SizedBox(height: 16),
          ...entries.map(
            (e) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed:
                              () => setState(() {
                                entries.removeWhere((n) => n.id == e.id);
                                approved.remove(e.id);
                              }),
                          tooltip: 'حذف از پیش‌نویس',
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Text(
                      '${financialKinds[e.intent] ?? 'نیازمند بررسی'} · ${e.amount == null ? 'مبلغ نامشخص' : '${money(e.amount!)} تومان'}',
                    ),
                    if (e.quantity != null && e.unitPrice != null)
                      Text(
                        '${money(e.quantity!)} × ${money(e.unitPrice!)} تومان',
                      ),
                    Text(
                      e.text,
                      style: const TextStyle(color: muted, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => edit(e),
                      icon: Icon(
                        approved.contains(e.id)
                            ? Icons.check_circle_outline
                            : Icons.edit_outlined,
                      ),
                      label: Text(
                        approved.contains(e.id)
                            ? 'تأییدشده؛ مشاهده و ویرایش'
                            : 'بررسی و تأیید ردیف',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed:
                entries.isEmpty
                    ? null
                    : () {
                      if (entries.any(
                        (e) =>
                            !approved.contains(e.id) ||
                            e.saveBlockReason != null,
                      )) {
                        setState(
                          () =>
                              error =
                                  'ابتدا تمام ردیف‌های باقی‌مانده را بررسی و تأیید کنید.',
                        );
                        return;
                      }
                      Navigator.pop(context, entries);
                    },
            icon: const Icon(Icons.save_outlined),
            label: Text('ثبت نهایی ${digits('${entries.length}')} تراکنش'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف؛ هیچ‌چیز ذخیره نشود'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
