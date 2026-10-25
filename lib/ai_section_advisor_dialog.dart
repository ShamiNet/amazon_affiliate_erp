import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gemini_advisor_service.dart';

// ============================================================================
// 1. نموذج تخزين التحليلات المحفوظة محلياً
// ============================================================================

class SavedAiAnalysis {
  final String id;
  final DateTime timestamp;
  final String sectionKey;
  final String sectionTitle;
  final String query;
  final String content;

  SavedAiAnalysis({
    required this.id,
    required this.timestamp,
    required this.sectionKey,
    required this.sectionTitle,
    required this.query,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'sectionKey': sectionKey,
        'sectionTitle': sectionTitle,
        'query': query,
        'content': content,
      };

  factory SavedAiAnalysis.fromJson(Map<String, dynamic> json) =>
      SavedAiAnalysis(
        id: json['id']?.toString() ?? '',
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
            DateTime.now(),
        sectionKey: json['sectionKey']?.toString() ?? '',
        sectionTitle: json['sectionTitle']?.toString() ?? 'تحليل عام',
        query: json['query']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
      );
}

class AiAnalysisHistoryStore {
  static File get _file {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '.';
    return File(
      '$home${Platform.pathSeparator}amazon_affiliate_erp_ai_history.json',
    );
  }

  static Future<List<SavedAiAnalysis>> loadHistory() async {
    try {
      final file = _file;
      if (await file.exists()) {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map(SavedAiAnalysis.fromJson)
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<void> saveAnalysis(SavedAiAnalysis item) async {
    final list = await loadHistory();
    list.removeWhere((x) => x.id == item.id);
    list.insert(0, item);
    await _writeList(list);
  }

  static Future<void> deleteAnalysis(String id) async {
    final list = await loadHistory();
    list.removeWhere((x) => x.id == id);
    await _writeList(list);
  }

  static Future<void> clearHistory() async {
    await _writeList([]);
  }

  static Future<void> _writeList(List<SavedAiAnalysis> list) async {
    final file = _file;
    final jsonString = const JsonEncoder.withIndent('  ').convert(
      list.map((e) => e.toJson()).toList(),
    );
    await file.writeAsString(jsonString);
  }
}

// ============================================================================
// 2. دوال الفتح وأزرار العرض
// ============================================================================

void showAiAdvisorDialog({
  required BuildContext context,
  required ErpSection section,
  required String sectionTitle,
  required Map<String, dynamic> contextData,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => AiSectionAdvisorDialog(
      section: section,
      sectionTitle: sectionTitle,
      contextData: contextData,
    ),
  );
}

class AiSectionAdvisorButton extends StatelessWidget {
  const AiSectionAdvisorButton({
    super.key,
    required this.section,
    required this.sectionTitle,
    required this.contextData,
    this.label = 'تحليل القسم عبر Gemini',
    this.iconOnly = false,
  });

  final ErpSection section;
  final String sectionTitle;
  final Map<String, dynamic> contextData;
  final String label;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final onPressed = () => showAiAdvisorDialog(
          context: context,
          section: section,
          sectionTitle: sectionTitle,
          contextData: contextData,
        );

    if (iconOnly) {
      return IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: const Icon(Icons.auto_awesome_rounded),
      );
    }

    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.15),
        foregroundColor: const Color(0xFF38BDF8),
        side: const BorderSide(color: Color(0xFF0EA5E9)),
      ),
      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

// ============================================================================
// 3. نافذة المستشار الذكي الرئيسية
// ============================================================================

class AiSectionAdvisorDialog extends StatefulWidget {
  const AiSectionAdvisorDialog({
    super.key,
    required this.section,
    required this.sectionTitle,
    required this.contextData,
  });

  final ErpSection section;
  final String sectionTitle;
  final Map<String, dynamic> contextData;

  @override
  State<AiSectionAdvisorDialog> createState() => _AiSectionAdvisorDialogState();
}

class _AiSectionAdvisorDialogState extends State<AiSectionAdvisorDialog> {
  final GeminiAdvisorService _advisor = GeminiAdvisorService();
  final TextEditingController _queryController = TextEditingController();

  late Future<String> _adviceFuture;
  String _currentAdvice = '';
  String _lastCustomQuery = '';
  int _selectedTab = 0; // 0: التحليل المباشر، 1: المحفوظة

  List<SavedAiAnalysis> _savedAnalyses = [];
  bool _isLoadingHistory = true;
  SavedAiAnalysis? _viewingSavedItem;

  @override
  void initState() {
    super.initState();
    _fetchAdvice();
    _reloadHistory();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _reloadHistory() async {
    final history = await AiAnalysisHistoryStore.loadHistory();
    if (mounted) {
      setState(() {
        _savedAnalyses = history;
        _isLoadingHistory = false;
      });
    }
  }

  void _fetchAdvice([String customQuery = '']) {
    setState(() {
      _lastCustomQuery = customQuery;
      _currentAdvice = '';
      _adviceFuture = _advisor
          .getSectionAdvice(
        section: widget.section,
        sectionData: widget.contextData,
        userCustomQuery: customQuery,
      )
          .then((result) {
        if (mounted) {
          setState(() {
            _currentAdvice = result;
          });
        }
        return result;
      });
    });
  }

  void _copyToClipboard(String text, String label) {
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ $label إلى الحافظة بنجاح ✅'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 320,
      ),
    );
  }

  Future<void> _saveCurrentAnalysis() async {
    if (_currentAdvice.trim().isEmpty) return;

    final item = SavedAiAnalysis(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      sectionKey: widget.section.name,
      sectionTitle: widget.sectionTitle,
      query: _lastCustomQuery,
      content: _currentAdvice,
    );

    await AiAnalysisHistoryStore.saveAnalysis(item);
    await _reloadHistory();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ التحليل في الأرشيف بنجاح 💾'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 320,
      ),
    );
  }

  Future<void> _deleteAnalysis(String id) async {
    await AiAnalysisHistoryStore.deleteAnalysis(id);
    if (_viewingSavedItem?.id == id) {
      _viewingSavedItem = null;
    }
    await _reloadHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف التحليل من الأرشيف.'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 300,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        title: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0EA5E9), Color(0xFF10B981)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'المستشار الذكي: ${widget.sectionTitle}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('التحليل المباشر'),
                  avatar: const Icon(Icons.bolt_rounded, size: 16),
                  selected: _selectedTab == 0,
                  onSelected: (val) {
                    if (val) setState(() => _selectedTab = 0);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('التحليلات المحفوظة (${_savedAnalyses.length})'),
                  avatar: const Icon(Icons.bookmark_rounded, size: 16),
                  selected: _selectedTab == 1,
                  onSelected: (val) {
                    if (val) setState(() => _selectedTab = 1);
                  },
                ),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: 760,
          child: _selectedTab == 0
              ? _buildCurrentAnalysisView()
              : _buildSavedAnalysesView(),
        ),
        actions: _buildDialogActions(),
      ),
    );
  }

  Widget _buildCurrentAnalysisView() {
    final hasContent = _currentAdvice.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // شريط الأزرار العلوي
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.04),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.insights_rounded,
                  size: 18, color: Color(0xFF0EA5E9)),
              const SizedBox(width: 8),
              const Text(
                'تقرير الأداء والتوصيات الإدارية',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                ),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label:
                    const Text('نسخ التقرير', style: TextStyle(fontSize: 12)),
                onPressed: hasContent
                    ? () => _copyToClipboard(_currentAdvice, 'تقرير التحليل')
                    : null,
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                ),
                icon: const Icon(Icons.bookmark_add_rounded, size: 15),
                label: const Text('حفظ في الأرشيف',
                    style: TextStyle(fontSize: 12)),
                onPressed: hasContent ? _saveCurrentAnalysis : null,
              ),
            ],
          ),
        ),

        // حاوية العرض المنسقة
        Container(
          constraints: const BoxConstraints(maxHeight: 460, minHeight: 220),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.02),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border(
              left: BorderSide(color: Colors.grey.withOpacity(0.2)),
              right: BorderSide(color: Colors.grey.withOpacity(0.2)),
              bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
          ),
          child: FutureBuilder<String>(
            future: _adviceFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5),
                      SizedBox(height: 14),
                      Text(
                        'Gemini يقوم بقراءة المؤشرات وتجهيز التقرير التنفيذي...',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      'تعذر إتمام التحليل:\n${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                );
              }
              return AiAdviceFormattedView(
                rawText: snapshot.data ?? 'لا توجد توصيات متاحة حالياً.',
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  hintText:
                      'اطلب توضيحاً مخصصاً (مثال: ما هو الإجراء الأفضل لحساب SH-02؟)...',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onSubmitted: _fetchAdvice,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'إرسال الاستفسار',
              icon: const Icon(Icons.send_rounded, size: 18),
              onPressed: () => _fetchAdvice(_queryController.text),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSavedAnalysesView() {
    if (_isLoadingHistory) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_viewingSavedItem != null) {
      final item = _viewingSavedItem!;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'العودة للقائمة',
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                onPressed: () => setState(() => _viewingSavedItem = null),
              ),
              Expanded(
                child: Text(
                  '${item.sectionTitle} (${item.timestamp.toLocal().toString().split('.').first})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'نسخ التحليل',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () =>
                    _copyToClipboard(item.content, 'التحليل المحفوظ'),
              ),
              IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFF43F5E), size: 18),
                onPressed: () => _deleteAnalysis(item.id),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 460),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: AiAdviceFormattedView(rawText: item.content),
          ),
        ],
      );
    }

    if (_savedAnalyses.isEmpty) {
      return Container(
        height: 280,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border_rounded, size: 48, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'لا توجد تحليلات محفوظة بعد.\nاضغط "حفظ في الأرشيف" للرجوع إلى أي تقرير في أي وقت.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 420,
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _savedAnalyses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _savedAnalyses[index];
          final dateStr = item.timestamp.toLocal().toString().substring(0, 16);
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1A0EA5E9),
                child: Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFF0EA5E9), size: 18),
              ),
              title: Text(
                item.sectionTitle,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              subtitle: Text(
                item.query.isNotEmpty
                    ? '$dateStr • سؤال: ${item.query}'
                    : dateStr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'نسخ المحتوى',
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    onPressed: () =>
                        _copyToClipboard(item.content, 'التحليل المحفوظ'),
                  ),
                  IconButton(
                    tooltip: 'عرض التحليل كاملاً',
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    onPressed: () => setState(() => _viewingSavedItem = item),
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFF43F5E), size: 16),
                    onPressed: () => _deleteAnalysis(item.id),
                  ),
                ],
              ),
              onTap: () => setState(() => _viewingSavedItem = item),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildDialogActions() {
    if (_selectedTab == 0) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('إعادة التحليل'),
          onPressed: () => _fetchAdvice(),
        ),
      ];
    }

    return [
      if (_savedAnalyses.isNotEmpty)
        TextButton.icon(
          icon: const Icon(Icons.delete_sweep_rounded,
              color: Color(0xFFF43F5E), size: 18),
          label: const Text(
            'حذف كل السجل',
            style: TextStyle(color: Color(0xFFF43F5E)),
          ),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('تأكيد مسح الأرشيف'),
                content: const Text(
                  'هل أنت متأكد من حذف جميع التحليلات المحفوظة نهائياً؟',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF43F5E),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('حذف الكل'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await AiAnalysisHistoryStore.clearHistory();
              setState(() => _viewingSavedItem = null);
              await _reloadHistory();
            }
          },
        ),
      const Spacer(),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إغلاق'),
      ),
    ];
  }
}

// ============================================================================
// 4. المكوّن البصري المنسق للتحليلات (AiAdviceFormattedView)
// ============================================================================

class AiAdviceFormattedView extends StatelessWidget {
  final String rawText;
  const AiAdviceFormattedView({super.key, required this.rawText});

  @override
  Widget build(BuildContext context) {
    if (rawText.trim().isEmpty) {
      return const Center(child: Text('لا توجد توصيات'));
    }

    // تقسيم النص وفق الفواصل أو الأقسام
    final sections = _parseSections(rawText);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:
            sections.map((sec) => _buildSectionWidget(context, sec)).toList(),
      ),
    );
  }

  List<_ParsedSection> _parseSections(String text) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final result = <_ParsedSection>[];

    String currentTitle = '';
    _SectionType currentType = _SectionType.normal;
    List<String> currentLines = [];

    void commit() {
      if (currentTitle.isNotEmpty || currentLines.isNotEmpty) {
        result.add(_ParsedSection(
          title: currentTitle,
          type: currentType,
          contentLines: List.from(currentLines),
        ));
        currentTitle = '';
        currentLines.clear();
        currentType = _SectionType.normal;
      }
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();

      // تجاهل الفواصل الأفقية البحتة
      if (line == '---' || line == '***' || line == '___') {
        commit();
        continue;
      }

      // 1. اكتشاف القرار الحاسم في البداية
      if (line.contains('القرار الحاسم:')) {
        commit();
        currentType = _SectionType.decision;
        currentTitle = 'القرار الحاسم';
        currentLines.add(line
            .replaceAll('**القرار الحاسم:**', '')
            .replaceAll('**القرار الحاسم**:', '')
            .trim());
        commit();
        continue;
      }

      // 2. اكتشاف العناوين الرئيسية ###
      if (line.startsWith('#')) {
        commit();
        final cleanTitle = line.replaceAll(RegExp(r'^#+\s*'), '').trim();
        currentTitle = cleanTitle;

        if (cleanTitle.contains('ملخص')) {
          currentType = _SectionType.summary;
        } else if (cleanTitle.contains('مؤشر') || cleanTitle.contains('أداء')) {
          currentType = _SectionType.metrics;
        } else if (cleanTitle.contains('خطة') || cleanTitle.contains('عمل')) {
          currentType = _SectionType.actionPlan;
        } else if (cleanTitle.contains('تحذير') || cleanTitle.contains('خطر')) {
          currentType = _SectionType.warnings;
        } else {
          currentType = _SectionType.normal;
        }
        continue;
      }

      if (line.isNotEmpty) {
        currentLines.add(rawLine);
      }
    }
    commit();
    return result;
  }

  Widget _buildSectionWidget(BuildContext context, _ParsedSection sec) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // أ. كارت "القرار الحاسم" العلوي
    if (sec.type == _SectionType.decision) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF43F5E).withOpacity(isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF43F5E).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.gavel_rounded,
                  color: Color(0xFFF43F5E), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'القرار الإداري الحاسم',
                    style: TextStyle(
                      color: Color(0xFFF43F5E),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText.rich(
                    _formatInlineMarkdown(
                      sec.contentLines.join(' '),
                      context,
                      defaultColor: theme.colorScheme.onSurface,
                    ),
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // تحديد ألوان وأيقونات الأقسام
    Color accentColor;
    IconData icon;
    switch (sec.type) {
      case _SectionType.summary:
        accentColor = const Color(0xFF0EA5E9);
        icon = Icons.summarize_rounded;
        break;
      case _SectionType.metrics:
        accentColor = const Color(0xFF10B981);
        icon = Icons.analytics_rounded;
        break;
      case _SectionType.actionPlan:
        accentColor = const Color(0xFFA855F7);
        icon = Icons.checklist_rounded;
        break;
      case _SectionType.warnings:
        accentColor = const Color(0xFFF59E0B);
        icon = Icons.warning_amber_rounded;
        break;
      default:
        accentColor = const Color(0xFF38BDF8);
        icon = Icons.article_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D31) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس القسم
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  sec.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
          // محتوى القسم
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sec.contentLines
                  .map((l) => _buildLineWidget(context, l))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineWidget(BuildContext context, String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return const SizedBox(height: 4);

    // إذا كان بنداً مرقماً (مثل: 1. أو 2.)
    final numberMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
    if (numberMatch != null) {
      final numStr = numberMatch.group(1)!;
      final rest = numberMatch.group(2)!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFA855F7).withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Text(
                numStr,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFA855F7),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SelectableText.rich(
                _formatInlineMarkdown(rest, context),
                style: const TextStyle(fontSize: 12.8, height: 1.55),
              ),
            ),
          ],
        ),
      );
    }

    // إذا كان بند نقطي (- أو *)
    if (trimmed.startsWith('-') || trimmed.startsWith('*')) {
      final isSubItem = line.startsWith('  ') || line.startsWith('\t');
      final content = trimmed.replaceAll(RegExp(r'^[-*]\s*'), '');

      return Padding(
        padding: EdgeInsets.only(right: isSubItem ? 20.0 : 6.0, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: isSubItem ? Colors.grey : const Color(0xFF0EA5E9),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText.rich(
                _formatInlineMarkdown(content, context),
                style: TextStyle(
                  fontSize: isSubItem ? 12.2 : 12.8,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // فقرة عادية
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SelectableText.rich(
        _formatInlineMarkdown(trimmed, context),
        style: const TextStyle(fontSize: 12.8, height: 1.55),
      ),
    );
  }

  // تحويل تنسيقات الماركداون العادية (** للخط العريض، والرموز البرمجية) إلى TextSpan ملون
  TextSpan _formatInlineMarkdown(String text, BuildContext context,
      {Color? defaultColor}) {
    final theme = Theme.of(context);
    final baseColor = defaultColor ?? theme.colorScheme.onSurface;

    // تنظيف علامات الدولار الخاصة بالمعادلات الرياضية لتظهر مرتبة
    final clean = text.replaceAll(r'$', '');

    final spans = <InlineSpan>[];
    final regex = RegExp(r'(\*\*[^*]+\*\*|`[^`]+`)');
    int lastIndex = 0;

    for (final match in regex.allMatches(clean)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: clean.substring(lastIndex, match.start),
          style: TextStyle(color: baseColor),
        ));
      }

      final matchedStr = match.group(0)!;
      if (matchedStr.startsWith('**') && matchedStr.endsWith('**')) {
        // نص عريض
        final boldContent = matchedStr.substring(2, matchedStr.length - 2);
        spans.add(TextSpan(
          text: boldContent,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
        ));
      } else if (matchedStr.startsWith('`') && matchedStr.endsWith('`')) {
        // نص برمجي / كود أو اسم حساب
        final codeContent = matchedStr.substring(1, matchedStr.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
              border:
                  Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
            ),
            child: Text(
              codeContent,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF38BDF8),
              ),
            ),
          ),
        ));
      }
      lastIndex = match.end;
    }

    if (lastIndex < clean.length) {
      spans.add(TextSpan(
        text: clean.substring(lastIndex),
        style: TextStyle(color: baseColor),
      ));
    }

    return TextSpan(children: spans);
  }
}

enum _SectionType { normal, decision, summary, metrics, actionPlan, warnings }

class _ParsedSection {
  final String title;
  final _SectionType type;
  final List<String> contentLines;

  _ParsedSection({
    required this.title,
    required this.type,
    required this.contentLines,
  });
}
