import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:alo_simple/data/store.dart';
import 'package:alo_simple/domain/entry.dart';
import 'package:alo_simple/domain/parser.dart';

void main() {
  late Directory dir;
  late EntryStore store;
  late String path;
  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dir = await Directory.systemTemp.createTemp('alo_storage_test_');
    path = '${dir.path}/notes.db';
    store = EntryStore();
    await store.open(databasePath: path, cleanTemp: false);
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });
  test('SQLite saves and survives reopening', () async {
    final e = NoteParser().parse(
      '۲۰ کارتن دفتر آوردم هر کارتن ده هزار تومان',
      Space.business,
    );
    await store.save(e);
    await store.close();
    store = EntryStore();
    await store.open(databasePath: path, cleanTemp: false);
    expect((await store.load()).single.toJson(), e.toJson());
  });
  test('update replaces exactly one note', () async {
    final e = NoteParser().parse('۵۰ هزار تومن دادم', Space.personal);
    await store.save(e);
    await store.save(e);
    expect((await store.load()).length, 1);
  });
  test('delete only removes requested note', () async {
    final e = NoteParser().parse('خرید اول', Space.personal),
        b = NoteParser().parse('خرید دوم', Space.business);
    await store.save(e);
    await store.save(b);
    await store.remove(e.id);
    expect((await store.load()).single.id, b.id);
  });
  test('backup merge preserves unrelated notes', () async {
    final e = NoteParser().parse('اول', Space.personal),
        b = NoteParser().parse('دوم', Space.business);
    await store.save(e);
    await store.merge([b]);
    expect((await store.load()).length, 2);
    await store.merge([e]);
    expect((await store.load()).length, 2);
  });
}
