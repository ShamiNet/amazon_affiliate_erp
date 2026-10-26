import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:amazon_affiliate_erp/gemini_advisor_service.dart';
import 'package:amazon_affiliate_erp/gemini_report_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

class TestKeys extends GeminiApiKeyStore {
  @override
  Future<GeminiApiKeyProfileState> readState() async =>
      const GeminiApiKeyProfileState(
          profiles: {'test': 'fake-key'}, activeName: 'test');
}

class Headers extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class Request extends Fake implements HttpClientRequest {
  final bytes = <int>[];
  @override
  HttpHeaders get headers => Headers();
  @override
  set persistentConnection(bool value) {}
  @override
  set contentLength(int value) {
    length = value;
  }

  int length = 0;
  @override
  void add(List<int> data) => bytes.addAll(data);
  @override
  Future<HttpClientResponse> close() async => Response();
}

class Response extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream.value(utf8.encode(jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'internal', 'thought': true},
                {'text': 'نتيجة التحليل'}
              ]
            }
          }
        ]
      }))).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Client extends Fake implements HttpClient {
  final request = Request();
  @override
  Future<HttpClientRequest> postUrl(Uri url) async => request;
}

void main() {
  test('Gemini receives ordered chat turns, current context and UTF8 length',
      () async {
    final client = Client();
    final service =
        GeminiAdvisorService(keyStore: TestKeys(), httpClient: client);
    final reply = await service
        .getSectionAdvice(section: ErpSection.campaigns, sectionData: {
      'scope': 'الأرباح',
      'count': 12
    }, conversation: [
      {'role': 'user', 'text': 'حلل'},
      {'role': 'model', 'text': 'التحليل'},
      {'role': 'user', 'text': 'اشرح أكثر'},
    ]);
    final body = jsonDecode(utf8.decode(client.request.bytes)) as Map;
    expect(client.request.length, client.request.bytes.length);
    expect((body['contents'] as List).map((m) => m['role']).toList(),
        ['user', 'model', 'user']);
    expect(
        body['system_instruction']['parts'][0]['text'], contains('"count":12'));
    expect(reply, 'نتيجة التحليل');
  });
}
