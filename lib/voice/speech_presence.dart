import 'dart:math' as math;
import 'dart:typed_data';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Checks presence only; never crops audio or removes spoken number syllables.
bool hasSpeech(Map<String, String> input) {
  sherpa.initBindings();
  final wave = sherpa.readWave(input['audio']!);
  if (wave.sampleRate != 16000 ||
      wave.samples.isEmpty ||
      wave.samples.length > 16000 * 61) {
    throw StateError('فایل صوتی قابل بررسی نیست؛ دوباره ضبط کن.');
  }
  final vad = sherpa.VoiceActivityDetector(
    config: sherpa.VadModelConfig(
      sileroVad: sherpa.SileroVadModelConfig(
        model: input['model']!,
        threshold: .5,
        minSpeechDuration: .2,
        minSilenceDuration: .3,
        maxSpeechDuration: 65,
      ),
      sampleRate: 16000,
      numThreads: 1,
      debug: false,
    ),
    bufferSizeInSeconds: 70,
  );
  try {
    for (var i = 0; i < wave.samples.length; i += 512) {
      final end = math.min(i + 512, wave.samples.length);
      final chunk =
          end - i == 512
                ? Float32List.sublistView(wave.samples, i, end)
                : Float32List(512)
            ..setRange(0, end - i, wave.samples, i);
      vad.acceptWaveform(chunk);
      if (!vad.isEmpty()) return true;
    }
    vad.flush();
    return !vad.isEmpty();
  } finally {
    vad.free();
  }
}
