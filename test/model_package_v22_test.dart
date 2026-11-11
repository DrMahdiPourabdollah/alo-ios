import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alo_simple/models/tts_package_installer.dart';

void main() {
  Future<Map<String, dynamic>> setup(
    Directory d, {
    String name = 'tts/model.txt',
    List<int>? content,
  }) async {
    final bytes = content ?? [1, 2, 3, 4];
    final zip = File('${d.path}/pack.zip');
    await zip.writeAsBytes(
      ZipEncoder().encode(
        Archive()..addFile(ArchiveFile(name, bytes.length, bytes)),
      ),
    );
    return {
      'source': zip.path,
      'root': '${d.path}/installed',
      'manifest': {
        name: {
          'size': 4,
          'sha256': sha256.convert([1, 2, 3, 4]).toString(),
        },
      },
    };
  }

  test('verified model ZIP installs completely', () async {
    final d = await Directory.systemTemp.createTemp();
    try {
      final r = await setup(d);
      await installTtsPackage(r);
      expect(await File('${r['root']}/model.txt').readAsBytes(), [1, 2, 3, 4]);
      expect(await File('${r['root']}/.ready').exists(), true);
    } finally {
      await d.delete(recursive: true);
    }
  });
  test('wrong SHA rejected, previous installed model retained', () async {
    final d = await Directory.systemTemp.createTemp();
    try {
      final r = await setup(d);
      await installTtsPackage(r);
      final bad = await setup(d, content: [4, 3, 2, 1]);
      await expectLater(installTtsPackage(bad), throwsStateError);
      expect(await File('${r['root']}/model.txt').readAsBytes(), [1, 2, 3, 4]);
    } finally {
      await d.delete(recursive: true);
    }
  });
  test('path traversal is rejected even with matching metadata', () async {
    final d = await Directory.systemTemp.createTemp();
    try {
      final r = await setup(d, name: 'tts/../escape');
      await expectLater(installTtsPackage(r), throwsStateError);
      expect(await File('${d.path}/escape').exists(), false);
    } finally {
      await d.delete(recursive: true);
    }
  });
  test('missing expected ZIP member rejected', () async {
    final d = await Directory.systemTemp.createTemp();
    try {
      final r = await setup(d);
      (r['manifest'] as Map)['tts/missing'] = {'size': 1, 'sha256': 'no'};
      await expectLater(installTtsPackage(r), throwsStateError);
    } finally {
      await d.delete(recursive: true);
    }
  });
}
