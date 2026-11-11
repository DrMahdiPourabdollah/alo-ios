import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:alo_simple/domain/persian_number_parser.dart';
import 'package:alo_simple/domain/persian_text_normalizer.dart';
import 'package:alo_simple/domain/entry.dart';
import 'package:alo_simple/domain/parser.dart';
import 'package:alo_simple/voice/operation_queue.dart';

void main() {
  for (final input in [
    '1,0000',
    '1234,567',
    '1,234,56',
    '12٬345٬67',
    '۱٬۰۰۰۰',
  ]) {
    test('malformed digit grouping is never silently repaired: $input', () {
      expect(PersianNumberParser.integer(input), isNull);
      final e = NoteParser().parse('$input تومان پرداخت کردم', Space.personal);
      expect(e.saveBlockReason, isNotNull);
    });
  }
  for (final pair in <String, int>{
    '۱٬۲۳۴٬۵۶۷': 1234567,
    '12,345': 12345,
    '۱۲٬۳۴۵٫۵ هزار': 12345500,
    'هزار میلیون': 1000000000,
    'دو هزار میلیون': 2000000000,
    'دو میلیون و نیم': 2500000,
  }.entries) {
    test('valid exact numeric forms remain supported: ${pair.key}', () {
      expect(PersianNumberParser.integer(pair.key), pair.value);
    });
  }
  test('punctuation after a valid grouped number is preserved', () {
    expect(PersianTextNormalizer.normalize('۱٬۲۳۴، نان'), '1234، نان');
    expect(PersianTextNormalizer.normalize('1,234, نان'), '1234, نان');
  });
  for (final input in ['هزار هزار', 'هزار و هزار', 'میلیون میلیون']) {
    test('repeated empty scale is ambiguous: $input', () {
      expect(PersianNumberParser.integer(input), isNull);
    });
  }
  test('recorder operations remain serial across await boundaries', () async {
    final queue = VoiceOperationQueue();
    final release = Completer<void>();
    final started = Completer<void>();
    final events = <String>[];
    final inference = queue.run(() async {
      events.add('inference-start');
      started.complete();
      await release.future;
      events.add('inference-end');
      return 'text';
    });
    final cancel = queue.run(() async => events.add('cancel'));
    final dispose = queue.run(() async => events.add('dispose'));
    await started.future;
    expect(events, ['inference-start']);
    release.complete();
    expect(await inference, 'text');
    await cancel;
    await dispose;
    expect(events, ['inference-start', 'inference-end', 'cancel', 'dispose']);
  });
  test('a failed recorder operation does not poison the queue', () async {
    final queue = VoiceOperationQueue();
    final failed = queue.run<int>(() async => throw StateError('stop failed'));
    final next = queue.run(() async => 42);
    await expectLater(failed, throwsStateError);
    expect(await next, 42);
  });
  test('synchronous operation failures also allow cleanup', () async {
    final queue = VoiceOperationQueue();
    final failed = queue.run<void>(() => throw StateError('platform failure'));
    final cleanup = queue.run(() async => true);
    await expectLater(failed, throwsStateError);
    expect(await cleanup, isTrue);
  });
}
