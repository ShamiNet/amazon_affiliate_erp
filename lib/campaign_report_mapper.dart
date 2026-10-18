class ParsedCampaignRow {
  const ParsedCampaignRow({
    required this.date,
    required this.campaignName,
    required this.cost,
    required this.clicks,
  });

  final String date;
  final String campaignName;
  final double cost;
  final int clicks;

  /// First token of the campaign name, e.g. "SH-04" from "SH-04 3% قناع وجه".
  String get accountCode {
    final match = RegExp(r'^\s*([A-Za-z]{1,4}-\d{1,3})').firstMatch(campaignName);
    return match?.group(1)?.toUpperCase() ?? '';
  }
}

String _normalizeDigits(String value) {
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  const extended = '۰۱۲۳۴۵۶۷۸۹';
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final a = arabicIndic.indexOf(char);
    final e = extended.indexOf(char);
    buffer.write(a >= 0 ? '$a' : (e >= 0 ? '$e' : char));
  }
  return buffer.toString();
}

double _parseMoney(String value) {
  final cleaned = _normalizeDigits(value).replaceAll(RegExp(r'[^0-9.\-]'), '');
  return double.tryParse(cleaned) ?? 0.0;
}

int _parseCount(String value) {
  final cleaned = _normalizeDigits(value).replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(cleaned) ?? 0;
}

/// Converts dd/MM/yyyy or yyyy-MM-dd into yyyy-MM-dd; returns null if unknown.
String? normalizeReportDate(String value) {
  final text = _normalizeDigits(value).trim();
  final dmy = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$').firstMatch(text);
  if (dmy != null) {
    return '${dmy.group(3)}-${dmy.group(2)!.padLeft(2, '0')}-'
        '${dmy.group(1)!.padLeft(2, '0')}';
  }
  final ymd = RegExp(r'^(\d{4})[/.\-](\d{1,2})[/.\-](\d{1,2})$').firstMatch(text);
  if (ymd != null) {
    return '${ymd.group(1)}-${ymd.group(2)!.padLeft(2, '0')}-'
        '${ymd.group(3)!.padLeft(2, '0')}';
  }
  return null;
}

int _findColumn(List<String> columns, List<String> keywords) {
  for (var i = 0; i < columns.length; i++) {
    final name = columns[i].toLowerCase();
    if (keywords.any(name.contains)) return i;
  }
  return -1;
}

List<ParsedCampaignRow> parseAdCampaignRows(
  List<String> columns,
  List<List<String>> rows, {
  String? fallbackDate,
}) {
  final nameIndex = _findColumn(columns, ['اسم الحملة', 'campaign name', 'campaign']);
  final costIndex = _findColumn(columns, ['التكلفة', 'cost', 'spend']);
  final clicksIndex = _findColumn(columns, ['النقرات', 'click']);
  final dateIndex = _findColumn(columns, ['تاريخ', 'date']);
  if (nameIndex < 0 || costIndex < 0) {
    throw const FormatException(
      'الجدول لا يحتوي عمودي "اسم الحملة" و"التكلفة" المطلوبين للإضافة.',
    );
  }

  String cell(List<String> row, int index) =>
      index >= 0 && index < row.length ? row[index] : '';

  final result = <ParsedCampaignRow>[];
  for (final row in rows) {
    final name = cell(row, nameIndex).trim();
    if (name.isEmpty) continue;
    final date = normalizeReportDate(cell(row, dateIndex)) ?? fallbackDate;
    if (date == null) continue;
    result.add(
      ParsedCampaignRow(
        date: date,
        campaignName: name,
        cost: _parseMoney(cell(row, costIndex)),
        clicks: _parseCount(cell(row, clicksIndex)),
      ),
    );
  }
  return result;
}

Set<String> _tokens(String value, String code) {
  var text = _normalizeDigits(value).toLowerCase();
  text = text.replaceAll(code.toLowerCase(), ' ');
  text = text.replaceAllMapped(RegExp(r'(\d)\s*%'), (m) => '${m.group(1)}%');
  return text
      .split(RegExp(r'[\s\-_–—,()]+'))
      .where((t) => t.isNotEmpty)
      .toSet();
}

/// Returns the index of the catalog entry that best matches the campaign
/// name, or null when no entry has the same account code or the match is
/// ambiguous.
int? matchCatalogIndex(
  ParsedCampaignRow row,
  List<({String product, String accountCode})> catalog,
) {
  final code = row.accountCode;
  if (code.isEmpty) return null;
  final candidates = <int>[
    for (var i = 0; i < catalog.length; i++)
      if (catalog[i].accountCode.trim().toUpperCase() == code) i,
  ];
  if (candidates.isEmpty) return null;
  if (candidates.length == 1) return candidates.first;

  final campaignTokens = _tokens(row.campaignName, code);
  int? best;
  var bestScore = 0;
  var tie = false;
  for (final index in candidates) {
    final score = _tokens(catalog[index].product, code)
        .intersection(campaignTokens)
        .length;
    if (score > bestScore) {
      best = index;
      bestScore = score;
      tie = false;
    } else if (score == bestScore && score > 0) {
      tie = true;
    }
  }
  return tie ? null : best;
}
