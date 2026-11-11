import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/store.dart';
import '../domain/entry.dart';
import '../domain/parser.dart';
import '../domain/financial_calculation_engine.dart';
import 'theme.dart';
import 'calculation_card.dart';
import '../speech/persian_speech.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({
    super.key,
    required this.entry,
    required this.store,
    required this.isNew,
  });
  final Entry entry;
  final EntryStore store;
  final bool isNew;
  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> with WidgetsBindingObserver {
  late Entry _entry;
  final _speech = PersianSpeech();
  bool _speaking = false;
  String? _feedback;
  final _scroll = ScrollController();
  bool _editing = false, _saving = false;
  late String _kind;
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title,
      _amount,
      _qty,
      _unit,
      _price,
      _person,
      _date;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entry = widget.entry;
    _kind = _entry.intent;
    _title = TextEditingController(text: _entry.title);
    _amount = TextEditingController(
      text: _entry.amount == null ? '' : money(_entry.amount!),
    );
    _qty = TextEditingController(
      text: _entry.quantity == null ? '' : digits('${_entry.quantity}'),
    );
    _unit = TextEditingController(text: _entry.unit ?? '');
    _price = TextEditingController(
      text: _entry.unitPrice == null ? '' : money(_entry.unitPrice!),
    );
    _person = TextEditingController(text: _entry.person ?? '');
    _date = TextEditingController(text: editableDate(_entry.date));
  }

  @override
  void dispose() {
    for (final c in [_title, _amount, _qty, _unit, _price, _person, _date]) {
      c.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    _speech.dispose();
    _scroll.dispose();
    super.dispose();
  }

  int? _numeric(TextEditingController c) =>
      c.text.trim().isEmpty ? null : NoteParser.number(c.text);
  String? _validateNumber(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final n = NoteParser.number(text);
    return n == null || n <= 0 ? 'یک عدد صحیح و مثبت وارد کن.' : null;
  }

  void _apply() {
    if (_form.currentState?.validate() != true) return;
    final qty = _numeric(_qty), price = _numeric(_price);
    final derived =
        qty != null && price != null
            ? FinancialCalculationEngine.multiply(qty, price)
            : null;
    if (derived != null && derived > 100000000000000) {
      _message('مبلغ از محدوده مجاز بیشتر است.');
      return;
    }
    final amount = _numeric(_amount) ?? derived;
    if (_kind == 'unknown') {
      _message('نوع تراکنش را انتخاب کن.');
      return;
    }
    if (_kind != 'note') {
      if (amount == null || amount <= 0) {
        _message('مبلغ دقیق و مثبت را وارد کن.');
        return;
      }
      if (price != null && qty == null) {
        _message('تعداد را وارد کن یا قیمت واحد را خالی کن.');
        return;
      }
      if (qty != null && (price == null || derived == null)) {
        _message('تعداد و قیمت واحد را کامل کن.');
        return;
      }
      if (derived != null && amount != derived) {
        _message('مبلغ کل با تعداد و قیمت واحد برابر نیست.');
        return;
      }
      if (['payable', 'receivable'].contains(_kind) &&
          _person.text.trim().isEmpty) {
        _message('نام طرف حساب را وارد کن.');
        return;
      }
    }
    setState(() {
      _entry = Entry(
        id: _entry.id,
        space: _entry.space,
        title: _title.text.trim(),
        text: _entry.text,
        date: parseDate(_date.text)!,
        createdAt: _entry.createdAt,
        amount: amount,
        quantity: qty,
        unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
        unitPrice: price,
        person: _person.text.trim().isEmpty ? null : _person.text.trim(),
        action:
            {
              'expense': 'پرداخت',
              'income': 'درآمد',
              'payable': 'بدهی',
              'receivable': 'طلب',
              'note': 'یادداشت',
            }[_kind]!,
        intent: _kind,
        rawTranscript: _entry.rawTranscript,
        merchant: _entry.merchant,
        sourceCurrency: _entry.sourceCurrency,
        manuallyReviewed: true,
        payment: _entry.payment,
        calculationResult: _entry.calculationResult,
        calculationExpression: _entry.calculationExpression,
      );
      _editing = false;
      _feedback = null;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _speech.stop();
  }

  Future<void> _read() async {
    if (_speaking) {
      await _speech.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    try {
      final e = _entry;
      final summary = [
        '${e.action}. ${e.title}.',
        if (e.amount != null) 'مبلغ کل ${money(e.amount!)} تومان.',
        if (e.quantity != null)
          'تعداد ${money(e.quantity!)} ${e.unit ?? 'عدد'}.',
        if (e.unitPrice != null) 'قیمت هر واحد ${money(e.unitPrice!)} تومان.',
        if (e.person != null) 'طرف حساب ${e.person}.',
        if (e.amount == null)
          'مبلغ هنوز مشخص نیست. لطفاً اطلاعات را اصلاح کنید.',
      ].join(' ');
      await _speech.speak(summary);
    } catch (error) {
      if (mounted) {
        _message(
          error is StateError
              ? error.message
              : 'تولید صدای فارسی انجام نشد. فضای خالی گوشی را بررسی کن.',
        );
      }
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _correctTranscript() async {
    final controller = TextEditingController(text: _entry.text);
    final corrected = await showDialog<String>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('اصلاح متن و محاسبهٔ دوباره'),
            content: SizedBox(
              width: 500,
              child: TextField(
                controller: controller,
                minLines: 3,
                maxLines: 6,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText: 'متن فارسی، تعداد و قیمت را اصلاح کن',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, controller.text),
                child: const Text('دوباره محاسبه کن'),
              ),
            ],
          ),
    );
    // Dialog route disposes its text field after the exit animation.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    controller.dispose();
    if (!mounted || corrected == null || corrected.trim().isEmpty) return;
    final draft = NoteParser().parse(
      corrected,
      _entry.space,
      now: _entry.createdAt,
    );
    setState(() {
      _entry = Entry.fromJson({
        ...draft.toJson(),
        'rawTranscript': _entry.rawTranscript,
        'id': _entry.id,
        'createdAt': _entry.createdAt.toIso8601String(),
      });
      _kind = _entry.intent;
      _title.text = _entry.title;
      _amount.text = _entry.amount == null ? '' : money(_entry.amount!);
      _qty.text = _entry.quantity == null ? '' : money(_entry.quantity!);
      _price.text = _entry.unitPrice == null ? '' : money(_entry.unitPrice!);
      _unit.text = _entry.unit ?? '';
      _person.text = _entry.person ?? '';
      _date.text = editableDate(_entry.date);
    });
  }

  void _message(String s) {
    setState(() => _feedback = s);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final reason = _entry.saveBlockReason;
    if (reason != null) {
      setState(() => _editing = true);
      _feedback = reason;
      if (_scroll.hasClients) _scroll.jumpTo(0);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.store.save(_entry);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _message('ذخیره انجام نشد. چیزی از دست نرفته؛ دوباره تلاش کن.');
      }
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('این یادداشت پاک شود؟'),
            content: const Text('این کار قابل برگشت نیست.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('نه'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text(
                  'پاک کن',
                  style: TextStyle(color: Color(0xFF9B3028)),
                ),
              ),
            ],
          ),
    );
    if (yes != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.store.remove(_entry.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _message('پاک کردن انجام نشد.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _entry;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _editing
                ? 'اصلاح یادداشت'
                : widget.isNew
                ? 'درست متوجه شدم؟'
                : 'یادداشت تو',
            style: const TextStyle(fontSize: 18),
          ),
          actions:
              widget.isNew
                  ? null
                  : [
                    IconButton(
                      tooltip: 'پاک کردن یادداشت',
                      onPressed: _saving ? null : _delete,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
        ),
        bottomNavigationBar:
            _editing
                ? null
                : SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    decoration: const BoxDecoration(
                      color: cream,
                      border: Border(top: BorderSide(color: Color(0xFFDFE4DA))),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon:
                              _saving
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Icon(
                                    e.saveBlockReason == null
                                        ? Icons.check_rounded
                                        : Icons.edit_rounded,
                                  ),
                          label: Text(
                            _saving
                                ? 'در حال ذخیره…'
                                : e.saveBlockReason != null
                                ? 'تکمیل اطلاعات'
                                : widget.isNew
                                ? 'ثبت کن'
                                : 'ذخیره کن',
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed:
                              _saving
                                  ? null
                                  : () => setState(() => _editing = true),
                          child: const Text('اصلاح کن'),
                        ),
                      ],
                    ),
                  ),
                ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                children: [
                  if (_feedback != null) ...[
                    _ReviewWarning(text: _feedback!),
                    const SizedBox(height: 16),
                  ],
                  if (!_editing) ...[
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: sage,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_outlined,
                          color: ink,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.isNew
                          ? 'این‌طوری ثبتش کنیم؟'
                          : 'همه‌چیز همین‌جاست.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.saveBlockReason == null
                          ? 'پیش نویس آماده است؛ مبلغ و جزئیات را تأیید کن.'
                          : 'نیاز به اصلاح دارد؛ هنوز قابل ثبت مالی نیست.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 14),
                    ),
                    CalculationCard(entry: e),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFDFE4DA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 20),
                          if (e.amount != null)
                            Text(
                              '${money(e.amount!)} تومان',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            )
                          else if (e.calculationResult == null)
                            const Text(
                              'مبلغی مشخص نشده',
                              style: TextStyle(color: muted, fontSize: 16),
                            ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 8),
                          _Detail(label: 'تاریخ', value: dateLabel(e.date)),
                          if (e.quantity != null)
                            _Detail(
                              label: 'تعداد',
                              value: '${money(e.quantity!)} ${e.unit ?? ''}',
                            ),
                          if (e.person != null)
                            _Detail(label: 'شخص', value: e.person!),
                          if (e.unitPrice != null)
                            _Detail(
                              label: 'هر واحد',
                              value: '${money(e.unitPrice!)} تومان',
                            ),
                          if (e.payment != null)
                            _Detail(label: 'پرداخت با', value: e.payment!),
                          _Detail(label: 'نوع', value: e.action),
                          if (e.merchant != null)
                            _Detail(label: 'فروشگاه', value: e.merchant!),
                          if (e.sourceCurrency != null)
                            _Detail(
                              label: 'واحد ورودی',
                              value: e.sourceCurrency!,
                            ),
                        ],
                      ),
                    ),
                    if (e.reviewNote != null) ...[
                      const SizedBox(height: 16),
                      _ReviewWarning(text: e.reviewNote!),
                    ],
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _read,
                      icon: Icon(
                        _speaking
                            ? Icons.stop_circle_outlined
                            : Icons.volume_up_rounded,
                      ),
                      label: Text(_speaking ? 'توقف خواندن' : 'بخوان به فارسی'),
                    ),
                    if (e.dateNeedsReview)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          'تاریخ گفته‌شده روشن نبود؛ قبل از ثبت اصلاحش کن.',
                          style: TextStyle(
                            color: Color(0xFF8A4828),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: sage.withValues(alpha: .5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'چیزی که گفتی یا نوشتی',
                            style: TextStyle(fontSize: 14, color: muted),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _correctTranscript,
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text('اصلاح متن و محاسبهٔ دوباره'),
                          ),
                          SelectableText(
                            e.text,
                            style: const TextStyle(fontSize: 16, height: 1.9),
                          ),
                        ],
                      ),
                    ),
                    if (e.rawTranscript != null && e.rawTranscript != e.text)
                      ExpansionTile(
                        title: const Text(
                          'متن اولیهٔ تشخیص صدا',
                          style: TextStyle(fontSize: 14),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: SelectableText(e.rawTranscript!),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                  ] else
                    Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'فقط هر چیزی که لازم است را تغییر بده.',
                            style: TextStyle(color: muted, fontSize: 16),
                          ),
                          const SizedBox(height: 24),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _kind,
                            decoration: const InputDecoration(
                              labelText: 'نوع ثبت',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'unknown',
                                child: Text('نوع مشخص نشده'),
                              ),
                              DropdownMenuItem(
                                value: 'expense',
                                child: Text('هزینه / خرید'),
                              ),
                              DropdownMenuItem(
                                value: 'income',
                                child: Text('درآمد'),
                              ),
                              DropdownMenuItem(
                                value: 'payable',
                                child: Text('بدهی من'),
                              ),
                              DropdownMenuItem(
                                value: 'receivable',
                                child: Text('طلب من'),
                              ),
                              DropdownMenuItem(
                                value: 'note',
                                child: Text('یادداشت غیرمالی'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _kind = v);
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _title,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: 'عنوان / نام کالا',
                            ),
                            validator:
                                (s) =>
                                    s == null || s.trim().isEmpty
                                        ? 'عنوان را بنویس.'
                                        : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _amount,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText:
                                  _kind == 'note'
                                      ? 'مبلغ کل (تومان، اختیاری)'
                                      : 'مبلغ کل (تومان، ضروری)',
                            ),
                            validator: _validateNumber,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _date,
                            decoration: const InputDecoration(
                              labelText: 'تاریخ شمسی',
                              hintText: '۱۴۰۵/۰۷/۰۹',
                            ),
                            validator:
                                (s) =>
                                    parseDate(s ?? '') == null
                                        ? 'تاریخ معتبر شمسی مثل ۱۴۰۵/۰۷/۰۹ وارد کن.'
                                        : null,
                          ),
                          ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _qty,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'تعداد (اختیاری)',
                              ),
                              validator: _validateNumber,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _unit,
                              maxLength: 30,
                              decoration: const InputDecoration(
                                labelText: 'واحد، مثلاً کارتن (اختیاری)',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _price,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'قیمت هر واحد (تومان، اختیاری)',
                              ),
                              validator: _validateNumber,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _person,
                              maxLength: 100,
                              decoration: const InputDecoration(
                                labelText: 'اسم شخص یا فروشگاه (اختیاری)',
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _apply,
                            child: const Text('تأیید اصلاحات'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => setState(() => _editing = false),
                            child: const Text('برگشت بدون تغییر'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: muted, fontSize: 14),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

class _ReviewWarning extends StatelessWidget {
  const _ReviewWarning({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3E4),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEBD2AE)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: Color(0xFF82542B),
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF78502F),
              fontSize: 14,
              height: 1.9,
            ),
          ),
        ),
      ],
    ),
  );
}
