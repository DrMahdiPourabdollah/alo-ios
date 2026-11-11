#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'iOS compilation requires macOS + Xcode. This project is not an installable IPA.' >&2
  exit 2
fi
command -v flutter >/dev/null || { echo 'Install Flutter 3.35.7 first.' >&2; exit 2; }
xcodebuild -version
python3 verify_models.py
flutter pub get
flutter analyze
flutter test
# First prove native compilation. Unsigned Runner.app is NOT directly installable.
flutter build ios --release --no-codesign
printf '\nUnsigned iOS compilation complete. Open ios/Runner.xcworkspace, select your Apple team, and sign for a device.\n'
printf 'After signing configuration, use flutter build ipa --release for the chosen distribution method.\n'
