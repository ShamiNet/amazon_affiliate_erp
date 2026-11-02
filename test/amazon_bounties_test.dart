import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:amazon_affiliate_erp/report_image_import_screen.dart';
import 'package:amazon_affiliate_erp/main.dart';
import 'package:amazon_affiliate_erp/campaign_report_mapper.dart';

const fabrice = fullFabriceClipboard;
const fullFabriceClipboard = '''
### Hello, Fabrice Florian
b0ct5fk2yf-20b0ct5fk2yf01-20
Reports Summary
Oct 27 2026 - Oct 27 2026 / Custom Date Range
Tracking ID: All
Country: US (b0ct5fk2yf-20)
Last Updated:Nov 02 2026 03:15 PST
CommissionsBountiesCreator Connections27 Oct0\$5.00\$10.00\$15.00Oct 27 2026● Commissions: \$2.95● Bounties: \$12.00● Creator Connections: \$0.00Total:
**Commissions Summary**
Clicks
1,118
Ordered
8
Shipped
4
Bonus
\$0.00
Conversion
0.72%
**Earning&#x73;*&#xA0;(Includes Bonus)***
**\$2.95**
**Creator Connections Summary**
Earnings
\$0.00
**Bounties Summary**
Total Number of Referrals
1
Earnings
\$12.00
**Total Earnings Summar&#x79;*&#xA0;(Includes Bonus)***
**\$14.95**
''';
void main() {
  testWidgets(
      'full copied page transfers exact commission and bounty through report UI',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? {'text': fullFabriceClipboard}
            : null);
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    List<ParsedAmazonEarningsRow>? transferred;
    await tester.pumpWidget(MaterialApp(
        home: ReportImageImportScreen(onImportAmazonEarnings: (rows) async {
      transferred = rows;
    })));
    await tester.tap(find.text('لصق جدول من الحافظة'));
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .map((f) => f.initialValue)
        .toList();
    expect(fields[fields.length - 2], '2.95');
    expect(fields.last, '12.00');
    await tester.tap(find.text('لصق في المكان المناسب ضمن الأرباح'));
    await tester.pumpAndSettle();
    expect(transferred!.single.commission, 2.95);
    expect(transferred!.single.bonus, 12);
    expect(transferred!.single.totalEarnings, 14.95);
    expect(transferred!.single.profileName, 'Fabrice Florian');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Fabrice resolves by greeting profile when store is absent in catalog',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = AppDataController(initialize: false);
    c.campaigns = [
      CampaignLogModel.fromJson({
        'seq': 1,
        'date': '2026-10-27',
        'profile': 'Other',
        'accountCode': 'SH-01'
      }),
      CampaignLogModel.fromJson({
        'seq': 2,
        'date': '2026-10-27',
        'profile': 'Fabrice Florian',
        'accountCode': 'SH-08'
      })
    ];
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showAmazonEarningsImportDialog(context, c,
                        [parseAmazonAssociatesClipboardReport(fabrice)!]),
                    child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final field = tester
        .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .firstWhere(
            (w) => w.decoration.labelText!.startsWith('المكان المناسب'));
    expect(field.initialValue, 'camp:2');
    expect(find.textContaining('14.95'), findsWidgets);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    c.dispose();
  });
  test('Fabrice full earnings and active store survive concatenated header',
      () {
    final r = parseAmazonAssociatesClipboardReport(fabrice)!;
    expect(r.commission, 2.95);
    expect(r.bonus, 12);
    expect(r.totalEarnings, 14.95);
    expect(r.label, 'b0ct5fk2yf-20');
    expect(r.accountCode, isEmpty);
    expect(r.profileName, 'Fabrice Florian');
    expect(r.date, '2026-10-27');
    expect(r.clicks, 1118);
  });
  test('European decimal money retains exact aggregate', () {
    final r = parseAmazonAssociatesClipboardReport(fabrice
        .replaceAll('2.95', '2,95')
        .replaceAll('12.00', '12,00')
        .replaceAll('14.95', '14,95'))!;
    expect(r.totalEarnings, 14.95);
    expect(r.commission, 2.95);
    expect(r.bonus, 12);
  });
  test('commission bonus is counted once together with bounties and creators',
      () {
    final text = fabrice
        .replaceFirst('Bonus\n\$0.00', 'Bonus\n\$1.00')
        .replaceFirst('Earnings\n\$0.00', 'Earnings\n\$3.00')
        .replaceAll('14.95', '17.95');
    final r = parseAmazonAssociatesClipboardReport(text)!;
    expect(r.commission, closeTo(1.95, .000001));
    expect(r.bonus, 16);
    expect(r.totalEarnings, 17.95);
  });
  test('flat commissions page uses aggregate summary card', () {
    final r = parseAmazonAssociatesClipboardReport('''Hello, Fabrice Florian
StoreID: b0ct5fk2yf-20
Oct 27 2026 /Yesterday
Summary
\$1495
Commissions
\$295
Bounties
\$1200
Creator Connections
\$000
Clicks
1,118
Ordered Items
8
Bonus
\$0.00
Total Earnings
(Includes Bonus)
\$2.95
''')!;
    expect(r.totalEarnings, 14.95);
    expect(r.commission, 2.95);
    expect(r.bonus, 12);
  });
  test(
      'full commissions clipboard ignores product row number after Total Earnings',
      () {
    final r = parseAmazonAssociatesClipboardReport('''Hello, Fabrice Florian
StoreID: b0ct5fk2yf-20
Oct 27 2026 /Yesterday
Summary
\$1495
Commissions
\$295
Bounties
\$1200
Creator Connections
\$000
Earnings
Clicks
Ordered Items
27 Oct
0
\$1.00
\$2.00
\$3.00
\$4.00
0
500
1K
2K
2K
0
5
10
15
20
Oct 27 2026● Earnings: \$2.95● Clicks: 1,118● Ordered Items: 8
Clicks
1,118
Ordered Items
8
Conversion
0.72%
Ordered Revenue
\$150.87
Shipped Items
4
Returned Items
0
Total Revenue
\$73.61
Bonus
\$0.00
Total Earnings
(Includes Bonus)
\$2.95
Native Shopping AdsNew: Group By:
Linked Product
Product Title\tClicks\tOrdered Revenue\tTotal Earnings
1Graco Extend2Fit 2-in-1 Convertible Car Seat
1,118
8
\$150.87
(Showing 1 - 1 Items)
25
results per page
Notes
Kindle E-Books EarningsYou have referred 0 Kindle Free E-books
''')!;
    expect(r.commission, 2.95);
    expect(r.bonus, 12);
    expect(r.totalEarnings, 14.95);
    expect(r.clicks, 1118);
    expect(r.orderedItems, 8);
    expect(r.orderedRevenue, 150.87);
    expect(r.shippedItems, 4);
    expect(r.returnedItems, 0);
    expect(r.totalRevenue, 73.61);
  });
}
