import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/store.dart';
import 'ui/finance_desk.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Whisper model',
    ], await rootBundle.loadString('assets/licenses/Whisper-MIT.txt'));
    yield LicenseEntryWithLineBreaks([
      'Vazirmatn',
    ], await rootBundle.loadString('assets/licenses/Vazirmatn-OFL.txt'));
    yield LicenseEntryWithLineBreaks(
      ['Sherpa-ONNX'],
      await rootBundle.loadString('assets/licenses/Sherpa-ONNX-Apache-2.0.txt'),
    );
    yield LicenseEntryWithLineBreaks([
      'eSpeak-NG',
    ], await rootBundle.loadString('assets/licenses/espeak-ng-GPL-3.0.txt'));
    yield LicenseEntryWithLineBreaks([
      'Persian Piper Mana',
    ], await rootBundle.loadString('assets/tts/MODEL_CARD'));
  });
  final store = EntryStore();
  Object? error;
  try {
    await store.open();
  } catch (e) {
    error = e;
  }
  runApp(AloApp(store: store, startupError: error));
}

class AloApp extends StatelessWidget {
  const AloApp({super.key, required this.store, this.startupError});
  final EntryStore store;
  final Object? startupError;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'alo · حسابداری صوتی',
    debugShowCheckedModeBanner: false,
    theme: aloTheme(),
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home:
        startupError != null
            ? const StorageFailure()
            : FinanceDesk(store: store),
  );
}

class StorageFailure extends StatelessWidget {
  const StorageFailure({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.lock_outline_rounded, size: 48, color: ink),
              SizedBox(height: 24),
              Text(
                'دفتر شما باز نشد',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'برای محافظت از یادداشت‌ها، چیزی تغییر ندادیم. فضای ذخیره‌سازی دستگاه را بررسی کنید و اپ را دوباره باز کنید.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
