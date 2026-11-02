import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'portal_client.dart';
import 'portal_admin_sync.dart';
import 'portal_users.dart';

const portalLabels = <String, String>{
  'capital': 'رأس المال',
  'spend': 'المصروف',
  'earnings': 'الأرباح',
  'netProfit': 'صافي الأرباح',
  'remainingCapital': 'المتبقي من رأس المال',
  'roi': 'العائد',
  'totalEarnings': 'إجمالي الأرباح',
  'conversionRate': 'نسبة التحويل',
  'seq': 'التسلسل',
  'id': 'المعرف',
  'date': 'التاريخ',
  'beneficiary': 'المستفيد',
  'accountCode': 'رمز الحساب',
  'code': 'رمز الحساب',
  'name': 'الاسم',
  'product': 'المنتج',
  'profile': 'البروفايل',
  'email': 'الإيميل',
  'baseCapital': 'رأس المال',
  'cost': 'التكلفة',
  'clicks': 'النقرات',
  'orderedItems': 'الطلبات',
  'orderedRevenue': 'قيمة الطلبات',
  'shippedItems': 'المشحون',
  'returnedItems': 'المرتجع',
  'totalRevenue': 'المبيعات',
  'commission': 'العمولة',
  'bonus': 'المكافآت',
  'isPending': 'قيد التشغيل',
  'storeId': 'Store ID',
  'country': 'الدولة',
  'status': 'الحالة',
  'product1': 'المنتج الأول',
  'product2': 'المنتج الثاني',
  'promoStatus1': 'حالة الترويج الأول',
  'promoStatus2': 'حالة الترويج الثاني',
  'host': 'الخادم',
  'port': 'المنفذ',
  'isUsed': 'مستخدم',
  'protocol': 'البروتوكول',
  'portType': 'نوع المنفذ',
  'profile1': 'البروفايل الأول',
  'profile2': 'البروفايل الثاني',
  'profile3': 'البروفايل الثالث',
  'platform': 'المنصة',
  'bankName': 'البنك',
  'beneficiaryName': 'صاحب الحساب',
  'amazonEmail': 'إيميل أمازون',
  'amazonAccountName': 'حساب أمازون',
  'category': 'الفئة',
  'windowName': 'الفترة',
  'syriaTime': 'توقيت سوريا',
  'usTime': 'توقيت أمريكا',
  'stepNumber': 'الخطوة',
  'title': 'العنوان',
  'details': 'التفاصيل',
  'stage': 'المرحلة',
  'isCompleted': 'مكتملة',
  'phone': 'الهاتف',
  'gologin': 'جو لوجن',
  'accountName': 'اسم الحساب',
  'linkType': 'نوع الرابط',
  'url': 'الرابط'
};

class PortalConfigFields extends StatelessWidget {
  const PortalConfigFields({super.key, required this.controllers});
  final List<TextEditingController> controllers;
  @override
  Widget build(BuildContext context) =>
      ExpansionTile(title: const Text('إعداد اتصال Firebase'), children: [
        for (var i = 0; i < 4; i++)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                  controller: controllers[i],
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: [
                        'Project ID',
                        'Firebase Web API Key',
                        'API URL',
                        'رابط بوابة الويب'
                      ][i]))),
      ]);
}

List<TextEditingController> _configControllers(PortalConfig config) => [
      config.projectId,
      config.apiKey,
      config.apiBase,
      config.webUrl
    ].map((s) => TextEditingController(text: s)).toList();
PortalConfig _configFrom(List<TextEditingController> c) => PortalConfig(
    projectId: c[0].text.trim(),
    apiKey: c[1].text.trim(),
    apiBase: c[2].text.trim(),
    webUrl: c[3].text.trim());

class PortalAdminDialog extends StatefulWidget {
  const PortalAdminDialog({super.key, required this.sync});
  final PortalAdminSync sync;
  @override
  State<PortalAdminDialog> createState() => _PortalAdminDialogState();
}

class _PortalAdminDialogState extends State<PortalAdminDialog> {
  late final _config =
      _configControllers(widget.sync.client?.config ?? const PortalConfig());
  final _email = TextEditingController(), _password = TextEditingController();
  bool _busy = false;
  String _error = '';
  @override
  void dispose() {
    for (final c in [..._config, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final revision = await widget.sync
          .signIn(_configFrom(_config), _email.text, _password.text);
      _password.clear();
      if (!mounted) return;
      bool? useLocal = true;
      if (revision > 0)
        useLocal = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text('توجد نسخة سحابية'),
                    content: const Text(
                        'اختر النسخة المعتمدة لبدء المزامنة. رفع المحلية يستبدل بيانات السحابة، وجلب السحابية يستبدل بيانات المدير المحلية مع الحفاظ على كلمات المرور المحلية المطابقة.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إلغاء')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('اعتماد النسخة السحابية')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('رفع بيانات المدير المحلية'))
                    ]));
      if (useLocal != null) await widget.sync.start(useLocal: useLocal);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve(bool local) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('اعتماد نسخة البيانات'),
                content: Text(local
                    ? 'سيتم استبدال النسخة السحابية بالبيانات المحلية الحالية.'
                    : 'سيتم استبدال البيانات المحلية بالنسخة السحابية الحالية. لن تُدمج التعديلات المتعارضة تلقائيًا.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('اعتماد'))
                ]));
    if (yes == true) {
      setState(() => _busy = true);
      try {
        if (local) {
          await widget.sync.publishLocal();
        } else {
          await widget.sync.pull();
        }
      } catch (e) {
        if (mounted) setState(() => _error = '$e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
          title: const Text('المستخدمون والمزامنة المباشرة'),
          content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                  child: AnimatedBuilder(
                      animation: widget.sync,
                      builder: (context, _) => Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(widget.sync.status,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                if (widget.sync.connected) ...[
                                  const Text(
                                      'تُرسل التغييرات المحفوظة إلى Firebase تلقائيًا. يرى كل مستفيد بياناته وفق صلاحياته فقط؛ لا تُرفع كلمات المرور أو مفاتيح الوصول.'),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => showDialog<void>(
                                              context: context,
                                              builder: (_) => PortalUsersDialog(
                                                  client: widget.sync.client!,
                                                  labels: portalLabels)),
                                      icon: const Icon(
                                          Icons.supervised_user_circle),
                                      label: const Text(
                                          'إدارة المستخدمين والصلاحيات داخل التطبيق')),
                                  FilledButton.icon(
                                      onPressed: () async {
                                        final url =
                                            widget.sync.client!.config.webUrl;
                                        final uri = Uri.tryParse(url);
                                        if (uri == null ||
                                            uri.scheme != 'https') {
                                          setState(() => _error =
                                              'أدخل رابط بوابة الويب الصحيح.');
                                          return;
                                        }
                                        await Process.start('rundll32.exe', [
                                          'url.dll,FileProtocolHandler',
                                          uri.toString()
                                        ]);
                                      },
                                      icon: const Icon(Icons.manage_accounts),
                                      label: const Text(
                                          'فتح إدارة المستخدمين والصلاحيات في المتصفح')),
                                  TextButton.icon(
                                      onPressed: () => Clipboard.setData(
                                          ClipboardData(
                                              text: widget
                                                  .sync.client!.config.webUrl)),
                                      icon: const Icon(Icons.copy),
                                      label: const Text(
                                          'نسخ رابط بوابة المستفيدين')),
                                  if (widget.sync.conflict)
                                    Wrap(spacing: 8, children: [
                                      OutlinedButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _resolve(false),
                                          child: const Text('اعتماد السحابية')),
                                      OutlinedButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _resolve(true),
                                          child: const Text('اعتماد المحلية'))
                                    ]),
                                  TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () async {
                                              await widget.sync.disconnect();
                                              if (mounted) setState(() {});
                                            },
                                      child: const Text(
                                          'إيقاف المزامنة وتسجيل الخروج')),
                                ] else ...[
                                  PortalConfigFields(controllers: _config),
                                  const SizedBox(height: 10),
                                  TextField(
                                      controller: _email,
                                      decoration: const InputDecoration(
                                          labelText: 'بريد مدير Firebase',
                                          border: OutlineInputBorder()),
                                      textDirection: TextDirection.ltr),
                                  const SizedBox(height: 10),
                                  TextField(
                                      controller: _password,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                          labelText: 'كلمة المرور',
                                          border: OutlineInputBorder())),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                      onPressed: _busy ? null : _connect,
                                      child: Text(_busy
                                          ? 'جارٍ الاتصال…'
                                          : 'ربط ومزامنة بيانات المدير')),
                                ],
                                if (_error.isNotEmpty)
                                  Text(_error,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error)),
                              ])))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'))
          ]));
}

/// Independent entry point: never imports the manager database or factory seed.
class BeneficiaryPortalApp extends StatelessWidget {
  const BeneficiaryPortalApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'بوابة المستفيدين',
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B6047)),
          fontFamily: 'Segoe UI',
          useMaterial3: true),
      home: const BeneficiaryPortalScreen());
}

class BeneficiaryPortalScreen extends StatefulWidget {
  const BeneficiaryPortalScreen({super.key, this.clientFactory});
  final PortalClient Function(PortalConfig)? clientFactory;
  @override
  State<BeneficiaryPortalScreen> createState() =>
      _BeneficiaryPortalScreenState();
}

class _BeneficiaryPortalScreenState extends State<BeneficiaryPortalScreen> {
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _search = TextEditingController();
  final _config = _configControllers(const PortalConfig());
  PortalClient? _client;
  StreamSubscription<Map<String, dynamic>>? _events;
  Map<String, dynamic>? _view;
  String _section = '',
      _status = 'سجّل الدخول للاطلاع على بياناتك',
      _error = '';
  bool _busy = false, _signedIn = false;
  BuildContext? _editingContext;
  @override
  void dispose() {
    _events?.cancel();
    _client?.dispose();
    for (final c in [..._config, _email, _password, _search]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      _client?.dispose();
      _client =
          (widget.clientFactory ?? PortalClient.new)(_configFrom(_config));
      await _client!.signIn(_email.text, _password.text);
      _password.clear();
      final access = await _client!.request('/access');
      if (access['role'] != 'beneficiary')
        throw const PortalError('BENEFICIARY_REQUIRED');
      final view = await _client!.request('/view');
      if (!mounted) return;
      setState(() {
        _view = view;
        _signedIn = true;
      });
      _events = _client!.events().listen((event) {
        if (!mounted) return;
        setState(() {
          switch (event['kind']) {
            case 'connected':
              _status = 'متصل • تحديث مباشر';
              break;
            case 'disconnected':
              _status = 'انقطع الاتصال • البيانات قديمة حتى إعادة الاتصال';
              break;
            case 'clear':
              if (_editingContext?.mounted == true)
                Navigator.pop(_editingContext!);
              _editingContext = null;
              _view = null;
              _status = 'تحديث الصلاحيات…';
              break;
            case 'view':
              _view = Map<String, dynamic>.from(event['data'] as Map);
              _error = '';
              break;
            case 'revoked':
              if (_editingContext?.mounted == true)
                Navigator.pop(_editingContext!);
              _editingContext = null;
              _signedIn = false;
              _view = null;
              _status = 'تم سحب صلاحية الوصول';
              _error = 'تواصل مع المدير لإعادة تفعيل الحساب.';
              unawaited(_client!.signOut());
              break;
          }
        });
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await _events?.cancel();
    await _client?.signOut();
    if (mounted)
      setState(() {
        _signedIn = false;
        _view = null;
        _error = '';
        _status = 'سجّل الدخول للاطلاع على بياناتك';
      });
  }

  Future<void> _edit(Map row, Map section) async {
    final values = Map<String, dynamic>.from(row['values'] as Map),
        fields = List<String>.from(section['editableFields'] as List);
    final controllers = {
      for (final f in fields)
        f: TextEditingController(text: '${values[f] ?? ''}')
    };
    final booleans = {
      for (final f in fields)
        if (values[f] is bool) f: values[f] as bool
    };
    final revision = _view!['revision'];
    String error = '';
    bool saving = false;
    await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, update) {
              _editingContext = ctx;
              return AlertDialog(
                  title: const Text('تعديل البيانات المسموح بها'),
                  content: SizedBox(
                      width: 450,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        for (final field in fields)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: values[field] is bool
                                  ? CheckboxListTile(
                                      title: Text(portalLabels[field] ?? field),
                                      value: booleans[field],
                                      onChanged: saving
                                          ? null
                                          : (v) => update(() =>
                                              booleans[field] = v ?? false))
                                  : TextField(
                                      controller: controllers[field],
                                      keyboardType: values[field] is num
                                          ? const TextInputType
                                              .numberWithOptions(decimal: true)
                                          : TextInputType.text,
                                      decoration: InputDecoration(
                                          labelText:
                                              portalLabels[field] ?? field,
                                          border: const OutlineInputBorder()))),
                        if (error.isNotEmpty) Text(error),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        child: const Text('إلغاء')),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                update(() => saving = true);
                                try {
                                  final changes = {
                                    for (final field in fields)
                                      field: values[field] is bool
                                          ? booleans[field]
                                          : values[field] is num
                                              ? num.parse(
                                                  controllers[field]!.text)
                                              : controllers[field]!.text
                                  };
                                  await _client!.request(
                                      '/records/$_section/${row['rowId']}',
                                      method: 'PATCH',
                                      body: {
                                        'expectedRevision': revision,
                                        'changes': changes
                                      });
                                  if (ctx.mounted) Navigator.pop(ctx);
                                } catch (e) {
                                  if (ctx.mounted)
                                    update(() {
                                      error = '$e';
                                      saving = false;
                                    });
                                }
                              },
                        child: const Text('حفظ'))
                  ]);
            }));
    _editingContext = null;
    for (final c in controllers.values) {
      c.dispose();
    }
  }

  Future<void> _export(Map section) async {
    if (_view?['canExport'] != true) return;
    final fields = List<String>.from(section['fields'] as List),
        rows = section['rows'] as List;
    String cell(dynamic value) {
      var s = '${value ?? ''}';
      if (RegExp(r'^[=+@-]').hasMatch(s)) s = "'$s";
      return '"${s.replaceAll('"', '""')}"';
    }

    final csv = [
      [for (final f in fields) portalLabels[f] ?? f],
      for (final r in rows) [for (final f in fields) (r['values'] as Map)[f]]
    ].map((r) => r.map(cell).join(',')).join('\r\n');
    final path = await FilePicker.platform.saveFile(
        fileName: 'my_$_section.csv',
        type: FileType.custom,
        allowedExtensions: ['csv']);
    if (path != null) await File(path).writeAsString('\uFEFF$csv');
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            appBar: AppBar(
                title: Text(view?['displayName'] ?? 'بوابة المستفيدين'),
                actions: [
                  if (view != null)
                    TextButton(
                        onPressed: _logout, child: const Text('تسجيل الخروج'))
                ]),
            body: view == null && _signedIn
                ? Center(child: Text(_status))
                : view == null
                    ? Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(children: [
                                  const Icon(Icons.account_circle_outlined,
                                      size: 54),
                                  const SizedBox(height: 16),
                                  Text(_status),
                                  const SizedBox(height: 20),
                                  PortalConfigFields(controllers: _config),
                                  const SizedBox(height: 10),
                                  TextField(
                                      controller: _email,
                                      textDirection: TextDirection.ltr,
                                      decoration: const InputDecoration(
                                          labelText: 'البريد الإلكتروني',
                                          border: OutlineInputBorder())),
                                  const SizedBox(height: 12),
                                  TextField(
                                      controller: _password,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                          labelText: 'كلمة المرور',
                                          border: OutlineInputBorder()),
                                      onSubmitted: (_) =>
                                          _busy ? null : _login()),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                      onPressed: _busy ? null : _login,
                                      child: Text(_busy
                                          ? 'جارٍ الدخول…'
                                          : 'تسجيل الدخول')),
                                  if (_error.isNotEmpty)
                                    Text(_error,
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error)),
                                ]))))
                    : _content(view)));
  }

  Widget _content(Map<String, dynamic> view) {
    final sections = Map<String, dynamic>.from(view['sections'] as Map);
    if (!sections.containsKey(_section))
      _section = sections.keys.firstOrNull ?? '';
    final section = sections[_section] as Map?;
    final fields = List<String>.from(section?['fields'] as List? ?? []),
        editable = List<String>.from(section?['editableFields'] as List? ?? []);
    final query = _search.text.trim().toLowerCase();
    final rows = (section?['rows'] as List? ?? [])
        .where((r) => (r['values'] as Map)
            .values
            .any((v) => '$v'.toLowerCase().contains(query)))
        .toList();
    return Padding(
        padding: const EdgeInsets.all(20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_status),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final entry in (view['metrics'] as Map).entries)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(children: [
                        Text(portalLabels[entry.key] ?? entry.key),
                        const SizedBox(height: 10),
                        Text(
                            entry.key == 'roi'
                                ? '${((entry.value as num) * 100).toStringAsFixed(1)}%'
                                : '\$${(entry.value as num).toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold))
                      ]))),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 8, children: [
            for (final entry in sections.entries)
              ChoiceChip(
                  label: Text((entry.value as Map)['label']),
                  selected: entry.key == _section,
                  onSelected: (_) => setState(() => _section = entry.key))
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        labelText: 'بحث في بياناتك',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder()))),
            if (view['canExport'] == true && section != null)
              TextButton(
                  onPressed: () => _export(section),
                  child: const Text('تصدير CSV'))
          ]),
          const SizedBox(height: 12),
          Expanded(
              child: fields.isEmpty
                  ? const Center(child: Text('لا توجد أقسام مسموحة حاليًا.'))
                  : SingleChildScrollView(
                      child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(columns: [
                            for (final field in fields)
                              DataColumn(
                                  label: Text(portalLabels[field] ?? field)),
                            if (editable.isNotEmpty)
                              const DataColumn(label: Text('تعديل'))
                          ], rows: [
                            for (final row in rows)
                              DataRow(cells: [
                                for (final field in fields)
                                  DataCell(
                                      Text('${(row['values'] as Map)[field]}')),
                                if (editable.isNotEmpty)
                                  DataCell(IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () =>
                                          _edit(Map.from(row), section!)))
                              ])
                          ])))),
        ]));
  }
}
