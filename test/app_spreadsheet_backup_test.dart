import 'package:amazon_affiliate_erp/app_spreadsheet_backup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const schema = {
    'campaigns': [
      {
        'seq': 1,
        'date': '',
        'accountCode': '',
        'clicks': 0,
        'cost': 0.0,
        'isPending': false,
        'password': '',
      },
    ],
    'emails': [
      {'email': '', 'password': '', 'status': ''},
    ],
    'bank_accounts': [
      {
        'amazonEmail': '',
        'bankName': '',
        'beneficiaryName': '',
        'iban': '',
        'bic': '',
        'status': '',
      },
    ],
  };

  test('exports every data sheet while omitting sensitive values', () {
    final bytes = AppSpreadsheetBackup.encode(
      data: {
        'campaigns': [
          {
            'seq': 1,
            'date': '2026-10-18',
            'accountCode': 'SH-01',
            'clicks': 12,
            'cost': 3.5,
            'isPending': true,
            'password': 'campaign-secret',
          },
        ],
        'emails': [
          {
            'email': 'affiliate@example.com',
            'password': 'email-secret',
            'status': 'active',
          },
        ],
        'bank_accounts': [
          {
            'amazonEmail': 'affiliate@example.com',
            'bankName': 'Example Bank',
            'beneficiaryName': 'Example',
            'iban': 'GB00SECRET',
            'bic': 'SECRETXX',
            'status': 'linked',
          },
        ],
      },
      schema: schema,
    );

    final restored = AppSpreadsheetBackup.merge(
      bytes: bytes,
      currentData: {'campaigns': [], 'emails': [], 'bank_accounts': []},
      schema: schema,
    );

    expect(restored.importedRows, 3);
    expect(restored.data['campaigns'], [
      {
        'seq': 1,
        'date': '2026-10-18',
        'accountCode': 'SH-01',
        'clicks': 12,
        'cost': 3.5,
        'isPending': true,
      },
    ]);
    expect(restored.data['emails'], [
      {'email': 'affiliate@example.com', 'status': 'active'},
    ]);
    expect(restored.data['bank_accounts'], [
      {
        'amazonEmail': 'affiliate@example.com',
        'bankName': 'Example Bank',
        'beneficiaryName': 'Example',
        'status': 'linked',
      },
    ]);
  });

  test('merges by identity and preserves excluded local secrets', () {
    final bytes = AppSpreadsheetBackup.encode(
      data: {
        'campaigns': [
          {
            'seq': 1,
            'date': '2026-10-18',
            'accountCode': 'SH-01',
            'clicks': 20,
            'cost': 3.5,
            'isPending': false,
            'password': '',
          },
        ],
        'emails': [],
        'bank_accounts': [
          {
            'amazonEmail': 'affiliate@example.com',
            'bankName': 'Example Bank',
            'beneficiaryName': 'Example',
            'iban': '',
            'bic': '',
            'status': 'updated',
          },
        ],
      },
      schema: schema,
    );

    final result = AppSpreadsheetBackup.merge(
      bytes: bytes,
      currentData: {
        'campaigns': [
          {
            'seq': 1,
            'date': '2026-10-18',
            'accountCode': 'SH-01',
            'clicks': 12,
            'cost': 3.5,
            'isPending': true,
            'password': 'keep-this-local',
          },
        ],
        'emails': [
          {
            'email': 'existing@example.com',
            'password': 'private',
            'status': ''
          },
        ],
        'bank_accounts': [
          {
            'amazonEmail': 'affiliate@example.com',
            'bankName': 'Example Bank',
            'beneficiaryName': 'Example',
            'iban': 'KEEPLOCAL',
            'bic': 'KEEPLOCAL',
            'status': 'old',
          },
        ],
      },
      schema: schema,
    );

    final campaigns = result.data['campaigns']! as List;
    final emails = result.data['emails']! as List;
    expect(result.insertedRows, 0);
    expect(result.updatedRows, 2);
    expect(campaigns, hasLength(1));
    expect(campaigns.single['clicks'], 20);
    expect(campaigns.single['password'], 'keep-this-local');
    expect(emails.single['password'], 'private');
    final banks = result.data['bank_accounts']! as List;
    expect(banks.single['status'], 'updated');
    expect(banks.single['iban'], 'KEEPLOCAL');
    expect(banks.single['bic'], 'KEEPLOCAL');
  });

  test('rejects unrecognized workbooks instead of silently importing nothing',
      () {
    final bytes = AppSpreadsheetBackup.encode(
      data: const {},
      schema: const {
        'campaigns': [
          {'seq': 1, 'date': ''},
        ],
      },
    );

    expect(
      () => AppSpreadsheetBackup.merge(
        bytes: bytes,
        currentData: const {},
        schema: const {
          'amazon_accounts': [
            {'code': ''},
          ],
        },
      ),
      throwsFormatException,
    );
  });
}
