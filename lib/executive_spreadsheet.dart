import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Adds a reader-facing dashboard to the reversible raw-data XLSX backup.
/// Input sheets retain their original identifiers for lossless application import.
class ExecutiveSpreadsheet {
  static const sheetName = 'لوحة الحملات';
  static const _ns =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  static const _bands = [
    'F0EAFE',
    'E8F5E9',
    'FFF4D8',
    'E3F2FD',
    'FCE8EF',
    'E0F2F1'
  ];
  static const headers = [
    'التسلسل',
    'التاريخ',
    'المستفيد',
    'رمز الحساب',
    'المنتج',
    'البروفايل',
    'الإيميل',
    'تكلفة الحملة',
    'النقرات',
    'الطلبات',
    'نسبة التحويل',
    'قيمة الطلبات',
    'المشحون',
    'المرتجع',
    'إجمالي المبيعات',
    'العمولة',
    'المكافآت',
    'إجمالي الأرباح',
    'صافي الربح',
    'العائد ROI',
    'حالة التنفيذ',
    'التوصية / الحالة',
  ];
  static const _fields = [
    'seq',
    'date',
    'beneficiary',
    'accountCode',
    'product',
    'profile',
    'email',
    'cost',
    'clicks',
    'orderedItems',
    '',
    'orderedRevenue',
    'shippedItems',
    'returnedItems',
    'totalRevenue',
    'commission',
    'bonus',
    '',
    '',
    '',
    'isPending',
    '',
  ];

  static List<int> decorate(
      List<int> input, Map<String, dynamic> data, Map<String, dynamic> schema) {
    final zip = ZipDecoder().decodeBytes(input);
    XmlDocument read(String path) =>
        XmlDocument.parse(utf8.decode(zip.findFile(path)!.content));
    void write(String path, XmlDocument doc) =>
        zip.addFile(ArchiveFile.string(path, doc.toXmlString()));
    final stylesDoc = read('xl/styles.xml');
    final styles = _Styles(stylesDoc.rootElement);
    final book = read('xl/workbook.xml');
    final rels = read('xl/_rels/workbook.xml.rels');
    final types = read('[Content_Types].xml');
    final sheets = book.rootElement.getElement('sheets')!;
    final ids = sheets
        .findElements('sheet')
        .map((s) => int.parse(s.getAttribute('sheetId')!));
    final id = ids.fold<int>(0, (a, b) => a > b ? a : b) + 1;
    const relationId = 'rIdExecutiveDashboard';
    final path = 'xl/worksheets/executive.xml';
    rels.rootElement.children.add(_el(
        '<Relationship Id="$relationId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/executive.xml"/>'));
    types.rootElement.children.add(_el(
        '<Override PartName="/$path" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'));
    sheets.children.insert(0,
        _el('<sheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" name="$sheetName" sheetId="$id" r:id="$relationId"/>'));
    final dashboard = _dashboard(data, schema, styles);
    zip.addFile(ArchiveFile.string(path, dashboard));

    // Format the original inputs too, without moving headers or changing values.
    for (final sheet in sheets.findElements('sheet').toList()) {
      final name = sheet.getAttribute('name');
      if (name == sheetName) continue;
      if (name == '_metadata') sheet.setAttribute('state', 'hidden');
      final rid = sheet.getAttribute('id',
          namespace:
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships');
      final relation = rels.rootElement
          .findElements('Relationship')
          .where((r) => r.getAttribute('Id') == rid)
          .first;
      final target = relation.getAttribute('Target')!;
      final sheetPath =
          target.startsWith('/') ? target.substring(1) : 'xl/$target';
      final doc = read(sheetPath);
      final root = doc.rootElement;
      root.getElement('sheetViews')?.remove();
      final views = _el(
          '<sheetViews><sheetView workbookViewId="0" rightToLeft="1" showGridLines="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/><selection pane="bottomLeft" activeCell="A2" sqref="A2"/></sheetView></sheetViews>');
      final dimension = root.getElement('dimension');
      root.children.insert(
          dimension == null ? 0 : root.children.indexOf(dimension) + 1, views);
      final rows =
          root.getElement('sheetData')?.findElements('row').toList() ?? [];
      for (final row in rows) {
        final heading = row.getAttribute('r') == '1';
        row.setAttribute('ht', heading ? '30' : '22');
        row.setAttribute('customHeight', '1');
        for (final cell in row.findElements('c')) {
          cell.setAttribute('s',
              '${styles.style(fill: heading ? '0F5132' : 'FFFFFF', white: heading, bold: heading, align: heading ? 'center' : 'right')}');
        }
      }
      root.getElement('cols')?.remove();
      final rawHeaders =
          ((schema[name] as List?)?.first as Map?)?.keys.toList() ?? [];
      final cols = StringBuffer('<cols>');
      for (var i = 0; i < rawHeaders.length; i++) {
        var width = rawHeaders[i].toString().length + 3;
        for (final record in (data[name] as List? ?? []).whereType<Map>()) {
          final size = (record[rawHeaders[i]] ?? '').toString().length + 2;
          if (size > width) width = size;
        }
        cols.write(
            '<col min="${i + 1}" max="${i + 1}" width="${width.clamp(14, 48)}" customWidth="1"/>');
      }
      cols.write('</cols>');
      final sheetData = root.getElement('sheetData')!;
      if (rawHeaders.isNotEmpty) {
        root.children
            .insert(root.children.indexOf(sheetData), _el(cols.toString()));
      }
      if (rows.isNotEmpty && rawHeaders.isNotEmpty) {
        root.getElement('autoFilter')?.remove();
        root.children.insert(root.children.indexOf(sheetData) + 1,
            _el('<autoFilter ref="A1:${_col(rawHeaders.length - 1)}${rows.length}"/>'));
      }
      write(sheetPath, doc);
    }
    final view =
        book.rootElement.getElement('bookViews')?.getElement('workbookView');
    view?.setAttribute('activeTab', '0');
    view?.setAttribute('firstSheet', '0');
    book.rootElement.getElement('calcPr')?.remove();
    book.rootElement.children.add(_el(
        '<calcPr calcId="191029" calcMode="auto" fullCalcOnLoad="1" forceFullCalc="1"/>'));
    write('xl/styles.xml', stylesDoc);
    write('xl/workbook.xml', book);
    write('xl/_rels/workbook.xml.rels', rels);
    write('[Content_Types].xml', types);
    return ZipEncoder().encode(zip);
  }

  static String _dashboard(
      Map<String, dynamic> data, Map<String, dynamic> schema, _Styles styles) {
    final records =
        (data['campaigns'] as List? ?? []).whereType<Map>().toList();
    final template =
        (schema['campaigns'] as List? ?? []).firstOrNull as Map? ?? {};
    final sourceHeaders = template.keys.toList();
    final last = records.isEmpty ? 8 : 7 + records.length;
    final totalRow = last + 1;
    String ref(int index, String key) {
      final column = sourceHeaders.indexOf(key);
      return column < 0
          ? ([
              'seq',
              'cost',
              'clicks',
              'orderedItems',
              'orderedRevenue',
              'shippedItems',
              'returnedItems',
              'totalRevenue',
              'commission',
              'bonus'
            ].contains(key)
              ? '0'
              : '""')
          : "'campaigns'!\$${_col(column)}\$${index + 2}";
    }

    final out = StringBuffer(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="$_ns"><sheetPr><tabColor rgb="FF0F5132"/><pageSetUpPr fitToPage="1"/></sheetPr><dimension ref="A1:V${totalRow + 2}"/><sheetViews><sheetView workbookViewId="0" rightToLeft="1" showGridLines="0" tabSelected="1"><pane ySplit="7" topLeftCell="A8" activePane="bottomLeft" state="frozen"/><selection pane="bottomLeft" activeCell="A8" sqref="A8"/></sheetView></sheetViews><sheetFormatPr defaultRowHeight="25"/><cols>');
    const widths = [
      11,
      17,
      19,
      15,
      32,
      25,
      30,
      17,
      14,
      14,
      17,
      19,
      15,
      15,
      19,
      17,
      17,
      19,
      19,
      17,
      20,
      48
    ];
    for (var i = 0; i < widths.length; i++) {
      var width = widths[i];
      for (final record in records) {
        final value = record[_fields[i]];
        final length = value is num
            ? value.toStringAsFixed(2).length + 6
            : (value ?? '').toString().runes.length + 3;
        if (length > width) width = length;
      }
      out.write(
          '<col min="${i + 1}" max="${i + 1}" width="${width.clamp(widths[i], 80)}" bestFit="1" customWidth="1"/>');
    }
    out.write('</cols><sheetData>');
    final merges = <String>[
      'A2:V2',
      'A6:V6',
      'A$totalRow:G$totalRow',
      'A${totalRow + 2}:V${totalRow + 2}'
    ];
    String range(String col) => '$col\$8:$col\$$last';
    double sum(String key) =>
        records.fold<double>(0, (v, r) => v + _num(r[key]));
    final earnings = sum('commission') + sum('bonus');
    final cost = sum('cost');
    final net = earnings - cost;
    final capRows =
        (data['beneficiaries'] as List? ?? []).whereType<Map>().toList();
    final capTemplate =
        (schema['beneficiaries'] as List? ?? []).firstOrNull as Map? ?? {};
    final capColumn = capTemplate.keys.toList().indexOf('baseCapital');
    final capital =
        capRows.fold<double>(0, (s, r) => s + _num(r['baseCapital']));
    final capFormula = capColumn < 0 || capRows.isEmpty
        ? '0'
        : "SUM('beneficiaries'!${_col(capColumn)}2:${_col(capColumn)}${capRows.length + 1})";
    final cardNames = [
      'إجمالي رأس المال',
      'إجمالي التكلفة',
      'إجمالي الأرباح',
      'صافي الأرباح',
      'العائد ROI',
      'عدد الحملات'
    ];
    final formulas = [
      capFormula,
      'H$totalRow',
      'R$totalRow',
      'S$totalRow',
      'IF(H$totalRow>0,S$totalRow/H$totalRow,0)',
      'COUNT(${range('A')})'
    ];
    final values = [
      capital,
      cost,
      earnings,
      net,
      cost > 0 ? net / cost : 0,
      records.length
    ];
    const starts = [0, 4, 8, 12, 16, 19];
    const ends = [3, 7, 11, 15, 18, 21];
    out.write(
        '<row r="2" ht="34" customHeight="1">${_cell('A2', styles.style(fill: '0F5132', white: true, bold: true, size: 14), '📊 لوحة الجرد والإحصاء اليومي للحملات وأرباح أمازون')}</row>');
    for (var r = 3; r <= 4; r++) {
      out.write('<row r="$r" ht="${r == 3 ? 27 : 38}" customHeight="1">');
      for (var card = 0; card < starts.length; card++) {
        merges.add('${_col(starts[card])}$r:${_col(ends[card])}$r');
        for (var c = starts[card]; c <= ends[card]; c++) {
          final style = styles.style(
              fill: r == 3 ? (card.isEven ? 'DAEBDD' : 'EDF1EE') : 'F5FAF6',
              bold: true,
              size: r == 3 ? 11 : 16,
              format: r == 3
                  ? ''
                  : card == 4
                      ? '0.0%'
                      : card == 5
                          ? '#,##0'
                          : card == 3
                              ? r'[Green]"▲ $"#,##0.00;[Red]"▼ $"#,##0.00;"$"0.00'
                              : r'"$"#,##0.00;[Red]("$"#,##0.00)',
              color: card == 3 && net < 0 ? 'B42318' : '0F5132');
          out.write(_cell(
              '${_col(c)}$r',
              style,
              c == starts[card]
                  ? (r == 3 ? cardNames[card] : values[card])
                  : null,
              formula: r == 4 && c == starts[card] ? formulas[card] : null));
        }
      }
      out.write('</row>');
    }
    out.write(
        '<row r="6" ht="28" customHeight="1">${_cell('A6', styles.style(fill: 'E8F2EA', italic: true, align: 'right'), 'عدّل بيانات الإدخال في أوراق البيانات الأصلية مثل campaigns؛ تُحدّث المعادلات تلقائيًا. استخدم فلاتر الصف 7. العائد المرتفع ≥100%، والتحسين الطفيف عند 0–10%.')}</row>');
    out.write('<row r="7" ht="44" customHeight="1">');
    for (var c = 0; c < headers.length; c++) {
      out.write(_cell(
          '${_col(c)}7',
          styles.style(fill: '0F5132', white: true, bold: true, wrap: true),
          headers[c]));
    }
    out.write('</row>');
    final moneyCols = {7, 11, 14, 15, 16, 17, 18};
    final numericCols = {0, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19};
    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      final r = i + 8;
      final clicks = _num(record['clicks']),
          orders = _num(record['orderedItems']);
      final earning = _num(record['commission']) + _num(record['bonus']);
      final spend = _num(record['cost']), profit = earning - spend;
      final roi = spend > 0 ? profit / spend : 0.0;
      final pending = record['isPending'] == true;
      final day = DateTime.tryParse('${record['date']}');
      final serial = day == null
          ? null
          : DateTime.utc(day.year, day.month, day.day)
              .difference(DateTime.utc(1899, 12, 30))
              .inDays;
      final band = _bands[(serial ?? 0) % _bands.length];
      out.write('<row r="$r" ht="34" customHeight="1">');
      for (var c = 0; c < headers.length; c++) {
        final field = _fields[c];
        var formula = ref(i, field);
        dynamic value = record[field] ?? (numericCols.contains(c) ? 0 : '');
        if ([2, 3, 4, 5, 6].contains(c))
          formula = 'IF($formula="","",$formula)';
        if (c == 1) {
          final source = ref(i, 'date');
          formula =
              'IF($source="","",DATE(VALUE(LEFT($source,4)),VALUE(MID($source,6,2)),VALUE(RIGHT($source,2))))';
          value = serial ?? '';
        } else if (c == 10) {
          formula = 'IF(I$r>0,J$r/I$r,0)';
          value = clicks > 0 ? orders / clicks : 0;
        } else if (c == 17) {
          formula = 'SUM(P$r:Q$r)';
          value = earning;
        } else if (c == 18) {
          formula = 'R$r-H$r';
          value = profit;
        } else if (c == 19) {
          formula = 'IF(H$r>0,S$r/H$r,0)';
          value = roi;
        } else if (c == 20) {
          formula = 'IF(${ref(i, 'isPending')}=TRUE,"قيد التشغيل","مكتملة")';
          value = pending ? 'قيد التشغيل' : 'مكتملة';
        } else if (c == 21) {
          formula =
              'IF(U$r="قيد التشغيل","⏳ بانتظار النتائج",IF(H$r=0,"⚪ تجريبية / مجانية",IF(S$r<0,"🛑 إيقاف فوري",IF(T$r>=1,"🚀 كرر الحملة وضاعف الميزانية",IF(T$r<=0.1,"⚠️ تعديل طفيف لتحسين العائد","✅ رابحة - استمر بتكرارها")))))';
          value = pending
              ? '⏳ بانتظار النتائج'
              : spend == 0
                  ? '⚪ تجريبية / مجانية'
                  : profit < 0
                      ? '🛑 إيقاف فوري'
                      : roi >= 1
                          ? '🚀 كرر الحملة وضاعف الميزانية'
                          : roi <= .1
                              ? '⚠️ تعديل طفيف لتحسين العائد'
                              : '✅ رابحة - استمر بتكرارها';
        }
        final identityFill =
            (c == 2 || c == 3) ? _identityFill('$value') : band;
        final format = c == 1
            ? 'yyyy-mm-dd'
            : c == 10 || c == 19
                ? '0.0%'
                : moneyCols.contains(c)
                    ? r'"$"#,##0.00;[Red]("$"#,##0.00)'
                    : numericCols.contains(c)
                        ? '#,##0'
                        : '';
        out.write(_cell(
            '${_col(c)}$r',
            styles.style(
                fill: identityFill,
                align: numericCols.contains(c) || c == 1 || c == 3
                    ? 'center'
                    : 'right',
                format: format,
                bold: c == 1 || c == 2 || c == 3 || c == 18,
                wrap: c == 4 || c == 21),
            value,
            formula: formula));
      }
      out.write('</row>');
    }
    if (records.isEmpty) out.write('<row r="8" ht="25" customHeight="1"/>');
    out.write('<row r="$totalRow" ht="32" customHeight="1">');
    out.write(_cell(
        'A$totalRow',
        styles.style(fill: 'DAEBDD', bold: true, doubleBottom: true),
        '📊 المجموع الكلي'));
    for (var c = 7; c < 22; c++) {
      if (c == 20 || c == 21) {
        out.write(_cell(
            '${_col(c)}$totalRow',
            styles.style(fill: 'DAEBDD', bold: true, doubleBottom: true),
            null));
        continue;
      }
      final column = _col(c);
      final isRate = c == 10 || c == 19;
      final f = isRate
          ? 'IF(COUNT(${range(column)})>0,AVERAGE(${range(column)}),0)'
          : 'SUM(${range(column)})';
      double cached;
      if (c == 17) {
        cached = earnings;
      } else if (c == 18) {
        cached = net;
      } else if (isRate) {
        cached = records.isEmpty
            ? 0
            : records.fold<double>(0, (s, r) {
                  final denominator = _num(r[c == 10 ? 'clicks' : 'cost']);
                  final numerator = c == 10
                      ? _num(r['orderedItems'])
                      : _num(r['commission']) +
                          _num(r['bonus']) -
                          _num(r['cost']);
                  return s + (denominator > 0 ? numerator / denominator : 0);
                }) /
                records.length;
      } else {
        cached = sum(_fields[c]);
      }
      out.write(_cell(
          '$column$totalRow',
          styles.style(
              fill: 'DAEBDD',
              bold: true,
              doubleBottom: true,
              format: isRate
                  ? '0.0%'
                  : moneyCols.contains(c)
                      ? r'"$"#,##0.00;[Red]("$"#,##0.00)'
                      : '#,##0'),
          cached,
          formula: f));
    }
    out.write(
        '</row><row r="${totalRow + 2}" ht="28" customHeight="1">${_cell('A${totalRow + 2}', styles.style(italic: true, align: 'right'), 'نسب صف المجموع هي متوسط نسب الحملات. بطاقة ROI بالأعلى = إجمالي صافي الربح ÷ إجمالي التكلفة. المؤشرات تشمل الحملات قيد التشغيل.')}</row></sheetData><autoFilter ref="A7:V$last"/><mergeCells count="${merges.length}">');
    for (final merge in merges) {
      out.write('<mergeCell ref="$merge"/>');
    }
    out.write('</mergeCells>');
    var priority = 1;
    // Date bands react to changed source dates; identity cells keep their badges.
    for (var i = 0; i < _bands.length; i++) {
      final dxf = styles.dxf(fill: _bands[i]);
      out.write(
          '<conditionalFormatting sqref="A8:B$last E8:Q$last U8:U$last"><cfRule type="expression" dxfId="$dxf" priority="${priority++}"><formula>AND(ISNUMBER(\$B8),MOD(INT(\$B8),6)=$i)</formula></cfRule></conditionalFormatting>');
    }
    for (final column in ['R', 'S', 'T']) {
      final negative = styles.dxf(fill: 'FDE7E7', color: 'B42318');
      out.write(
          '<conditionalFormatting sqref="${column}8:$column$last"><cfRule type="cellIs" operator="lessThan" dxfId="$negative" priority="${priority++}" stopIfTrue="1"><formula>0</formula></cfRule><cfRule type="colorScale" priority="${priority++}"><colorScale><cfvo type="num" val="0"/><cfvo type="formula" val="MAX(0.000001,MAX(${column}8:$column$last))"/><color rgb="FFF4FAF5"/><color rgb="FFA9D8B4"/></colorScale></cfRule></conditionalFormatting>');
    }
    final statusColors = [
      ('⏳', 'FFF4D8', '8A5700'),
      ('⚪', 'EEF1F4', '53616A'),
      ('🛑', 'FDE7E7', 'B42318'),
      ('🚀', 'D8EEDB', '116329'),
      ('⚠', 'FFF4D8', '8A5700'),
      ('✅', 'E8F5E9', '166534')
    ];
    for (final entry in statusColors) {
      out.write(
          '<conditionalFormatting sqref="V8:V$last"><cfRule type="expression" dxfId="${styles.dxf(fill: entry.$2, color: entry.$3)}" priority="${priority++}"><formula>ISNUMBER(SEARCH("${entry.$1}",V8))</formula></cfRule></conditionalFormatting>');
    }
    out.write(
        '<pageMargins left="0.25" right="0.25" top="0.35" bottom="0.35" header="0.15" footer="0.15"/><pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/></worksheet>');
    return out.toString();
  }

  static double _num(dynamic value) => value is num ? value.toDouble() : 0;
  static String _identityFill(String value) {
    final hash = value
        .trim()
        .toUpperCase()
        .codeUnits
        .fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff);
    return _bands[hash % _bands.length];
  }

  static String _col(int index) {
    var n = index + 1;
    var out = '';
    while (n > 0) {
      n--;
      out = String.fromCharCode(65 + n % 26) + out;
      n ~/= 26;
    }
    return out;
  }

  static String _cell(String address, int style, dynamic value,
      {String? formula}) {
    if (formula != null) {
      final text = value is String;
      return '<c r="$address" s="$style"${text ? ' t="str"' : ''}><f>${_x(formula)}</f><v>${_x(value ?? '')}</v></c>';
    }
    if (value == null) return '<c r="$address" s="$style"/>';
    return '<c r="$address" s="$style" t="inlineStr"><is><t xml:space="preserve">${_x(value)}</t></is></c>';
  }
}

XmlElement _el(String xml) => XmlDocument.parse(xml).rootElement.copy();
String _x(dynamic value) => value
    .toString()
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

class _Styles {
  _Styles(this.root);
  final XmlElement root;
  final _cache = <String, int>{};
  XmlElement section(String name) {
    var node = root.getElement(name);
    if (node == null) {
      node = XmlElement(XmlName(name));
      const order = [
        'numFmts',
        'fonts',
        'fills',
        'borders',
        'cellStyleXfs',
        'cellXfs',
        'cellStyles',
        'dxfs',
        'tableStyles',
        'colors',
        'extLst'
      ];
      final rank = order.indexOf(name);
      final next = root.children
          .whereType<XmlElement>()
          .where((n) => order.indexOf(n.name.local) > rank)
          .firstOrNull;
      if (next == null) {
        root.children.add(node);
      } else {
        root.children.insert(root.children.indexOf(next), node);
      }
    }
    return node;
  }

  int append(String name, String xml) {
    final node = section(name);
    final id = node.childElements.length;
    node.children.add(_el(xml));
    node.setAttribute('count', '${id + 1}');
    return id;
  }

  int style(
      {String fill = 'FFFFFF',
      String color = '24392D',
      bool white = false,
      bool bold = false,
      bool italic = false,
      int size = 11,
      String align = 'center',
      String format = '',
      bool wrap = false,
      bool doubleBottom = false}) {
    final key =
        '$fill|$color|$white|$bold|$italic|$size|$align|$format|$wrap|$doubleBottom';
    if (_cache.containsKey(key)) return _cache[key]!;
    final font = append('fonts',
        '<font><sz val="$size"/><color rgb="FF${white ? 'FFFFFF' : color}"/><name val="Segoe UI"/>${bold ? '<b/>' : ''}${italic ? '<i/>' : ''}</font>');
    final fillId = append('fills',
        '<fill><patternFill patternType="solid"><fgColor rgb="FF$fill"/><bgColor indexed="64"/></patternFill></fill>');
    final border = append('borders',
        '<border><left style="thin"><color rgb="FFD6E0DB"/></left><right style="thin"><color rgb="FFD6E0DB"/></right><top style="thin"><color rgb="FFD6E0DB"/></top><bottom style="${doubleBottom ? 'double' : 'thin'}"><color rgb="FF${doubleBottom ? '0F5132' : 'D6E0DB'}"/></bottom><diagonal/></border>');
    var fmt = 0;
    if (format.isNotEmpty) {
      final formats = section('numFmts');
      fmt = formats.childElements
              .map((e) => int.tryParse(e.getAttribute('numFmtId') ?? '') ?? 0)
              .fold<int>(163, (a, b) => a > b ? a : b) +
          1;
      formats.children
          .add(_el('<numFmt numFmtId="$fmt" formatCode="${_x(format)}"/>'));
      formats.setAttribute('count', '${formats.childElements.length}');
    }
    return _cache[key] = append('cellXfs',
        '<xf numFmtId="$fmt" fontId="$font" fillId="$fillId" borderId="$border" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1" applyNumberFormat="1"><alignment horizontal="$align" vertical="center" readingOrder="2"${wrap ? ' wrapText="1"' : ''}/></xf>');
  }

  int dxf({required String fill, String? color}) => append('dxfs',
      '<dxf>${color == null ? '' : '<font><b/><color rgb="FF$color"/></font>'}<fill><patternFill patternType="solid"><fgColor rgb="FF$fill"/><bgColor indexed="64"/></patternFill></fill></dxf>');
}
