import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'report_image_models.dart';

class GeminiApiKeyStore {
  GeminiApiKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _profilesKey = 'gemini_api_key_profiles';
  static const _legacyKeyName = 'gemini_api_key';
  final FlutterSecureStorage _storage;

  Future<GeminiApiKeyProfileState> readState() async {
    final encodedProfiles = await _storage.read(key: _profilesKey);
    if (encodedProfiles != null) {
      final decoded = jsonDecode(encodedProfiles);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
            'تنسيق ملفات مفاتيح Gemini المحفوظة غير صالح.');
      }
      final profileValues = decoded['profiles'];
      if (profileValues is! Map) {
        throw const FormatException('قائمة مفاتيح Gemini المحفوظة غير صالحة.');
      }
      final profiles = <String, String>{};
      for (final entry in profileValues.entries) {
        final name = entry.key;
        final key = entry.value;
        if (name is! String || key is! String) {
          throw const FormatException(
              'بيانات أحد مفاتيح Gemini المحفوظة غير صالحة.');
        }
        profiles[name] = key;
      }
      final activeName = decoded['active']?.toString();
      return GeminiApiKeyProfileState(
        profiles: profiles,
        activeName: profiles.containsKey(activeName) ? activeName : null,
      );
    }

    final legacyKey = await _storage.read(key: _legacyKeyName);
    if (legacyKey == null || legacyKey.trim().isEmpty) {
      return const GeminiApiKeyProfileState(profiles: {}, activeName: null);
    }
    const legacyProfileName = 'الافتراضي';
    final state = GeminiApiKeyProfileState(
      profiles: {legacyProfileName: legacyKey},
      activeName: legacyProfileName,
    );
    await _writeState(state);
    await _storage.delete(key: _legacyKeyName);
    return state;
  }

  Future<void> saveProfile({
    required String name,
    required String apiKey,
  }) async {
    final normalizedName = name.trim();
    final normalizedKey = apiKey.trim();
    if (normalizedName.isEmpty || normalizedKey.isEmpty) {
      throw const FormatException('أدخل اسم الملف ومفتاح Gemini.');
    }
    final current = await readState();
    final profiles = Map<String, String>.from(current.profiles)
      ..[normalizedName] = normalizedKey;
    await _writeState(GeminiApiKeyProfileState(
      profiles: profiles,
      activeName: current.activeName ?? normalizedName,
    ));
  }

  Future<void> selectProfile(String name) async {
    final current = await readState();
    if (!current.profiles.containsKey(name)) {
      throw const FormatException('ملف مفتاح Gemini المحدد غير موجود.');
    }
    await _writeState(GeminiApiKeyProfileState(
      profiles: current.profiles,
      activeName: name,
    ));
  }

  Future<void> deleteProfile(String name) async {
    final current = await readState();
    if (!current.profiles.containsKey(name)) return;
    final profiles = Map<String, String>.from(current.profiles)..remove(name);
    final activeName = current.activeName == name
        ? (profiles.isEmpty ? null : profiles.keys.first)
        : current.activeName;
    await _writeState(GeminiApiKeyProfileState(
      profiles: profiles,
      activeName: activeName,
    ));
  }

  Future<void> _writeState(GeminiApiKeyProfileState state) {
    return _storage.write(
      key: _profilesKey,
      value: jsonEncode({
        'profiles': state.profiles,
        'active': state.activeName,
      }),
    );
  }
}

class GeminiApiKeyProfileState {
  const GeminiApiKeyProfileState({
    required this.profiles,
    required this.activeName,
  });

  final Map<String, String> profiles;
  final String? activeName;

  String? get activeKey => activeName == null ? null : profiles[activeName];
}

class GeminiReportExtractor {
  GeminiReportExtractor({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  static const model = 'gemini-3.6-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$model:generateContent';

  final HttpClient _httpClient;

  static const _retryableStatuses = {429, 500, 502, 503, 504};
  static const _maxAttempts = 4;

  Future<ExtractedReport> extract({
    required String apiKey,
    required List<int> imageBytes,
    required String mimeType,
    required ReportImageType reportType,
    void Function(int attempt, int maxAttempts, Duration wait)? onRetry,
  }) async {
    for (var attempt = 1;; attempt++) {
      try {
        return await _extractOnce(
          apiKey: apiKey,
          imageBytes: imageBytes,
          mimeType: mimeType,
          reportType: reportType,
        );
      } on _RetryableGeminiException catch (e) {
        if (attempt >= _maxAttempts) {
          throw HttpException(e.message, uri: Uri.parse(_endpoint));
        }
        final wait = Duration(seconds: 2 * attempt * attempt);
        onRetry?.call(attempt, _maxAttempts, wait);
        await Future<void>.delayed(wait);
      }
    }
  }

  Future<ExtractedReport> _extractOnce({
    required String apiKey,
    required List<int> imageBytes,
    required String mimeType,
    required ReportImageType reportType,
  }) async {
    final request = await _httpClient
        .postUrl(Uri.parse(_endpoint))
        .timeout(const Duration(seconds: 20));
    request.headers
      ..set(HttpHeaders.contentTypeHeader, ContentType.json.mimeType)
      ..set('x-goog-api-key', apiKey);
    request.write(jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': _prompt(reportType)},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Encode(imageBytes),
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0,
        'responseMimeType': 'application/json',
        'responseSchema': _responseSchema,
      },
    }));

    final response = await request.close().timeout(
          const Duration(seconds: 120),
        );
    final responseText = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 30));
    final decoded = _decodeJsonObject(responseText);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _apiErrorMessage(response.statusCode, decoded);
      if (_retryableStatuses.contains(response.statusCode)) {
        throw _RetryableGeminiException(message);
      }
      throw HttpException(message, uri: Uri.parse(_endpoint));
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty || candidates.first is! Map) {
      throw const FormatException(
        'لم يُرجع Gemini نتيجة قابلة للاستخدام. جرّب صورة أوضح.',
      );
    }
    final content = candidates.first['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) {
      throw const FormatException('استجابة Gemini لا تحتوي بيانات الجدول.');
    }
    final modelText = parts
        .whereType<Map>()
        .map((part) => part['text'])
        .whereType<String>()
        .join();
    if (modelText.trim().isEmpty) {
      throw const FormatException('أعاد Gemini نتيجة فارغة.');
    }
    return parseModelText(modelText);
  }

  static ExtractedReport parseModelText(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('نتيجة Gemini ليست كائن JSON صالحاً.');
    }
    return ExtractedReport.fromJson(decoded);
  }

  void close() => _httpClient.close(force: true);

  static const _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'title': {'type': 'STRING'},
      'columns': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'rows': {
        'type': 'ARRAY',
        'items': {
          'type': 'ARRAY',
          'items': {'type': 'STRING'},
        },
      },
      'warnings': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
    },
    'required': ['title', 'columns', 'rows', 'warnings'],
  };

  static String _prompt(ReportImageType reportType) {
    final tableDescription = switch (reportType) {
      ReportImageType.amazonEarnings => 'Amazon Associates earnings report',
      ReportImageType.adCampaigns => 'advertising campaign report',
    };
    return '''
Read the visible $tableDescription table in this image. Return only the requested JSON.
Copy every visible header into columns in its original left-to-right order, and copy each data row into rows in the same column order.
Keep all cell values as strings. Preserve the displayed digits, decimal separators, currency symbols, percentages, dates, and labels exactly; do not calculate, infer, or invent missing values. Use an empty string for an unreadable or blank cell. Ignore charts, navigation, and text outside the table. If no complete table with at least one data row is visible, return empty columns and rows and explain this in warnings.
''';
  }

  static Map<String, dynamic> _decodeJsonObject(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('استجابة Gemini بصيغة غير صحيحة.');
    }
    return decoded;
  }

  static String _apiErrorMessage(
    int statusCode,
    Map<String, dynamic> response,
  ) {
    final error = response['error'];
    final detail = error is Map ? error['message']?.toString() : null;
    if (statusCode == 400 || statusCode == 403) {
      return 'رفض Gemini الطلب أو المفتاح (HTTP $statusCode). '
          '${detail ?? 'تحقق من صحة مفتاح API وإعداداته.'}';
    }
    if (statusCode == 401) {
      return 'مفتاح Gemini غير صالح أو غير مخوّل. أعد إدخال المفتاح.';
    }
    if (statusCode == 429) {
      return 'تم تجاوز حد طلبات Gemini أو الحصة المتاحة. حاول لاحقاً. '
          '${detail ?? ''}';
    }
    if (statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504) {
      return 'خوادم Gemini مزدحمة حالياً (HTTP $statusCode) وفشلت كل '
          'المحاولات التلقائية. أعد المحاولة بعد دقائق أو استخدم المحرك المحلي.';
    }
    return 'فشل طلب Gemini (HTTP $statusCode). ${detail ?? ''}';
  }
}

class _RetryableGeminiException implements Exception {
  const _RetryableGeminiException(this.message);
  final String message;
}
