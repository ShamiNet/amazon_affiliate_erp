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
    final match =
        RegExp(r'^\s*([A-Za-z]{1,4}-\d{1,3})').firstMatch(campaignName);
    return match?.group(1)?.toUpperCase() ?? '';
  }
}

class ParsedAmazonEarningsRow {
  const ParsedAmazonEarningsRow({
    required this.clicks,
    required this.orderedItems,
    required this.orderedRevenue,
    required this.shippedItems,
    required this.returnedItems,
    required this.totalRevenue,
    required this.commission,
    required this.bonus,
    this.date,
    this.label = '',
  });

  final int clicks;
  final int orderedItems;
  final double orderedRevenue;
  final int shippedItems;
  final int returnedItems;
  final double totalRevenue;
  final double commission;
  final double bonus;
  final String? date;
  final String label;

  double get conversionRate => clicks > 0 ? orderedItems / clicks : 0.0;
  double get totalEarnings => commission + bonus;

  /// يستخرج رمز الحساب إن وُجد في التسمية (مثل SH-04 أو MK-01).
  String get accountCode {
    final match = RegExp(r'([A-Za-z]{1,4}-\d{1,3})').firstMatch(label);
    return match?.group(1)?.toUpperCase() ?? '';
  }

  /// يجمع صفين من الأرباح (عند تجميع عدة صفوف منتجات لحساب واحد).
  ParsedAmazonEarningsRow operator +(ParsedAmazonEarningsRow other) {
    return ParsedAmazonEarningsRow(
      clicks: clicks + other.clicks,
      orderedItems: orderedItems + other.orderedItems,
      orderedRevenue: orderedRevenue + other.orderedRevenue,
      shippedItems: shippedItems + other.shippedItems,
      returnedItems: returnedItems + other.returnedItems,
      totalRevenue: totalRevenue + other.totalRevenue,
      commission: commission + other.commission,
      bonus: bonus + other.bonus,
      date: date ?? other.date,
      label: label.isNotEmpty ? label : other.label,
    );
  }

  /// يحوّل الصف إلى نص TSV مطابق تماماً لترتيب أعمدة ورقة "الارباح والجرد"
  /// بدءاً من خلية النقرات (عمود K) وحتى المكافآت الإضافية (عمود S) بدون عناوين،
  /// بحيث ينزل كل رقم في عموده الصحيح عند اللصق المباشر ولا يمسح معادلة الأرباح الإجمالية (عمود T).
  String toSheetTsvRow({bool includeTotalEarnings = false}) {
    final crPercent = '${(conversionRate * 100).toStringAsFixed(2)}%';
    final cells = <String>[
      '$clicks',
      '$orderedItems',
      crPercent,
      orderedRevenue.toStringAsFixed(2),
      '$shippedItems',
      '$returnedItems',
      totalRevenue.toStringAsFixed(2),
      commission.toStringAsFixed(2),
      bonus.toStringAsFixed(2),
      if (includeTotalEarnings) totalEarnings.toStringAsFixed(2),
    ];
    return cells.join('\t');
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
  final normalized = _normalizeDigits(value).trim();
  if (normalized.isEmpty) return 0;
  // إذا كان الرقم بصيغة عشرية مثل 1188.0 نأخذ الجزء الصحيح منه
  final asDouble = double.tryParse(
    normalized.replaceAll(RegExp(r'[^0-9.\-]'), ''),
  );
  if (asDouble != null) return asDouble.round();
  final cleaned = normalized.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(cleaned) ?? 0;
}

/// Converts dd/MM/yyyy or yyyy-MM-dd into yyyy-MM-dd; returns null if unknown.
String? normalizeReportDate(String value) {
  final text = _normalizeDigits(value).trim();
  final dmy =
      RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$').firstMatch(text);
  if (dmy != null) {
    return '${dmy.group(3)}-${dmy.group(2)!.padLeft(2, '0')}-'
        '${dmy.group(1)!.padLeft(2, '0')}';
  }
  final ymd =
      RegExp(r'^(\d{4})[/.\-](\d{1,2})[/.\-](\d{1,2})$').firstMatch(text);
  if (ymd != null) {
    return '${ymd.group(1)}-${ymd.group(2)!.padLeft(2, '0')}-'
        '${ymd.group(3)!.padLeft(2, '0')}';
  }
  return null;
}

double? _clipboardMetric(String text, List<String> labels) {
  final labelPattern = labels.map(RegExp.escape).join('|');
  final matches = RegExp(
    '(?:^|[^A-Za-z])(?:$labelPattern)'
    r'(?:\s*\([^)]*\))?\s*[:：]?\s*'
    r'([$€£]?\s*[-+]?\d[\d,]*(?:\.\d+)?%?)',
    caseSensitive: false,
  ).allMatches(text);
  if (matches.isEmpty) return null;
  return _parseMoney(matches.last.group(1)!);
}

String? _amazonClipboardDate(String text) {
  final match = RegExp(
    r'\b(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|'
    r'Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|'
    r'Dec(?:ember)?)\s+(\d{1,2}),?\s+(\d{4})\b',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;
  const months = {
    'jan': '01',
    'feb': '02',
    'mar': '03',
    'apr': '04',
    'may': '05',
    'jun': '06',
    'jul': '07',
    'aug': '08',
    'sep': '09',
    'oct': '10',
    'nov': '11',
    'dec': '12',
  };
  final month = months[match.group(1)!.substring(0, 3).toLowerCase()];
  if (month == null) return null;
  return '${match.group(3)}-$month-${match.group(2)!.padLeft(2, '0')}';
}

/// Parses Amazon Associates' copied summary text without OCR or a model.
/// Returns null when the copied text does not contain enough labeled metrics.
ParsedAmazonEarningsRow? parseAmazonAssociatesClipboardReport(String text) {
  final clicks = _clipboardMetric(text, ['Clicks', 'النقرات']);
  final orderedItems = _clipboardMetric(
    text,
    ['Ordered Items', 'Items Ordered', 'الطلبات المسجلة', 'الطلبات'],
  );
  final orderedRevenue = _clipboardMetric(
    text,
    ['Ordered Revenue', 'Ordered Sales', 'قيمة الطلبات'],
  );
  final shippedItems = _clipboardMetric(
    text,
    ['Shipped Items', 'Items Shipped', 'المنتجات المشحونة'],
  );
  final returnedItems = _clipboardMetric(
    text,
    ['Returned Items', 'Items Returned', 'المنتجات المرتجعة'],
  );
  final totalRevenue = _clipboardMetric(
    text,
    ['Total Revenue', 'Items Shipped Revenue', 'إجمالي قيمة المبيعات'],
  );
  final commission = _clipboardMetric(
    text,
    ['Commissions', 'Commission', 'Items Shipped Earnings', 'العمولات'],
  );
  final bonus = _clipboardMetric(text, ['Bounties', 'Bonus', 'المكافآت']);
  final totalEarnings = _clipboardMetric(
    text,
    ['Total Earnings', 'الأرباح الإجمالية'],
  );
  final requiredMetricCount = [
    clicks,
    orderedItems,
    orderedRevenue,
    totalRevenue,
  ].whereType<double>().length;
  if (requiredMetricCount < 2) return null;

  var commissionValue = commission ?? 0;
  final bonusValue = bonus ?? 0;
  if (commissionValue == 0 && bonusValue == 0 && (totalEarnings ?? 0) > 0) {
    commissionValue = totalEarnings!;
  }
  final trackingId = RegExp(
    r'(?:StoreID|Tracking ID)\s*:\s*([A-Za-z0-9_-]+)',
    caseSensitive: false,
  ).firstMatch(text)?.group(1);

  return ParsedAmazonEarningsRow(
    clicks: (clicks ?? 0).round(),
    orderedItems: (orderedItems ?? 0).round(),
    orderedRevenue: orderedRevenue ?? 0,
    shippedItems: (shippedItems ?? 0).round(),
    returnedItems: (returnedItems ?? 0).round(),
    totalRevenue: totalRevenue ?? 0,
    commission: commissionValue,
    bonus: bonusValue,
    date: _amazonClipboardDate(text),
    label: trackingId ?? '',
  );
}

int _findColumn(List<String> columns, List<String> keywords) {
  for (var i = 0; i < columns.length; i++) {
    final name = columns[i].toLowerCase();
    if (keywords.any(name.contains)) return i;
  }
  return -1;
}

int _findColumnFiltered(
  List<String> columns,
  List<String> includeKeywords, {
  List<String> excludeKeywords = const [],
}) {
  for (var i = 0; i < columns.length; i++) {
    final name = columns[i].toLowerCase().trim();
    if (excludeKeywords.any(name.contains)) continue;
    if (includeKeywords.any(name.contains)) return i;
  }
  return -1;
}

List<ParsedCampaignRow> parseAdCampaignRows(
  List<String> columns,
  List<List<String>> rows, {
  String? fallbackDate,
}) {
  final nameIndex = _findColumnFiltered(
    columns,
    ['اسم الحملة', 'campaign name', 'campaign'],
    excludeKeywords: ['معرف', 'رمز', ' id', 'code'],
  );
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

/// يحلل جدول أرباح أمازون المستخرج من الصورة أو الملصوق من الحافظة
/// ويدعم الترتيب الأفقي المعتاد، والترتيب العمودي (مؤشر/قيمة)، والترتيب الموضعي.
List<ParsedAmazonEarningsRow> parseAmazonEarningsRows(
  List<String> columns,
  List<List<String>> rows,
) {
  if (rows.isEmpty) return const [];

  final clicksIdx = _findColumnFiltered(
    columns,
    ['النقرات', 'نقرات', 'clicks', 'click'],
  );
  final orderedItemsIdx = _findColumnFiltered(
    columns,
    [
      'الطلبات المسجلة',
      'الطلبات',
      'طلبات',
      'ordered items',
      'items ordered',
      'ordered',
    ],
    excludeKeywords: [
      'قيمة',
      'إيراد',
      'عائد',
      'مبيعات',
      'revenue',
      'sales',
      'amount',
    ],
  );
  final orderedRevIdx = _findColumnFiltered(
    columns,
    [
      'قيمة الطلبات المقدرة',
      'قيمة الطلبات',
      'إيرادات الطلبات',
      'عائد الطلبات',
      'ordered revenue',
      'ordered sales',
    ],
  );
  final shippedItemsIdx = _findColumnFiltered(
    columns,
    [
      'المنتجات المشحونة',
      'المشحونة',
      'المشحون',
      'مشحونة',
      'مشحون',
      'shipped items',
      'items shipped',
      'shipped',
    ],
    excludeKeywords: [
      'قيمة',
      'إيراد',
      'عائد',
      'مبيعات',
      'revenue',
      'sales',
      'amount',
    ],
  );
  final returnedItemsIdx = _findColumnFiltered(
    columns,
    [
      'المنتجات المرتجعة',
      'المرتجعة',
      'المرتجع',
      'مرتجعة',
      'مرتجع',
      'returned items',
      'items returned',
      'returned',
      'returns',
    ],
    excludeKeywords: ['قيمة', 'إيراد', 'revenue'],
  );
  final totalRevIdx = _findColumnFiltered(
    columns,
    [
      'إجمالي قيمة المبيعات',
      'قيمة المبيعات',
      'إجمالي المبيعات',
      'المبيعات',
      'إيرادات الشحن',
      'عائدات الشحن',
      'total revenue',
      'shipped revenue',
      'sales',
      'revenue',
    ],
    excludeKeywords: ['الطلبات', 'ordered'],
  );
  final commissionIdx = _findColumnFiltered(
    columns,
    [
      'عمولات أمازون',
      'عمولة أمازون',
      'العمولات',
      'العمولة',
      'عمولات',
      'عمولة',
      'رسوم الإعلانات',
      'أرباح الإعلانات',
      'commission',
      'ad fees',
      'advertising fees',
      'standard fees',
      'referral fees',
    ],
  );
  final bonusIdx = _findColumnFiltered(
    columns,
    [
      'المكافآت الإضافية',
      'المكافآت',
      'المكافأة',
      'مكافآت',
      'مكافأة',
      'بونص',
      'حوافز',
      'bonus',
      'bounties',
      'bounty',
    ],
  );
  final totalEarningsIdx = _findColumnFiltered(
    columns,
    [
      'الأرباح الإجمالية',
      'إجمالي الأرباح',
      'الأرباح الكلية',
      'الأرباح',
      'total earnings',
      'earnings',
    ],
    excludeKeywords: [
      'يومية',
      'صافي',
      'عمول',
      'مكاف',
      'net',
      'daily',
      'commission',
      'bonus',
    ],
  );
  final dateIdx = _findColumnFiltered(
    columns,
    ['التاريخ', 'تاريخ', 'date', 'اليوم', 'day'],
  );
  final labelIdx = _findColumnFiltered(
    columns,
    [
      'رمز الحساب',
      'معرف المتجر',
      'معرف التتبع',
      'المنتج',
      'الصنف',
      'اسم الحملة',
      'البروفايل',
      'الحساب',
      'store',
      'tracking',
      'account',
      'product',
      'campaign',
      'item',
      'title',
    ],
  );

  final hasRecognizedColumns = [
    clicksIdx,
    orderedItemsIdx,
    orderedRevIdx,
    shippedItemsIdx,
    returnedItemsIdx,
    totalRevIdx,
    commissionIdx,
    bonusIdx,
    totalEarningsIdx,
  ].any((idx) => idx >= 0);

  if (hasRecognizedColumns) {
    String cell(List<String> row, int index) =>
        index >= 0 && index < row.length ? row[index].trim() : '';

    final parsed = <ParsedAmazonEarningsRow>[];
    for (final row in rows) {
      if (row.every((c) => c.trim().isEmpty)) continue;
      var comm = _parseMoney(cell(row, commissionIdx));
      final bon = _parseMoney(cell(row, bonusIdx));
      final totEarn = _parseMoney(cell(row, totalEarningsIdx));
      if (comm == 0.0 && bon == 0.0 && totEarn > 0.0) {
        comm = totEarn;
      }
      parsed.add(
        ParsedAmazonEarningsRow(
          clicks: _parseCount(cell(row, clicksIdx)),
          orderedItems: _parseCount(cell(row, orderedItemsIdx)),
          orderedRevenue: _parseMoney(cell(row, orderedRevIdx)),
          shippedItems: _parseCount(cell(row, shippedItemsIdx)),
          returnedItems: _parseCount(cell(row, returnedItemsIdx)),
          totalRevenue: _parseMoney(cell(row, totalRevIdx)),
          commission: comm,
          bonus: bon,
          date: normalizeReportDate(cell(row, dateIdx)),
          label: cell(row, labelIdx),
        ),
      );
    }
    return parsed;
  }

  // دعم الجداول العمودية ذات العمودين (المؤشر / القيمة)
  if (columns.length == 2) {
    final kvResult = _tryParseKeyValueEarnings(columns, rows);
    if (kvResult != null) return [kvResult];
  }

  // دعم المطابقة الموضعية إذا كانت الأعمدة بدون عناوين قياسية
  final positional = <ParsedAmazonEarningsRow>[];
  for (final row in rows) {
    final p = _tryParsePositionalEarningsRow(row);
    if (p != null) positional.add(p);
  }
  if (positional.isNotEmpty) return positional;

  throw const FormatException(
    'تعذر التعرف على أعمدة أرباح أمازون في الجدول (مثل النقرات، الطلبات، المشحون، المبيعات، العمولة).',
  );
}

ParsedAmazonEarningsRow? _tryParseKeyValueEarnings(
  List<String> columns,
  List<List<String>> rows,
) {
  var clicks = 0;
  var orderedItems = 0;
  var orderedRevenue = 0.0;
  var shippedItems = 0;
  var returnedItems = 0;
  var totalRevenue = 0.0;
  var commission = 0.0;
  var bonus = 0.0;
  var totalEarnings = 0.0;
  var matchedAny = false;

  final allPairs = <List<String>>[
    if (columns.length == 2) columns,
    ...rows,
  ];

  for (final pair in allPairs) {
    if (pair.length < 2) continue;
    final k = pair[0].toLowerCase().trim();
    final v = pair[1].trim();
    if (k.isEmpty || v.isEmpty) continue;

    if (k.contains('نقرات') || k.contains('click')) {
      clicks = _parseCount(v);
      matchedAny = true;
    } else if ((k.contains('قيمة الطلبات') || k.contains('ordered revenue'))) {
      orderedRevenue = _parseMoney(v);
      matchedAny = true;
    } else if ((k.contains('طلبات') || k.contains('ordered')) &&
        !k.contains('قيمة') &&
        !k.contains('revenue')) {
      orderedItems = _parseCount(v);
      matchedAny = true;
    } else if ((k.contains('مشحون') || k.contains('shipped')) &&
        !k.contains('قيمة') &&
        !k.contains('revenue')) {
      shippedItems = _parseCount(v);
      matchedAny = true;
    } else if (k.contains('مرتجع') || k.contains('return')) {
      returnedItems = _parseCount(v);
      matchedAny = true;
    } else if (k.contains('مبيعات') ||
        k.contains('shipped revenue') ||
        k.contains('total revenue') ||
        k.contains('إيرادات الشحن')) {
      totalRevenue = _parseMoney(v);
      matchedAny = true;
    } else if (k.contains('عمول') ||
        k.contains('commission') ||
        k.contains('fees')) {
      commission = _parseMoney(v);
      matchedAny = true;
    } else if (k.contains('مكاف') ||
        k.contains('بونص') ||
        k.contains('bonus') ||
        k.contains('bount')) {
      bonus = _parseMoney(v);
      matchedAny = true;
    } else if (k.contains('أرباح') || k.contains('earnings')) {
      totalEarnings = _parseMoney(v);
      matchedAny = true;
    }
  }

  if (!matchedAny) return null;
  if (commission == 0.0 && bonus == 0.0 && totalEarnings > 0.0) {
    commission = totalEarnings;
  }
  return ParsedAmazonEarningsRow(
    clicks: clicks,
    orderedItems: orderedItems,
    orderedRevenue: orderedRevenue,
    shippedItems: shippedItems,
    returnedItems: returnedItems,
    totalRevenue: totalRevenue,
    commission: commission,
    bonus: bonus,
  );
}

ParsedAmazonEarningsRow? _tryParsePositionalEarningsRow(List<String> cells) {
  final trimmed = cells.map((c) => c.trim()).toList();
  if (trimmed.length < 8) return null;

  // التحقق من أن معظم الخلايا رقمية
  var numericCount = 0;
  for (final c in trimmed) {
    final cleaned = _normalizeDigits(c).replaceAll(RegExp(r'[\$,%\s]'), '');
    if (cleaned.isNotEmpty && double.tryParse(cleaned) != null) {
      numericCount++;
    }
  }
  if (numericCount < 6) return null;

  // حالة 9 أو 10 أعمدة مطابقة لورقة "الارباح والجرد" من K إلى S (أو T):
  // [Clicks, OrderedItems, Conversion%, OrderedRev, ShippedItems, ReturnedItems, TotalRev, Commission, Bonus, (TotalEarnings)]
  if (trimmed.length == 9 || trimmed.length == 10) {
    var comm = _parseMoney(trimmed[7]);
    final bon = _parseMoney(trimmed[8]);
    if (trimmed.length == 10 && comm == 0.0 && bon == 0.0) {
      comm = _parseMoney(trimmed[9]);
    }
    return ParsedAmazonEarningsRow(
      clicks: _parseCount(trimmed[0]),
      orderedItems: _parseCount(trimmed[1]),
      orderedRevenue: _parseMoney(trimmed[3]),
      shippedItems: _parseCount(trimmed[4]),
      returnedItems: _parseCount(trimmed[5]),
      totalRevenue: _parseMoney(trimmed[6]),
      commission: comm,
      bonus: bon,
    );
  }

  // حالة 8 أعمدة (بدون عمود نسبة التحويل CR%):
  // [Clicks, OrderedItems, OrderedRev, ShippedItems, ReturnedItems, TotalRev, Commission, Bonus]
  if (trimmed.length == 8) {
    return ParsedAmazonEarningsRow(
      clicks: _parseCount(trimmed[0]),
      orderedItems: _parseCount(trimmed[1]),
      orderedRevenue: _parseMoney(trimmed[2]),
      shippedItems: _parseCount(trimmed[3]),
      returnedItems: _parseCount(trimmed[4]),
      totalRevenue: _parseMoney(trimmed[5]),
      commission: _parseMoney(trimmed[6]),
      bonus: _parseMoney(trimmed[7]),
    );
  }

  return null;
}

/// ينسّق صفوف أرباح أمازون كنص TSV جاهز للصق المباشر في شيت "الارباح والجرد"
/// بدءاً من خلية النقرات (عمود K) وحتى المكافآت (عمود S) بدون سطر العناوين.
String formatAmazonEarningsForSheetTsv(
  List<ParsedAmazonEarningsRow> rows, {
  bool includeTotalEarnings = false,
}) {
  return rows
      .map((r) => r.toSheetTsvRow(includeTotalEarnings: includeTotalEarnings))
      .join('\r\n');
}

/// يحلل النص المنسوخ في الحافظة (سواء نُسخ مع عناوين أو بدون عناوين بصيغة TSV أو CSV)
/// ويستخرج منه صفوف أرباح أمازون للصقها في المكان المناسب ضمن الأرباح.
List<ParsedAmazonEarningsRow> parseAmazonEarningsFromClipboardText(
  String rawText,
) {
  final sanitized = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = sanitized
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) {
    throw const FormatException('الحافظة فارغة لا تحتوي على بيانات أرباح.');
  }

  final delimiter = lines.first.contains('\t') ? '\t' : ',';
  final parsedLines =
      lines.map((line) => _splitClipboardLine(line, delimiter)).toList();

  // إذا كان السطر الأول سطر أرقام مباشرة (بدون عناوين، مثل مخرجات "نسخ صف الأرباح فقط")
  final firstAsPositional = _tryParsePositionalEarningsRow(parsedLines.first);
  if (firstAsPositional != null) {
    final results = <ParsedAmazonEarningsRow>[];
    for (final cells in parsedLines) {
      final row = _tryParsePositionalEarningsRow(cells);
      if (row != null) results.add(row);
    }
    if (results.isNotEmpty) return results;
  }

  // إذا كان يحتوي على سطر عناوين متبوع بصفوف بيانات
  if (parsedLines.length >= 2) {
    final columns = parsedLines.first;
    final rows = parsedLines.sublist(1);
    return parseAmazonEarningsRows(columns, rows);
  }

  throw const FormatException(
    'لم يتم العثور على صفوف أرباح صالحة في الحافظة. انسخ الأرباح أولاً ثم حاول اللصق.',
  );
}

List<String> _splitClipboardLine(String line, String delimiter) {
  final cells = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch == delimiter && !inQuotes) {
      cells.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(ch);
    }
  }
  cells.add(buffer.toString());
  return cells;
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
