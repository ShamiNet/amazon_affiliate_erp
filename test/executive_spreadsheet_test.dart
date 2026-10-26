import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amazon_affiliate_erp/app_spreadsheet_backup.dart';

const fields = {
  'seq': 0,
  'date': '',
  'beneficiary': '',
  'accountCode': '',
  'product': '',
  'profile': '',
  'email': '',
  'cost': 0.0,
  'clicks': 0,
  'orderedItems': 0,
  'orderedRevenue': 0.0,
  'shippedItems': 0,
  'returnedItems': 0,
  'totalRevenue': 0.0,
  'commission': 0.0,
  'bonus': 0.0,
  'isPending': false,
  'password': '',
};
const schema = {
  'campaigns': [fields],
  'beneficiaries': [
    {'id': 0, 'name': '', 'baseCapital': 0.0}
  ]
};
List<Map<String, dynamic>> sampleRows() => [
      for (var i = 0; i < 6; i++)
        {
          ...fields,
          'seq': i + 1,
          'date': '2026-10-${24 + i ~/ 2}',
          'beneficiary': i.isEven ? 'شامي' : 'أبو مخلص',
          'accountCode': i.isEven ? 'SH-01' : 'MK-01',
          'product': ['قناع وجه', 'شاحن لاسلكي', 'ماكينة قهوة'][i % 3],
          'profile': 'Profile ${i + 1}',
          'email': 'profile${i + 1}@example.com',
          'cost': i == 4 ? 0.0 : 10.0,
          'clicks': i == 4 ? 0 : 100,
          'orderedItems': i + 1,
          'orderedRevenue': 50.0,
          'shippedItems': i,
          'totalRevenue': 40.0,
          'commission': [25.0, 15.0, 10.5, 0.0, 2.0, 0.0][i],
          'bonus': i == 0 ? 1.0 : 0.0,
          'isPending': i == 5,
          'password': 'NEVER_EXPORT_THIS',
        }
    ];

void main() {
  test(
      'executive export has RTL, frozen headers, formulas, caches, filters and safe round trip',
      () async {
    final rows = sampleRows();
    final bytes = AppSpreadsheetBackup.encode(data: {
      'campaigns': rows,
      'beneficiaries': [
        {'id': 1, 'name': 'شامي', 'baseCapital': 270.0}
      ]
    }, schema: schema);
    final zip = ZipDecoder().decodeBytes(bytes);
    XmlDocument doc(String path) =>
        XmlDocument.parse(utf8.decode(zip.findFile(path)!.content));
    final sheet = doc('xl/worksheets/executive.xml');
    XmlElement cell(String ref) => sheet
        .findAllElements('c')
        .firstWhere((c) => c.getAttribute('r') == ref);
    expect(
        sheet.findAllElements('sheetView').single.getAttribute('rightToLeft'),
        '1');
    expect(sheet.findAllElements('pane').single.getAttribute('ySplit'), '7');
    expect(sheet.findAllElements('autoFilter').single.getAttribute('ref'),
        'A7:V13');
    expect(cell('K8').getElement('f')!.innerText, 'IF(I8>0,J8/I8,0)');
    expect(cell('R8').getElement('f')!.innerText, 'SUM(P8:Q8)');
    expect(cell('S8').getElement('v')!.innerText, '16.0');
    expect(cell('T8').getElement('v')!.innerText, '1.6');
    expect(cell('V8').getElement('v')!.innerText, startsWith('🚀'));
    expect(cell('V9').getElement('v')!.innerText, startsWith('✅'));
    expect(cell('V10').getElement('v')!.innerText, startsWith('⚠'));
    expect(cell('V11').getElement('v')!.innerText, startsWith('🛑'));
    expect(cell('V12').getElement('v')!.innerText, startsWith('⚪'));
    expect(cell('V13').getElement('v')!.innerText, startsWith('⏳'));
    expect(cell('S14').getElement('v')!.innerText, '3.5');
    expect(cell('M4').getElement('f')!.innerText, 'S14');
    expect(cell('K14').getElement('f')!.innerText, contains('AVERAGE'));
    expect(cell('B8').getElement('f')!.innerText, contains('DATE('));
    expect(
        sheet.findAllElements('conditionalFormatting').length, greaterThan(10));
    final book = doc('xl/workbook.xml');
    expect(book.findAllElements('sheet').first.getAttribute('name'),
        'لوحة الحملات');
    expect(book.findAllElements('calcPr').single.getAttribute('fullCalcOnLoad'),
        '1');
    for (final file in zip.files.where((f) => f.name.endsWith('.xml'))) {
      expect(utf8.decode(file.content), isNot(contains('NEVER_EXPORT_THIS')));
    }
    final merged = AppSpreadsheetBackup.merge(
        bytes: bytes, currentData: const {}, schema: schema);
    expect(merged.data['campaigns'], hasLength(6));
    expect((merged.data['campaigns'] as List).first['commission'], 25.0);
    await Directory('build/executive_qa').create(recursive: true);
    await File('build/executive_qa/sample.xlsx').writeAsBytes(bytes);
  });

  test('empty export has zero totals without circular or invalid ranges', () {
    final bytes = AppSpreadsheetBackup.encode(data: const {}, schema: schema);
    final zip = ZipDecoder().decodeBytes(bytes);
    final xml =
        utf8.decode(zip.findFile('xl/worksheets/executive.xml')!.content);
    final doc = XmlDocument.parse(xml);
    expect(
        doc.findAllElements('autoFilter').single.getAttribute('ref'), 'A7:V8');
    expect(xml, isNot(contains('#REF!')));
    expect(
        AppSpreadsheetBackup.merge(
                bytes: bytes, currentData: const {}, schema: schema)
            .importedRows,
        0);
  });
}
