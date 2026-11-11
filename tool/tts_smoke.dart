// ignore_for_file: avoid_print
import 'package:sherpa_onnx/sherpa_onnx.dart' as s;

void main(List<String> args) {
  s.initBindings();
  final root = args[0];
  final t = s.OfflineTts(
    s.OfflineTtsConfig(
      model: s.OfflineTtsModelConfig(
        vits: s.OfflineTtsVitsModelConfig(
          model: '$root/fa_IR-amir-medium.onnx',
          tokens: '$root/tokens.txt',
          dataDir: '$root/espeak-ng-data',
        ),
        numThreads: 2,
        debug: false,
      ),
    ),
  );
  try {
    final a = t.generate(
      text:
          'امروز بیست عدد دفتر خریدم. هر کدام صد و هشتاد هزار تومان. مبلغ کل سه میلیون و ششصد هزار تومان.',
      speed: .95,
    );
    if (!s.writeWave(
      filename: args[1],
      samples: a.samples,
      sampleRate: a.sampleRate,
    )) {
      throw StateError('WAV write failed');
    }
    print('Persian TTS: ${a.samples.length} samples at ${a.sampleRate} Hz');
  } finally {
    t.free();
  }
}
