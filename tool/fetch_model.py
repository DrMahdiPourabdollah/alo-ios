#!/usr/bin/env python3
"""Developer-only downloader. Never called by the app. Use a trusted model URL."""
import argparse, hashlib, os, urllib.request
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--url',required=True,help='Trusted HTTPS URL or your own accessible model mirror')
p.add_argument('--sha256',help='Expected SHA-256 from a trusted upstream manifest')
p.add_argument('--output',default='assets/models/ggml-base.bin')
a=p.parse_args()
if not a.url.startswith('https://'):p.error('Only HTTPS URLs are accepted')
if a.sha256 and (len(a.sha256)!=64 or any(c not in '0123456789abcdefABCDEF' for c in a.sha256)):p.error('Invalid SHA-256')
dest=Path(a.output);dest.parent.mkdir(parents=True,exist_ok=True);tmp=dest.with_suffix('.part')
h=hashlib.sha256()
try:
 with urllib.request.urlopen(a.url,timeout=60) as response, open(tmp,'wb') as output:
  while chunk:=response.read(1024*1024):output.write(chunk);h.update(chunk)
  output.flush();os.fsync(output.fileno())
 if tmp.stat().st_size<10000000 or tmp.open('rb').read(4)!=b'lmgg':raise ValueError('Not a ggml Whisper model')
 digest=h.hexdigest()
 if a.sha256 and digest.lower()!=a.sha256.lower():raise ValueError('SHA-256 mismatch; existing model was not changed')
 os.replace(tmp,dest)
 print(f'Saved {dest}; SHA-256 {digest}')
 if not a.sha256:print('WARNING: no trusted checksum supplied. Verify this hash before distributing.')
finally:
 if tmp.exists():tmp.unlink()
