class TtsEngine {
  Future<void> speak(String text) async =>
      throw StateError('خواندن آفلاین فارسی در نسخهٔ موبایل فعال است.');
  Future<void> stop() async {}
  Future<void> dispose() async {}
}
