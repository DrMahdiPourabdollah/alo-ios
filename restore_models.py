#!/usr/bin/env python3
"""Restore only exact ASR/TTS model assets from an existing alo APK."""
import argparse,hashlib,json,pathlib,os,sys,urllib.parse,zipfile
ROOT=pathlib.Path(__file__).resolve().parent
def specs(root):
 m=json.loads((root/'assets/model_manifest.json').read_text())
 return {'models/ggml-persian-turbo-q8_0.bin':m['asr'],**m['tts']}
def matches(path,spec):
 if not path.is_file() or path.stat().st_size!=spec['size']:return False
 h=hashlib.sha256()
 with path.open('rb') as f:
  while b:=f.read(1024*1024):h.update(b)
 return h.hexdigest()==spec['sha256']
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('apk',type=pathlib.Path);p.add_argument('--destination',type=pathlib.Path,default=ROOT);a=p.parse_args()
 root=a.destination.resolve();entries=specs(root);changed=0
 with zipfile.ZipFile(a.apk) as z:
  for name,spec in entries.items():
   target=root/'assets'/name
   if matches(target,spec):continue
   member='assets/flutter_assets/'+urllib.parse.quote('assets/'+name,safe='/!')
   if z.getinfo(member).file_size!=spec['size']:sys.exit('Wrong model size in APK: '+name)
   target.parent.mkdir(parents=True,exist_ok=True);temp=target.with_name(target.name+'.restore-part');h=hashlib.sha256();size=0
   try:
    with z.open(member) as src,temp.open('wb') as dst:
     while b:=src.read(1024*1024):dst.write(b);h.update(b);size+=len(b)
    if size!=spec['size'] or h.hexdigest()!=spec['sha256']:sys.exit('Model checksum mismatch: '+name)
    os.replace(temp,target);changed+=1
   finally:temp.unlink(missing_ok=True)
 print(f'{len(entries)} exact model assets verified; {changed} restored. No model downloaded or substituted.')
if __name__=='__main__':main()
