import 'dart:convert';

import 'package:amazon_affiliate_erp/gemini_api_key_vault.dart';
import 'package:amazon_affiliate_erp/report_image_import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('request content length matches encoded JSON body bytes', () {
    final body = ReportImageRequestBody.create(
      imageBytes: [1, 2, 3],
      mimeType: 'image/png',
      reportType: ReportImageType.amazonEarnings,
    );
    final decoded = jsonDecode(utf8.decode(body.bytes)) as Map<String, dynamic>;

    expect(body.contentLength, body.bytes.length);
    expect(decoded['report_type'], 'amazon_earnings');
    expect(decoded['mime_type'], 'image/png');
    expect(decoded['image_base64'], base64Encode([1, 2, 3]));
  });

  test('selected key is sent in a header and not in the image payload', () {
    final headers =
        ReportImageImportService.authenticationHeaders(' selected-secret ');
    final body = ReportImageRequestBody.create(
      imageBytes: [1, 2, 3],
      mimeType: 'image/png',
      reportType: ReportImageType.amazonEarnings,
    );

    expect(headers, {'X-Gemini-API-Key': 'selected-secret'});
    expect(utf8.decode(body.bytes), isNot(contains('selected-secret')));
    expect(
      () => ReportImageImportService.authenticationHeaders(''),
      throwsFormatException,
    );
  });

  test('secure key vault adds, switches, and removes keys', () async {
    final store = _MemorySecureStringStore();
    final vault = GeminiApiKeyVault(store: store);
    final first = await vault.add(name: 'Main key', secret: 'first-secret');
    final second = await vault.add(name: 'Backup key', secret: 'second-secret');

    expect(second.activeId, first.activeId);
    expect(second.activeKey?.maskedSecret, '••••••••cret');

    final selected = await vault.select(second.keys.last.id);
    expect(selected.activeKey?.name, 'Backup key');

    final removed = await vault.remove(second.keys.last.id);
    expect(removed.activeKey?.name, 'Main key');
    expect(removed.keys, hasLength(1));
    expect((await vault.load()).activeKey?.secret, 'first-secret');
  });

  test('falls back to the first valid key when saved active key is stale',
      () async {
    final store = _MemorySecureStringStore();
    final vault = GeminiApiKeyVault(store: store);

    await vault.add(name: 'Main key', secret: 'first-secret');
    await store.write(
      'gemini_api_key_collection_v1',
      jsonEncode({
        'active_id': 'missing-id',
        'keys': [
          {'id': 'first-id', 'name': 'Main key', 'secret': 'first-secret'},
        ],
      }),
    );

    final loaded = await vault.load();
    expect(loaded.activeId, 'first-id');
    expect(loaded.activeKey?.secret, 'first-secret');
  });

  test('rejects tab characters in API keys', () {
    expect(
      () => ReportImageImportService.authenticationHeaders('  secret\tvalue  '),
      throwsFormatException,
    );
  });

  group('ExtractedReport', () {
    test('parses extracted columns, rows, and warnings', () {
      final report = ExtractedReport.fromJson({
        'title': 'أرباح Amazon',
        'columns': ['Date', 'Earnings'],
        'rows': [
          ['2026-10-18', '\$12.40'],
        ],
        'warnings': ['Check currency'],
      });

      expect(report.title, 'أرباح Amazon');
      expect(report.columns, ['Date', 'Earnings']);
      expect(report.rows, [
        ['2026-10-18', '\$12.40'],
      ]);
      expect(report.warnings, ['Check currency']);
    });

    test('exports edited rows as tab-separated values', () {
      const report = ExtractedReport(
        title: 'Report',
        columns: ['Date', 'Product', 'Earnings'],
        rows: [],
        warnings: [],
      );

      expect(
        report.toTsv([
          ['2026-10-18', 'Tea\tMaker', '\$12.40'],
          ['2026-10-19', 'Face mask\nset', '\$3.20'],
        ]),
        'Date\tProduct\tEarnings\r\n'
        '2026-10-18\tTea Maker\t\$12.40\r\n'
        '2026-10-19\tFace mask set\t\$3.20',
      );
    });

    test('exports edited rows as comma-separated values', () {
      const report = ExtractedReport(
        title: 'Report',
        columns: ['Date', 'Product', 'Earnings'],
        rows: [],
        warnings: [],
      );

      expect(
        report.toCsv([
          ['2026-10-18', 'Tea, Maker', '\$12.40'],
          ['2026-10-19', 'Face "mask"', '\$3.20'],
        ]),
        'Date,Product,Earnings\r\n'
        '2026-10-18,"Tea, Maker",\$12.40\r\n'
        '2026-10-19,"Face ""mask""",\$3.20',
      );
    });

    test(
        'parses comma- and tab-delimited files imported from spreadsheet files',
        () {
      const csv = 'Date,Product,Earnings\n2026-10-18,"Tea, Maker",\$12.40';
      const tsv = 'Date\tProduct\tEarnings\n2026-10-18\tTea Maker\t\$12.40';

      expect(
        ExtractedReport.fromDelimitedText(csv, delimiter: ',').columns,
        ['Date', 'Product', 'Earnings'],
      );
      expect(
        ExtractedReport.fromDelimitedText(tsv, delimiter: '\t').rows.first,
        ['2026-10-18', 'Tea Maker', '\$12.40'],
      );
    });

    test('compares rows by matching column names and highlights changed cells',
        () {
      const imported = ExtractedReport(
        title: 'Imported',
        columns: ['Earnings', 'Product'],
        rows: [
          ['\$12.40', 'Tea'],
          ['\$3.20', 'Mask'],
        ],
        warnings: [],
      );
      final comparison = ReportComparison(
        currentColumns: ['Product', 'Earnings'],
        currentRows: [
          ['Tea', '\$12.40'],
          ['Mask', '\$3.50'],
        ],
        importedReport: imported,
      );

      expect(comparison.differingCells, 1);
      expect(comparison.differingRows, 1);
      expect(comparison.cellDiffers(0, 0), isFalse);
      expect(comparison.cellDiffers(1, 1), isTrue);
      expect(comparison.rowDiffers(0), isFalse);
      expect(comparison.rowDiffers(1), isTrue);
    });

    test('reports rows and columns that exist on only one side', () {
      const imported = ExtractedReport(
        title: 'Imported',
        columns: ['Date', 'Note'],
        rows: [
          ['2026-10-18', 'Updated'],
          ['2026-10-19', 'New row'],
        ],
        warnings: [],
      );
      final comparison = ReportComparison(
        currentColumns: ['Date', 'Earnings'],
        currentRows: [
          ['2026-10-18', '\$12.40'],
        ],
        importedReport: imported,
      );

      expect(comparison.missingColumns, {'Earnings'});
      expect(comparison.extraColumns, {'Note'});
      expect(comparison.currentOnlyRows, 0);
      expect(comparison.importedOnlyRows, 1);
      expect(comparison.cellDiffers(0, 1), isTrue);
    });

    test('rejects rows whose cell count does not match columns', () {
      expect(
        () => ExtractedReport.fromJson({
          'columns': ['Date', 'Earnings'],
          'rows': [
            ['2026-10-18'],
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects empty extraction results', () {
      expect(
        () => ExtractedReport.fromJson({
          'columns': ['Date'],
          'rows': <List<String>>[],
        }),
        throwsFormatException,
      );
    });
  });

  testWidgets('renders screenshot extraction controls', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: ReportImageImportScreen()),
    );

    expect(find.text('استخراج بيانات التقارير من الصور'), findsOneWidget);
    expect(find.text('اختيار لقطة شاشة'), findsOneWidget);
    expect(find.text('استخراج البيانات'), findsOneWidget);
    expect(find.text('أرباح Amazon'), findsWidgets);
    expect(find.text('لصق من الحافظة (Ctrl+V)'), findsOneWidget);
    expect(find.text('لصق جدول من الحافظة'), findsOneWidget);
  });

  testWidgets('pastes clipboard TSV into the report table', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return {'text': 'Date\tClicks\r\n2026-10-18\t12'};
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      const MaterialApp(home: ReportImageImportScreen()),
    );
    await tester.tap(find.text('لصق جدول من الحافظة'));
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Clicks'), findsOneWidget);
    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .map((field) => field.initialValue),
      ['2026-10-18', '12'],
    );
  });
}

class _MemorySecureStringStore implements SecureStringStore {
  String? _value;

  @override
  Future<String?> read(String key) async => _value;

  @override
  Future<void> write(String key, String value) async {
    _value = value;
  }
}
