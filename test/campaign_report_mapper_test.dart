import 'package:amazon_affiliate_erp/campaign_report_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const columns = [
    'تاريخ البدء',
    'اسم الحملة',
    'المجلد',
    'معرف الحملة (ID)',
    'التكلفة',
    'الظهور',
    'النقرات',
    'CPM',
    'الميزانية الإجمالية',
  ];

  test('parses ad campaign rows', () {
    final rows = parseAdCampaignRows(columns, [
      [
        '23/09/2026',
        'SH-04 3% قناع وجه',
        'شامي',
        '1',
        '\$1.804',
        '2,674',
        '',
        '\$0.675',
        '٣٠'
      ],
    ]);
    expect(rows.single.date, '2026-09-23');
    expect(rows.single.cost, 1.804);
    expect(rows.single.clicks, 0);
    expect(rows.single.accountCode, 'SH-04');
  });

  test('throws when required columns are missing', () {
    expect(
        () => parseAdCampaignRows([
              'a'
            ], [
              ['b']
            ]),
        throwsFormatException);
  });

  test('reads copied commissions with implicit cents', () {
    for (final entry in {
      r'$3323': 33.23,
      r'$33.23': 33.23,
      r'$000': 0.0,
      r'$5': 0.05,
      r'$1,234.56': 1234.56,
    }.entries) {
      final row = parseAmazonAssociatesClipboardReport(
        'Commissions\n${entry.key}\nClicks\n22\nOrdered Items\n44\n'
        'Ordered Revenue\n858.08\nTotal Revenue\n1003.62\n',
      );
      expect(row!.commission, entry.value, reason: entry.key);
      expect(row.clicks, 22);
      expect(row.orderedItems, 44);
      expect(row.orderedRevenue, 858.08);
    }
  });

  test('extracts Amazon summary metrics from copied page text', () {
    const copiedReport = '''
Hello, Lara Floriane
StoreID: b09mqwwp8705-20
Oct 23 2026 /Yesterday
Summary
Commissions
\$000
Bounties
\$000
Clicks
3
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
Total Earnings(Includes Bonus)
\$0.00
''';

    final row = parseAmazonAssociatesClipboardReport(copiedReport);

    expect(row, isNotNull);
    expect(row!.date, '2026-10-23');
    expect(row.label, 'b09mqwwp8705-20');
    expect(row.clicks, 3);
    expect(row.orderedItems, 0);
    expect(row.orderedRevenue, 0);
    expect(row.shippedItems, 0);
    expect(row.returnedItems, 0);
    expect(row.totalRevenue, 0);
    expect(row.commission, 0);
    expect(row.bonus, 0);
  });

  test('uses campaign name instead of campaign ID as the imported name', () {
    final rows = parseAdCampaignRows(
      ['Campaign ID', 'Campaign Name', 'Cost', 'Date'],
      [
        ['12345', 'SH-04 Face Mask', '\$1.25', '2026-09-23'],
      ],
    );

    expect(rows.single.campaignName, 'SH-04 Face Mask');
  });

  test('matches catalog by code and product tokens', () {
    final catalog = [
      (product: 'قناع وجه 1%', accountCode: 'SH-04'),
      (product: 'قناع وجه 3%', accountCode: 'SH-04'),
      (product: 'قناع وجه 3 %', accountCode: 'SH-01'),
    ];
    ParsedCampaignRow row(String name) => ParsedCampaignRow(
        date: '2026-09-23', campaignName: name, cost: 0, clicks: 0);
    expect(matchCatalogIndex(row('SH-04 3% قناع وجه'), catalog), 1);
    expect(matchCatalogIndex(row('SH-04 1% قناع وجه'), catalog), 0);
    expect(matchCatalogIndex(row('SH-01 3% قناع وجه'), catalog), 2);
    expect(matchCatalogIndex(row('XX-09 شيء'), catalog), isNull);
  });
}
