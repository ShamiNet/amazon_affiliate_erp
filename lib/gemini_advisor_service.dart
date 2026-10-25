import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'gemini_report_extractor.dart';

enum ErpSection {
  dashboard,
  campaigns,
  catalog,
  amazonAccounts,
  emailsAndGoLogin,
  proxiesAndBanks,
  platformsAndTiming,
  workflowSteps,
}

class GeminiAdvisorService {
  GeminiAdvisorService({
    GeminiApiKeyStore? keyStore,
    HttpClient? httpClient,
  })  : _keyStore = keyStore ?? GeminiApiKeyStore(),
        _injectedClient = httpClient;

  final GeminiApiKeyStore _keyStore;
  final HttpClient? _injectedClient;
  static const List<String> _models = ['gemini-3.8-flash', 'gemini-3.6-flash'];

  Future<String> getSectionAdvice({
    required ErpSection section,
    required Map<String, dynamic> sectionData,
    String userCustomQuery = '',
  }) async {
    final state = await _keyStore.readState();
    final activeKey = state.activeKey?.trim();
    final apiKeys = <String>[
      if (activeKey != null && activeKey.isNotEmpty) activeKey,
      for (final k in state.profiles.values)
        if (k.trim().isNotEmpty && k.trim() != activeKey) k.trim(),
    ];

    if (apiKeys.isEmpty) {
      throw const FormatException(
        'لم يتم ضبط مفتاح Gemini API. انتقل إلى شاشة "استخراج التقارير" وأضف المفتاح أولاً.',
      );
    }

    final systemInstruction = _buildSystemPrompt(section);
    final promptPayload = {
      'system_instruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': '''
بيانات القسم الحالية من النظام (JSON):
${jsonEncode(sectionData)}

${userCustomQuery.trim().isNotEmpty ? "سؤال المستخدم الإضافي: $userCustomQuery" : "المطلوب: حلل البيانات السابقة وقدم 3 إلى 5 نقاط عملية وتوصيات مباشرة لزيادة الأرباح وتجنب الخسائر وإدارة الحسابات بكفاءة."}
'''
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 4096,
        'thinkingConfig': {'thinkingLevel': 'low'},
      }
    };

    Object? lastError;
    Map<String, dynamic>? decoded;

    // نجرب المفاتيح بالترتيب (النشط أولاً)، ولكل مفتاح كل نموذج؛ الأخطاء الخاصة بالمفتاح أو الحصة تنقلنا للمفتاح التالي.
    keysLoop:
    for (final apiKey in apiKeys) {
      for (final model in _models) {
        final isPrimary = model == _models.first;
        final config =
            Map<String, dynamic>.from(promptPayload['generationConfig'] as Map);
        if (!isPrimary) config.remove('thinkingConfig');
        final bodyBytes = utf8.encode(
          jsonEncode({...promptPayload, 'generationConfig': config}),
        );
        final modelUrl = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
        );

        for (var attempt = 1; attempt <= 2; attempt++) {
          final client = _injectedClient ?? HttpClient();
          var nextKey = false;
          try {
            final request = await client
                .postUrl(modelUrl)
                .timeout(const Duration(seconds: 20));
            request.persistentConnection = false;
            request.headers
              ..set(HttpHeaders.contentTypeHeader,
                  'application/json; charset=utf-8')
              ..set('x-goog-api-key', apiKey);
            request.contentLength = bodyBytes.length;
            request.add(bodyBytes);

            final response =
                await request.close().timeout(const Duration(seconds: 90));
            final body = await utf8.decoder
                .bind(response)
                .join()
                .timeout(const Duration(seconds: 90));
            final json = jsonDecode(body) as Map<String, dynamic>;
            final status = response.statusCode;

            if (status == 200) {
              decoded = json;
              break keysLoop;
            }
            final msg = json['error']?['message'] ?? 'فشل طلب الذكاء الاصطناعي';
            lastError = HttpException('خطأ ($status): $msg');
            if (status == 400 || status == 404) break; // جرّب النموذج التالي
            if (status == 401 || status == 403 || status == 429) {
              nextKey = true;
            }
          } on TimeoutException catch (e) {
            lastError = e;
          } on HttpException catch (e) {
            lastError = e;
          } on SocketException catch (e) {
            lastError = e;
          } finally {
            if (_injectedClient == null) client.close(force: true);
          }
          if (nextKey) continue keysLoop;
          if (attempt < 2) {
            await Future<void>.delayed(Duration(seconds: attempt * 2));
          }
        }
      }
    }

    if (decoded == null) {
      throw HttpException(
        'تعذر الحصول على رد بعد تجربة ${apiKeys.length} مفتاح/مفاتيح وعدة نماذج. '
        'أعد المحاولة بعد دقيقة.\n$lastError',
      );
    }

    final candidates = decoded['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const FormatException('لم يُرجع Gemini أي محتوى.');
    }

    final content = candidates.first['content']?['parts'] as List?;
    return content?.map((p) => p['text']).join() ??
        'لا توجد توصيات متاحة حالياً.';
  }

  String _buildSystemPrompt(ErpSection section) {
    const base = '''
أنت الخبير الاستراتيجي والمستشار التقني لمنظومة إدارة حملات أمازون أفلييت (Amazon Associates) والإعلانات المدفوعة (Adsterra, PropellerAds, Twitter Ads) وإدارة الحسابات المعزولة (Anti-detect & Proxies).
أسلوبك: أجب بالعربية بأسلوب عملي ومباشر، وركز على العائد المالي (ROI)، وإدارة المخاطر، والامتثال دون مقدمات إنشائية. اكتب دائماً بهذا الترتيب:
1. ملخص تنفيذي: خلاصة الحالة في جملتين.
2. أبرز المؤشرات: استشهد بالأرقام الواردة في البيانات فقط، واذكر إذا كانت البيانات غير كافية.
3. خطة عمل: من 3 إلى 5 خطوات مرتبة بالأولوية، مع توضيح الإجراء وسبب اختياره.
4. تحذيرات: المخاطر أو البيانات الناقصة التي تتطلب التحقق.
لا تخترع أرقاماً أو استنتاجات لا تدعمها البيانات، ولا توصي بمضاعفة الإنفاق دون دليل كافٍ على ربحية مستدامة.
''';

    switch (section) {
      case ErpSection.dashboard:
        return '$base ركز على قراءة السيولة الكلية، توزيع رأس المال بين المستفيدين، رصد الحملات الخاسرة فوراً، وتحديد أولويات الإنفاق.';
      case ErpSection.campaigns:
        return '$base ركز على معادلات: (CR = Orders/Clicks)، الربح الصافي، ونسبة الـ ROI. أعطِ قراراً حاسماً: (إيقاف الحملة، تعديل الرابط والاستهداف، أو مضاعفة الميزانية).';
      case ErpSection.catalog:
        return '$base ركز على كفاية رأس المال، ربط المنتجات بالحسابات والمستفيدين، واكتشاف البيانات الناقصة أو غير المتسقة.';
      case ErpSection.amazonAccounts:
        return '$base ركز على تجنب حظر الحسابات (Account Hygiene)، وفصل الـ Store IDs، والتأكد من توافق روابط التوجيه (Bridge Pages / Cloudflare Workers).';
      case ErpSection.emailsAndGoLogin:
        return '$base ركز على اكتمال ربط البريد والبروفايل، حالة التوثيق، واتساق سجلات الوصول دون كشف بيانات اعتماد حساسة.';
      case ErpSection.proxiesAndBanks:
        return '$base ركز على سلامة ربط البروكسي والدولة والحساب البنكي، واكتشاف السجلات غير المكتملة. لا تقترح تدوير الحسابات أو التحايل على أنظمة الكشف.';
      case ErpSection.platformsAndTiming:
        return '$base ركز على توقيت سلوك الشراء في أمريكا (EST/PST) مقابل توقيت دمشق، وتحديد ساعات حرق الإعلانات وساعات الذروة الذهبية.';
      case ErpSection.workflowSteps:
        return '$base اشرح أفضل الممارسات لتطبيق الخطوة الحالية من خطوات العمل القياسية (SOP) لتفادي الأخطاء البشرية.';
    }
  }
}
