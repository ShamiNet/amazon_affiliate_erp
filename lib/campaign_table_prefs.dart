import 'dart:convert';
import 'dart:io';

/// Sort/filter state of the daily campaigns table, persisted between runs.
class CampaignTablePrefs {
  CampaignTablePrefs({
    this.sortColumn,
    this.ascending = true,
    this.beneficiary = 'الكل',
    this.search = '',
    this.dailySummary = false,
    Map<int, String>? columnFilters,
  }) : columnFilters = columnFilters ?? {};

  final Map<int, bool> sortLevels = {};
  final Set<int> hiddenColumns = {};
  final Set<int> hiddenSummaryColumns = {};
  int? sortColumn;
  bool ascending;
  String beneficiary;
  String search;
  bool dailySummary;
  final Map<int, String> columnFilters;

  Map<String, dynamic> toJson() => {
        'hiddenColumns': hiddenColumns.toList(),
        'hiddenSummaryColumns': hiddenSummaryColumns.toList(),
        'sortLevels': sortLevels.map((k, v) => MapEntry('$k', v)),
        'sortColumn': sortColumn,
        'ascending': ascending,
        'beneficiary': beneficiary,
        'search': search,
        'dailySummary': dailySummary,
        'columnFilters': columnFilters.map((k, v) => MapEntry('$k', v)),
      };

  factory CampaignTablePrefs.fromJson(Map<String, dynamic> j) {
    final filters = <int, String>{};
    final raw = j['columnFilters'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final index = int.tryParse('$k');
        if (index != null && '$v'.trim().isNotEmpty) filters[index] = '$v';
      });
    }
    final prefs = CampaignTablePrefs(
      sortColumn: j['sortColumn'] is int ? j['sortColumn'] as int : null,
      ascending: j['ascending'] is bool ? j['ascending'] as bool : true,
      beneficiary: (j['beneficiary'] ?? 'الكل').toString(),
      search: (j['search'] ?? '').toString(),
      dailySummary:
          j['dailySummary'] is bool ? j['dailySummary'] as bool : false,
      columnFilters: filters,
    );
    final levels = j['sortLevels'];
    if (levels is Map) {
      levels.forEach((k, v) {
        final col = int.tryParse('$k');
        if (col != null && col >= 0 && col < 19 && v is bool)
          prefs.sortLevels[col] = v;
      });
    } else if (prefs.sortColumn != null) {
      prefs.sortLevels[prefs.sortColumn!] = prefs.ascending;
    }
    void readHidden(String key, Set<int> target, int count) {
      final raw = j[key];
      if (raw is List) {
        target.addAll(raw.whereType<int>().where((i) => i >= 0 && i < count));
        if (target.length == count) target.remove(0);
      }
    }

    readHidden('hiddenColumns', prefs.hiddenColumns, 21);
    readHidden('hiddenSummaryColumns', prefs.hiddenSummaryColumns, 9);
    return prefs;
  }

  static File _file() {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '.';
    return File(
        '$home${Platform.pathSeparator}amazon_affiliate_erp_ui_prefs.json');
  }

  static CampaignTablePrefs load() {
    try {
      final file = _file();
      if (file.existsSync()) {
        final data = jsonDecode(file.readAsStringSync());
        if (data is Map<String, dynamic>)
          return CampaignTablePrefs.fromJson(data);
      }
    } catch (_) {}
    return CampaignTablePrefs();
  }

  void save() {
    try {
      _file().writeAsStringSync(jsonEncode(toJson()));
    } catch (_) {}
  }
}

/// Matches [cell] against a column filter. Numeric cells accept a leading
/// operator (>, <, >=, <=, =) or a range "a-b"; anything else is a
/// case-insensitive "contains" match on the displayed text.
bool matchesColumnFilter(String filter, String cell, num? numeric) {
  final f = filter.trim();
  if (f.isEmpty) return true;
  if (numeric != null) {
    final op = RegExp(r'^(>=|<=|>|<|=)\s*(-?\d+(?:\.\d+)?)$').firstMatch(f);
    if (op != null) {
      final v = double.parse(op.group(2)!);
      switch (op.group(1)) {
        case '>':
          return numeric > v;
        case '<':
          return numeric < v;
        case '>=':
          return numeric >= v;
        case '<=':
          return numeric <= v;
        default:
          return numeric == v;
      }
    }
    final range =
        RegExp(r'^(-?\d+(?:\.\d+)?)\s*(?:\.\.|to)\s*(-?\d+(?:\.\d+)?)$')
            .firstMatch(f);
    if (range != null) {
      return numeric >= double.parse(range.group(1)!) &&
          numeric <= double.parse(range.group(2)!);
    }
  }
  return cell.toLowerCase().contains(f.toLowerCase());
}
