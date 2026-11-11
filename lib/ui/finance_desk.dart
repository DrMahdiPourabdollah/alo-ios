import 'premium_effects.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../data/store.dart';
import '../domain/entry.dart';
import '../domain/financial_book.dart';
import 'compose.dart';
import 'finance_review.dart';
import 'settings.dart';
import 'theme.dart';

class FinanceDesk extends StatefulWidget {
  const FinanceDesk({
    super.key,
    required this.store,
    this.initialEntries,
    this.today,
  });
  final EntryStore store;
  final List<Entry>? initialEntries;
  final DateTime? today;
  @override
  State<FinanceDesk> createState() => _FinanceDeskState();
}

class _FinanceDeskState extends State<FinanceDesk> {
  List<Entry> all = [];
  bool loading = true, busy = false;
  String? error;
  int tab = 0, tablePage = 0;
  String period = 'ماه', kind = 'همه', search = '';
  Space? space;
  late DateTime anchor;
  ReportWindow? custom;
  @override
  void initState() {
    super.initState();
    anchor = widget.today ?? DateTime.now();
    if (widget.initialEntries != null) {
      all = widget.initialEntries!;
      loading = false;
    } else {
      load();
    }
  }

  Future<void> load() async {
    try {
      final rows = await widget.store.load();
      if (mounted) {
        setState(() {
          all = rows;
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'دفتر مالی باز نشد. اطلاعات تغییری نکرده است.';
          loading = false;
        });
      }
    }
  }

  List<Entry> get legacyEntries {
    final converted =
        all
            .where((e) => e.isFinancial && e.saveBlockReason == null)
            .map((e) => e.sourceId)
            .toSet();
    return all
        .where(
          (e) =>
              (!e.isFinancial || e.saveBlockReason != null) &&
              !converted.contains('legacy:${e.id}'),
        )
        .toList();
  }

  Future<void> reviewLegacy() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder:
            (c) => Scaffold(
              appBar: AppBar(title: const Text('تحلیل ثبت‌های قبلی')),
              body: ListView(
                padding: const EdgeInsets.all(24),
                children:
                    legacyEntries
                        .map(
                          (old) => Card(
                            child: ListTile(
                              title: Text(old.title),
                              subtitle: Text(
                                old.text,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_left),
                              onTap: () async {
                                final drafts =
                                    FinancialBatch.parse(
                                          old.text,
                                          old.space,
                                          now: old.createdAt,
                                          rawTranscript: old.rawTranscript,
                                        )
                                        .map(
                                          (e) => revise(e, {
                                            'sourceId': 'legacy:${old.id}',
                                          }),
                                        )
                                        .toList();
                                final approved =
                                    await Navigator.push<List<Entry>>(
                                      c,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => BatchReview(
                                              entries: drafts,
                                              existing: all,
                                            ),
                                      ),
                                    );
                                if (approved != null && mounted) {
                                  await saveRows(approved);
                                  if (c.mounted) Navigator.pop(c);
                                }
                              },
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
      ),
    );
  }

  ReportWindow get window => custom ?? ReportWindow.make(period, anchor);
  FinancialReport get report => FinancialReport(all, window, space: space);
  void message(String text) {
    if (mounted) setState(() => error = text);
  }

  Future<void> saveRows(List<Entry> rows) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.store.merge(rows);
      await load();
    } catch (e) {
      message(
        e is StateError
            ? e.message
            : 'ثبت انجام نشد. فضای خالی دستگاه را بررسی کنید.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> add({bool voice = false}) async {
    if (busy) return;
    final entries = await Navigator.push<List<Entry>>(
      context,
      MaterialPageRoute(
        builder:
            (_) => ComposePage(
              space: space ?? Space.personal,
              startWithVoice: voice,
              financialBatch: true,
            ),
      ),
    );
    if (entries == null || !mounted) return;
    final confirmed = await Navigator.push<List<Entry>>(
      context,
      MaterialPageRoute(
        builder: (_) => BatchReview(entries: entries, existing: all),
      ),
    );
    if (confirmed != null && mounted) await saveRows(confirmed);
  }

  Future<void> manual() async {
    final now = DateTime.now();
    final e = Entry(
      id: const Uuid().v4(),
      space: space ?? Space.personal,
      title: '',
      text: 'ثبت دستی',
      date: DateTime(now.year, now.month, now.day),
      createdAt: now,
      intent: 'unknown',
    );
    await edit(e, newEntry: true);
  }

  Future<void> edit(Entry e, {bool newEntry = false}) async {
    final result = await Navigator.push<Entry>(
      context,
      MaterialPageRoute(builder: (_) => FinanceEditor(entry: e, all: all)),
    );
    if (result != null && mounted) await saveRows([result]);
  }

  Future<void> remove(Entry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('حذف تراکنش'),
            content: Text('«${e.title}» حذف شود؟ این کار قابل بازگشت نیست.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('حذف'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    try {
      await widget.store.remove(e.id);
      await load();
    } catch (e) {
      message(e is StateError ? e.message : 'حذف انجام نشد.');
    }
  }

  Future<void> settle(Entry debt) async {
    final remaining = FinancialBook.remaining(debt, all);
    if (remaining <= 0) return;
    final now = DateTime.now();
    final e = Entry(
      id: const Uuid().v4(),
      space: debt.space,
      title:
          debt.intent == 'payable'
              ? 'پرداخت بدهی به ${debt.person}'
              : 'وصول مطالبه از ${debt.person}',
      text: 'تسویه مرتبط با ${debt.title}',
      date: DateTime(now.year, now.month, now.day),
      createdAt: now,
      intent:
          debt.intent == 'payable'
              ? 'payable_payment'
              : 'receivable_collection',
      amount: remaining,
      person: debt.person,
      relatedId: debt.id,
      account: debt.account,
    );
    await edit(e, newEntry: true);
  }

  Future<void> chooseRange() async {
    final a = TextEditingController(text: editableDate(window.start)),
        b = TextEditingController(
          text: editableDate(window.end.subtract(const Duration(days: 1))),
        );
    String? feedback;
    final result = await showDialog<ReportWindow>(
      context: context,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, set) => AlertDialog(
                  title: const Text('بازه دلخواه؛ تقویم شمسی'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: a,
                          decoration: const InputDecoration(
                            labelText: 'از تاریخ ۱۴۰۵/۰۷/۰۱',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: b,
                          decoration: const InputDecoration(
                            labelText: 'تا تاریخ (شامل این روز)',
                          ),
                        ),
                        if (feedback != null)
                          Text(
                            feedback!,
                            style: const TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('انصراف'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final start = parseDate(a.text),
                            end = parseDate(b.text);
                        if (start == null ||
                            end == null ||
                            end.isBefore(start)) {
                          set(
                            () =>
                                feedback = 'تاریخ‌ها باید معتبر و مرتب باشند.',
                          );
                          return;
                        }
                        Navigator.pop(
                          c,
                          ReportWindow(
                            start,
                            DateTime(end.year, end.month, end.day + 1),
                            'بازه دلخواه',
                          ),
                        );
                      },
                      child: const Text('نمایش گزارش'),
                    ),
                  ],
                ),
          ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    a.dispose();
    b.dispose();
    if (result != null && mounted) setState(() => custom = result);
  }

  Future<void> exportCsv() async {
    final rows = filtered();
    if (rows.isEmpty) {
      message('در این بازه تراکنشی برای خروجی وجود ندارد.');
      return;
    }
    String quote(String s) => '"${s.replaceAll('"', '""')}"';
    String safe(String s) => RegExp(r'^\s*[=+@\-]').hasMatch(s) ? "'$s" : s;
    final lines = <List<String>>[
      [
        'شناسه',
        'تاریخ وقوع شمسی',
        'تاریخ ثبت',
        'نوع',
        'شرح',
        'دسته‌بندی',
        'مبلغ تومان',
        'تعداد',
        'واحد',
        'قیمت واحد تومان',
        'طرف حساب',
        'فروشگاه',
        'روش پرداخت',
        'حساب',
        'حساب مقصد',
        'شناسه تسویه مرتبط',
        'شناسه صوت',
        'متن',
      ],
    ];
    for (final e in rows) {
      lines.add([
        e.id,
        editableDate(e.date),
        e.createdAt.toIso8601String(),
        financialKinds[e.intent] ?? e.intent,
        e.title,
        e.category,
        '${e.amount ?? ''}',
        '${e.quantity ?? ''}',
        e.unit ?? '',
        '${e.unitPrice ?? ''}',
        e.person ?? '',
        e.merchant ?? '',
        e.payment ?? '',
        e.account,
        e.counterAccount ?? '',
        e.relatedId ?? '',
        e.sourceId ?? '',
        e.text,
      ]);
    }
    try {
      await FilePicker.platform.saveFile(
        dialogTitle: 'ذخیره جدول تراکنش‌ها',
        fileName: 'alo-transactions.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(
          utf8.encode(
            '\uFEFF${lines.map((r) => r.map((x) => quote(safe(x))).join(',')).join('\r\n')}',
          ),
        ),
      );
    } catch (_) {
      message('خروجی ذخیره نشد. دسترسی و فضای خالی را بررسی کنید.');
    }
  }

  List<Entry> filtered() =>
      report.period
          .where(
            (e) =>
                (kind == 'همه' || e.intent == kind) &&
                (search.isEmpty ||
                    '${e.title} ${e.person ?? ''} ${e.merchant ?? ''} ${e.category} ${e.text}'
                        .contains(search)),
          )
          .toList();
  @override
  Widget build(BuildContext context) {
    final r = report;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.graphic_eq_rounded, size: 30),
            SizedBox(width: 10),
            Brand(size: 30),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تنظیمات و نسخه پشتیبان',
            onPressed:
                busy
                    ? null
                    : () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettingsPage(store: widget.store),
                        ),
                      );
                      await load();
                    },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      bottomNavigationBar: AloGlassNavigation(
        child: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            setState(() => tab = i);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              label: 'داشبورد',
            ),
            NavigationDestination(
              icon: Icon(Icons.table_rows_outlined),
              label: 'دفتر مالی',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              label: 'بدهی و مطالبات',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child:
            loading
                ? const Center(child: CircularProgressIndicator())
                : AloReveal(
                  key: ValueKey(tab),
                  child: ListView(
                    key: ValueKey(tab),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      Text(
                        tab == 0
                            ? 'حسابداری شخصی صوتی'
                            : tab == 1
                            ? 'دفتر تراکنش‌ها'
                            : 'بدهی و مطالبات',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ثبت ساختاریافته، محاسبه دقیق، تأیید پیش از ذخیره',
                        style: TextStyle(color: muted, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('همه دفترها'),
                            selected: space == null,
                            onSelected: (_) => setState(() => space = null),
                          ),
                          ...Space.values.map(
                            (s) => ChoiceChip(
                              label: Text(s.label),
                              selected: space == s,
                              onSelected: (_) => setState(() => space = s),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (error != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0DB),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(error!)),
                              IconButton(
                                onPressed: () => setState(() => error = null),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                      if (tab != 2) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            ...['روز', 'هفته', 'ماه', 'سال', 'همه'].map(
                              (s) => ChoiceChip(
                                label: Text(s),
                                selected: custom == null && period == s,
                                onSelected:
                                    (_) => setState(() {
                                      period = s;
                                      custom = null;
                                    }),
                              ),
                            ),
                            ActionChip(
                              label: const Text('بازه دلخواه'),
                              onPressed: chooseRange,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${dateLabel(window.start)} تا ${dateLabel(window.end.subtract(const Duration(days: 1)))}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (period != 'همه' && custom == null) ...[
                              IconButton(
                                tooltip: 'دوره قبل',
                                onPressed: () => move(-1),
                                icon: const Icon(Icons.chevron_right),
                              ),
                              IconButton(
                                tooltip: 'دوره بعد',
                                onPressed: () => move(1),
                                icon: const Icon(Icons.chevron_left),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (tab == 0) ...dashboard(r),
                      if (tab == 1) ...ledger(),
                      if (tab == 2) ...debtRows(),
                      const SizedBox(height: 24),
                      if (legacyEntries.isNotEmpty) ...[
                        OutlinedButton.icon(
                          onPressed: reviewLegacy,
                          icon: const Icon(Icons.auto_awesome_outlined),
                          label: Text(
                            'تحلیل ${digits('${legacyEntries.length}')} ثبت قبلی',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton.icon(
                        onPressed: busy ? null : () => add(voice: true),
                        icon: const Icon(Icons.mic),
                        label: const Text('ثبت صوتی تراکنش‌ها'),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: busy ? null : () => add(),
                            icon: const Icon(Icons.text_fields),
                            label: const Text('تحلیل متن'),
                          ),
                          OutlinedButton.icon(
                            onPressed: busy ? null : manual,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('ثبت دستی'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'پردازش صوت و محاسبات روی دستگاه انجام می‌شوند. گزارش‌ها فقط بر اساس ثبت‌های تأییدشده هستند.',
                        style: TextStyle(color: muted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  void move(int direction) {
    final w = window;
    if (period == 'روز') {
      anchor = DateTime(anchor.year, anchor.month, anchor.day + direction);
    } else if (period == 'هفته') {
      anchor = DateTime(anchor.year, anchor.month, anchor.day + 7 * direction);
    } else if (period == 'سال') {
      final j = Jalali.fromDateTime(anchor);
      anchor = Jalali(j.year + direction, 1, 1).toDateTime();
    } else {
      anchor =
          direction > 0
              ? w.end
              : DateTime(w.start.year, w.start.month, w.start.day - 1);
    }
    setState(() {});
  }

  List<Widget> dashboard(FinancialReport r) => [
    AloHero(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF104830), Color(0xFF237650)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'خالص درآمد و هزینه ثبت‌شده',
              style: TextStyle(color: Color(0xFFD8F3E2), fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              '${bigMoney(r.net)} تومان',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${digits('${r.period.length}')} تراکنش در این بازه',
              style: const TextStyle(color: Color(0xFFD8F3E2), fontSize: 14),
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 16),
    LayoutBuilder(
      builder:
          (c, size) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              metric('درآمد', r.income, Icons.south_west, size.maxWidth),
              metric('هزینه', r.expense, Icons.north_east, size.maxWidth),
              metric(
                'مانده مطالبات',
                r.outstanding('receivable'),
                Icons.call_received,
                size.maxWidth,
              ),
              metric(
                'مانده بدهی',
                r.outstanding('payable'),
                Icons.call_made,
                size.maxWidth,
              ),
            ],
          ),
    ),
    const SizedBox(height: 12),
    const Text(
      'خالص درآمد و هزینه، موجودی بانک نیست. مانده بدهی و مطالبات تا پایان بازه محاسبه می‌شود.',
      style: TextStyle(color: muted, fontSize: 14),
    ),
    const SizedBox(height: 24),
    card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'روند درآمد و هزینه ثبت‌شده',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'آخرین ۷ روز دارای ثبت در بازه انتخاب‌شده',
            style: TextStyle(color: muted, fontSize: 14),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 16,
            children: [
              Text('● درآمد', style: TextStyle(color: Color(0xFF176244))),
              Text('● هزینه', style: TextStyle(color: Color(0xFF99551E))),
            ],
          ),
          const SizedBox(height: 12),
          if (r.daily.isNotEmpty) ...[
            Text(
              'محور عمودی: ${chartUnit(r.daily)}',
              style: const TextStyle(color: muted, fontSize: 14),
            ),
            const SizedBox(height: 16),
          ],
          if (r.daily.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('برای نمایش روند، تراکنش درآمد یا هزینه ثبت کنید.'),
            )
          else
            SizedBox(
              height: 210,
              child: CustomPaint(painter: DailyPainter(r.daily)),
            ),
          if (r.daily.isNotEmpty)
            ExpansionTile(
              title: const Text('جدول مقادیر دقیق'),
              children: [
                ...((r.daily.keys.toList()..sort()).reversed.take(7)).map(
                  (d) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '${dateLabel(d)}\nدرآمد ${bigMoney(r.daily[d]!.income)} · هزینه ${bigMoney(r.daily[d]!.expense)} تومان',
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'هزینه به تفکیک دسته‌بندی',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (r.categories.isEmpty)
            const Text(
              'هزینه‌ای در این بازه ثبت نشده است.',
              style: TextStyle(color: muted),
            ),
          ...((r.categories.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${e.key} · ${bigMoney(e.value)} تومان'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value:
                            r.expense == BigInt.zero
                                ? 0
                                : (e.value.toDouble() / r.expense.toDouble()),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                        backgroundColor: sage,
                        color: ink,
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    ),
    const SizedBox(height: 24),
    const Text(
      'تراکنش‌های این بازه',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 12),
    if (r.period.isEmpty) empty('هنوز تراکنشی در این بازه ثبت نشده است.'),
    ...r.period.take(5).map(transactionCard),
  ];
  Widget metric(String title, BigInt value, IconData icon, double width) =>
      SizedBox(
        width: width < 340 ? width : (width - 12) / 2,
        child: card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: ink),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(color: muted, fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                '${bigMoney(value)} تومان',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      );
  List<Widget> ledger() {
    final rows = filtered();
    final page = rows.isEmpty ? 0 : tablePage.clamp(0, (rows.length - 1) ~/ 50);
    return [
      TextField(
        decoration: const InputDecoration(
          labelText: 'جست‌وجوی شرح، طرف حساب یا دسته‌بندی',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (s) => setState(() => search = s),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ChoiceChip(
            label: const Text('همه'),
            selected: kind == 'همه',
            onSelected: (_) => setState(() => kind = 'همه'),
          ),
          ...financialKinds.entries
              .where((x) => x.key != 'unknown')
              .map(
                (x) => ChoiceChip(
                  label: Text(x.value),
                  selected: kind == x.key,
                  onSelected: (_) => setState(() => kind = x.key),
                ),
              ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        '${digits('${rows.length}')} ردیف · واحد تمام مبالغ: تومان',
        style: const TextStyle(color: muted, fontSize: 14),
      ),
      const SizedBox(height: 12),
      if (rows.isEmpty)
        empty('تراکنشی مطابق این فیلتر وجود ندارد.')
      else
        card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              headingRowColor: WidgetStateProperty.all(sage),
              columns: const [
                DataColumn(label: Text('تاریخ وقوع')),
                DataColumn(label: Text('نوع')),
                DataColumn(label: Text('شرح')),
                DataColumn(label: Text('مبلغ کل')),
                DataColumn(label: Text('تعداد')),
                DataColumn(label: Text('واحد')),
                DataColumn(label: Text('قیمت واحد')),
                DataColumn(label: Text('طرف حساب')),
                DataColumn(label: Text('فروشگاه')),
                DataColumn(label: Text('دسته‌بندی')),
                DataColumn(label: Text('حساب')),
                DataColumn(label: Text('حساب مقصد')),
                DataColumn(label: Text('روش پرداخت')),
                DataColumn(label: Text('جزئیات')),
              ],
              rows:
                  rows
                      .skip(page * 50)
                      .take(50)
                      .map(
                        (e) => DataRow(
                          cells: [
                            DataCell(Text(editableDate(e.date))),
                            DataCell(Text(financialKinds[e.intent] ?? '')),
                            DataCell(
                              SizedBox(width: 180, child: Text(e.title)),
                            ),
                            DataCell(Text(money(e.amount!))),
                            DataCell(
                              Text(
                                e.quantity == null ? '—' : money(e.quantity!),
                              ),
                            ),
                            DataCell(Text(e.unit ?? '—')),
                            DataCell(
                              Text(
                                e.unitPrice == null ? '—' : money(e.unitPrice!),
                              ),
                            ),
                            DataCell(Text(e.person ?? '—')),
                            DataCell(Text(e.merchant ?? '—')),
                            DataCell(Text(e.category)),
                            DataCell(Text(e.account)),
                            DataCell(Text(e.counterAccount ?? '—')),
                            DataCell(Text(e.payment ?? '—')),
                            DataCell(
                              IconButton(
                                tooltip: 'مشاهده و ویرایش',
                                onPressed: () => details(e),
                                icon: const Icon(Icons.open_in_new),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
            ),
          ),
        ),
      const SizedBox(height: 12),
      if (rows.length > 50)
        Row(
          children: [
            Expanded(
              child: Text(
                'صفحه ${digits('${page + 1}')} از ${digits('${(rows.length / 50).ceil()}')}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            IconButton(
              tooltip: 'صفحه قبل',
              onPressed:
                  page == 0 ? null : () => setState(() => tablePage = page - 1),
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: 'صفحه بعد',
              onPressed:
                  (page + 1) * 50 >= rows.length
                      ? null
                      : () => setState(() => tablePage = page + 1),
              icon: const Icon(Icons.chevron_left),
            ),
          ],
        ),
      const Text(
        'برای مشاهده همه ستون‌ها، جدول را افقی جابه‌جا کنید.',
        style: TextStyle(fontSize: 14, color: muted),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: exportCsv,
        icon: const Icon(Icons.download_outlined),
        label: const Text('خروجی جدول CSV'),
      ),
      const SizedBox(height: 16),
      ...rows.skip(page * 50).take(10).map(transactionCard),
    ];
  }

  List<Widget> debtRows() {
    final rows =
        all
            .where(
              (e) =>
                  ['payable', 'receivable'].contains(e.intent) &&
                  e.saveBlockReason == null &&
                  (space == null || space == e.space),
            )
            .toList();
    return [
      const Text(
        'مانده فعلی هر بدهی یا مطالبه، با کسر تسویه‌های مرتبط. این بخش محدود به بازه داشبورد نیست.',
        style: TextStyle(color: muted, fontSize: 14),
      ),
      const SizedBox(height: 16),
      if (rows.isEmpty) empty('بدهی یا مطالبه‌ای ثبت نشده است.'),
      ...rows.map(
        (e) => card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                e.person ?? e.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${financialKinds[e.intent]} · ${dateLabel(e.date)}',
                style: const TextStyle(color: muted, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text('مبلغ اولیه: ${money(e.amount!)} تومان'),
              Text(
                'مانده: ${money(FinancialBook.remaining(e, all))} تومان',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => details(e),
                child: const Text('جزئیات و سوابق'),
              ),
              const SizedBox(height: 12),
              if (FinancialBook.remaining(e, all) > 0)
                FilledButton(
                  onPressed: () => settle(e),
                  child: Text(
                    e.intent == 'payable'
                        ? 'ثبت پرداخت بدهی'
                        : 'ثبت وصول مطالبه',
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget transactionCard(Entry e) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: card(
      child: InkWell(
        onTap: () => details(e),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              e.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${money(e.amount!)} تومان',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${financialKinds[e.intent]} · ${dateLabel(e.date)}\n${e.category} · ${e.account}',
              style: const TextStyle(color: muted, fontSize: 14),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> details(Entry e) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (c) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(e.title, style: Theme.of(c).textTheme.titleLarge),
                  Text(
                    '${money(e.amount!)} تومان',
                    style: Theme.of(c).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'نوع: ${financialKinds[e.intent]}\nتاریخ وقوع: ${dateLabel(e.date)}\nتاریخ ثبت: ${dateLabel(e.createdAt)}\nدسته‌بندی: ${e.category}\nحساب: ${e.account}\nطرف حساب: ${e.person ?? '—'}\nفروشگاه: ${e.merchant ?? '—'}\nروش پرداخت: ${e.payment ?? '—'}',
                  ),
                  if (e.calculatedTotal != null)
                    Text(
                      'محاسبه: ${money(e.quantity!)} × ${money(e.unitPrice!)} = ${money(e.calculatedTotal!)} تومان',
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'متن مرتبط با این تراکنش',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(e.text),
                  const SizedBox(height: 16),
                  ...all
                      .where((n) => n.relatedId == e.id)
                      .map(
                        (n) => Text(
                          '${dateLabel(n.date)} · تسویه ${money(n.amount!)} تومان',
                        ),
                      ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(c);
                      edit(e);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('ویرایش تراکنش'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(c);
                      remove(e);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('حذف با تأیید'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget card({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFD8E5DC)),
    ),
    child: child,
  );
  Widget empty(String text) => card(
    child: Column(
      children: [
        const Icon(Icons.receipt_long_outlined, size: 40, color: muted),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted),
        ),
      ],
    ),
  );
}

class DailyPainter extends CustomPainter {
  DailyPainter(this.values);
  final Map<DateTime, ({BigInt income, BigInt expense})> values;
  @override
  void paint(Canvas canvas, Size size) {
    final days =
        (values.keys.toList()..sort()).reversed
            .take(7)
            .toList()
            .reversed
            .toList();
    if (days.isEmpty) return;
    final max = days
        .map(
          (d) =>
              values[d]!.income > values[d]!.expense
                  ? values[d]!.income
                  : values[d]!.expense,
        )
        .fold(BigInt.zero, (a, b) => a > b ? a : b);
    final rawMax = max == BigInt.zero ? 1.0 : max.toDouble();
    final power =
        math.pow(10, (math.log(rawMax / 4) / math.ln10).floor()).toDouble();
    final step =
        [1.0, 2.0, 2.5, 5.0, 10.0].firstWhere((v) => v * power >= rawMax / 4) *
        power;
    final ceiling = (rawMax / step).ceil() * step;
    final divisor =
        rawMax >= 1000000
            ? 1000000.0
            : rawMax >= 1000
            ? 1000.0
            : 1.0;
    const left = 64.0;
    final width = size.width - left - 8, plotHeight = size.height - 40;
    final group = width / days.length;
    void label(String s, Offset offset, {Color color = muted}) {
      final t = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: color),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      t.paint(canvas, offset);
    }

    for (var k = 0; k <= 4; k++) {
      final y = plotHeight - k * plotHeight / 4;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width, y),
        Paint()..color = const Color(0xFFE2EBE4),
      );
      final v = (ceiling * k / 4).round();
      final scaled = v / divisor;
      final text = digits(
        scaled == scaled.roundToDouble()
            ? scaled.toStringAsFixed(0)
            : scaled.toStringAsFixed(1),
      );
      label(text, Offset(2, y - 8));
    }

    for (var i = 0; i < days.length; i++) {
      final d = days[i], v = values[d]!;
      final x = left + i * group + group * .15,
          bw = (group * .28).clamp(2.0, 24.0);
      for (final item
          in [
            (v.income, const Color(0xFF176244)),
            (v.expense, const Color(0xFFB56C2C)),
          ].indexed) {
        final h = item.$2.$1.toDouble() / ceiling * plotHeight;
        canvas.drawRect(
          Rect.fromLTWH(x + item.$1 * (bw + 3), plotHeight - h, bw, h),
          Paint()..color = item.$2.$2,
        );
      }
      final parts = editableDate(d).split('/');
      label('${parts[1]}/${parts[2]}', Offset(x - 2, plotHeight + 10));
    }
  }

  @override
  bool shouldRepaint(DailyPainter old) => old.values != values;
}

String chartUnit(Map<DateTime, ({BigInt income, BigInt expense})> values) {
  final max = values.values.fold(
    BigInt.zero,
    (a, v) => [a, v.income, v.expense].reduce((x, y) => x > y ? x : y),
  );
  return max >= BigInt.from(1000000)
      ? 'میلیون تومان'
      : max >= BigInt.from(1000)
      ? 'هزار تومان'
      : 'تومان';
}
