import 'dart:convert';
import 'dart:io';
import 'package:amazon_affiliate_erp/portal_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amazon_affiliate_erp/main.dart';

void main() {
  test('cloud merged rows import into the real application controller',
      () async {
    final dir = await Directory.systemTemp.createTemp('erp_cloud_import_');
    try {
      final controller = AppDataController(
          initialize: false, databaseFile: File('${dir.path}/data.json'));
      final local = <String, dynamic>{
        'campaigns': [
          <dynamic, dynamic>{
            'seq': 1,
            'date': '2026-11-02',
            'cost': 10,
            'password': 'local-only'
          }
        ],
        'beneficiaries': [
          <dynamic, dynamic>{'id': 1, 'name': 'test'}
        ]
      };
      final remote = portalSafeSnapshot(local);
      final merged = mergePortalSnapshot(local, remote);
      expect((merged['campaigns'] as List).single, isA<Map<String, dynamic>>());
      await controller.importMergedSpreadsheetData(merged);
      expect(controller.campaigns.single.cost, 10);
      expect(controller.campaigns.single.password, 'local-only');
      expect(controller.beneficiaries.single.name, 'test');
      controller.dispose();
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test(
      'legacy duplicate campaigns keep separate stable cloud identities and backup',
      () async {
    final dir = await Directory.systemTemp.createTemp('erp_migration_');
    try {
      final file = File('${dir.path}/data.json');
      final row = CampaignLogModel.fromJson({
        'seq': 1,
        'date': '2026-10-21',
        'beneficiary': 'test',
        'accountCode': 'MK-01',
        'product': 'test'
      }).toJson()
        ..remove('_portalRecordId');
      final original = jsonEncode({
        'campaigns': [row, row]
      });
      await file.writeAsString(original);
      final first = AppDataController(databaseFile: file);
      await first.ready;
      expect(first.campaigns.length, 2);
      final ids = first.campaigns.map((r) => r.cloudId).toList();
      expect(ids.toSet().length, 2);
      expect(await File('${file.path}.before_portal_ids.bak').readAsString(),
          original);
      final second = AppDataController(databaseFile: file);
      await second.ready;
      expect(second.campaigns.map((r) => r.cloudId).toList(), ids);
      first.dispose();
      second.dispose();
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('invalid existing database is never replaced by factory data', () async {
    final dir = await Directory.systemTemp.createTemp('erp_invalid_');
    try {
      final file = File('${dir.path}/data.json');
      await file.writeAsString('broken');
      final controller = AppDataController(databaseFile: file);
      await expectLater(controller.ready, throwsFormatException);
      expect(await file.readAsString(), 'broken');
      controller.dispose();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
