import 'package:amazon_affiliate_erp/app_table_scroll_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pinned heading remains clickable after vertical and horizontal scrolling', (tester) async {
    var sorts = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(
      width: 400, height: 300,
      child: AppTableScrollWrapper(pinHeader: true, child: DataTable(
        headingRowHeight: 46,
        columns: [
          DataColumn(label: const Text('Sequence'), onSort: (_, __) => sorts++),
          const DataColumn(label: Text('Product')),
        ],
        rows: List.generate(30, (i) => DataRow(cells: [
          DataCell(Text('$i')),
          const DataCell(SizedBox(width: 650, child: Text('Product name'))),
        ])),
      ),
    )))));
    final heading = tester.getCenter(find.text('Sequence'));
    final vertical = tester.widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
      .firstWhere((view) => view.scrollDirection == Axis.vertical);
    vertical.controller!.jumpTo(250);
    await tester.pump();
    await tester.tapAt(heading);
    await tester.pump();
    expect(sorts, 1);
    expect(tester.takeException(), isNull);
    final horizontal = tester.widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
      .firstWhere((view) => view.scrollDirection == Axis.horizontal);
    horizontal.controller!.jumpTo(40);
    await tester.pump();
    await tester.tapAt(heading - const Offset(40, 0));
    await tester.pump();
    expect(sorts, 2);
    expect(tester.takeException(), isNull);
  });
}

