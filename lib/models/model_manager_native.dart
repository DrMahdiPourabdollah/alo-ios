import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// All model binaries are embedded in the app. Copying is streamed natively,
/// never loading the large recognition model into the Flutter UI heap.
class ModelManager {
  static const _channel = MethodChannel('ir.alo/bundled_models');
  static Future<void>? _asrInstall;
  static Future<String>? _ttsInstall;
  static Future<Map<String, dynamic>> _manifest() async =>
      jsonDecode(await rootBundle.loadString('assets/model_manifest.json'))
          as Map<String, dynamic>;
  static Future<String> modelPath() async => p.join(
    (await getApplicationSupportDirectory()).path,
    'alo-persian-turbo-v23.bin',
  );
  static Future<bool> ready() async {
    final file = File(await modelPath());
    final spec = (await _manifest())['asr'] as Map;
    final marker = File('${file.path}.verified');
    return await file.exists() &&
        await file.length() == spec['size'] &&
        await marker.exists() &&
        await marker.readAsString() == spec['sha256'];
  }

  static Future<void> downloadAsr(void Function(double) progress) async {
    progress(0);
    await (_asrInstall ??= _installAsr().whenComplete(
      () => _asrInstall = null,
    ));
    progress(1);
  }

  static Future<void> _installAsr() async {
    if (await ready()) return;
    final spec = (await _manifest())['asr'] as Map;
    try {
      await _channel.invokeMethod<void>('ensureFiles', {
        'root': (await getApplicationSupportDirectory()).path,
        'files': [
          {
            'asset': 'assets/models/ggml-persian-turbo-q8_0.bin',
            'target': 'alo-persian-turbo-v23.bin',
            'size': spec['size'],
            'sha256': spec['sha256'],
          },
        ],
      });
    } on PlatformException {
      throw StateError(
        'آماده‌سازی مدل داخل برنامه انجام نشد؛ فضای خالی گوشی را بررسی کن و دوباره تلاش کن.',
      );
    }
    if (!await ready()) {
      throw StateError('مدل تشخیص کامل آماده نشد. دوباره تلاش کن.');
    }
  }

  static Future<void> checkRecognitionMemory() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final info = await _channel.invokeMapMethod<String, dynamic>('memoryInfo');
    if (info != null &&
        ((info['available'] as num).toInt() < 1600000000 ||
            info['low'] == true)) {
      throw StateError(
        'حافظه آزاد برای پردازش گفتار کافی نیست. برنامه‌های دیگر را ببندید یا متن را وارد کنید.',
      );
    }
  }

  static Future<void> importAsr() => downloadAsr((_) {});
  static void
  cancelDownload() {} // No network transfer in the self-contained app.
  static Future<String> ttsPath() =>
      _ttsInstall ??= _prepareTts().catchError((Object e) {
        _ttsInstall = null;
        throw e;
      });
  static Future<String> _prepareTts() async {
    final root = p.join(
      (await getApplicationSupportDirectory()).path,
      'alo-mana-tts-v23',
    );
    final specs = (await _manifest())['tts'] as Map;
    try {
      await _channel.invokeMethod<void>('ensureFiles', {
        'root': root,
        'files': [
          for (final key in specs.keys)
            {
              'asset': 'assets/$key',
              'target': (key as String).substring(4),
              'size': (specs[key] as Map)['size'],
              'sha256': (specs[key] as Map)['sha256'],
            },
        ],
      });
    } on PlatformException {
      throw StateError(
        'آماده‌سازی صدای فارسی انجام نشد؛ فضای خالی گوشی را بررسی کن.',
      );
    }
    return root;
  }

  static Future<void> importTts() async {
    await ttsPath();
  }
}
