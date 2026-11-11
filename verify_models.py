#!/usr/bin/env python3
from pathlib import Path
from restore_models import specs,matches
root=Path(__file__).resolve().parent
for name,spec in specs(root).items():
 if not matches(root/'assets'/name,spec):
  raise SystemExit('Missing/wrong model: '+name+'\nRun: python3 restore_models.py /path/to/alo-2.4-Offline-Financial.apk')
print('All 360 ASR/TTS model assets match the original release manifest.')
