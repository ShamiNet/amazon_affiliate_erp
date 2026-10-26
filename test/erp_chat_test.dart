import 'dart:async';
import 'dart:convert';
import 'package:amazon_affiliate_erp/erp_chat_context.dart';
import 'package:amazon_affiliate_erp/erp_chat_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'scopes include operational rows and exclude credentials and account numbers',
      () {
    final data = {
      'campaigns': [
        {'seq': 1, 'cost': 5, 'password': 'secret'}
      ],
      'amazon_accounts': [
        {'code': 'MK-01', 'storeId': 'test-20', 'password': 'secret'}
      ],
      'emails': [
        {
          'email': 'test@example.com',
          'password': 'secret',
          'twoFa': 'secret',
          'notes': 'secret'
        }
      ],
      'bank_accounts': [
        {
          'bankName': 'Example Bank',
          'iban': 'private-iban',
          'verificationDoc': 'private-doc'
        }
      ],
      'proxies': [
        {
          'country': 'US',
          'username': 'private-user',
          'password': 'secret',
          'host': 'private-host'
        }
      ],
    };
    final campaigns = buildErpChatContext(data, '1');
    expect(campaigns['campaigns'], [
      {'seq': 1, 'cost': 5}
    ]);
    expect(campaigns.containsKey('emails'), isFalse);
    final all = jsonEncode(buildErpChatContext(data, 'all'));
    for (final value in [
      'secret',
      'private-iban',
      'private-doc',
      'private-user',
      'private-host'
    ]) {
      expect(all.contains(value), isFalse);
    }
    expect(all, contains('Example Bank'));
    expect(buildErpChatContext(data, '10')['reportStatus'], isNotNull);
  });

  test('conversation carries turns and scope, recovers after failed request',
      () async {
    final session = ErpChatSession();
    await session.send('first', '1', {}, (history, data) async {
      expect(history.single['role'], 'user');
      return 'answer';
    });
    await session.send('follow up', 'all', {'fresh': true},
        (history, data) async {
      expect(history.map((m) => m['role']).toList(), ['user', 'model', 'user']);
      expect(history.last['text'], contains('جميع الأقسام'));
      expect(data['fresh'], isTrue);
      throw const FormatException('try again');
    });
    expect(session.messages.length, 2);
    expect(session.error, 'try again');
    final failed = session.failedMessage!;
    await session.send(
        failed.text, failed.scope, {}, (_, __) async => 'success');
    expect(session.messages.length, 4);
    expect(session.error, isNull);
    expect(session.busy, isFalse);
    session.clear();
    expect(session.messages, isEmpty);
    session.dispose();
  });

  testWidgets(
      'chat sends only on request, retains messages on reopen, switches scopes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = ErpChatSession();
    var calls = 0;
    var scope = '';
    final pending = Completer<String>();
    Widget app() => MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  child: const Text('open'),
                  onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => ErpChatDialog(
                            session: session,
                            initialScope: '1',
                            contextProvider: (s) {
                              scope = s;
                              return {'scope': s};
                            },
                            respond: (_, __) {
                              calls++;
                              return pending.future;
                            },
                          )),
                ))));
    await tester.pumpWidget(app());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>));
    dropdown.onChanged!('all');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Compare results');
    await tester.tap(find.text('إرسال'));
    await tester.pump();
    expect(calls, 1);
    expect(scope, 'all');
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'إرسال'))
            .onPressed,
        isNull);
    await tester.tap(find.byTooltip('إغلاق'));
    await tester.pumpAndSettle();
    pending.complete('Comparison complete');
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Comparison complete'), findsOneWidget);
    expect(find.text('Compare results'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('محادثة جديدة'));
    await tester.pumpAndSettle();
    expect(session.messages, isEmpty);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
