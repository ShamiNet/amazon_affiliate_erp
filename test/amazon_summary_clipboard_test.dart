import 'package:amazon_affiliate_erp/campaign_report_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amazon_affiliate_erp/report_image_import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const summaryClipboard = '''
### Hello, Calixte Athanase
StoreID: b0fmxh8stx02-20
[Reports](https://affiliate-program.amazon.com/p/reporting/earnings)
Oct 18 2026 - Oct 18 2026 /
Custom Date Range
Last Updated:Oct 26 2026 03:52 PDT
CommissionsBountiesCreator Connections18 Oct0\$5.00\$10.00\$15.00
**Commissions Summary**
Clicks
17
Ordered
39
Shipped
3
Bonus
\$0.00
Conversion
229.41%
**Earning&#x73;*&#xA0;(Includes Bonus)***
**\$11.39**
**Creator Connections Summary**
**Earnings**
\$0.00
**Bounties Summary**
Total Number of Referrals
0
**Earnings**
\$0.00
**Total Earnings Summar&#121;*&#160;(Includes Bonus)***
**\$11.39**
''';

void main() {
  testWidgets('pastes and transfers the new summary with its store and date',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? {'text': summaryClipboard}
            : null);
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    List<ParsedAmazonEarningsRow>? transferred;
    await tester.pumpWidget(MaterialApp(home: ReportImageImportScreen(
      onImportAmazonEarnings: (rows) async {
        transferred = rows;
      },
    )));
    await tester.tap(find.text('لصق جدول من الحافظة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('لصق في المكان المناسب ضمن الأرباح'));
    await tester.pumpAndSettle();
    expect(transferred!.single.label, 'b0fmxh8stx02-20');
    expect(transferred!.single.date, '2026-10-18');
    expect(transferred!.single.commission, 11.39);
    expect(transferred!.single.orderedItems, 39);
    expect(tester.takeException(), isNull);
  });
  test('reads Markdown summary without mixing creator or bounty earnings', () {
    final row = parseAmazonAssociatesClipboardReport(summaryClipboard)!;
    expect(row.date, '2026-10-18');
    expect(row.label, 'b0fmxh8stx02-20');
    expect(row.clicks, 17);
    expect(row.orderedItems, 39);
    expect(row.shippedItems, 3);
    expect(row.totalEarnings, 11.39);
    expect(row.bonus, 0);
    expect(row.conversionRate * 100, closeTo(229.41, .01));
    expect(row.totalRevenue, 0);
  });
  test('summary bonus is counted once', () {
    final row = parseAmazonAssociatesClipboardReport(
        summaryClipboard.replaceFirst('Bonus\n\$0.00', 'Bonus\n\$2.00'))!;
    expect(row.commission, closeTo(9.39, .001));
    expect(row.bonus, 2);
    expect(row.totalEarnings, 11.39);
  });
  test('plain summary and all-zero reports remain supported', () {
    final row = parseAmazonAssociatesClipboardReport('''
StoreID: zero_store-20
Oct 25 2026 /Yesterday
Commissions Summary
Clicks
0
Ordered
0
Shipped
0
Bonus
\$0.00
Earnings (Includes Bonus)
\$0.00
Creator Connections Summary
Earnings
\$99.00
''')!;
    expect(row.label, 'zero_store-20');
    expect(row.clicks, 0);
    expect(row.totalEarnings, 0);
  });
}
