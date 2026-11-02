import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amazon_affiliate_erp/portal_client.dart';
import 'package:amazon_affiliate_erp/portal_users.dart';

class AdminClient extends PortalClient {
  AdminClient() : super(const PortalConfig());
  final calls = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> request(String path,
      {String method = 'GET', Map<String, dynamic>? body}) async {
    if (method != 'GET') {
      calls.add({'path': path, 'method': method, 'body': body});
      return {'ok': true};
    }
    if (path == '/admin/catalog')
      return {
        'beneficiaries': [
          {'id': 2, 'name': 'أبو مخلص'}
        ],
        'metrics': {'capital': 'رأس المال'},
        'tables': {
          'campaigns': {
            'label': 'الحملات',
            'keys': ['clicks', 'commission', 'beneficiary']
          }
        },
        'defaultPermissions': {
          'metrics': ['capital'],
          'sections': {
            'campaigns': {
              'fields': ['clicks'],
              'editableFields': []
            }
          },
          'export': false
        }
      };
    return {
      'users': [
        {
          'uid': 'member-test',
          'role': 'beneficiary',
          'displayName': 'أبو مخلص',
          'email': 'abu@example.test',
          'enabled': true,
          'beneficiaryId': '2',
          'permissions': {
            'metrics': ['capital'],
            'sections': {
              'campaigns': {
                'fields': ['clicks'],
                'editableFields': []
              }
            },
            'export': false
          }
        }
      ]
    };
  }
}

void main() {
  Future<AdminClient> setup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = AdminClient();
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PortalUsersDialog(client: client))));
    await tester.pumpAndSettle();
    return client;
  }

  testWidgets('manager saves granular permissions in native dialog',
      (tester) async {
    final client = await setup(tester);
    await tester.tap(find.text('تعديل الصلاحيات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('السماح بالدخول'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ المستخدم والصلاحيات'));
    await tester.pumpAndSettle();
    expect(client.calls.single['path'], '/admin/users/member-test');
    expect(client.calls.single['body']['enabled'], false);
    expect(
        client.calls.single['body']['permissions']['sections']['campaigns']
            ['fields'],
        ['clicks']);
  });
  testWidgets('manager creates a linked beneficiary account in app',
      (tester) async {
    final client = await setup(tester);
    await tester.tap(find.text('إضافة مستخدم'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'حساب جديد');
    await tester.enterText(fields.at(1), 'new@example.test');
    await tester.enterText(fields.at(3), 'Initial-password-123!');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أبو مخلص').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ المستخدم والصلاحيات'));
    await tester.pumpAndSettle();
    expect(client.calls.single['path'], '/admin/users');
    expect(client.calls.single['method'], 'POST');
    expect(client.calls.single['body']['beneficiaryId'], '2');
    expect(client.calls.single['body']['email'], 'new@example.test');
  });
  testWidgets(
      'password confirmation blocks mismatches and submits only password',
      (tester) async {
    final client = await setup(tester);
    await tester.tap(find.text('تغيير كلمة المرور'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'New-test-password-123!');
    await tester.enterText(fields.at(1), 'different');
    await tester.tap(find.widgetWithText(FilledButton, 'تغيير كلمة المرور'));
    await tester.pumpAndSettle();
    expect(client.calls, isEmpty);
    expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
    await tester.enterText(fields.at(1), 'New-test-password-123!');
    await tester.tap(find.widgetWithText(FilledButton, 'تغيير كلمة المرور'));
    await tester.pumpAndSettle();
    expect(client.calls.single['path'], '/admin/users/member-test/password');
    expect(client.calls.single['body'], {'password': 'New-test-password-123!'});
  });
}
