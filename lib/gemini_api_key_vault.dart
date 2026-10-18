import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureStringStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class FlutterSecureStringStore implements SecureStringStore {
  FlutterSecureStringStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class GeminiApiKey {
  const GeminiApiKey({
    required this.id,
    required this.name,
    required this.secret,
  });

  final String id;
  final String name;
  final String secret;

  String get maskedSecret {
    final suffix = secret.length > 4 ? secret.substring(secret.length - 4) : '';
    return '••••••••$suffix';
  }
}

class GeminiApiKeyCollection {
  const GeminiApiKeyCollection({
    required this.keys,
    required this.activeId,
  });

  final List<GeminiApiKey> keys;
  final String? activeId;

  GeminiApiKey? get activeKey {
    for (final key in keys) {
      if (key.id == activeId) return key;
    }
    return null;
  }
}

class GeminiApiKeyVault {
  GeminiApiKeyVault({SecureStringStore? store})
      : _store = store ?? FlutterSecureStringStore();

  static const _storageKey = 'gemini_api_key_collection_v1';
  final SecureStringStore _store;

  Future<GeminiApiKeyCollection> load() async {
    final serialized = await _store.read(_storageKey);
    if (serialized == null) {
      return const GeminiApiKeyCollection(keys: [], activeId: null);
    }

    final decoded = jsonDecode(serialized);
    if (decoded is! Map<String, dynamic> || decoded['keys'] is! List) {
      throw const FormatException('بيانات مفاتيح Gemini المحفوظة غير صالحة.');
    }

    final keys = <GeminiApiKey>[];
    for (final value in decoded['keys'] as List) {
      if (value is! Map<String, dynamic> ||
          value['id'] is! String ||
          value['name'] is! String ||
          value['secret'] is! String ||
          (value['id'] as String).isEmpty ||
          (value['name'] as String).trim().isEmpty ||
          (value['secret'] as String).trim().isEmpty) {
        throw const FormatException(
          'أحد مفاتيح Gemini المحفوظة يحتوي بيانات غير صالحة.',
        );
      }
      keys.add(
        GeminiApiKey(
          id: value['id'] as String,
          name: value['name'] as String,
          secret: value['secret'] as String,
        ),
      );
    }

    final activeIdValue = decoded['active_id'];
    final activeId = activeIdValue is String && keys.any((key) => key.id == activeIdValue)
        ? activeIdValue
        : (keys.isNotEmpty ? keys.first.id : null);
    return GeminiApiKeyCollection(
      keys: keys,
      activeId: activeId,
    );
  }

  Future<GeminiApiKeyCollection> add({
    required String name,
    required String secret,
  }) async {
    final normalizedName = name.trim();
    final normalizedSecret = secret.trim();
    if (normalizedName.isEmpty || normalizedSecret.isEmpty) {
      throw const FormatException('أدخل اسماً ومفتاح Gemini غير فارغين.');
    }
    if (normalizedSecret.contains('\r') || normalizedSecret.contains('\n')) {
      throw const FormatException('مفتاح Gemini لا يمكن أن يحتوي أسطرًا جديدة.');
    }

    final current = await load();
    final random = Random.secure();
    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}';
    final keys = [
      ...current.keys,
      GeminiApiKey(id: id, name: normalizedName, secret: normalizedSecret),
    ];
    final activeId = current.activeId ?? id;
    await _save(keys, activeId);
    return GeminiApiKeyCollection(keys: keys, activeId: activeId);
  }

  Future<GeminiApiKeyCollection> select(String id) async {
    final current = await load();
    if (!current.keys.any((key) => key.id == id)) {
      throw const FormatException('مفتاح Gemini المحدد غير موجود.');
    }
    await _save(current.keys, id);
    return GeminiApiKeyCollection(keys: current.keys, activeId: id);
  }

  Future<GeminiApiKeyCollection> remove(String id) async {
    final current = await load();
    final keys = current.keys.where((key) => key.id != id).toList();
    if (keys.length == current.keys.length) return current;

    String? activeId = current.activeId;
    if (current.activeId == id) {
      if (keys.isEmpty) {
        activeId = null;
      } else {
        final removedIndex = current.keys.indexWhere((key) => key.id == id);
        final replacementIndex = removedIndex >= 0 && removedIndex < keys.length
            ? removedIndex
            : keys.length - 1;
        activeId = keys[replacementIndex].id;
      }
    }

    await _save(keys, activeId);
    return GeminiApiKeyCollection(keys: keys, activeId: activeId);
  }

  Future<void> _save(List<GeminiApiKey> keys, String? activeId) {
    return _store.write(
      _storageKey,
      jsonEncode({
        'active_id': activeId,
        'keys': [
          for (final key in keys)
            {'id': key.id, 'name': key.name, 'secret': key.secret},
        ],
      }),
    );
  }
}
