import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'speech_presence.dart';
import 'inference_gate.dart';
import 'operation_queue.dart';
import '../models/model_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

/// Local Persian recognition. Persian fine-tuned Turbo Q8 model embedded in the app.
class VoiceService {
  final _recorder = AudioRecorder();
  String? _audio;
  bool _busy = false;
  bool _disposed = false;
  final _operations = VoiceOperationQueue();
  bool get supported => Platform.isAndroid || Platform.isIOS;
  Future<File> _model() async => File(await ModelManager.modelPath());
  Future<bool> ready() => ModelManager.ready();
  Future<void> importModel() => ModelManager.importAsr();
  Future<T> _run<T>(Future<T> Function() operation) =>
      _operations.run(() async {
        if (_disposed) throw StateError('صفحهٔ ضبط بسته شده است.');
        return operation();
      });

  Future<void> start() => _run(_start);
  Future<void> _start() async {
    if (_audio != null) throw StateError('ضبط قبلی هنوز تمام نشده است.');
    if (_busy || InferenceGate.busy) {
      throw StateError('پردازش صدای قبلی هنوز تمام نشده؛ چند لحظه صبر کن.');
    }
    if (!await ready()) throw StateError('اول مدل صوت را نصب کنید.');
    await ModelManager.checkRecognitionMemory();
    if (!await _recorder.hasPermission()) {
      throw StateError('دسترسی میکروفون داده نشد؛ می‌توانید بنویسید.');
    }
    _audio = p.join(
      (await getTemporaryDirectory()).path,
      'alo_voice_${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: _audio!,
      );
    } catch (_) {
      try {
        await _cancel();
      } catch (_) {
        // Keep the original recording/permission error.
      }
      rethrow;
    }
  }

  Future<double> amplitude() async => (await _recorder.getAmplitude()).current;
  Future<String> finish(void Function(int) onProgress) =>
      _run(() => _finish(onProgress));
  Future<String> _finish(void Function(int) onProgress) async {
    final originalPath = _audio;
    if (originalPath == null) throw StateError('ضبط فعالی وجود ندارد.');
    String? stoppedPath;
    _busy = true;
    var entered = false;
    try {
      stoppedPath = await _recorder.stop();
      final path = stoppedPath;
      if (path == null) {
        throw StateError('صدا ضبط نشد؛ دوباره تلاش کنید یا بنویسید.');
      }
      InferenceGate.enter();
      entered = true;
      final f = File(path);
      if (!await f.exists() || await f.length() < 3244) {
        throw StateError('صدای ضبط‌شده خیلی کوتاه است.');
      }
      final vadFile = File(
        p.join(
          (await getApplicationSupportDirectory()).path,
          'alo-vad-v22.onnx',
        ),
      );
      if (!await vadFile.exists()) {
        final bytes = await rootBundle.load('assets/vad/silero_vad.onnx');
        await vadFile.writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          flush: true,
        );
      }
      if (!await compute(hasSpeech, {'audio': path, 'model': vadFile.path})) {
        throw StateError(
          'گفتار واضحی پیدا نشد؛ نزدیک تر و با صدای روشن صحبت کن.',
        );
      }
      await ModelManager.checkRecognitionMemory();
      // Model is specified by LOCAL path. This does not invoke downloadModel.
      final response = await const Whisper(
        model: WhisperModel.large,
      ).transcribe(
        modelPath: (await _model()).path,
        transcribeRequest: TranscribeRequest(
          audio: path,
          language: 'fa',
          isTranslate: false,
          isNoTimestamps: true,
          noContext: true,
          suppressNonSpeechTokens: true,
          initialPrompt:
              'خرید، هزینه، درآمد، بدهکار، طلب، تومان، ریال، تعداد، قیمت، هر کدام، کارت، نقد.',
          keepModelLoaded: false,
          noFallback: true,
          threads: Platform.numberOfProcessors.clamp(2, 6),
        ),
        onProgress: onProgress,
      );
      final text = response.text.trim();
      if (text.isEmpty || RegExp(r'^\[.*\]$').hasMatch(text)) {
        throw StateError('گفتار واضحی دریافت نشد؛ دوباره بگویید یا بنویسید.');
      }
      return text;
    } finally {
      if (entered) InferenceGate.leave();
      if (stoppedPath == null) {
        try {
          await _recorder.cancel();
        } catch (_) {
          // Preserve the stop error; cleanup still runs below.
        }
      }
      _busy = false;
      _audio = null;
      for (final name in {
        originalPath,
        '$originalPath.wav',
        if (stoppedPath != null) stoppedPath,
        if (stoppedPath != null) '$stoppedPath.wav',
      }) {
        final file = File(name);
        try {
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // Retry on next app startup; do not hide recognition errors.
        }
      }
    }
  }

  Future<void> cancel() => _run(_cancel);
  Future<void> _cancel() async {
    final path = _audio;
    try {
      await _recorder.cancel();
    } finally {
      _audio = null;
      if (path != null) {
        for (final name in {path, '$path.wav'}) {
          final file = File(name);
          try {
            if (await file.exists()) await file.delete();
          } on FileSystemException {
            // Startup cleanup will retry temporary audio deletion.
          }
        }
      }
    }
  }

  // Queued after inference: never free a recorder during native processing.
  Future<void> dispose() => _operations.run(() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _cancel();
    } finally {
      await _recorder.dispose();
    }
  });
}
