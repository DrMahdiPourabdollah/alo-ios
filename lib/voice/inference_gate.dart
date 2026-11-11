/// Shared UI-isolate guard: never run two memory-heavy local engines together.
class InferenceGate {
  static bool _busy = false;
  static bool get busy => _busy;
  static void enter() {
    if (_busy) {
      throw StateError('پردازش صدای قبلی هنوز تمام نشده؛ چند لحظه صبر کن.');
    }
    _busy = true;
  }

  static void leave() => _busy = false;
}
