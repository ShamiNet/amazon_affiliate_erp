import 'package:amazon_affiliate_erp/main.dart';
import 'package:amazon_affiliate_erp/campaign_report_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in ['multiple', 'pending', 'profile', 'new', 'unknown']) {
    testWidgets('Lara store matching: $mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = AppDataController(initialize: false);
      c.amazonAccounts = [
        AmazonAccountModel.fromJson({
          'code': 'MK-01',
          'storeId': 'b09mqwwp8705-20',
          'name': 'Lara Floriane',
        })
      ];
      c.campaigns = [
        CampaignLogModel.fromJson({
          'seq': 120,
          'date': '2026-10-21',
          'accountCode': 'SH-05',
          'profile': 'Calixte Athanase'
        }),
        if (mode != 'new' && mode != 'unknown') ...[
          CampaignLogModel.fromJson({
            'seq': 121,
            'date': '2026-10-21',
            'accountCode': mode == 'profile' ? '' : 'MK-01',
            'profile': 'Lara Floriane',
            'isPending': mode == 'pending'
          }),
          CampaignLogModel.fromJson({
            'seq': 122,
            'date': '2026-10-21',
            'accountCode': mode == 'profile' ? '' : 'MK-01',
            'profile': 'Lara Floriane'
          }),
        ],
        CampaignLogModel.fromJson({
          'seq': 130,
          'date': '2026-10-22',
          'accountCode': 'MK-01',
          'profile': 'Lara Floriane'
        }),
      ];
      if (mode == 'new')
        c.productsCatalog = [
          ProductCatalogModel.fromJson({'id': 1, 'accountCode': 'SH-05'}),
          ProductCatalogModel.fromJson(
              {'id': 2, 'accountCode': 'MK-01', 'profile': 'Lara Floriane'}),
        ];
      final row = parseAmazonAssociatesClipboardReport('''
Hello, Lara Floriane
StoreID: b09mqwwp8705-20
Oct 21 2026 - Oct 21 2026 /Custom Date Range
Last Updated:Oct 26 2026 03:52 PDT
Summary
\$000
Commissions
\$000
Bounties
\$000
Clicks
10
Ordered Items
0
Conversion
0.00%
Ordered Revenue
\$0.00
Shipped Items
0
Returned Items
0
Total Revenue
\$0.00
Bonus
\$0.00
Total Earnings
(Includes Bonus)
\$0.00
''')!;
      expect(row.label, 'b09mqwwp8705-20');
      expect(row.date, '2026-10-21');
      expect(row.clicks, 10);
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () =>
                          showAmazonEarningsImportDialog(context, c, [row]),
                      child: const Text('open'))))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final target = tester
          .widgetList<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>))
          .firstWhere(
              (w) => w.decoration.labelText!.startsWith('المكان المناسب'));
      expect(
          target.initialValue,
          mode == 'unknown'
              ? null
              : mode == 'new'
                  ? 'new:2'
                  : mode == 'pending'
                      ? 'camp:121'
                      : 'camp:122');
      final save = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'لصق وحفظ (1)'));
      expect(save.onPressed == null, mode == 'unknown');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      c.dispose();
    });
  }
}
