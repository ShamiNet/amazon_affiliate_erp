import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'portal_config.dart';
import 'portal_schema.dart';

class PortalError implements Exception {
  const PortalError(this.code);
  final String code;
  @override
  String toString() => switch (code) {
        'SIGN_IN_REQUIRED' => 'بيانات الدخول غير صحيحة أو انتهت الجلسة.',
        'ACCESS_DENIED' => 'تم سحب الوصول إلى هذا الحساب. تواصل مع المدير.',
        'ADMIN_REQUIRED' => 'يلزم حساب مدير لهذه العملية.',
        'REVISION_CONFLICT' =>
          'تغيرت النسخة السحابية؛ راجع النسختين قبل المتابعة.',
        'CONFIGURATION_REQUIRED' => 'إعدادات مشروع Firebase غير مكتملة.',
        'FIELD_DENIED' => 'ليس لديك صلاحية تعديل هذا الحقل.',
        'BENEFICIARY_NOT_FOUND' => 'لم ينشر المدير بيانات المستفيد بعد.',
        'INVALID_BENEFICIARY' => 'اختر مستفيدًا موجودًا في البيانات المنشورة.',
        'INVALID_PASSWORD' => 'استخدم كلمة مرور من 12 إلى 128 حرفًا.',
        'EMAIL_ALREADY_EXISTS' =>
          'البريد مستخدم مسبقًا. أدخل UID لربط الحساب الموجود.',
        'MEMBER_EXISTS' => 'المستخدم مضاف إلى البوابة مسبقًا.',
        'MEMBER_NOT_FOUND' => 'حساب المستفيد غير موجود أو غير قابل للتعديل.',
        _ => 'تعذر إتمام العملية ($code). تحقق من الشبكة وإعدادات Firebase.',
      };
}

class PortalConfig {
  const PortalConfig(
      {this.apiKey = portalFirebaseApiKey,
      this.projectId = portalProjectId,
      this.apiBase = portalApiBase,
      this.webUrl = portalWebUrl});
  final String apiKey, projectId, apiBase, webUrl;
  bool get valid {
    final uri = Uri.tryParse(apiBase);
    return apiKey.isNotEmpty &&
        projectId.isNotEmpty &&
        uri != null &&
        (uri.scheme == 'https' ||
            uri.scheme == 'http' &&
                ['localhost', '127.0.0.1'].contains(uri.host));
  }

  Map<String, dynamic> toJson() => {
        'apiKey': apiKey,
        'projectId': projectId,
        'apiBase': apiBase,
        'webUrl': webUrl
      };
  factory PortalConfig.fromJson(Map<String, dynamic> json) => PortalConfig(
      apiKey: json['apiKey'] ?? '',
      projectId: json['projectId'] ?? '',
      apiBase: json['apiBase'] ?? '',
      webUrl: json['webUrl'] ?? '');
}

class PortalClient {
  PortalClient(this.config,
      {FlutterSecureStorage? storage, this.sessionNamespace = 'member'})
      : storage = storage ?? const FlutterSecureStorage();
  final PortalConfig config;
  final String sessionNamespace;
  final FlutterSecureStorage storage;
  String? _idToken, _refreshToken;
  DateTime _expiry = DateTime(2000);
  HttpClient? _streamClient;
  bool _disposed = false;
  Future<String>? _refreshing;
  String get _tokenKey =>
      'erp-portal-refresh-$sessionNamespace-${config.projectId}';
  Future<Map<String, dynamic>> _json(Uri url,
      {String method = 'POST',
      Map<String, dynamic>? body,
      String? bearer,
      bool form = false}) async {
    final client = HttpClient();
    try {
      final request = await client
          .openUrl(method, url)
          .timeout(const Duration(seconds: 20));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (bearer != null)
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
      if (body != null) {
        final bytes = utf8.encode(form
            ? Uri(queryParameters: body.map((k, v) => MapEntry(k, '$v'))).query
            : jsonEncode(body));
        request.headers.contentType = form
            ? ContentType('application', 'x-www-form-urlencoded',
                charset: 'utf-8')
            : ContentType.json;
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      final response =
          await request.close().timeout(const Duration(seconds: 45));
      final text = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 45));
      Map<String, dynamic> result;
      try {
        result = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        throw const PortalError('INVALID_RESPONSE');
      }
      if (response.statusCode >= 400) {
        final error = result['error'];
        throw PortalError(error is String ? error : 'SIGN_IN_REQUIRED');
      }
      return result;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> signIn(String email, String password) async {
    if (!config.valid) throw const PortalError('CONFIGURATION_REQUIRED');
    final result = await _json(
        Uri.https('identitytoolkit.googleapis.com',
            '/v1/accounts:signInWithPassword', {'key': config.apiKey}),
        body: {
          'email': email.trim(),
          'password': password,
          'returnSecureToken': true
        });
    _idToken = result['idToken'];
    _refreshToken = result['refreshToken'];
    _expiry =
        DateTime.now().add(Duration(seconds: int.parse(result['expiresIn'])));
    await storage.write(key: _tokenKey, value: _refreshToken);
  }

  Future<bool> restore() async {
    if (!config.valid) return false;
    _refreshToken = await storage.read(key: _tokenKey);
    if (_refreshToken == null) return false;
    await token();
    return true;
  }

  Future<String> token() {
    if (_idToken != null &&
        _expiry.isAfter(DateTime.now().add(const Duration(minutes: 1))))
      return Future.value(_idToken!);
    return _refreshing ??= _renew().whenComplete(() => _refreshing = null);
  }

  Future<String> _renew() async {
    if (_refreshToken == null) throw const PortalError('SIGN_IN_REQUIRED');
    final result = await _json(
        Uri.https(
            'securetoken.googleapis.com', '/v1/token', {'key': config.apiKey}),
        body: {'grant_type': 'refresh_token', 'refresh_token': _refreshToken},
        form: true);
    _idToken = result['id_token'];
    _refreshToken = result['refresh_token'];
    _expiry =
        DateTime.now().add(Duration(seconds: int.parse(result['expires_in'])));
    await storage.write(key: _tokenKey, value: _refreshToken);
    return _idToken!;
  }

  Future<Map<String, dynamic>> request(String path,
          {String method = 'GET', Map<String, dynamic>? body}) async =>
      _json(Uri.parse(config.apiBase.replaceAll(RegExp(r'/$'), '') + path),
          method: method, body: body, bearer: await token());
  Stream<Map<String, dynamic>> events() async* {
    while (!_disposed) {
      final client = HttpClient();
      _streamClient = client;
      try {
        final request = await client
            .getUrl(Uri.parse(
                config.apiBase.replaceAll(RegExp(r'/$'), '') + '/events'))
            .timeout(const Duration(seconds: 20));
        request.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer ${await token()}');
        request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
        final response =
            await request.close().timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          final result =
              jsonDecode(await utf8.decoder.bind(response).join()) as Map;
          throw PortalError(result['error'] ?? 'REQUEST_FAILED');
        }
        yield {'kind': 'connected'};
        await for (final line in response
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .timeout(const Duration(seconds: 60))) {
          if (line.startsWith('data: '))
            yield jsonDecode(line.substring(6)) as Map<String, dynamic>;
        }
      } catch (e) {
        if (_disposed) break;
        if (e is PortalError &&
            ['SIGN_IN_REQUIRED', 'ACCESS_DENIED'].contains(e.code)) {
          yield {'kind': 'revoked'};
          break;
        }
        yield {'kind': 'disconnected'};
      } finally {
        client.close(force: true);
        if (_streamClient == client) _streamClient = null;
      }
      if (!_disposed) await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> signOut() async {
    dispose();
    _idToken = null;
    _refreshToken = null;
    await storage.delete(key: _tokenKey);
  }

  void dispose() {
    _disposed = true;
    _streamClient?.close(force: true);
  }
}

Map<String, dynamic> portalSafeSnapshot(Map<String, dynamic> data) => {
      for (final entry in portalTableFields.entries)
        entry.key: [
          for (final row in (data[entry.key] as List? ?? []).whereType<Map>())
            {
              for (final key in entry.value)
                if (row.containsKey(key)) key: row[key],
              if (['campaigns', 'proxies', 'bank_accounts'].contains(entry.key))
                '_portalRecordId': _cloudRecordId(entry.key, row)
            },
        ],
    };
String _cloudRecordId(String table, Map row) =>
    row['_portalRecordId'] as String? ??
    sha256
        .convert(utf8.encode(jsonEncode([
          for (final key in table == 'campaigns'
              ? ['seq', 'date', 'accountCode', 'product']
              : table == 'proxies'
                  ? ['host', 'port', 'username']
                  : ['iban', 'bankName', 'beneficiaryName'])
            row[key]
        ])))
        .toString();
String _identity(String table, Map row) =>
    ['campaigns', 'proxies', 'bank_accounts'].contains(table)
        ? _cloudRecordId(table, row)
        : jsonEncode(
            [for (final key in portalIdentities[table] ?? []) row[key]]);
Map<String, dynamic> mergePortalSnapshot(
        Map<String, dynamic> local, Map<String, dynamic> remote) =>
    {
      for (final table in portalTableFields.keys)
        table: [
          for (final row in (remote[table] as List? ?? []).whereType<Map>())
            <String, dynamic>{
              ...<String, dynamic>{
                for (final old
                    in (local[table] as List? ?? []).whereType<Map>())
                  if (_identity(table, old) == _identity(table, row))
                    ...Map<String, dynamic>.from(old)
              },
              ...Map<String, dynamic>.from(row),
            },
        ],
    };
