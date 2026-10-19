import 'dart:convert';

import 'package:excel_community/excel_community.dart';

const _spreadsheetSchemaVersion = 1;
const _metadataSheetName = '_metadata';
const _sensitiveFields = {
  'password',
  'twoFa',
  'recovery',
  'iban',
  'bic',
  'bankAddress',
  'postalAndCountry',
  'verificationDoc',
};

const _identityFields = <String, List<String>>{
  'beneficiaries': ['id'],
  'products_catalog': ['id'],
  'campaigns': ['seq', 'date', 'accountCode', 'product'],
  'amazon_accounts': ['code'],
  'historical_links': [
    'beneficiary',
    'accountName',
    'product',
    'linkType',
    'url',
  ],
  'emails': ['email'],
  'gologin': ['email', 'platform'],
  'proxies': ['host', 'port', 'username'],
  'bank_accounts': ['amazonEmail', 'bankName', 'beneficiaryName'],
  'platforms': ['category', 'name'],
  'promo_times': ['windowName'],
  'workflow_steps': ['stepNumber'],
};

class SpreadsheetMergeResult {
  const SpreadsheetMergeResult({
    required this.data,
    required this.importedRows,
    required this.insertedRows,
    required this.updatedRows,
  });

  final Map<String, dynamic> data;
  final int importedRows;
  final int insertedRows;
  final int updatedRows;
}

class AppSpreadsheetBackup {
  static List<int> encode({
    required Map<String, dynamic> data,
    required Map<String, dynamic> schema,
  }) {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', _metadataSheetName);
    final metadata = workbook[_metadataSheetName];
    metadata.appendRow([
      TextCellValue('schema_version'),
      const IntCellValue(_spreadsheetSchemaVersion),
    ]);
    metadata.appendRow([
      TextCellValue('created_utc'),
      TextCellValue(DateTime.now().toUtc().toIso8601String()),
    ]);
    metadata.appendRow([
      TextCellValue('sensitive_fields_excluded'),
      TextCellValue(_sensitiveFields.join(', ')),
    ]);

    for (final tableName in schema.keys) {
      final templateRows = schema[tableName];
      if (templateRows is! List || templateRows.isEmpty) continue;
      final template = templateRows.first;
      if (template is! Map) continue;

      final headers = template.keys.map((key) => key.toString()).toList();
      if (headers.isEmpty) continue;
      final sheet = workbook[tableName];
      sheet.appendRow(headers.map(TextCellValue.new).toList());

      final values = data[tableName];
      if (values is! List) continue;
      for (final value in values) {
        if (value is! Map) continue;
        sheet.appendRow([
          for (final header in headers)
            _cellValue(header, value[header]),
        ]);
      }
    }

    final bytes = workbook.encode();
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('تعذر إنشاء ملف Excel.');
    }
    return bytes;
  }

  static SpreadsheetMergeResult merge({
    required List<int> bytes,
    required Map<String, dynamic> currentData,
    required Map<String, dynamic> schema,
  }) {
    final workbook = Excel.decodeBytes(bytes);
    _validateSchemaVersion(workbook);

    final imported = <String, List<Map<String, dynamic>>>{};
    var recognizedSheets = 0;
    for (final tableName in schema.keys) {
      final sheet = workbook.tables[tableName];
      if (sheet == null || sheet.rows.isEmpty) continue;
      recognizedSheets++;

      final templateRows = schema[tableName];
      if (templateRows is! List || templateRows.isEmpty) continue;
      final template = templateRows.first;
      if (template is! Map) continue;
      final fieldNames = template.keys.map((key) => key.toString()).toSet();

      final headers = sheet.rows.first
          .map((cell) => cell?.displayText.trim() ?? '')
          .toList();
      if (!headers.any(fieldNames.contains)) {
        throw FormatException(
          'ورقة "$tableName" لا تحتوي عناوين أعمدة معروفة.',
        );
      }

      final rows = <Map<String, dynamic>>[];
      for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
        final cells = sheet.rows[rowIndex];
        final row = <String, dynamic>{};
        for (var columnIndex = 0;
            columnIndex < headers.length && columnIndex < cells.length;
            columnIndex++) {
          final header = headers[columnIndex];
          if (!fieldNames.contains(header) ||
              _sensitiveFields.contains(header)) {
            continue;
          }
          row[header] = _typedValue(
            tableName: tableName,
            fieldName: header,
            value: _readCell(cells[columnIndex]),
            template: template,
            rowNumber: rowIndex + 1,
          );
        }
        if (row.values.every((value) => value == null || value == '')) {
          continue;
        }
        rows.add(row);
      }
      imported[tableName] = rows;
    }
    if (recognizedSheets == 0) {
      throw const FormatException(
        'لم يتم العثور على أوراق بيانات معروفة في ملف Excel.',
      );
    }

    final mergedData = Map<String, dynamic>.from(currentData);
    var insertedRows = 0;
    var updatedRows = 0;
    var importedRows = 0;

    for (final entry in imported.entries) {
      final tableName = entry.key;
      final sourceRows = entry.value;
      final existingValue = currentData[tableName];
      final mergedRows = <Map<String, dynamic>>[
        if (existingValue is List)
          for (final row in existingValue)
            if (row is Map) Map<String, dynamic>.from(row),
      ];

      for (final sourceRow in sourceRows) {
        importedRows++;
        final sourceKey = _identity(tableName, sourceRow);
        final existingIndex = mergedRows.indexWhere(
          (row) => _identity(tableName, row) == sourceKey,
        );
        if (existingIndex < 0) {
          mergedRows.add(sourceRow);
          insertedRows++;
        } else {
          // Excluded secret columns remain untouched on matching local records.
          mergedRows[existingIndex] = {
            ...mergedRows[existingIndex],
            ...sourceRow,
          };
          updatedRows++;
        }
      }
      mergedData[tableName] = mergedRows;
    }

    return SpreadsheetMergeResult(
      data: mergedData,
      importedRows: importedRows,
      insertedRows: insertedRows,
      updatedRows: updatedRows,
    );
  }

  static void _validateSchemaVersion(Excel workbook) {
    final metadata = workbook.tables[_metadataSheetName];
    if (metadata == null || metadata.rows.isEmpty) return;
    for (final row in metadata.rows) {
      if (row.length < 2 || row[0]?.displayText.trim() != 'schema_version') {
        continue;
      }
      final version = int.tryParse(row[1]?.displayText.trim() ?? '');
      if (version == null || version > _spreadsheetSchemaVersion) {
        throw const FormatException(
          'إصدار ملف الشيت غير مدعوم. حدّث التطبيق لاستيراده.',
        );
      }
      return;
    }
  }

  static CellValue _cellValue(String fieldName, dynamic value) {
    if (_sensitiveFields.contains(fieldName) || value == null) {
      return TextCellValue('');
    }
    return switch (value) {
      bool value => BoolCellValue(value),
      int value => IntCellValue(value),
      num value => DoubleCellValue(value.toDouble()),
      _ => TextCellValue(value.toString()),
    };
  }

  static dynamic _readCell(Data? cell) {
    final value = cell?.value;
    return switch (value) {
      null => '',
      TextCellValue(value: final text) => text.text ?? '',
      IntCellValue(value: final number) => number,
      DoubleCellValue(value: final number) => number,
      BoolCellValue(value: final boolean) => boolean,
      DateCellValue() => value.asDateTimeLocal().toIso8601String().substring(0, 10),
      DateTimeCellValue() =>
        value.asDateTimeLocal().toIso8601String().substring(0, 10),
      FormulaCellValue() => throw const FormatException(
          'لا يمكن استيراد خلايا المعادلات؛ الصق قيمها في ملف الشيت أولاً.',
        ),
      _ => cell?.displayText ?? '',
    };
  }

  static dynamic _typedValue({
    required String tableName,
    required String fieldName,
    required dynamic value,
    required Map template,
    required int rowNumber,
  }) {
    final sample = template[fieldName];
    if (sample is int) {
      if (value is int) return value;
      if (value is num && value == value.roundToDouble()) return value.toInt();
      final text = value.toString().replaceAll(',', '').trim();
      final parsed = int.tryParse(text);
      if (parsed != null) return parsed;
      throw FormatException(
        'قيمة "$fieldName" غير صحيحة في ورقة "$tableName"، الصف $rowNumber.',
      );
    }
    if (sample is double || sample is num) {
      if (value is num) return value.toDouble();
      final text = value
          .toString()
          .replaceAll(',', '')
          .replaceAll('\$', '')
          .trim();
      final parsed = double.tryParse(text);
      if (parsed != null) return parsed;
      throw FormatException(
        'قيمة "$fieldName" غير صحيحة في ورقة "$tableName"، الصف $rowNumber.',
      );
    }
    if (sample is bool) {
      if (value is bool) return value;
      return switch (value.toString().trim().toLowerCase()) {
        'true' || '1' || 'yes' || 'نعم' => true,
        'false' || '0' || 'no' || 'لا' || '' => false,
        _ => throw FormatException(
            'قيمة "$fieldName" غير صحيحة في ورقة "$tableName"، الصف $rowNumber.',
          ),
      };
    }
    return value?.toString() ?? '';
  }

  static String _identity(String tableName, Map<String, dynamic> row) {
    final fields = _identityFields[tableName] ?? const [];
    final values = fields.map((field) => row[field]?.toString().trim() ?? '');
    final key = values.join('\u001f').toLowerCase();
    if (key.replaceAll('\u001f', '').isNotEmpty) return key;
    final normalized = Map<String, dynamic>.from(row)
      ..removeWhere((key, _) => _sensitiveFields.contains(key));
    return jsonEncode(normalized);
  }
}
