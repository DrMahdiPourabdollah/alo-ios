class ModelManager {
  static Future<void> checkRecognitionMemory() async {}
  static Future<bool> ready() async => false;
  static Future<String> modelPath() async => '';
  static Future<void> importAsr() async =>
      throw StateError('نصب مدل صوت در نسخهٔ موبایل فعال است.');
  static Future<void> downloadAsr(void Function(double) progress) async =>
      throw StateError('دانلود مدل صوت در نسخهٔ موبایل فعال است.');
  static void cancelDownload() {}
  static Future<void> importTts() async =>
      throw StateError('نصب صدای فارسی در نسخهٔ موبایل فعال است.');
  static Future<String> ttsPath() async =>
      throw StateError('برای خواندن، بستهٔ صدای فارسی را در تنظیمات نصب کن.');
}
