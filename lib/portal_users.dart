import 'package:flutter/material.dart';
import 'portal_client.dart';

const _locked = {
  'totalEarnings',
  'netProfit',
  'roi',
  'conversionRate',
  'id',
  'seq',
  'beneficiary',
  'accountCode',
  'code',
  'email',
  'profile',
  'profile1',
  'profile2',
  'profile3',
  'storeId',
  'amazonEmail',
  'amazonAccountName',
  'name',
  'beneficiaryName',
  'host',
  'port',
  'stepNumber',
  'category',
  'platform',
  'windowName',
  'accountName',
  'product',
  'linkType',
  'url'
};

class PortalUsersDialog extends StatefulWidget {
  const PortalUsersDialog(
      {super.key, required this.client, this.labels = const {}});
  final PortalClient client;
  final Map<String, String> labels;
  @override
  State<PortalUsersDialog> createState() => _PortalUsersDialogState();
}

class _PortalUsersDialogState extends State<PortalUsersDialog> {
  Map<String, dynamic>? catalog;
  List<dynamic> users = [];
  String error = '';
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final result = await Future.wait([
        widget.client.request('/admin/catalog'),
        widget.client.request('/admin/users')
      ]);
      if (!mounted) return;
      setState(() {
        catalog = result[0];
        users = result[1]['users'] as List;
        error = '';
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? member]) async {
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) => _MemberEditor(
            client: widget.client,
            catalog: catalog!,
            member: member,
            labels: widget.labels));
    if (saved == true && mounted) await _load();
  }

  Future<void> _password(Map<String, dynamic> member) async {
    await showDialog<void>(
        context: context,
        builder: (_) => _PasswordEditor(client: widget.client, member: member));
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
          title: const Text('إدارة المستخدمين والصلاحيات'),
          content: SizedBox(
              width: 900,
              height: 600,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(spacing: 12, children: [
                      FilledButton.icon(
                          onPressed:
                              loading || catalog == null ? null : () => _edit(),
                          icon: const Icon(Icons.person_add),
                          label: const Text('إضافة مستخدم')),
                      OutlinedButton.icon(
                          onPressed: loading ? null : _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('تحديث القائمة'))
                    ]),
                    if (error.isNotEmpty)
                      Text(error,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    if (loading) const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    Expanded(
                        child: ListView(children: [
                      if (catalog != null &&
                          (catalog!['beneficiaries'] as List).isEmpty)
                        const Text('ارفع بيانات المستفيدين من المزامنة أولًا.'),
                      for (final value in users)
                        Builder(builder: (context) {
                          final m = Map<String, dynamic>.from(value as Map);
                          final admin = m['role'] == 'admin';
                          return Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${m['displayName'] ?? m['email']}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Text('${m['email'] ?? ''}'),
                                        Text(admin
                                            ? 'مدير النظام'
                                            : '${_beneficiaryName(m['beneficiaryId'])} • ${m['enabled'] == true ? 'نشط' : 'الوصول مسحوب'}'),
                                        if (!admin)
                                          Wrap(spacing: 8, children: [
                                            TextButton.icon(
                                                onPressed: loading
                                                    ? null
                                                    : () => _edit(m),
                                                icon: const Icon(
                                                    Icons.admin_panel_settings),
                                                label: const Text(
                                                    'تعديل الصلاحيات')),
                                            TextButton.icon(
                                                onPressed: loading
                                                    ? null
                                                    : () => _password(m),
                                                icon:
                                                    const Icon(Icons.password),
                                                label: const Text(
                                                    'تغيير كلمة المرور'))
                                          ])
                                      ])));
                        })
                    ]))
                  ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'))
          ]));
  String _beneficiaryName(dynamic id) {
    for (final b in catalog?['beneficiaries'] ?? []) {
      if ('${b['id']}' == '$id') return '${b['name']}';
    }
    return 'المستفيد غير موجود';
  }
}

class _MemberEditor extends StatefulWidget {
  const _MemberEditor(
      {required this.client,
      required this.catalog,
      required this.member,
      required this.labels});
  final PortalClient client;
  final Map<String, dynamic> catalog;
  final Map<String, dynamic>? member;
  final Map<String, String> labels;
  @override
  State<_MemberEditor> createState() => _MemberEditorState();
}

class _MemberEditorState extends State<_MemberEditor> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      uid = TextEditingController();
  final metrics = <String>{};
  final visible = <String, Set<String>>{}, editable = <String, Set<String>>{};
  String? beneficiary;
  bool enabled = true, export = false, busy = false;
  String error = '';
  @override
  void initState() {
    super.initState();
    final m = widget.member;
    name.text = m?['displayName'] ?? '';
    email.text = m?['email'] ?? '';
    beneficiary = m?['beneficiaryId']?.toString();
    enabled = m?['enabled'] ?? true;
    final p =
        (m?['permissions'] ?? widget.catalog['defaultPermissions']) as Map;
    metrics.addAll((p['metrics'] as List? ?? []).cast<String>());
    export = p['export'] == true;
    for (final entry in ((p['sections'] ?? {}) as Map).entries) {
      final section = entry.value as Map;
      visible['${entry.key}'] =
          (section['fields'] as List? ?? []).cast<String>().toSet();
      editable['${entry.key}'] =
          (section['editableFields'] as List? ?? []).cast<String>().toSet();
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    uid.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final body = <String, dynamic>{
        'displayName': name.text.trim(),
        'beneficiaryId': beneficiary,
        'enabled': enabled,
        'permissions': {
          'metrics': metrics.toList(),
          'export': export,
          'sections': {
            for (final t in visible.keys)
              t: {
                'fields': visible[t]!.toList(),
                'editableFields':
                    (editable[t] ?? {}).where(visible[t]!.contains).toList()
              }
          }
        }
      };
      if (widget.member != null) {
        await widget.client.request(
            '/admin/users/${Uri.encodeComponent(widget.member!['uid'])}',
            method: 'PATCH',
            body: body);
      } else {
        body.addAll(uid.text.trim().isNotEmpty
            ? {'uid': uid.text.trim()}
            : {'email': email.text.trim(), 'password': password.text});
        await widget.client.request('/admin/users', method: 'POST', body: body);
      }
      password.clear();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
          title: Text(widget.member == null
              ? 'إضافة مستخدم'
              : 'تعديل المستخدم والصلاحيات'),
          content: SizedBox(
              width: 760,
              height: 620,
              child: AbsorbPointer(
                  absorbing: busy,
                  child: Form(
                      key: form,
                      child: SingleChildScrollView(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            TextFormField(
                                controller: name,
                                decoration: const InputDecoration(
                                    labelText: 'الاسم الظاهر'),
                                validator: (v) =>
                                    v!.trim().isEmpty ? 'أدخل الاسم' : null),
                            TextFormField(
                                controller: email,
                                enabled: widget.member == null,
                                textDirection: TextDirection.ltr,
                                decoration: const InputDecoration(
                                    labelText: 'البريد الإلكتروني'),
                                validator: (v) => widget.member == null &&
                                        uid.text.trim().isEmpty &&
                                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                            .hasMatch(v!.trim())
                                    ? 'أدخل بريدًا صحيحًا'
                                    : null),
                            if (widget.member == null) ...[
                              TextFormField(
                                  controller: uid,
                                  textDirection: TextDirection.ltr,
                                  decoration: const InputDecoration(
                                      labelText:
                                          'Firebase UID لحساب موجود (اختياري)'),
                                  onChanged: (_) => setState(() {})),
                              if (uid.text.trim().isEmpty)
                                TextFormField(
                                    controller: password,
                                    obscureText: true,
                                    enableSuggestions: false,
                                    autocorrect: false,
                                    decoration: const InputDecoration(
                                        labelText:
                                            'كلمة المرور الأولية (12 حرفًا على الأقل)'),
                                    validator: (v) =>
                                        v!.length < 12 || v.length > 128
                                            ? 'استخدم 12 إلى 128 حرفًا'
                                            : null),
                            ],
                            DropdownButtonFormField<String>(
                                initialValue: beneficiary,
                                decoration: const InputDecoration(
                                    labelText: 'المستفيد المرتبط'),
                                items: [
                                  for (final b
                                      in widget.catalog['beneficiaries'])
                                    DropdownMenuItem(
                                        value: '${b['id']}',
                                        child: Text('${b['name']}'))
                                ],
                                onChanged: (v) =>
                                    setState(() => beneficiary = v),
                                validator: (v) =>
                                    v == null ? 'اختر المستفيد' : null),
                            CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('السماح بالدخول'),
                                value: enabled,
                                onChanged: (v) => setState(() => enabled = v!)),
                            const Text('المؤشرات المالية',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            for (final entry
                                in (widget.catalog['metrics'] as Map).entries)
                              CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${entry.value}'),
                                  value: metrics.contains(entry.key),
                                  onChanged: (v) => setState(() {
                                        v!
                                            ? metrics.add('${entry.key}')
                                            : metrics.remove(entry.key);
                                      })),
                            const Text('الأقسام والحقول المسموح عرضها وتعديلها',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            for (final entry
                                in (widget.catalog['tables'] as Map).entries)
                              ExpansionTile(
                                  title: Text('${entry.value['label']}'),
                                  children: [
                                    for (final dynamic field
                                        in entry.value['keys'])
                                      Row(children: [
                                        Expanded(
                                            child: Text(widget.labels[field] ??
                                                '$field')),
                                        const Text('عرض'),
                                        Checkbox(
                                            value: visible[entry.key]
                                                    ?.contains(field) ??
                                                false,
                                            onChanged: (v) => setState(() {
                                                  final s = visible.putIfAbsent(
                                                      '${entry.key}', () => {});
                                                  if (v!) {
                                                    s.add('$field');
                                                  } else {
                                                    s.remove(field);
                                                    editable[entry.key]
                                                        ?.remove(field);
                                                  }
                                                })),
                                        const Text('تعديل'),
                                        Checkbox(
                                            value: editable[entry.key]
                                                    ?.contains(field) ??
                                                false,
                                            onChanged: _locked
                                                        .contains(field) ||
                                                    !(visible[entry.key]
                                                            ?.contains(field) ??
                                                        false)
                                                ? null
                                                : (v) => setState(() {
                                                      final s =
                                                          editable.putIfAbsent(
                                                              '${entry.key}',
                                                              () => {});
                                                      v!
                                                          ? s.add('$field')
                                                          : s.remove(field);
                                                    }))
                                      ])
                                  ]),
                            CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title:
                                    const Text('السماح بتصدير بياناته إلى CSV'),
                                value: export,
                                onChanged: (v) => setState(() => export = v!)),
                            if (error.isNotEmpty)
                              Text(error,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                          ]))))),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: busy ? null : _save,
                child: Text(busy ? 'جارٍ الحفظ…' : 'حفظ المستخدم والصلاحيات'))
          ]));
}

class _PasswordEditor extends StatefulWidget {
  const _PasswordEditor({required this.client, required this.member});
  final PortalClient client;
  final Map<String, dynamic> member;
  @override
  State<_PasswordEditor> createState() => _PasswordEditorState();
}

class _PasswordEditorState extends State<_PasswordEditor> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController(), confirm = TextEditingController();
  bool busy = false;
  String error = '';
  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.client.request(
          '/admin/users/${Uri.encodeComponent(widget.member['uid'])}/password',
          method: 'POST',
          body: {'password': password.text});
      password.clear();
      confirm.clear();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('تم تغيير كلمة المرور وإلغاء جلسات الدخول السابقة.')));
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
          title: const Text('تغيير كلمة المرور'),
          content: SizedBox(
              width: 480,
              child: Form(
                  key: form,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            '${widget.member['displayName']} • ${widget.member['email']}'),
                        const Text(
                            'ستُلغى الجلسات السابقة. قد يستخدم هذا الحساب كلمة المرور نفسها في تطبيقات أخرى ضمن مشروع Firebase.'),
                        TextFormField(
                            controller: password,
                            enabled: !busy,
                            obscureText: true,
                            enableSuggestions: false,
                            autocorrect: false,
                            decoration: const InputDecoration(
                                labelText: 'كلمة المرور الجديدة'),
                            validator: (v) => v!.length < 12 || v.length > 128
                                ? 'استخدم 12 إلى 128 حرفًا'
                                : null),
                        TextFormField(
                            controller: confirm,
                            enabled: !busy,
                            obscureText: true,
                            enableSuggestions: false,
                            autocorrect: false,
                            decoration: const InputDecoration(
                                labelText: 'تأكيد كلمة المرور'),
                            validator: (v) => v != password.text
                                ? 'كلمتا المرور غير متطابقتين'
                                : null),
                        if (error.isNotEmpty)
                          Text(error,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))
                      ]))),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: busy ? null : _save,
                child: Text(busy ? 'جارٍ الحفظ…' : 'تغيير كلمة المرور'))
          ]));
}
