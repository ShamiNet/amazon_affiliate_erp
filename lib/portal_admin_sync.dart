import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'portal_client.dart';

/// One revision-checked writer; remote data never silently overwrites pending edits.
class PortalAdminSync extends ChangeNotifier {
  PortalAdminSync(
      {required this.snapshot,
      required this.applySnapshot,
      required this.changes,
      this.storage = const FlutterSecureStorage(),
      this.clientFactory});
  final PortalClient Function(PortalConfig)? clientFactory;
  PortalClient _makeClient(PortalConfig config) =>
      clientFactory?.call(config) ??
      PortalClient(config, storage: storage, sessionNamespace: 'admin');
  final Map<String, dynamic> Function() snapshot;
  final Future<void> Function(Map<String, dynamic>) applySnapshot;
  final Listenable changes;
  final FlutterSecureStorage storage;
  PortalClient? client;
  StreamSubscription<Map<String, dynamic>>? _events;
  Timer? _debounce;
  int revision = 0;
  String status = 'المزامنة غير مفعّلة', _baseline = '';
  bool connected = false,
      conflict = false,
      _applying = false,
      _pushing = false,
      _dirty = false,
      _disposed = false;
  int _remoteSeen = 0;
  String fingerprint(Map<String, dynamic> value) => sha256
      .convert(utf8.encode(jsonEncode(portalSafeSnapshot(value))))
      .toString();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
    final encoded = await storage.read(key: 'erp-portal-admin-config');
    if (encoded == null) return;
    try {
      client = _makeClient(
          PortalConfig.fromJson(jsonDecode(encoded) as Map<String, dynamic>));
      if (!await client!.restore()) return;
      await _requireAdmin();
      final journal = jsonDecode(
          await storage.read(key: 'erp-portal-admin-journal') ?? '{}') as Map;
      revision = journal['revision'] ?? 0;
      _baseline = journal['baseline'] ?? '';
      final remote = await client!.request('/admin/state');
      final localHash = fingerprint(snapshot());
      if (localHash == _baseline) {
        await _apply(remote);
      } else if (remote['revision'] == revision) {
        _dirty = true;
        await _push();
      } else {
        conflict = true;
        status = 'توجد تغييرات محلية وسحابية؛ اختر النسخة التي تريد اعتمادها.';
      }
      _listen();
    } catch (e) {
      status = '$e';
      _notify();
    }
  }

  Future<void> _requireAdmin() async {
    final access = await client!.request('/access');
    if (access['role'] != 'admin') throw const PortalError('ADMIN_REQUIRED');
  }

  Future<int> signIn(PortalConfig config, String email, String password) async {
    await disconnect(clearSession: false);
    client = _makeClient(config);
    await client!.signIn(email, password);
    await _requireAdmin();
    return (await client!.request('/admin/state'))['revision'] as int;
  }

  Future<void> start({required bool useLocal}) async {
    final remote = await client!.request('/admin/state');
    revision = remote['revision'] as int;
    conflict = false;
    if (useLocal) {
      _dirty = true;
      await _push();
    } else {
      await _apply(remote);
    }
    await storage.write(
        key: 'erp-portal-admin-config',
        value: jsonEncode(client!.config.toJson()));
    _listen();
  }

  void _listen() {
    connected = true;
    changes.removeListener(_localChanged);
    changes.addListener(_localChanged);
    _events?.cancel();
    _events = client!.events().listen((event) async {
      switch (event['kind']) {
        case 'connected':
          status = conflict ? 'تعارض يحتاج مراجعة' : 'متصل • تحديث مباشر';
          if (_dirty && !conflict) unawaited(_push());
          break;
        case 'disconnected':
          status = 'انقطع الاتصال • التغييرات محفوظة محليًا';
          break;
        case 'revoked':
          connected = false;
          status = 'انتهت صلاحية الاتصال السحابي';
          changes.removeListener(_localChanged);
          break;
        case 'revision':
          final remote = (event['data'] as Map)['revision'] as int;
          if (remote > revision) {
            if (remote > _remoteSeen) _remoteSeen = remote;
            if (!_pushing) {
              if (_dirty) {
                conflict = true;
                status = 'تعارض بين تعديلات محلية وسحابية؛ راجع النسختين.';
              } else {
                await pull();
              }
            }
          }
      }
      _notify();
    });
    _notify();
  }

  void _localChanged() {
    if (_applying || !connected) return;
    if (fingerprint(snapshot()) == _baseline) return;
    _dirty = true;
    status = 'جارٍ رفع التغييرات…';
    _notify();
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 600), () => unawaited(_push()));
  }

  Future<void> _journal() async {
    await storage.write(
        key: 'erp-portal-admin-journal',
        value: jsonEncode({'revision': revision, 'baseline': _baseline}));
  }

  Future<void> _push() async {
    if (_pushing || conflict || client == null || _disposed) return;
    _pushing = true;
    final data = portalSafeSnapshot(snapshot()), sent = fingerprint(snapshot());
    try {
      final result = await client!.request('/admin/publish',
          method: 'POST', body: {'data': data, 'expectedRevision': revision});
      revision = result['revision'] as int;
      _baseline = sent;
      _dirty = fingerprint(snapshot()) != sent;
      await _journal();
      status = 'تمت مزامنة البيانات • الإصدار $revision';
      if (_remoteSeen > revision) {
        if (_dirty) {
          conflict = true;
          status = 'وصلت تعديلات سحابية أثناء الرفع؛ راجع النسختين.';
        }
      }
    } catch (e) {
      if (e is PortalError && e.code == 'REVISION_CONFLICT') conflict = true;
      status = '$e';
      if (!conflict && connected && !_disposed) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 5), () => unawaited(_push()));
      }
    } finally {
      _pushing = false;
      _notify();
    }
    if (_dirty && !conflict && status.startsWith('تمت'))
      _debounce =
          Timer(const Duration(milliseconds: 600), () => unawaited(_push()));
    else if (_remoteSeen > revision && !_dirty && !conflict) await pull();
  }

  Future<void> _apply(Map<String, dynamic> remote) async {
    _applying = true;
    try {
      final merged = mergePortalSnapshot(
          snapshot(), Map<String, dynamic>.from(remote['data'] as Map));
      await applySnapshot(merged);
      revision = remote['revision'] as int;
      _baseline = fingerprint(snapshot());
      _dirty = false;
      conflict = false;
      await _journal();
      status = 'متصل • تمت مزامنة الإصدار $revision';
    } finally {
      _applying = false;
      _notify();
    }
  }

  Future<void> pull() async {
    if (client == null || _pushing) return;
    try {
      await _apply(await client!.request('/admin/state'));
    } catch (e) {
      status = '$e';
      _notify();
    }
  }

  Future<void> publishLocal() async {
    if (client == null || _pushing) return;
    final remote = await client!.request('/admin/state');
    revision = remote['revision'] as int;
    conflict = false;
    _dirty = true;
    await _push();
  }

  Future<void> disconnect({bool clearSession = true}) async {
    _debounce?.cancel();
    await _events?.cancel();
    _events = null;
    changes.removeListener(_localChanged);
    connected = false;
    conflict = false;
    _dirty = false;
    _baseline = '';
    revision = 0;
    _remoteSeen = 0;
    if (clearSession) {
      await client?.signOut();
      await storage.delete(key: 'erp-portal-admin-config');
    } else {
      client?.dispose();
    }
    client = null;
    status = 'المزامنة غير مفعّلة';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _events?.cancel();
    changes.removeListener(_localChanged);
    client?.dispose();
    super.dispose();
  }
}
