import 'package:amazon_affiliate_erp/main.dart';
import 'package:amazon_affiliate_erp/campaign_report_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final ambiguous in [false, true]) {
    testWidgets('matches store and date; ambiguous=$ambiguous', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = AppDataController(initialize: false);
      c.amazonAccounts = [
        AmazonAccountModel.fromJson({
          'code': 'SH-05',
          'storeId': 'b0fmxh8stx02-20',
        })
      ];
      c.campaigns = [
        CampaignLogModel.fromJson(
            {'seq': 1, 'date': '2026-10-18', 'accountCode': 'SH-01'}),
        CampaignLogModel.fromJson(
            {'seq': 2, 'date': '2026-10-18', 'accountCode': 'SH-05'}),
        CampaignLogModel.fromJson(
            {'seq': 3, 'date': '2026-10-25', 'accountCode': 'SH-05'}),
        if (ambiguous)
          CampaignLogModel.fromJson(
              {'seq': 4, 'date': '2026-10-18', 'accountCode': 'SH-05'}),
      ];
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () =>
                          showAmazonEarningsImportDialog(context, c, [
                            const ParsedAmazonEarningsRow(
                                clicks: 0,
                                orderedItems: 0,
                                orderedRevenue: 0,
                                shippedItems: 0,
                                returnedItems: 0,
                                totalRevenue: 0,
                                commission: 0,
                                bonus: 0,
                                date: '2026-10-18',
                                label: 'b0fmxh8stx02-20'),
                          ]),
                      child: const Text('open'))))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final target = tester
          .widgetList<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>))
          .firstWhere(
              (w) => w.decoration.labelText!.startsWith('المكان المناسب'));
      expect(target.initialValue, ambiguous ? 'camp:4' : 'camp:2');
      expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isTrue);
      expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, isTrue);
      final save = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'لصق وحفظ (1)'));
      expect(save.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      c.dispose();
    });
  }
}
