import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:alo_simple/data/store.dart';
import 'package:alo_simple/domain/entry.dart';
import 'package:alo_simple/domain/financial_book.dart';
import 'package:alo_simple/domain/parser.dart';

Entry sample(
  String id,
  String kind,
  int amount,
  DateTime date, {
  String? person,
  String? related,
  Space space = Space.personal,
}) => Entry(
  id: id,
  space: space,
  title: 'ثبت آزمون',
  text: 'متن آزمون',
  date: date,
  createdAt: date,
  intent: kind,
  amount: amount,
  person: person,
  relatedId: related,
);
void main() {
  final now = DateTime(2026, 10, 4);
  test('shared yesterday date is carried across batch', () {
    final rows = FinancialBatch.parse(
      'دیروز پانصد هزار تومان خرج کردم و پنج میلیون تومان درآمد داشتم',
      Space.personal,
      now: now,
    );
    expect(rows.length, 2);
    expect(rows.every((e) => e.date == DateTime(2026, 10, 3)), true);
  });
  test('multi transaction expense and income', () {
    final es = FinancialBatch.parse(
      'پانصد هزار تومان خرج کردم و پنج میلیون تومان درآمد داشتم',
      Space.personal,
      now: now,
    );
    expect(es.length, 2);
    expect(es.map((e) => e.intent), ['expense', 'income']);
    expect(es.map((e) => e.amount), [500000, 5000000]);
    expect(es.map((e) => e.sourceId).toSet().length, 1);
  });
  test('three financial rows', () {
    final es = FinancialBatch.parse(
      'پانصد هزار تومان خرج کردم؛ پنج میلیون تومان درآمد داشتم؛ علی هشتصد هزار تومان به من بدهکار است',
      Space.personal,
      now: now,
    );
    expect(es.length, 3);
    expect(es.last.intent, 'receivable');
    expect(es.last.person, 'علی');
  });
  test('quantity price comma not split', () {
    final es = FinancialBatch.parse(
      'سه عدد دفتر خریدم، هرکدام دویست و پنجاه هزار تومان',
      Space.personal,
      now: now,
    );
    expect(es.length, 1);
    expect(es.single.amount, 750000);
  });
  test('numbers conjunction is not a boundary', () {
    final es = FinancialBatch.parse(
      'دو میلیون و سیصد هزار تومان پرداخت کردم',
      Space.personal,
      now: now,
    );
    expect(es.length, 1);
    expect(es.single.amount, 2300000);
  });
  test('unknown voice never saved as note', () {
    final e =
        FinancialBatch.parse('سلام امروز باران آمد', Space.personal).single;
    expect(e.intent, 'unknown');
    expect(e.saveBlockReason, isNotNull);
  });
  test('negated speech must be reviewed', () {
    final e =
        FinancialBatch.parse(
          'پانصد هزار تومان پرداخت نکردم',
          Space.personal,
        ).single;
    expect(e.intent, 'unknown');
    expect(e.saveBlockReason, isNotNull);
  });
  test('loan not ordinary income', () {
    expect(
      FinancialBatch.parse(
        'پنج میلیون تومان وام گرفتم',
        Space.personal,
      ).single.intent,
      'unknown',
    );
  });
  test('date follows yesterday', () {
    expect(
      FinancialBatch.parse(
        'دیروز پانصد هزار تومان خرج کردم',
        Space.personal,
        now: now,
      ).single.date,
      DateTime(2026, 10, 3),
    );
  });
  test('Gregorian day exact end exclusive', () {
    final w = ReportWindow.make('روز', now);
    expect(w.contains(DateTime(2026, 10, 4, 23, 59)), true);
    expect(w.contains(DateTime(2026, 10, 5)), false);
  });
  test('Persian week begins Saturday', () {
    final w = ReportWindow.make('هفته', now);
    expect(w.start.weekday, DateTime.saturday);
    expect(w.end.difference(w.start).inDays, 7);
    expect(w.contains(now), true);
  });
  test('Persian month boundaries', () {
    final w = ReportWindow.make('ماه', now);
    expect(Jalali.fromDateTime(w.start).day, 1);
    expect(Jalali.fromDateTime(w.start).month, 7);
    expect(Jalali.fromDateTime(w.end).month, 8);
  });
  test('Persian year starts Farvardin', () {
    final w = ReportWindow.make('سال', now);
    expect(Jalali.fromDateTime(w.start).month, 1);
    expect(Jalali.fromDateTime(w.start).day, 1);
    expect(Jalali.fromDateTime(w.end).year, Jalali.fromDateTime(now).year + 1);
  });
  test('future and prior rows do not enter monthly totals', () {
    final r = FinancialReport([
      sample('a', 'income', 5000000, now),
      sample('b', 'expense', 750000, now),
      sample('c', 'expense', 100000, DateTime(2026, 9, 1)),
      sample('d', 'income', 90000, DateTime(2027)),
    ], ReportWindow.make('ماه', now));
    expect(r.income, BigInt.from(5000000));
    expect(r.expense, BigInt.from(750000));
    expect(r.net, BigInt.from(4250000));
  });
  test('debt and transfer never counted as expenses', () {
    final r = FinancialReport([
      sample('a', 'payable', 1000, now, person: 'علی'),
      sample('b', 'receivable', 400, now, person: 'رضا'),
      revise(sample('c', 'transfer', 300, now), {'counterAccount': 'نقد'}),
    ], ReportWindow.make('ماه', now));
    expect(r.net, BigInt.zero);
    expect(r.expense, BigInt.zero);
  });
  test('settlement changes balance not income or expense', () {
    final debt = sample(
          'd',
          'payable',
          800000,
          DateTime(2026, 9, 1),
          person: 'علی',
        ),
        paid = sample(
          'p',
          'payable_payment',
          300000,
          now,
          person: 'علی',
          related: 'd',
        );
    final r = FinancialReport([debt, paid], ReportWindow.make('ماه', now));
    expect(r.outstanding('payable'), BigInt.from(500000));
    expect(r.expense, BigInt.zero);
    expect(r.cashOut, BigInt.from(300000));
  });
  test('settlement more than remaining rejected', () {
    final rows = [
      sample('d', 'payable', 800, now, person: 'علی'),
      sample('p', 'payable_payment', 801, now, person: 'علی', related: 'd'),
    ];
    expect(FinancialBook.validateRelations(rows), isNotNull);
  });
  test('settlement wrong party rejected', () {
    final rows = [
      sample('d', 'receivable', 800, now, person: 'علی'),
      sample(
        'p',
        'receivable_collection',
        100,
        now,
        person: 'رضا',
        related: 'd',
      ),
    ];
    expect(FinancialBook.validateRelations(rows), isNotNull);
  });
  test('settlement date before principal rejected', () {
    final rows = [
      sample('d', 'payable', 800, now, person: 'علی'),
      sample(
        'p',
        'payable_payment',
        100,
        DateTime(2026, 9, 1),
        person: 'علی',
        related: 'd',
      ),
    ];
    expect(FinancialBook.validateRelations(rows), isNotNull);
  });
  test('report space separation', () {
    final r = FinancialReport(
      [
        sample('a', 'income', 10, now),
        sample('b', 'income', 20, now, space: Space.business),
      ],
      ReportWindow.make('ماه', now),
      space: Space.personal,
    );
    expect(r.income, BigInt.from(10));
  });
  test('huge aggregate exact beyond float safe range', () {
    final rows = List.generate(
      1000,
      (i) => sample('$i', 'income', 100000000000000, now),
    );
    expect(
      FinancialReport(rows, ReportWindow.make('ماه', now)).income,
      BigInt.parse('100000000000000000'),
    );
  });
  test('missing amount does not become zero expense', () {
    final r = FinancialReport([
      Entry(
        id: 'x',
        space: Space.personal,
        title: 'نامشخص',
        text: '',
        date: now,
        createdAt: now,
        intent: 'expense',
      ),
    ], ReportWindow.make('ماه', now));
    expect(r.period, isEmpty);
  });
  test('category totals reconcile', () {
    final rows = [
      revise(sample('a', 'expense', 100, now), {'category': 'خوراک'}),
      revise(sample('b', 'expense', 200, now), {'category': 'خرید'}),
    ];
    final r = FinancialReport(rows, ReportWindow.make('ماه', now));
    expect(r.categories.values.fold(BigInt.zero, (a, b) => a + b), r.expense);
  });
  for (var i = 1; i <= 30; i++) {
    test('batch compositional quantities $i', () {
      final es = FinancialBatch.parse(
        '$i عدد کالا خریدم هرکدام ۲۵۰ هزار تومان و پنج میلیون تومان درآمد داشتم',
        Space.personal,
        now: now,
      );
      expect(es.length, 2);
      expect(es.first.amount, i * 250000);
      expect(es.last.amount, 5000000);
    });
  }
  group('normalized SQLite', () {
    late Directory dir;
    late EntryStore store;
    late String path;
    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      dir = await Directory.systemTemp.createTemp('alo_v24_');
      path = '${dir.path}/db';
      store = EntryStore();
      await store.open(databasePath: path, cleanTemp: false);
    });
    tearDown(() async {
      await store.close();
      await dir.delete(recursive: true);
    });
    test('real columns and detail lines', () async {
      final e = NoteParser().parse(
        'سه عدد دفتر خریدم هرکدام پنجاه هزار تومان',
        Space.personal,
        now: now,
      );
      await store.save(e);
      final db = await databaseFactory.openDatabase(path);
      final rows = await db.query('financial_transactions');
      expect(rows.single['amount_toman'], 150000);
      expect(rows.single['kind'], 'expense');
      expect((await db.query('transaction_lines')).single['quantity'], 3);
      await db.close();
    });
    test('batch transaction all or nothing', () async {
      final good = sample('g', 'income', 100, now),
          bad = revise(sample('b', 'expense', 100, now), {'amount': null});
      await expectLater(store.merge([good, bad]), throwsStateError);
      expect(await store.load(), isEmpty);
    });
    test('debt cannot delete while settlement exists', () async {
      final d = sample('d', 'payable', 800, now, person: 'علی'),
          s = sample(
            's',
            'payable_payment',
            100,
            now,
            person: 'علی',
            related: 'd',
          );
      await store.merge([d, s]);
      await expectLater(store.remove('d'), throwsStateError);
      expect((await store.load()).length, 2);
    });
    test('overpayment is transactional', () async {
      final d = sample('d', 'receivable', 800, now, person: 'رضا');
      await store.save(d);
      await expectLater(
        store.save(
          sample(
            's',
            'receivable_collection',
            900,
            now,
            person: 'رضا',
            related: 'd',
          ),
        ),
        throwsStateError,
      );
      expect((await store.load()).length, 1);
    });
    test('upgrade preserves old notes and creates structured columns', () async {
      await store.close();
      await deleteDatabase(path);
      final e = sample('legacy', 'income', 5000, now);
      final db = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE notes (id TEXT PRIMARY KEY, space TEXT NOT NULL, date TEXT NOT NULL, body TEXT NOT NULL)',
            );
            await db.insert('notes', {
              'id': e.id,
              'space': 'personal',
              'date': e.date.toIso8601String(),
              'body': jsonEncode(e.toJson()),
            });
          },
        ),
      );
      await db.close();
      await store.open(databasePath: path, cleanTemp: false);
      expect((await store.load()).single.id, 'legacy');
      final check = await databaseFactory.openDatabase(path);
      expect(
        (await check.query('financial_transactions')).single['amount_toman'],
        5000,
      );
      await check.close();
    });
  });
}
