import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entry.dart';
import '../domain/financial_book.dart';

/// Web is a UI preview only. Mobile uses SQLite, not browser storage.
class EntryStore {
  late SharedPreferences _prefs;
  List<Entry> _entries = [];
  Future<void> open({String? databasePath, bool cleanTemp = true}) async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString('alo_preview_v2');
    if (raw != null) {
      _entries =
          (jsonDecode(raw) as List)
              .map((m) => Entry.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList();
    }
  }

  Future<List<Entry>> load() async => List.of(_entries);
  Future<void> save(Entry e) async {
    if (e.saveBlockReason != null) throw StateError(e.saveBlockReason!);
    final updated = [e, ..._entries.where((n) => n.id != e.id)];
    final error = FinancialBook.validateRelations(updated);
    if (error != null) throw StateError(error);
    await _persist(updated);
    _entries = updated;
  }

  Future<void> remove(String id) async {
    final updated = _entries.where((n) => n.id != id).toList();
    final error = FinancialBook.validateRelations(updated);
    if (error != null) throw StateError(error);
    await _persist(updated);
    _entries = updated;
  }

  Future<void> _persist(List<Entry> es) async {
    if (!await _prefs.setString(
      'alo_preview_v2',
      jsonEncode(es.map((e) => e.toJson()).toList()),
    )) {
      throw StateError('Storage write failed');
    }
  }

  Future<void> merge(List<Entry> entries) async {
    for (final e in entries) {
      if (e.saveBlockReason != null) throw StateError(e.saveBlockReason!);
    }
    final ids = entries.map((e) => e.id).toSet();
    final updated = [...entries, ..._entries.where((e) => !ids.contains(e.id))];
    final error = FinancialBook.validateRelations(updated);
    if (error != null) throw StateError(error);
    await _persist(updated);
    _entries = updated;
  }

  Future<void> close() async {}
}
