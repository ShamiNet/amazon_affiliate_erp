/// Only operational fields explicitly listed here can be shared with Gemini.
const chatSectionTitles = <String, String>{
  'all': 'جميع الأقسام',
  '0': 'التقرير التنفيذي الشامل',
  '1': 'الأرباح والجرد اليومي',
  '2': 'دليل المنتجات والمستفيدين',
  '3': 'حسابات أمازون والأرشيف',
  '4': 'حسابات البريد',
  '5': 'حسابات جو لوجن',
  '6': 'إدارة البروكسي',
  '7': 'الحسابات البنكية',
  '8': 'المنصات وأوقات الترويج',
  '9': 'دليل وخطوات العمل',
  '10': 'استخراج بيانات التقارير',
};

const _fields = <String, List<String>>{
  'beneficiaries': ['id', 'name', 'baseCapital', 'accountCodeRange'],
  'products_catalog': [
    'id',
    'product',
    'beneficiary',
    'accountCode',
    'profile',
    'capital',
    'email'
  ],
  'campaigns': [
    'seq',
    'date',
    'beneficiary',
    'accountCode',
    'product',
    'email',
    'cost',
    'profile',
    'clicks',
    'orderedItems',
    'orderedRevenue',
    'shippedItems',
    'returnedItems',
    'totalRevenue',
    'commission',
    'bonus',
    'isPending'
  ],
  'amazon_accounts': [
    'beneficiary',
    'code',
    'name',
    'storeId',
    'country',
    'status',
    'product1',
    'promoStatus1',
    'product2',
    'promoStatus2',
    'email'
  ],
  'emails': ['email', 'gologin', 'status', 'country'],
  'gologin': [
    'accountType',
    'platform',
    'email',
    'profile1',
    'profile2',
    'profile3',
    'country'
  ],
  'proxies': ['country', 'isUsed', 'portType', 'protocol'],
  'bank_accounts': [
    'beneficiaryName',
    'bankName',
    'postalAndCountry',
    'status',
    'amazonAccountName'
  ],
  'platforms': ['category', 'name'],
  'promo_times': ['windowName', 'syriaTime', 'usTime'],
  'workflow_steps': ['stepNumber', 'title', 'details', 'stage', 'isCompleted'],
};

Map<String, dynamic> buildErpChatContext(
    Map<String, dynamic> data, String scope) {
  final tables = switch (scope) {
    'all' => _fields.keys.toList(),
    '0' => ['beneficiaries', 'products_catalog', 'campaigns'],
    '1' => ['campaigns', 'amazon_accounts', 'products_catalog'],
    '2' => ['beneficiaries', 'products_catalog'],
    '3' => ['amazon_accounts'],
    '4' => ['emails'],
    '5' => ['gologin'],
    '6' => ['proxies'],
    '7' => ['bank_accounts'],
    '8' => ['platforms', 'promo_times'],
    '9' => ['workflow_steps'],
    _ => <String>[],
  };
  return {
    'scope': chatSectionTitles[scope] ?? scope,
    'snapshotAt': DateTime.now().toIso8601String(),
    if (scope == '10')
      'reportStatus':
          'التقرير المؤقت غير مرفق؛ يمكن للمستخدم لصق نصه في المحادثة لتحليله.',
    for (final name in tables)
      name: [
        for (final row in (data[name] as List? ?? []).whereType<Map>())
          {
            for (final key in _fields[name]!)
              if (row.containsKey(key)) key: row[key]
          }
      ],
  };
}
