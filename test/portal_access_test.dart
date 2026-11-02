import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amazon_affiliate_erp/portal_client.dart';
import 'package:amazon_affiliate_erp/portal_admin_sync.dart';
import 'package:amazon_affiliate_erp/portal_screens.dart';

class TestPortalClient extends PortalClient {
  TestPortalClient()
      : super(const PortalConfig(
            projectId: 'demo',
            apiKey: 'test',
            apiBase: 'https://example.test/api'));
  final stream = StreamController<Map<String, dynamic>>.broadcast();
  Map<String, dynamic> remote = {
    'beneficiaries': [
      {'id': 2, 'name': 'أبو مخلص', 'baseCapital': 270}
    ],
    'campaigns': [
      {'seq': 2, 'beneficiary': 'أبو مخلص', 'cost': 20, 'commission': 35}
    ]
  };
  int revision = 1;
  String role = 'admin';
  final published = <Map<String, dynamic>>[];
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<Map<String, dynamic>> request(String path,
      {String method = 'GET', Map<String, dynamic>? body}) async {
    if (path == '/access') return {'role': role};
    if (path == '/admin/state') return {'revision': revision, 'data': remote};
    if (path == '/admin/publish') {
      if (body!['expectedRevision'] != revision)
        throw const PortalError('REVISION_CONFLICT');
      published.add(body);
      remote = Map<String, dynamic>.from(body['data']);
      revision++;
      return {'revision': revision};
    }
    if (path == '/view') return memberView();
    throw const PortalError('NOT_FOUND');
  }

  Map<String, dynamic> memberView() => {
        'displayName': 'أبو مخلص',
        'revision': revision,
        'metrics': {'capital': 270, 'netProfit': 20},
        'sections': {
          'campaigns': {
            'label': 'حملاتي',
            'fields': ['product', 'commission'],
            'editableFields': [],
            'rows': [
              {
                'rowId': 'own',
                'values': {'product': 'حملة خاصة بي', 'commission': 35}
              }
            ]
          }
        },
        'canExport': false
      };
  @override
  Stream<Map<String, dynamic>> events() => stream.stream;
  @override
  Future<void> signOut() async {}
  @override
  void dispose() {}
}

void main() {
  test('shared proxy endpoints retain separate private credentials after sync',
      () {
    final local = {
      'proxies': [
        {
          'host': 'shared.example',
          'port': 8000,
          'username': 'first-user',
          'password': 'first-secret'
        },
        {
          'host': 'shared.example',
          'port': 8000,
          'username': 'second-user',
          'password': 'second-secret'
        },
      ]
    };
    final remote = portalSafeSnapshot(local);
    final records = remote['proxies'] as List;
    expect(records[0]['_portalRecordId'], isNot(records[1]['_portalRecordId']));
    expect(records[0].containsKey('username'), isFalse);
    final merged = mergePortalSnapshot(local, remote)['proxies'] as List;
    expect(merged[0]['password'], 'first-secret');
    expect(merged[1]['password'], 'second-secret');
  });
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
      'cloud snapshots exclude credentials; pulling preserves local-only secrets',
      () {
    final local = {
      'campaigns': [
        {'seq': 2, 'cost': 1, 'password': 'private', 'adUrl': 'private-link'}
      ],
      'emails': [
        {'email': 'x', 'password': 'email-secret'}
      ]
    };
    final safe = portalSafeSnapshot(local);
    expect((safe['campaigns'] as List).single.containsKey('password'), isFalse);
    final merged = mergePortalSnapshot(local, {
      'campaigns': [
        {'seq': 2, 'cost': 20}
      ],
      'emails': []
    });
    expect((merged['campaigns'] as List).single['password'], 'private');
    expect((merged['campaigns'] as List).single['cost'], 20);
    expect(merged['emails'], isEmpty);
  });
  testWidgets(
      'admin changes push once; concurrent cloud revision requires explicit resolution',
      (tester) async {
    final events = ChangeNotifier(), client = TestPortalClient();
    var local = <String, dynamic>{
      'campaigns': [
        {'seq': 2, 'cost': 1, 'password': 'private'}
      ]
    };
    final sync = PortalAdminSync(
        snapshot: () => local,
        applySnapshot: (next) async {
          local = next;
          events.notifyListeners();
        },
        changes: events,
        clientFactory: (_) => client);
    await sync.signIn(client.config, 'admin', 'unused');
    await sync.start(useLocal: false);
    expect((local['campaigns'] as List).single['password'], 'private');
    (local['campaigns'] as List).single['cost'] = 25;
    events.notifyListeners();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(client.published, hasLength(1));
    expect(
        (client.published.single['data']['campaigns'] as List)
            .single
            .containsKey('password'),
        isFalse);
    (local['campaigns'] as List).single['cost'] = 30;
    events.notifyListeners();
    client.revision++;
    client.stream.add({
      'kind': 'revision',
      'data': {'revision': client.revision}
    });
    await tester.pump();
    expect(sync.conflict, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(client.published, hasLength(1));
    await sync.pull();
    expect(sync.conflict, isFalse);
    expect((local['campaigns'] as List).single['cost'], 25);
    sync.dispose();
    events.dispose();
    await client.stream.close();
  });
  testWidgets(
      'beneficiary app shows only API projection and clears it on revocation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = TestPortalClient()..role = 'beneficiary';
    await tester.pumpWidget(MaterialApp(
        home: BeneficiaryPortalScreen(clientFactory: (_) => client)));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'member@example.test');
    await tester.enterText(fields.at(1), 'unused');
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();
    expect(find.text('حملة خاصة بي'), findsOneWidget);
    expect(find.text('تصدير CSV'), findsNothing);
    expect(find.text('شامي'), findsNothing);
    client.stream.add({'kind': 'revoked'});
    await tester.pumpAndSettle();
    expect(find.text('حملة خاصة بي'), findsNothing);
    expect(find.text('تم سحب صلاحية الوصول'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await client.stream.close();
  });
}
