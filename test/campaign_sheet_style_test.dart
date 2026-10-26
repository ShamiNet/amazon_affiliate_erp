import 'dart:io';
import 'dart:ui' as ui;
import 'package:amazon_affiliate_erp/main.dart';
import 'package:amazon_affiliate_erp/campaign_sheet_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('campaign sheet renders in light and dark modes with date bands',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1700, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = AppDataController(initialize: false);
    c.campaigns = List.generate(
        9,
        (i) => CampaignLogModel.fromJson({
              'seq': i + 1,
              'date': '2026-10-${23 + i ~/ 3}',
              'accountCode': 'SH-01',
              'beneficiary': 'شامي',
              'product': 'ماكينة قهوة',
              'profile': 'Calixte Athanase',
              'email': 'profile@example.com',
              'clicks': 10,
            }));
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: RepaintBoundary(
                key: ValueKey(brightness),
                child: CampaignsInventoryScreen(controller: c)),
          )));
      await tester.pumpAndSettle();
      final table = tester.widget<DataTable>(find.byType(DataTable));
      final colors = table.rows.map((r) => r.color!.resolve({})).toList();
      expect(colors[0], colors[1]);
      expect(colors[0], isNot(colors[3]));
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(ValueKey(brightness)));
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('build/campaign_sheet_${brightness.name}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(campaignDateColor('2026-10-23', dark: false),
        campaignDateColor(' 2026-10-23 ', dark: false));
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  }, semanticsEnabled: false);
}
