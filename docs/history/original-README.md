# alo — iOS 2.4.1 source code

**This ZIP contains source code. It is NOT an installable IPA.** Native Xcode compilation, Apple signing and physical-iPhone acceptance testing remain pending. Do not send this ZIP to an employer as an iPhone installer.

This is the iPhone port of the offline financial alo app, with the same financial domain, number parser, calculation engine, SQLite schema and review form as Android 2.4. The iOS UI adds a frosted navigation bar, finite entrance animations, microphone press feedback, green hero-card waves, a new opaque icon, Cupertino transitions and Reduce Motion support.

## Contents
- Flutter UI, financial domain, storage and tests.
- iOS Runner/Xcode project and Swift bridge for streamed, SHA-verified model copying.
- Per-process iOS memory check, microphone permission description and initial privacy manifest.
- Vendored Whisper native plugin sources, fonts, VAD and upstream license notices.
- Model manifest, model-restoration tools and English iPhone installation/test PDF.

**Large ASR/TTS weights are excluded to keep this code ZIP small.** After restoring them, the intended runtime has the same original Persian Whisper Q8_0 and Mana Piper models, with no API key or runtime model download.

## Restore the exact models
From this folder:

```bash
python3 restore_models.py /path/to/alo-2.4-Offline-Financial.apk
python3 verify_models.py
```

All 360 expected ASR/TTS files must match the included manifest. Reference APK SHA256: `4e1fc1e152aef3e7830ade3722fea78443e2c58b6b421b92712647de0e7d3a7f`.

## Build on a Mac
1. Install Flutter **3.35.7**, Xcode and CocoaPods. Source target: **iOS 17+**, iPhone. Default bundle ID: `ir.alo.aloFinance`; project version: 2.4.1+6.
2. Restore/verify the model assets using the commands above.
3. Run:

```bash
bash build-ios.sh
```

The script verifies assets, resolves dependencies, runs Flutter analysis/tests and attempts **unsigned** release compilation with Xcode. It intentionally refuses to run on Linux. An unsigned `.app` is not a directly installable IPA.

4. Open **`ios/Runner.xcworkspace`**, select your Apple signing team and an appropriate registered bundle ID/device configuration. Prove native compilation and run the supplied native `RunnerTests`.
5. Test on a real iPhone in Release mode. After configuring valid Apple signing/distribution, build an IPA with `flutter build ipa --release` and the appropriate export configuration. Deliver a TestFlight invitation or a correctly provisioned device build—not this source ZIP.

No Apple certificate, provisioning profile, password or private key is included. Never paste Apple credentials into chat or commit them to a repository.

## Validation and limitations
Recorded shared Dart/Flutter result: **611 tests passed**, analysis without issues. Swift syntax and Xcode project structure were parsed, and the original 360 model hashes checked. The three supplied native XCTest tests were NOT run. There has been NO native Xcode build, signed IPA, iPhone Simulator run or physical-iPhone voice benchmark. This code handoff does not change that status; see `BUILD-STATUS.json`.

Same model files do not guarantee identical device performance. The large offline model may exceed an iPhone’s per-process memory budget; CPU inference speed, heat, microphone behavior and real Persian voice accuracy require device testing. Typed/manual entry remains the alternative, and financial drafts are never saved without user confirmation.

The privacy manifest is a starting configuration, not App Store approval. Review dependency/model licenses, including espeak-ng/GPL obligations, before public release. Local processing does not disable the user’s system backups. Exported financial JSON/CSV files are private and unencrypted.

## راهنمای کوتاه فارسی
این بسته فقط کد نسخهٔ آیفون است، نه IPA قابل نصب. وزن مدل‌ها را با APK اندروید فعلی و ابزار بازیابی داخل بسته برگردانید. ساخت روی Mac/Xcode، تست واقعی و امضای اپل همچنان لازم‌اند. مراحل نصب و تست به انگلیسی در `docs/iPhone-Installation-and-Test-Guide.pdf` قرار دارد. مدل‌ها همان مدل‌های فارسی نسخهٔ اندرویدند، ولی عملکرد واقعی آیفون هنوز تأیید نشده است.
