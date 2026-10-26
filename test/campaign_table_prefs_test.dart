import 'package:amazon_affiliate_erp/campaign_table_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hidden columns round trip and invalid indices cannot hide entire table',
      () {
    final prefs = CampaignTablePrefs();
    prefs.hiddenColumns.addAll({0, 3, 20});
    prefs.hiddenSummaryColumns.addAll({1, 8});
    final copy = CampaignTablePrefs.fromJson(prefs.toJson());
    expect(copy.hiddenColumns, {0, 3, 20});
    expect(copy.hiddenSummaryColumns, {1, 8});
    final corrupt = CampaignTablePrefs.fromJson({
      'hiddenColumns': [-1, ...List.generate(21, (i) => i), 999, 'bad'],
      'hiddenSummaryColumns': List.generate(9, (i) => i),
    });
    expect(corrupt.hiddenColumns.length, 20);
    expect(corrupt.hiddenSummaryColumns.length, 8);
    expect(corrupt.hiddenColumns.contains(0), isFalse);
  });
  test('sort priorities and directions survive persistence', () {
    final prefs = CampaignTablePrefs();
    prefs.sortLevels.addAll({4: true, 1: false, 0: true});
    final copy = CampaignTablePrefs.fromJson(prefs.toJson());
    expect(copy.sortLevels.keys.toList(), [4, 1, 0]);
    expect(copy.sortLevels.values.toList(), [true, false, true]);
  });

  test('legacy single sort migrates to a sort level', () {
    final prefs =
        CampaignTablePrefs.fromJson({'sortColumn': 1, 'ascending': false});
    expect(prefs.sortLevels, {1: false});
  });

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
