# Third-party components
- Whisper GGML Small Q5_1: https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin — Whisper MIT; source https://github.com/ggml-org/whisper.cpp
- whisper_ggml 2.6.0: https://pub.dev/packages/whisper_ggml — native Whisper/FFmpeg wrapper; inspect package licenses for redistribution.
- Persian Piper Amir: https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-fa_IR-amir-medium.tar.bz2 — Persian Iran, one speaker, medium, 22050Hz; dataset CC0; accompanying MODEL_CARD included.
- Piper voice metadata: https://huggingface.co/rhasspy/piper-voices/tree/main/fa/fa_IR/amir/medium
- Sherpa-ONNX 1.13.8: https://github.com/k2-fsa/sherpa-onnx — Apache-2.0. Native dependencies include ONNX Runtime and eSpeak-NG.
- eSpeak-NG: https://github.com/espeak-ng/espeak-ng — GPL-3.0; its language data is delivered in the optional voice ZIP under tts/espeak-ng-data. Full license included. Source/build references: https://github.com/k2-fsa/sherpa-onnx/tree/master/cmake and https://github.com/espeak-ng/espeak-ng . This source archive contains the application's modified Dart code, not every third-party native build tree.
- ONNX Runtime: https://github.com/microsoft/onnxruntime — MIT.
- Vazirmatn: SIL Open Font License; bundled notice retained.

- Silero VAD: https://github.com/snakers4/silero-vad — MIT, bundled license in assets/licenses/Silero-VAD-MIT.txt.
- unorm_dart, crypto and archive: consult package LICENSE files and pubspec.lock for pinned versions.
- Models are separately distributed in 2.2; the source ZIP excludes large ASR/TTS binaries. Notices remain in assets/licenses.
