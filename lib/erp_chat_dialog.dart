import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'erp_chat_context.dart';
import 'gemini_advisor_service.dart';

typedef ChatResponder = Future<String> Function(
    List<Map<String, String>> history, Map<String, dynamic> data);

class ErpChatMessage {
  const ErpChatMessage(this.role, this.text, this.scope);
  final String role;
  final String text;
  final String scope;
  Map<String, String> toRequest() => {
        'role': role,
        'text':
            role == 'user' ? 'النطاق: ${chatSectionTitles[scope]}\n$text' : text
      };
}

/// Kept by the shell so closing the window does not lose an ongoing chat.
class ErpChatSession extends ChangeNotifier {
  bool _disposed = false;
  final List<ErpChatMessage> messages = [];
  bool busy = false;
  String? error;
  ErpChatMessage? failedMessage;

  Future<void> send(String text, String scope, Map<String, dynamic> data,
      ChatResponder respond) async {
    if (_disposed || busy || text.trim().isEmpty) return;
    final message = ErpChatMessage('user', text.trim(), scope);
    messages.add(message);
    busy = true;
    error = null;
    failedMessage = null;
    notifyListeners();
    try {
      final reply =
          await respond(messages.map((m) => m.toRequest()).toList(), data);
      if (reply.trim().isEmpty)
        throw const FormatException('الرد فارغ. أعد المحاولة.');
      messages.add(ErpChatMessage('model', reply, scope));
    } catch (e) {
      messages.remove(message);
      failedMessage = message;
      error = e is FormatException
          ? e.message.toString()
          : 'تعذر الحصول على الرد. تحقق من اتصال الإنترنت وإعدادات مفتاح Gemini في صفحة استخراج التقارير.\n$e';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void clear() {
    if (busy) return;
    messages.clear();
    error = null;
    failedMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class ErpChatDialog extends StatefulWidget {
  const ErpChatDialog(
      {super.key,
      required this.session,
      required this.initialScope,
      required this.contextProvider,
      this.respond});
  final ErpChatSession session;
  final String initialScope;
  final Map<String, dynamic> Function(String scope) contextProvider;
  final ChatResponder? respond;
  @override
  State<ErpChatDialog> createState() => _ErpChatDialogState();
}

class _ErpChatDialogState extends State<ErpChatDialog> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _service = GeminiAdvisorService();
  late String _scope = widget.initialScope;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_scrollToEnd);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients)
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    widget.session.removeListener(_scrollToEnd);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([ErpChatMessage? retry]) {
    final text = retry?.text ?? _input.text.trim();
    if (text.isEmpty || widget.session.busy) return;
    final scope = retry?.scope ?? _scope;
    final data = widget.contextProvider(scope);
    if (retry == null) _input.clear();
    widget.session.send(
        text,
        scope,
        data,
        widget.respond ??
            (history, data) => _service.getSectionAdvice(
                section: ErpSection.dashboard,
                sectionData: data,
                conversation: history));
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
            insetPadding: const EdgeInsets.all(20),
            child: SizedBox(
              width: 980,
              height: MediaQuery.sizeOf(context).height * .88,
              child: AnimatedBuilder(
                  animation: widget.session,
                  builder: (context, _) {
                    final session = widget.session;
                    return Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(children: [
                          Row(children: [
                            const Icon(Icons.forum_outlined),
                            const SizedBox(width: 10),
                            const Expanded(
                                child: Text('محادثة الذكاء الاصطناعي',
                                    style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold))),
                            IconButton(
                                tooltip: 'محادثة جديدة',
                                onPressed: session.busy ? null : session.clear,
                                icon: const Icon(Icons.add_comment_outlined)),
                            IconButton(
                                tooltip: 'إغلاق',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close)),
                          ]),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _scope,
                            decoration: const InputDecoration(
                                labelText: 'نطاق البيانات للتحليل والسؤال',
                                border: OutlineInputBorder(),
                                isDense: true),
                            items: [
                              for (final entry in chatSectionTitles.entries)
                                DropdownMenuItem(
                                    value: entry.key, child: Text(entry.value))
                            ],
                            onChanged: session.busy
                                ? null
                                : (value) {
                                    if (value != null)
                                      setState(() => _scope = value);
                                  },
                          ),
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                  'تُرسل بيانات النطاق المحدد إلى Gemini عند الإرسال. المحادثة تبقى متاحة حتى إغلاق التطبيق.',
                                  style: TextStyle(fontSize: 12))),
                          const Divider(height: 1),
                          Expanded(
                              child: session.messages.isEmpty &&
                                      session.error == null
                                  ? Center(
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                          const Text(
                                              'اسأل عن بيانات القسم، أو قارن النتائج، أو اطلب شرحًا وخطة عمل.'),
                                          const SizedBox(height: 12),
                                          Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                for (final question in [
                                                  'حلّل بيانات هذا القسم',
                                                  'ما البيانات الناقصة؟',
                                                  'ما أهم التحسينات المقترحة؟'
                                                ])
                                                  ActionChip(
                                                      label: Text(question),
                                                      onPressed: () {
                                                        _input.text = question;
                                                        _send();
                                                      }),
                                              ]),
                                        ]))
                                  : ListView(
                                      controller: _scroll,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      children: [
                                          for (final message
                                              in session.messages)
                                            Align(
                                                alignment: message.role == 'user'
                                                    ? Alignment.centerRight
                                                    : Alignment.centerLeft,
                                                child: Container(
                                                    margin: const EdgeInsets.only(
                                                        bottom: 12),
                                                    padding: const EdgeInsets.all(
                                                        14),
                                                    constraints:
                                                        const BoxConstraints(
                                                            maxWidth: 830),
                                                    decoration: BoxDecoration(
                                                        color: message.role == 'user'
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .primaryContainer
                                                            : Theme.of(context)
                                                                .colorScheme
                                                                .surfaceContainerHighest,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                12)),
                                                    child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Expanded(
                                                                    child: Text(
                                                                        '${message.role == 'user' ? 'أنت' : 'Gemini'} • ${chatSectionTitles[message.scope]}',
                                                                        style: const TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontSize: 12))),
                                                                IconButton(
                                                                    tooltip:
                                                                        'نسخ الرسالة',
                                                                    visualDensity:
                                                                        VisualDensity
                                                                            .compact,
                                                                    onPressed: () =>
                                                                        Clipboard.setData(ClipboardData(
                                                                            text: message
                                                                                .text)),
                                                                    icon: const Icon(
                                                                        Icons
                                                                            .copy,
                                                                        size:
                                                                            16)),
                                                              ]),
                                                          SelectableText(
                                                              message.text),
                                                        ]))),
                                          if (session.busy)
                                            const Padding(
                                                padding: EdgeInsets.all(16),
                                                child: Row(children: [
                                                  SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2)),
                                                  SizedBox(width: 10),
                                                  Text('جارٍ إعداد الرد…')
                                                ])),
                                          if (session.error != null)
                                            Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      SelectableText(
                                                          'السؤال: ${session.failedMessage?.text}\n${session.error}',
                                                          style: TextStyle(
                                                              color: Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .error)),
                                                      TextButton.icon(
                                                          onPressed: session
                                                                  .busy
                                                              ? null
                                                              : () => _send(session
                                                                  .failedMessage),
                                                          icon: const Icon(
                                                              Icons.refresh),
                                                          label: const Text(
                                                              'إعادة المحاولة')),
                                                    ])),
                                        ])),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                    child: TextField(
                                        controller: _input,
                                        minLines: 1,
                                        maxLines: 5,
                                        decoration: const InputDecoration(
                                            hintText:
                                                'اكتب سؤالك أو الصق بيانات تريد تحليلها…',
                                            border: OutlineInputBorder()),
                                        onSubmitted: (_) => _send())),
                                const SizedBox(width: 10),
                                FilledButton.icon(
                                    onPressed:
                                        session.busy ? null : () => _send(),
                                    icon: const Icon(Icons.send),
                                    label: const Text('إرسال')),
                              ]),
                        ]));
                  }),
            )),
      );
}
