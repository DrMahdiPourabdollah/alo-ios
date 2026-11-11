import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/store.dart';
import '../domain/entry.dart';
import 'theme.dart';
import 'model_setup.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});
  final EntryStore store;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;

  void _message(String s) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
    }
  }

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      _message(
        e is StateError
            ? e.message
            : 'انجام نشد. فایل و فضای ذخیره‌سازی را بررسی کنید.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final notes = await widget.store.load();
    if (!mounted) return;
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('نسخه پشتیبان خصوصی است'),
            content: const Text(
              'این فایل متن تراکنش‌ها و یادداشت‌های قبلی را دارد و رمزگذاری نشده. در محل امن نگهش دار و برای دیگران نفرست.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('ذخیره فایل'),
              ),
            ],
          ),
    );
    if (yes != true) return;
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'alo.notebook',
          'version': 1,
          'exportedAt': DateTime.now().toUtc().toIso8601String(),
          'entries': notes.map((e) => e.toJson()).toList(),
        }),
      ),
    );
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'ذخیره پشتیبان alo',
      fileName: 'alo-backup-${DateTime.now().millisecondsSinceEpoch}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    if (path != null) _message('فایل پشتیبان ذخیره شد.');
  }

  Future<void> _restore() async {
    final file = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (file == null) return;
    if (file.files.single.size > 10000000) {
      throw StateError('فایل پشتیبان بیش از حد بزرگ است.');
    }
    final bytes = file.files.single.bytes;
    if (bytes == null) throw StateError('فایل خوانده نشد.');
    final map = jsonDecode(utf8.decode(bytes));
    if (map is! Map ||
        map['format'] != 'alo.notebook' ||
        map['version'] != 1 ||
        map['entries'] is! List) {
      throw StateError('این فایل پشتیبان alo نیست.');
    }
    final list = map['entries'] as List;
    if (list.length > 20000) {
      throw StateError(
        'تعداد تراکنش‌ها و یادداشت‌های قبلی بیش از حد مجاز است.',
      );
    }
    final entries =
        list
            .map((m) => Entry.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList();
    if (entries.map((e) => e.id).toSet().length != entries.length) {
      throw StateError('فایل شناسه تکراری دارد.');
    }
    for (final e in entries) {
      if (e.id.isEmpty ||
          e.id.length > 100 ||
          e.title.trim().isEmpty ||
          e.title.length > 100 ||
          e.text.length > 2000 ||
          (e.rawTranscript?.length ?? 0) > 2000 ||
          (e.person?.length ?? 0) > 100 ||
          (e.merchant?.length ?? 0) > 100 ||
          e.validationIssues.length > 30 ||
          (e.calculationResult != null &&
              (!e.calculationResult!.isFinite ||
                  e.calculationResult!.abs() > 100000000000000)) ||
          (e.calculationExpression?.length ?? 0) > 2000 ||
          [
            e.amount,
            e.quantity,
            e.unitPrice,
          ].any((n) => n != null && (n < 0 || n > 100000000000000))) {
        throw StateError('بخشی از فایل معتبر نیست؛ چیزی تغییر نکرد.');
      }
    }
    final incomplete = entries.where((e) => e.saveBlockReason != null).length;
    if (!mounted) return;
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('تراکنش‌ها و یادداشت‌های قبلی برگردند؟'),
            content: Text(
              '${digits('${entries.length}')} یادداشت به دفتر اضافه می شود. رکوردهای هم نام با نسخهٔ فایل جایگزین می شوند.${incomplete == 0 ? '' : ' تعداد ${digits('$incomplete')} رکورد ناقص فقط به عنوان یادداشت بازیابی می شود؛ برای ثبت مالی باید اصلاح شود.'}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('برگردان'),
              ),
            ],
          ),
    );
    if (yes != true) return;
    await widget.store.merge(
      entries
          .map(
            (e) =>
                e.saveBlockReason == null
                    ? e
                    : Entry.fromJson({
                      ...e.toJson(),
                      'intent': 'note',
                      'reviewNote':
                          'اطلاعات مالی این رکورد ناقص بود؛ فقط به عنوان یادداشت بازیابی شد.',
                    }),
          )
          .toList(),
    );
    _message('تراکنش‌ها و یادداشت‌های قبلی برگشتند.');
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات', style: TextStyle(fontSize: 18)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Brand(size: 40),
                const SizedBox(height: 24),
                Text(
                  'صدایت، فقط روی گوشی خودت.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'بدون حساب کاربری و بدون ارسال صدا یا تراکنش‌ها و یادداشت‌های قبلی به سرور. فایل صوتی پس از بررسی پاک می‌شود؛ متن تشخیص‌داده‌شده برای بازبینی همراه تراکنش باقی می‌ماند.',
                  style: TextStyle(fontSize: 16, color: muted, height: 1.9),
                ),
                const SizedBox(height: 24),
                const ModelSetup(),
                const SizedBox(height: 24),
                Text(
                  'امنیت و نسخه پشتیبان',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'حذف اپ یا پاک کردن داده‌های آن، دفتر را پاک می‌کند. از تراکنش‌ها و یادداشت‌های قبلیی مهم نسخه پشتیبان بگیر. دفتر محلی رمزگذاری اختصاصی ندارد؛ از قفل دستگاه استفاده کن.',
                  style: TextStyle(fontSize: 14, color: muted, height: 1.9),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(_export),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('ذخیره نسخه پشتیبان'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _busy ? null : () => _run(_restore),
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('برگرداندن از فایل پشتیبان'),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                const SizedBox(height: 32),
                const Text(
                  'alo 2.2 · ساده برای زندگی، ساده برای کار',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
