import 'package:amazon_affiliate_erp/campaign_table_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('numeric filters support operators and ranges', () {
    expect(matchesColumnFilter('>5', '6', 6), isTrue);
    expect(matchesColumnFilter('>5', '5', 5), isFalse);
    expect(matchesColumnFilter('<=2', '2', 2), isTrue);
    expect(matchesColumnFilter('=0', '0', 0), isTrue);
    expect(matchesColumnFilter('1..10', '4', 4), isTrue);
    expect(matchesColumnFilter('1..10', '11', 11), isFalse);
  });

  test('text filters are case-insensitive contains', () {
    expect(matchesColumnFilter('sh-0', 'SH-04', null), isTrue);
    expect(matchesColumnFilter('mk', 'SH-04', null), isFalse);
    expect(matchesColumnFilter('', 'x', null), isTrue);
  });

  test('prefs round-trip through json', () {
    final prefs = CampaignTablePrefs(
      sortColumn: 7,
      ascending: false,
      beneficiary: 'شامي',
      search: 'قناع',
      dailySummary: true,
      columnFilters: {3: 'SH', 7: '>1'},
    );
    final copy = CampaignTablePrefs.fromJson(prefs.toJson());
    expect(copy.sortColumn, 7);
    expect(copy.ascending, isFalse);
    expect(copy.beneficiary, 'شامي');
    expect(copy.search, 'قناع');
    expect(copy.dailySummary, isTrue);
    expect(copy.columnFilters, {3: 'SH', 7: '>1'});
  });
}
