import 'package:amazon_affiliate_erp/main.dart';
import 'package:amazon_affiliate_erp/report_image_import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'refresh clears extracted report without deleting saved campaigns',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? {'text': 'Date\tClicks\r\n2026-10-18\t17'}
            : null);
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final c = AppDataController(initialize: false);
    c.campaigns = [
      CampaignLogModel.fromJson({'seq': 1, 'date': '2026-10-18', 'clicks': 99})
    ];
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(size: Size(1800, 1200)),
            child: WindowsDesktopShell(controller: c))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('استخراج بيانات التقارير').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('لصق جدول من الحافظة'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(ReportImageImportScreen),
            matching: find.byType(TextFormField)),
        findsNWidgets(2));
    await tester.tap(find.text('تحديث الصفحة'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(ReportImageImportScreen),
            matching: find.byType(TextFormField)),
        findsNothing);
    expect(c.campaigns.single.clicks, 99);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
