import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/entry.dart';
import '../domain/financial_book.dart';

class EntryStore {
  Database? _db;
  static Future<void> _financialSchema(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS financial_transactions (id TEXT PRIMARY KEY, space TEXT NOT NULL, occurred_at TEXT NOT NULL, created_at TEXT NOT NULL, kind TEXT NOT NULL, title TEXT NOT NULL, amount_toman INTEGER NOT NULL, category TEXT NOT NULL, account TEXT NOT NULL, counter_account TEXT, person TEXT, merchant TEXT, payment TEXT, related_id TEXT, source_id TEXT, transcript TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS financial_date_kind ON financial_transactions(occurred_at,kind)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS financial_related ON financial_transactions(related_id)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS transaction_lines (transaction_id TEXT PRIMARY KEY, description TEXT NOT NULL, quantity INTEGER NOT NULL, unit TEXT, unit_price_toman INTEGER NOT NULL, total_toman INTEGER NOT NULL)',
    );
  }

  static Future<void> _write(DatabaseExecutor db, Entry e) async {
    await db.insert('notes', {
      'id': e.id,
      'space': e.space.name,
      'date': e.date.toIso8601String(),
      'body': jsonEncode(e.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.delete(
      'transaction_lines',
      where: 'transaction_id=?',
      whereArgs: [e.id],
    );
    await db.delete('financial_transactions', where: 'id=?', whereArgs: [e.id]);
    if (!e.isFinancial || e.saveBlockReason != null) return;
    await db.insert('financial_transactions', {
      'id': e.id,
      'space': e.space.name,
      'occurred_at': e.date.toIso8601String(),
      'created_at': e.createdAt.toIso8601String(),
      'kind': e.intent,
      'title': e.title,
      'amount_toman': e.amount,
      'category': e.category,
      'account': e.account,
      'counter_account': e.counterAccount,
      'person': e.person,
      'merchant': e.merchant,
      'payment': e.payment,
      'related_id': e.relatedId,
      'source_id': e.sourceId,
      'transcript': e.rawTranscript ?? e.text,
    });
    if (e.quantity != null && e.unitPrice != null) {
      await db.insert('transaction_lines', {
        'transaction_id': e.id,
        'description': e.title,
        'quantity': e.quantity,
        'unit': e.unit,
        'unit_price_toman': e.unitPrice,
        'total_toman': e.calculatedTotal,
      });
    }
  }

  Future<void> open({String? databasePath, bool cleanTemp = true}) async {
    _db = await openDatabase(
      databasePath ?? p.join(await getDatabasesPath(), 'alo_notebook_v2.db'),
      version: 2,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE notes (id TEXT PRIMARY KEY, space TEXT NOT NULL, date TEXT NOT NULL, body TEXT NOT NULL)',
        );
        await db.execute('CREATE INDEX notes_space_date ON notes(space,date)');
        await _financialSchema(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        await _financialSchema(db);
        final rows = await db.query('notes');
        for (final row in rows) {
          final e = Entry.fromJson(
            jsonDecode(row['body'] as String) as Map<String, dynamic>,
          );
          await _write(db, e);
        }
      },
    );
    if (!cleanTemp) return;
    final tmp = await getTemporaryDirectory();
    for (final file in tmp.listSync().whereType<File>()) {
      if (p.basename(file.path).startsWith('alo_voice_')) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  static Future<List<Entry>> _read(DatabaseExecutor db) async =>
      (await db.query('notes', orderBy: 'date DESC, rowid DESC'))
          .map(
            (m) => Entry.fromJson(
              jsonDecode(m['body'] as String) as Map<String, dynamic>,
            ),
          )
          .toList();
  Future<List<Entry>> load() => _read(_db!);
  Future<void> save(Entry e) => merge([e]);
  Future<void> merge(List<Entry> entries) async {
    if (entries.map((e) => e.id).toSet().length != entries.length) {
      throw StateError('شناسه تراکنش‌ها تکراری است.');
    }
    for (final e in entries) {
      if (e.saveBlockReason != null) throw StateError(e.saveBlockReason!);
    }
    await _db!.transaction((txn) async {
      final previous = await _read(txn), ids = entries.map((e) => e.id).toSet();
      final error = FinancialBook.validateRelations([
        ...previous.where((e) => !ids.contains(e.id)),
        ...entries,
      ]);
      if (error != null) throw StateError(error);
      for (final e in entries) {
        await _write(txn, e);
      }
    });
  }

  Future<void> remove(String id) async {
    await _db!.transaction((txn) async {
      final rows = await _read(txn);
      if (rows.any((e) => e.relatedId == id)) {
        throw StateError('ابتدا تسویه‌های مرتبط را حذف یا اصلاح کنید.');
      }
      await txn.delete(
        'transaction_lines',
        where: 'transaction_id=?',
        whereArgs: [id],
      );
      await txn.delete(
        'financial_transactions',
        where: 'id=?',
        whereArgs: [id],
      );
      await txn.delete('notes', where: 'id=?', whereArgs: [id]);
    });
  }

  Future<void> close() async => _db?.close();
}
