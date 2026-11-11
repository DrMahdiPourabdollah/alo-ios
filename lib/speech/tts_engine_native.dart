import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/model_manager.dart';
import '../voice/inference_gate.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// All synthesis is local. Inference runs off the Flutter UI isolate.
class TtsEngine {
  AudioPlayer? _audioPlayer;
  AudioPlayer get _player => _audioPlayer ??= AudioPlayer();
  int _ticket = 0;
  Completer<void>? _completion;
  Future<String> _prepare() => ModelManager.ttsPath();

  Future<void> speak(String text) async {
    await stop();
    final ticket = ++_ticket;
    final root = await _prepare();
    final output = p.join(
      (await getTemporaryDirectory()).path,
      'alo_voice_tts_${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    StreamSubscription<void>? subscription;
    try {
      if (ticket != _ticket) return;
      InferenceGate.enter();
      try {
        await compute(_synthesize, {
          'root': root,
          'text': text,
          'output': output,
        });
      } finally {
        InferenceGate.leave();
      }
      if (ticket != _ticket) return;
      final completion = Completer<void>();
      _completion = completion;
      subscription = _player.onPlayerComplete.listen(
        (_) {
          if (!completion.isCompleted) completion.complete();
        },
        onError: (Object error, StackTrace stack) {
          if (!completion.isCompleted) completion.completeError(error, stack);
        },
      );
      await _player.play(DeviceFileSource(output));
      await completion.future;
    } finally {
      await subscription?.cancel();
      if (ticket == _ticket) _completion = null;
      final file = File(output);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> stop() async {
    ++_ticket;
    if (_completion?.isCompleted == false) _completion!.complete();
    _completion = null;
    try {
      await _audioPlayer?.stop();
    } catch (_) {
      /* Preview or disposed plugin. */
    }
  }

  Future<void> dispose() async {
    await stop();
    await _audioPlayer?.dispose();
    _audioPlayer = null;
  }
}

String _synthesize(Map<String, String> input) {
  sherpa.initBindings();
  final root = input['root']!;
  final tts = sherpa.OfflineTts(
    sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: p.join(root, 'fa_IR-mana-medium.onnx'),
          tokens: p.join(root, 'tokens.txt'),
          dataDir: p.join(root, 'espeak-ng-data'),
          noiseScale: .667,
          noiseScaleW: .8,
        ),
        numThreads: 2,
        debug: false,
      ),
      maxNumSenetences: 2,
    ),
  );
  try {
    final audio = tts.generate(text: input['text']!, speed: 1.0);
    if (audio.samples.isEmpty ||
        !sherpa.writeWave(
          filename: input['output']!,
          samples: audio.samples,
          sampleRate: audio.sampleRate,
        )) {
      throw StateError(
        'تولید صدای فارسی انجام نشد. فضای خالی گوشی را بررسی کن.',
      );
    }
    return input['output']!;
  } finally {
    tts.free();
  }
}
