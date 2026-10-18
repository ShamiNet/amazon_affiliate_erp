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
      ['23/09/2026', 'SH-04 3% قناع وجه', 'شامي', '1', '\$1.804', '2,674', '', '\$0.675', '٣٠'],
    ]);
    expect(rows.single.date, '2026-09-23');
    expect(rows.single.cost, 1.804);
    expect(rows.single.clicks, 0);
    expect(rows.single.accountCode, 'SH-04');
  });

  test('throws when required columns are missing', () {
    expect(() => parseAdCampaignRows(['a'], [['b']]), throwsFormatException);
  });

  test('matches catalog by code and product tokens', () {
    final catalog = [
      (product: 'قناع وجه 1%', accountCode: 'SH-04'),
      (product: 'قناع وجه 3%', accountCode: 'SH-04'),
      (product: 'قناع وجه 3 %', accountCode: 'SH-01'),
    ];
    ParsedCampaignRow row(String name) =>
        ParsedCampaignRow(date: '2026-09-23', campaignName: name, cost: 0, clicks: 0);
    expect(matchCatalogIndex(row('SH-04 3% قناع وجه'), catalog), 1);
    expect(matchCatalogIndex(row('SH-04 1% قناع وجه'), catalog), 0);
    expect(matchCatalogIndex(row('SH-01 3% قناع وجه'), catalog), 2);
    expect(matchCatalogIndex(row('XX-09 شيء'), catalog), isNull);
  });
}
