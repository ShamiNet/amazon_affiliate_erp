import 'package:amazon_affiliate_erp/main.dart';
import 'package:amazon_affiliate_erp/campaign_table_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryPrefs extends CampaignTablePrefs {
  @override
  void save() {}
}

void main() {
  testWidgets('hide restore and sort columns in both campaign views',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = AppDataController(initialize: false);
    c.campaigns = [
      CampaignLogModel.fromJson({'seq': 1, 'date': '2026-10-21'})
    ];
    final prefs = MemoryPrefs();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CampaignsInventoryScreen(controller: c, tablePrefs: prefs))));
    await tester.pumpAndSettle();
    DataTable table() => tester.widget<DataTable>(find.byType(DataTable));
    expect(table().columns.length, 21);
    table().columns[2].onSort!(2, true);
    await tester.pumpAndSettle();
    expect(table().sortColumnIndex, 2);
    await tester.tap(find.text('إظهار / إخفاء الأعمدة'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('column-visibility-0')));
    await tester.pumpAndSettle();
    expect(table().columns.length, 20);
    expect(table().rows.single.cells.length, 20);
    expect(table().sortColumnIndex, 1);
    await tester.tap(find.byKey(const ValueKey('column-visibility-2')));
    await tester.pumpAndSettle();
    expect(table().sortColumnIndex, isNull);
    expect(prefs.sortLevels.containsKey(1), isTrue);
    await tester.tap(find.text('إظهار الكل'));
    await tester.pumpAndSettle();
    expect(table().columns.length, 21);
    expect(table().sortColumnIndex, 2);
    await tester.tap(find.text('تم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عرض الملخص اليومي المجمّع'));
    await tester.pumpAndSettle();
    expect(table().columns.length, 9);
    await tester.tap(find.text('إظهار / إخفاء الأعمدة'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      await tester.ensureVisible(find.byKey(ValueKey('column-visibility-$i')));
      await tester.tap(find.byKey(ValueKey('column-visibility-$i')));
      await tester.pumpAndSettle();
    }
    expect(table().columns.length, 1);
    expect(table().rows.single.cells.length, 1);
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('column-visibility-8')))
            .onChanged,
        isNull);
    expect(prefs.hiddenColumns, isEmpty);
    await tester.tap(find.text('إظهار الكل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تم'));
    await tester.pumpAndSettle();
    expect(table().columns.length, 9);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  }, semanticsEnabled: false);
}
