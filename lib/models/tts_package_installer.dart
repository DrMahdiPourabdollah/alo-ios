import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

Future<String> installTtsPackage(Map<String, dynamic> request) async {
  final root = request['root'] as String, temporary = Directory('$root.part');
  if (await temporary.exists()) await temporary.delete(recursive: true);
  await temporary.create(recursive: true);
  final manifest = request['manifest'] as Map;
  await _checkDirectory(request['source'] as String, manifest.length + 100);
  final input = InputFileStream(request['source'] as String);
  try {
    final archive = ZipDecoder().decodeStream(input, verify: true);
    final seen = <String>{};
    for (final file in archive) {
      if (file.isSymbolicLink) throw StateError('بستهٔ صوتی معتبر نیست.');
      if (!file.isFile) continue;
      if (!file.name.startsWith('tts/') ||
          p.isAbsolute(file.name) ||
          file.name.split('/').contains('..') ||
          file.name.contains('\\')) {
        throw StateError('مسیر فایل بسته معتبر نیست.');
      }
      final spec = manifest[file.name];
      if (spec is! Map || !seen.add(file.name) || file.size != spec['size']) {
        throw StateError('بستهٔ صوتی معتبر نیست.');
      }
      // Names are fixed by the app's manifest, never trusted from the archive.
      final relative = file.name.substring('tts/'.length);
      final dest = File(p.join(temporary.path, relative));
      await dest.parent.create(recursive: true);
      final output = _BoundedFileStream(dest.path, spec['size'] as int);
      try {
        file.writeContent(output);
      } finally {
        output.closeSync();
      }
      if (await dest.length() != spec['size'] ||
          (await sha256.bind(dest.openRead()).first).toString() !=
              spec['sha256']) {
        throw StateError('بستهٔ صوتی ناقص یا آسیب دیده است.');
      }
    }
    if (seen.length != manifest.length) {
      throw StateError('بستهٔ صوتی ناقص است.');
    }
    await File(
      p.join(temporary.path, '.ready'),
    ).writeAsString('verified', flush: true);
    final finalDir = Directory(root);
    final previous = Directory('$root.previous');
    if (await previous.exists()) await previous.delete(recursive: true);
    if (await finalDir.exists()) await finalDir.rename(previous.path);
    try {
      await temporary.rename(root);
    } catch (_) {
      if (await previous.exists()) await previous.rename(root);
      rethrow;
    }
    if (await previous.exists()) await previous.delete(recursive: true);
    return root;
  } finally {
    input.closeSync();
    if (await temporary.exists()) await temporary.delete(recursive: true);
  }
}

class _BoundedFileStream extends OutputFileStream {
  _BoundedFileStream(String path, this.limit)
    : super.withFileHandle(FileHandle(path, mode: FileAccess.write));
  final int limit;
  @override
  void writeBytes(List<int> bytes, {int? length}) {
    if (this.length + (length ?? bytes.length) > limit) {
      throw StateError('اندازهٔ فایل مدل معتبر نیست.');
    }
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeByte(int value) {
    if (length + 1 > limit) throw StateError('اندازهٔ فایل مدل معتبر نیست.');
    super.writeByte(value);
  }
}

Future<void> _checkDirectory(String path, int maximumFiles) async {
  final file = await File(path).open();
  try {
    final size = await file.length();
    if (size < 22 || size > 100000000) {
      throw StateError('بستهٔ صوتی معتبر نیست.');
    }
    final count = size < 65557 ? size : 65557;
    await file.setPosition(size - count);
    final bytes = await file.read(count);
    final data = ByteData.sublistView(bytes);
    for (var i = bytes.length - 22; i >= 0; i--) {
      if (data.getUint32(i, Endian.little) != 0x06054b50) continue;
      if (i + 22 + data.getUint16(i + 20, Endian.little) != bytes.length) {
        continue;
      }
      final entries = data.getUint16(i + 10, Endian.little);
      if (entries == 0 ||
          entries > maximumFiles ||
          data.getUint16(i + 4, Endian.little) != 0 ||
          data.getUint16(i + 6, Endian.little) != 0) {
        throw StateError('بستهٔ صوتی معتبر نیست.');
      }
      return;
    }
    throw StateError('بستهٔ صوتی معتبر نیست.');
  } finally {
    await file.close();
  }
}
