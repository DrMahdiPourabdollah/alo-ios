import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/store.dart';
import '../domain/entry.dart';
import 'theme.dart';
import 'compose.dart';
import 'review.dart';
import 'settings.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.store});
  final EntryStore store;
  void _open(BuildContext c, Space s) {
    HapticFeedback.selectionClick();
    Navigator.push(
      c,
      MaterialPageRoute<void>(
        builder: (_) => NotebookPage(store: store, space: s),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomPaint(
      painter: const AmbientPainter(),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      Brand(size: 40),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: muted,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'خصوصی، روی دستگاه',
                            style: TextStyle(fontSize: 14, color: muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'فقط بگو\nچی شد.',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 42,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'برای خودت یا برای کارت؛\nما مرتب ثبتش می‌کنیم.',
                    style: TextStyle(fontSize: 18, color: muted, height: 1.8),
                  ),
                  const SizedBox(height: 32),
                  _SpaceCard(
                    space: Space.personal,
                    onTap: () => _open(context, Space.personal),
                  ),
                  const SizedBox(height: 16),
                  _SpaceCard(
                    space: Space.business,
                    onTap: () => _open(context, Space.business),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    kIsWeb
                        ? 'پیش‌نمایش رابط · ثبت صوت آفلاین در نسخه موبایل'
                        : 'بدون شلوغی. بدون حساب‌وکتاب پیچیده.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SpaceCard extends StatelessWidget {
  const _SpaceCard({required this.space, required this.onTap});
  final Space space;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final dark = space == Space.personal;
    final fg = dark ? cream : ink;
    return Semantics(
      button: true,
      child: Material(
        color: dark ? pine : Colors.white,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: CustomPaint(
            painter: dark ? const AmbientPainter(dark: true) : null,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                dark
                                    ? Colors.white.withValues(alpha: .1)
                                    : sage,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            dark
                                ? Icons.favorite_border_rounded
                                : Icons.storefront_outlined,
                            color: fg,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          space.label,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dark
                              ? 'خریدها و پرداخت‌های روزانه‌ات'
                              : 'کالاها، فروش‌ها و پرداخت‌های کارت',
                          style: TextStyle(
                            fontSize: 14,
                            color: dark ? const Color(0xFFD0DFD5) : muted,
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.arrow_back_rounded, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NotebookPage extends StatefulWidget {
  const NotebookPage({super.key, required this.store, required this.space});
  final EntryStore store;
  final Space space;
  @override
  State<NotebookPage> createState() => _NotebookPageState();
}

class _NotebookPageState extends State<NotebookPage> {
  List<Entry> _entries = [];
  bool _loading = true, _table = false;
  String? _error;
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final entries = await widget.store.load();
      if (mounted) {
        setState(() {
          _entries =
              entries.where((e) => e.space == widget.space).toList()
                ..sort((a, b) {
                  final d = b.date.compareTo(a.date);
                  return d != 0 ? d : b.createdAt.compareTo(a.createdAt);
                });
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'یادداشت‌ها بارگذاری نشدند. دوباره تلاش کنید.';
        });
      }
    }
  }

  Future<void> _compose({bool voice = false}) async {
    final draft = await Navigator.push<Entry>(
      context,
      MaterialPageRoute(
        builder: (_) => ComposePage(space: widget.space, startWithVoice: voice),
      ),
    );
    if (draft == null || !mounted) return;
    await _review(draft, isNew: true);
  }

  Future<void> _review(Entry e, {bool isNew = false}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewPage(entry: e, store: widget.store, isNew: isNew),
      ),
    );
    if (changed == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('در دفترت ثبت شد ✓')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = widget.space == Space.business;
    final q = _search.text.trim();
    final filtered =
        _entries
            .where(
              (e) =>
                  q.isEmpty ||
                  '${e.title} ${e.text} ${e.person ?? ''}'.contains(q),
            )
            .toList();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'انتخاب دفتر',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
        title: Text(
          'دفتر ${widget.space.label}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'تنظیمات و مدل صوت',
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(store: widget.store),
                ),
              );
              await _load();
            },
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  Row(
                    children: [
                      const Brand(size: 28),
                      const Spacer(),
                      const Icon(Icons.circle, size: 7, color: ink),
                      const SizedBox(width: 6),
                      Text(
                        kIsWeb ? 'نسخه پیش‌نمایش' : 'ذخیره روی دستگاه',
                        style: const TextStyle(fontSize: 14, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    business ? 'امروز توی کارت\nچی گذشت؟' : 'امروز چی شد؟',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    business
                        ? 'چی آوردی، چی فروختی یا چی پرداخت کردی؟'
                        : 'هر خرید یا پرداختی داشتی، فقط بگو.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  _VoiceHero(
                    business: business,
                    onTap: () => _compose(voice: true),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _compose(),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('یا با نوشتن ثبت کن'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'یادداشت‌های تو',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (business)
                        IconButton(
                          tooltip: _table ? 'نمای کارت' : 'نمای جدول',
                          onPressed: () => setState(() => _table = !_table),
                          icon: Icon(
                            _table
                                ? Icons.view_agenda_outlined
                                : Icons.table_rows_outlined,
                          ),
                        ),
                      Text(
                        '${digits('${_entries.length}')} ثبت',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_entries.isNotEmpty) ...[
                    TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: 'در یادداشت‌ها جست‌وجو کن',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon:
                            q.isEmpty
                                ? null
                                : IconButton(
                                  tooltip: 'پاک کردن جست‌وجو',
                                  onPressed: _search.clear,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null)
                    Column(
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: _load,
                          child: const Text('تلاش دوباره'),
                        ),
                      ],
                    )
                  else if (filtered.isEmpty)
                    _Empty(isSearch: q.isNotEmpty, business: business)
                  else if (business && _table)
                    _BusinessTable(entries: filtered, onTap: _review)
                  else
                    for (final e in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: EntryCard(entry: e, onTap: () => _review(e)),
                      ),
                  if (kIsWeb)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Text(
                        'اطلاعات پیش‌نمایش در مرورگر ذخیره می‌شود؛ برای داده واقعی از نسخه موبایل استفاده کنید.',
                        style: TextStyle(fontSize: 14, color: muted),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceHero extends StatelessWidget {
  const _VoiceHero({required this.business, required this.onTap});
  final bool business;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: pine,
    borderRadius: BorderRadius.circular(28),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: CustomPaint(
        painter: const AmbientPainter(dark: true),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: cream,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7FB99C).withValues(alpha: .25),
                      blurRadius: 24,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.mic_none_rounded, size: 32, color: ink),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'بگو تا ثبت کنم',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: cream,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      business
                          ? 'مثلاً: بیست کارتن آب‌معدنی آوردم'
                          : 'مثلاً: امروز برای خرید کارت کشیدم',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFD0DFD5),
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.isSearch, required this.business});
  final bool isSearch, business;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFD5DED3)),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Icon(
          isSearch ? Icons.search_off_rounded : Icons.auto_stories_outlined,
          size: 36,
          color: muted,
        ),
        const SizedBox(height: 16),
        Text(
          isSearch ? 'چیزی پیدا نشد' : 'اولین یادداشتت رو ثبت کن',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isSearch
              ? 'یک عبارت دیگر امتحان کن.'
              : business
              ? 'بگو چه کالایی آوردی؛ ما مرتبش می‌کنیم.'
              : 'بگو کجا خرید کردی و چقدر پرداخت کردی.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class EntryCard extends StatelessWidget {
  const EntryCard({super.key, required this.entry, required this.onTap});
  final Entry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: sage,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      e.space == Space.business
                          ? Icons.inventory_2_outlined
                          : Icons.shopping_bag_outlined,
                      color: ink,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          dateLabel(e.date),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded, color: muted),
                ],
              ),
              const SizedBox(height: 16),
              if (e.quantity != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${money(e.quantity!)} ${e.unit ?? 'عدد'}${e.person == null ? '' : ' · ${e.person}'}',
                    style: const TextStyle(color: muted, fontSize: 16),
                  ),
                ),
              if (e.calculationResult != null)
                Text(
                  formatNumeric(e.calculationResult!),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                )
              else if (e.amount != null)
                Text(
                  '${money(e.amount!)} تومان',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                )
              else
                Text(
                  e.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, color: muted),
                ),
              if (e.payment != null || e.space == Space.business)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    [e.action, if (e.payment != null) e.payment!].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessTable extends StatelessWidget {
  const _BusinessTable({required this.entries, required this.onTap});
  final List<Entry> entries;
  final void Function(Entry) onTap;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: const WidgetStatePropertyAll(sage),
        dataRowMinHeight: 60,
        dataRowMaxHeight: 80,
        columns: const [
          DataColumn(label: Text('تاریخ')),
          DataColumn(label: Text('کالا / یادداشت')),
          DataColumn(label: Text('تعداد')),
          DataColumn(label: Text('شخص')),
          DataColumn(label: Text('هر واحد')),
          DataColumn(label: Text('مبلغ')),
        ],
        rows:
            entries
                .map(
                  (e) => DataRow(
                    cells: [
                      DataCell(Text(dateLabel(e.date)), onTap: () => onTap(e)),
                      DataCell(Text(e.title), onTap: () => onTap(e)),
                      DataCell(
                        Text(
                          e.quantity == null
                              ? '—'
                              : '${money(e.quantity!)} ${e.unit ?? ''}',
                        ),
                        onTap: () => onTap(e),
                      ),
                      DataCell(Text(e.person ?? '—'), onTap: () => onTap(e)),
                      DataCell(
                        Text(e.unitPrice == null ? '—' : money(e.unitPrice!)),
                        onTap: () => onTap(e),
                      ),
                      DataCell(
                        Text(
                          e.calculationResult != null
                              ? formatNumeric(e.calculationResult!)
                              : e.amount == null
                              ? '—'
                              : '${money(e.amount!)} تومان',
                        ),
                        onTap: () => onTap(e),
                      ),
                    ],
                  ),
                )
                .toList(),
      ),
    ),
  );
}
