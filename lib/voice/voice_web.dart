class VoiceService {
  bool get supported => false;
  Future<bool> ready() async => false;
  Future<void> importModel() async =>
      throw StateError('مدل صوت روی نسخه موبایل نصب می‌شود.');
  Future<void> start() async =>
      throw StateError(
        'ثبت صوت آفلاین در نسخه موبایل فعال است. در پیش‌نمایش بنویسید.',
      );
  Future<String> finish(void Function(int) onProgress) async => '';
  Future<void> cancel() async {}
  Future<void> dispose() async {}
  Future<double> amplitude() async => -80;
}
