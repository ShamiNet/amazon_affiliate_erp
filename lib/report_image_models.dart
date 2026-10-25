enum ReportImageType {
  amazonEarnings('amazon_earnings', 'أرباح Amazon'),
  adCampaigns('ad_campaigns', 'تقرير الحملات الإعلانية');

  const ReportImageType(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

enum ReportExtractionMode {
  gemini('Gemini السحابي'),
  local('OCR المحلي');

  const ReportExtractionMode(this.label);

  final String label;
}

class ExtractedReport {
  const ExtractedReport({
    required this.title,
    required this.columns,
    required this.rows,
    required this.warnings,
  });

  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  final List<String> warnings;

  factory ExtractedReport.fromJson(Map<String, dynamic> json) {
    final columnsValue = json['columns'];
    final rowsValue = json['rows'];
    if (columnsValue is! List || rowsValue is! List) {
      throw const FormatException('استجابة OCR لا تحتوي أعمدة وصفوفاً.');
    }

    final columns = columnsValue.map((value) => value.toString()).toList();
    if (columns.isEmpty) {
      throw const FormatException('لم يتم استخراج أعمدة من الصورة.');
    }
    final rows = <List<String>>[];
    final warnings = <String>[
      if (json['warnings'] is List)
        ...(json['warnings'] as List).map((value) => value.toString()),
    ];
    var expectedWidth = columns.length;
    for (final rowValue in rowsValue) {
      if (rowValue is! List) {
        throw const FormatException('صيغة أحد صفوف التقرير غير صحيحة.');
      }
      final row = rowValue.map((value) => value?.toString() ?? '').toList();
      if (row.length > expectedWidth) expectedWidth = row.length;
      rows.add(row);
    }
    while (columns.length < expectedWidth) {
      columns.add('عمود إضافي ${columns.length - columnsValue.length + 1}');
    }
    if (columns.length > columnsValue.length) {
      warnings.add(
        'اكتُشفت خلايا إضافية في بعض الصفوف، فأُضيفت أعمدة مؤقتة للحفاظ على القيم.',
      );
    }
    for (var index = 0; index < rows.length; index++) {
      if (rows[index].length < expectedWidth) {
        rows[index] = [
          ...rows[index],
          ...List.filled(expectedWidth - rows[index].length, ''),
        ];
        warnings.add(
          'تمت إضافة خلايا فارغة لاستكمال الصف ${index + 1} بما يطابق الأعمدة.',
        );
      }
    }
    if (rows.isEmpty) {
      throw const FormatException('لم يتم استخراج أي صف من الصورة.');
    }

    return ExtractedReport(
      title: (json['title'] ?? 'نتيجة استخراج التقرير').toString(),
      columns: columns,
      rows: rows,
      warnings: warnings,
    );
  }

  String toTsv(List<List<String>> editedRows) {
    String cleanCell(String value) =>
        value.replaceAll(RegExp(r'[\t\r\n]+'), ' ').trim();
    return [
      columns.map(cleanCell).join('\t'),
      ...editedRows.map((row) => row.map(cleanCell).join('\t')),
    ].join('\r\n');
  }

  String toRowsOnlyTsv(List<List<String>> editedRows) {
    String cleanCell(String value) =>
        value.replaceAll(RegExp(r'[\t\r\n]+'), ' ').trim();
    return editedRows.map((row) => row.map(cleanCell).join('\t')).join('\r\n');
  }

  String toCsv(List<List<String>> editedRows) {
    final rows = [
      columns.map(_quoteCsvCell).join(','),
      ...editedRows.map((row) => row.map(_quoteCsvCell).join(',')),
    ];
    return rows.join('\r\n');
  }

  static String _quoteCsvCell(String value) {
    final normalized = value.replaceAll('"', '""');
    if (normalized.contains(',') ||
        normalized.contains('"') ||
        normalized.contains('\n') ||
        normalized.contains('\r')) {
      return '"$normalized"';
    }
    return normalized;
  }

  factory ExtractedReport.fromDelimitedText(String text,
      {required String delimiter}) {
    final sanitized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = sanitized
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      throw const FormatException('الملف المستورد فارغ.');
    }

    final columns = _splitDelimitedLine(lines.first, delimiter: delimiter);
    final rows = <List<String>>[];
    for (var i = 1; i < lines.length; i++) {
      final row = _splitDelimitedLine(lines[i], delimiter: delimiter);
      if (row.length != columns.length) {
        throw const FormatException(
          'عدد أعمدة الملف المستورد لا يطابق الصفوف.',
        );
      }
      rows.add(row);
    }

    return ExtractedReport(
      title: 'استيراد ملف',
      columns: columns,
      rows: rows,
      warnings: const [],
    );
  }

  static List<String> _splitDelimitedLine(String line,
      {required String delimiter}) {
    if (delimiter.isEmpty) {
      return [line];
    }

    final cells = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (char == '"') {
        if (inQuotes && index + 1 < line.length && line[index + 1] == '"') {
          buffer.write('"');
          index++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        cells.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    cells.add(buffer.toString());
    return cells;
  }
}
