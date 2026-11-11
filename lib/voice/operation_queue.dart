/// Serializes recorder lifecycle operations, including asynchronous failures.
/// Cancellation/disposal wait for native inference rather than interrupting it.
class VoiceOperationQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final result = _tail.then<T>((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
