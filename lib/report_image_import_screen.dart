import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:amazon_affiliate_erp/app_table_scroll_wrapper.dart';
import 'package:amazon_affiliate_erp/campaign_report_mapper.dart';
import 'package:amazon_affiliate_erp/gemini_report_extractor.dart';
import 'package:image/image.dart' as img;
import 'package:pasteboard/pasteboard.dart';
import 'package:amazon_affiliate_erp/report_backend_launcher.dart';
import 'package:amazon_affiliate_erp/report_image_models.dart';

export 'package:amazon_affiliate_erp/report_image_models.dart';

const _reportExtractorBaseUrl = 'http://127.0.0.1:8765';

class ReportComparison {
  ReportComparison({
    required List<String> currentColumns,
    required List<List<String>> currentRows,
    required ExtractedReport importedReport,
  })  : _currentRows = currentRows,
        _importedRows = importedReport.rows,
        _importedColumnIndexes = _indexColumns(importedReport.columns),
        _currentColumnIndexes = _indexColumns(currentColumns) {
    missingColumns = currentColumns
        .where(
          (column) =>
              !_importedColumnIndexes.containsKey(column.trim().toLowerCase()),
        )
        .toSet();
    extraColumns = importedReport.columns
        .where(
          (column) =>
              !_currentColumnIndexes.containsKey(column.trim().toLowerCase()),
        )
        .toSet();

    var changedCells = 0;
    var changedRows = 0;
    final comparableRows = _currentRows.length < _importedRows.length
        ? _currentRows.length
        : _importedRows.length;
    for (var rowIndex = 0; rowIndex < comparableRows; rowIndex++) {
      var rowChanged = false;
      for (final entry in _currentColumnIndexes.entries) {
        final importedColumnIndex = _importedColumnIndexes[entry.key];
        if (importedColumnIndex == null) continue;
        final currentColumnIndex = entry.value;
        final currentRow = _currentRows[rowIndex];
        final importedRow = _importedRows[rowIndex];
        final currentValue = currentColumnIndex < currentRow.length
            ? currentRow[currentColumnIndex].trim()
            : '';
        final importedValue = importedColumnIndex < importedRow.length
            ? importedRow[importedColumnIndex].trim()
            : '';
        if (currentValue != importedValue) {
          changedCells++;
          rowChanged = true;
        }
      }
      if (rowChanged) changedRows++;
    }
    differingCells = changedCells;
    differingRows = changedRows;
    currentOnlyRows = _currentRows.length - comparableRows;
    importedOnlyRows = _importedRows.length - comparableRows;
  }

  final List<List<String>> _currentRows;
  final List<List<String>> _importedRows;
  final Map<String, int> _currentColumnIndexes;
  final Map<String, int> _importedColumnIndexes;
  late final Set<String> missingColumns;
  late final Set<String> extraColumns;
  late final int differingCells;
  late final int differingRows;
  late final int currentOnlyRows;
  late final int importedOnlyRows;

  static Map<String, int> _indexColumns(List<String> columns) {
    final indexes = <String, int>{};
    for (var index = 0; index < columns.length; index++) {
      indexes.putIfAbsent(columns[index].trim().toLowerCase(), () => index);
    }
    return indexes;
  }

  bool cellDiffers(int rowIndex, int columnIndex) {
    if (rowIndex >= _currentRows.length ||
        rowIndex >= _importedRows.length ||
        columnIndex >= _currentRows[rowIndex].length) {
      return true;
    }
    String? columnName;
    for (final entry in _currentColumnIndexes.entries) {
      if (entry.value == columnIndex) {
        columnName = entry.key;
        break;
      }
    }
    if (columnName == null) return true;
    final importedColumnIndex = _importedColumnIndexes[columnName];
    if (importedColumnIndex == null) return true;
    final importedRow = _importedRows[rowIndex];
    if (importedColumnIndex >= importedRow.length) return true;
    return _currentRows[rowIndex][columnIndex].trim() !=
        importedRow[importedColumnIndex].trim();
  }

  bool rowDiffers(int rowIndex) {
    if (rowIndex >= _importedRows.length) return true;
    for (var columnIndex = 0;
        columnIndex < _currentRows[rowIndex].length;
        columnIndex++) {
      if (cellDiffers(rowIndex, columnIndex)) return true;
    }
    return false;
  }
}

class _ComparisonLegend extends StatelessWidget {
  const _ComparisonLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      );
}

class ReportImageRequestBody {
  ReportImageRequestBody._(this.bytes);

  final List<int> bytes;

  int get contentLength => bytes.length;

  factory ReportImageRequestBody.create({
    required List<int> imageBytes,
    required String mimeType,
    required ReportImageType reportType,
  }) {
    return ReportImageRequestBody._(
      utf8.encode(
        jsonEncode({
          'report_type': reportType.apiValue,
          'mime_type': mimeType,
          'image_base64': base64Encode(imageBytes),
        }),
      ),
    );
  }
}

class ReportExtractorHealth {
  const ReportExtractorHealth({
    required this.isAvailable,
    required this.engine,
    this.error,
  });

  final bool isAvailable;
  final String engine;
  final String? error;
}

class ReportImageImportService {
  ReportImageImportService({
    HttpClient? httpClient,
    this.baseUrl = _reportExtractorBaseUrl,
  }) : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  final String baseUrl;

  Future<ReportExtractorHealth> checkHealth() async {
    final uri = Uri.tryParse('$baseUrl/health');
    if (uri == null || !uri.hasAuthority || uri.scheme != 'http') {
      throw const FormatException('عنوان خدمة الاستخراج غير صالح.');
    }

    final request =
        await _httpClient.getUrl(uri).timeout(const Duration(seconds: 5));
    final response = await request.close().timeout(const Duration(seconds: 5));
    final responseBody = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 5));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('فحص الخدمة رجع HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic> || decoded['status'] != 'ok') {
      throw const FormatException('رد فحص الخدمة غير صحيح.');
    }
    final serviceVersion = decoded['service_version'];
    if (serviceVersion is! int || serviceVersion < 8) {
      throw const FormatException(
        'نسخة خدمة الخلفية قديمة. أوقفها بـ Ctrl+C ثم أعد تشغيل التطبيق أو backend\\run_report_extractor.ps1 لتفعيل سجل التشخيص.',
      );
    }
    return ReportExtractorHealth(
      isAvailable: decoded['available'] == true,
      engine: (decoded['engine'] ?? 'غير محدد').toString(),
      error: decoded['error']?.toString(),
    );
  }

  Future<ExtractedReport> extract({
    required List<int> imageBytes,
    required String mimeType,
    required ReportImageType reportType,
  }) async {
    final uri = Uri.tryParse('$baseUrl/v1/reports/extract-image');
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                (uri.host == '127.0.0.1' || uri.host == 'localhost')))) {
      throw const FormatException(
        'عنوان خدمة الاستخراج غير آمن. استخدم HTTPS أو الخدمة المحلية.',
      );
    }

    final request =
        await _httpClient.postUrl(uri).timeout(const Duration(seconds: 15));
    final requestBody = ReportImageRequestBody.create(
      imageBytes: imageBytes,
      mimeType: mimeType,
      reportType: reportType,
    );
    request.headers.contentType = ContentType.json;
    request.contentLength = requestBody.contentLength;
    request.add(requestBody.bytes);

    final response = await request.close().timeout(
          const Duration(seconds: 120),
        );
    final responseBody = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 120));
    Map<String, dynamic> responseJson;
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('صيغة رد الخدمة غير صحيحة.');
      }
      responseJson = decoded;
    } on FormatException {
      throw const FormatException(
        'تعذر قراءة رد خدمة الاستخراج. تحقق من تشغيل الخدمة المحلية.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = responseJson['error']?.toString();
      throw HttpException(
        message?.isNotEmpty == true
            ? message!
            : 'فشل الاستخراج (HTTP ${response.statusCode}).',
      );
    }
    return ExtractedReport.fromJson(responseJson);
  }

  void close() => _httpClient.close(force: true);
}

class ReportImageImportScreen extends StatefulWidget {
  const ReportImageImportScreen({
    super.key,
    this.onImportCampaigns,
    this.onImportAmazonEarnings,
  });

  /// Receives the parsed ad-campaign rows so the host app can add them to
  /// its daily campaign records.
  final Future<void> Function(List<ParsedCampaignRow> rows)? onImportCampaigns;

  /// Receives the parsed Amazon earnings rows so the host app can paste/apply
  /// them into the appropriate campaign(s) in the daily earnings log.
  final Future<void> Function(List<ParsedAmazonEarningsRow> rows)?
      onImportAmazonEarnings;

  @override
  State<ReportImageImportScreen> createState() =>
      _ReportImageImportScreenState();
}

class _ReportImageImportScreenState extends State<ReportImageImportScreen> {
  final ReportImageImportService _service = ReportImageImportService();
  final GeminiReportExtractor _geminiExtractor = GeminiReportExtractor();
  final GeminiApiKeyStore _geminiApiKeyStore = GeminiApiKeyStore();
  ReportExtractionMode _extractionMode = ReportExtractionMode.gemini;
  ReportImageType _reportType = ReportImageType.amazonEarnings;
  List<int>? _imageBytes;
  String? _imageName;
  String? _mimeType;
  ExtractedReport? _report;
  ExtractedReport? _importedReport;
  List<List<String>> _editedRows = [];
  String? _lastExportPath;
  String? _lastImportPath;
  bool _isLoading = false;
  String? _error;
  String _backendStatus = 'جارٍ فحص محرك OCR المحلي…';
  bool? _backendAvailable;
  List<String> _geminiProfileNames = [];
  String? _activeGeminiProfile;
  String? _geminiKeyStatus;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshGeminiKeyStatus());
  }

  Future<void> _refreshGeminiKeyStatus() async {
    try {
      final state = await _geminiApiKeyStore.readState();
      if (!mounted) return;
      setState(() {
        _geminiProfileNames = state.profiles.keys.toList()..sort();
        _activeGeminiProfile = state.activeName;
        _geminiKeyStatus = state.activeKey?.isNotEmpty == true
            ? 'المفتاح النشط: ${state.activeName}. ستُرسل الصورة إلى Google عند الاستخراج.'
            : 'أضف ملف مفتاح Gemini واختره. ستُرسل الصور إلى Google عند الاستخراج.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _geminiProfileNames = [];
        _activeGeminiProfile = null;
        _geminiKeyStatus = 'تعذر قراءة ملفات مفاتيح Gemini: $error';
      });
    }
  }

  Future<void> _configureGeminiKey({String? initialName}) async {
    final nameController = TextEditingController(text: initialName ?? '');
    final controller = TextEditingController();
    final profile = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          initialName == null ? 'إضافة ملف مفتاح Gemini' : 'تحديث مفتاح Gemini',
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'أدخل مفتاح API الخاص بك. يُحفظ محلياً بتشفير Windows، '
                'ولا يُضمّن في ملفات التطبيق. تذكّر أن مفتاح تطبيق سطح المكتب '
                'يمكن استخراجه من الجهاز، واستخدم مفتاحاً مقيّداً بحصة مناسبة.',
              ),
              const SizedBox(height: 12),
              const SelectableText(
                'إنشاء المفتاح: https://aistudio.google.com/apikey',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: initialName == null,
                decoration: const InputDecoration(
                  labelText: 'اسم الملف (مثل baynancish)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: initialName != null,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Gemini API key',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, (
              nameController.text.trim(),
              controller.text.trim(),
            )),
            child: const Text('حفظ الملف'),
          ),
        ],
      ),
    );
    nameController.dispose();
    controller.dispose();
    if (profile == null) return;

    try {
      await _geminiApiKeyStore.saveProfile(
        name: profile.$1,
        apiKey: profile.$2,
      );
      await _refreshGeminiKeyStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ ملف المفتاح محلياً بأمان.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _geminiKeyStatus = 'تعذر حفظ ملف المفتاح: $error');
    }
  }

  Future<void> _selectGeminiProfile(String? name) async {
    if (name == null) return;
    try {
      await _geminiApiKeyStore.selectProfile(name);
      await _refreshGeminiKeyStatus();
    } catch (error) {
      if (mounted) {
        setState(() => _geminiKeyStatus = 'تعذر اختيار الملف: $error');
      }
    }
  }

  Future<void> _deleteGeminiProfile() async {
    final name = _activeGeminiProfile;
    if (name == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف ملف مفتاح Gemini'),
        content: Text('هل تريد حذف المفتاح المحفوظ للملف "$name"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _geminiApiKeyStore.deleteProfile(name);
      await _refreshGeminiKeyStatus();
    } catch (error) {
      if (mounted) setState(() => _geminiKeyStatus = 'تعذر حذف الملف: $error');
    }
  }

  Future<void> _refreshBackendStatus({bool tryStartBackend = false}) async {
    if (tryStartBackend && Platform.isWindows) {
      await ReportBackendLauncher.instance.start();
    }
    try {
      final health = await _service.checkHealth();
      if (!mounted) return;
      setState(() {
        _backendAvailable = health.isAvailable;
        _backendStatus = health.isAvailable
            ? 'محرك OCR المحلي جاهز (${health.engine}). لا تُرسل الصورة إلى الإنترنت.'
            : health.error ?? 'محرك OCR المحلي غير جاهز.';
      });
    } on SocketException {
      if (mounted) {
        final startupError = ReportBackendLauncher.instance.lastStartError;
        setState(() {
          _backendAvailable = false;
          _backendStatus = startupError == null
              ? 'خدمة الخلفية غير متصلة على 127.0.0.1:8765. شغّل backend أولاً.'
              : 'خدمة الخلفية غير متصلة على 127.0.0.1:8765. $startupError';
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _backendAvailable = false;
          _backendStatus = 'انتهت مهلة فحص خدمة الخلفية.';
        });
      }
    } on HttpException catch (error) {
      if (mounted) {
        setState(() {
          _backendAvailable = false;
          _backendStatus = error.message;
        });
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _backendAvailable = false;
          _backendStatus = error.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _backendAvailable = false;
          _backendStatus = 'تعذر فحص الخدمة المحلية: $error';
        });
      }
    }
  }

  Future<Uint8List> _encodeClipboardImageAsPng(Uint8List bytes) async {
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) {
      throw const FormatException('تعذر قراءة الصورة المنسوخة من الحافظة.');
    }
    return Uint8List.fromList(img.encodePng(decodedImage));
  }

  void _setSelectedImage({
    required Uint8List bytes,
    required String name,
    required String mimeType,
  }) {
    setState(() {
      _imageBytes = bytes;
      _imageName = name;
      _mimeType = mimeType;
      _report = null;
      _editedRows = [];
      _error = null;
    });
  }

  Future<void> _pasteImageFromClipboard() async {
    if (_isLoading) return;
    try {
      final clipboardImage = await Pasteboard.image;
      if (clipboardImage == null || clipboardImage.isEmpty) {
        await _pasteReportFromClipboard();
        return;
      }
      if (clipboardImage.length > 50 * 1024 * 1024) {
        throw const FormatException('حجم صورة الحافظة كبير جداً.');
      }

      final pngBytes = await _encodeClipboardImageAsPng(clipboardImage);
      if (pngBytes.length > 10 * 1024 * 1024) {
        throw const FormatException(
          'حجم الصورة بعد تجهيزها يتجاوز الحد المسموح (10 MB).',
        );
      }
      if (!mounted) return;
      _setSelectedImage(
        bytes: pngBytes,
        name: 'لقطة الحافظة.png',
        mimeType: 'image/png',
      );
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.message ?? 'تعذر قراءة الصورة من الحافظة.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر لصق صورة الحافظة: $error');
    }
  }

  @override
  void dispose() {
    _service.close();
    _geminiExtractor.close();
    super.dispose();
  }

  Future<void> _selectImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final extension = file.extension?.toLowerCase();
      final mimeType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };
      if (mimeType == null) {
        throw const FormatException('اختر صورة PNG أو JPG أو WEBP.');
      }
      if (file.size > 10 * 1024 * 1024) {
        throw const FormatException('حجم الصورة يتجاوز الحد المسموح (10 MB).');
      }
      final bytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('تعذر قراءة ملف الصورة.');
      }

      _setSelectedImage(
        bytes: Uint8List.fromList(bytes),
        name: file.name,
        mimeType: mimeType,
      );
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    } on FileSystemException catch (error) {
      setState(() => _error = 'تعذر قراءة الصورة: ${error.message}');
    } catch (error) {
      setState(() => _error = 'تعذر اختيار الصورة: $error');
    }
  }

  Future<void> _extract() async {
    final bytes = _imageBytes;
    final mimeType = _mimeType;
    if (bytes == null || mimeType == null || _isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _report = null;
      _editedRows = [];
    });

    try {
      late final ExtractedReport report;
      if (_extractionMode == ReportExtractionMode.gemini) {
        var state = await _geminiApiKeyStore.readState();
        if (state.activeKey?.trim().isNotEmpty != true) {
          await _configureGeminiKey();
          state = await _geminiApiKeyStore.readState();
        }
        if (state.activeKey?.trim().isNotEmpty != true) return;
        report = await _geminiExtractor.extract(
          apiKey: state.activeKey!,
          imageBytes: bytes,
          mimeType: mimeType,
          reportType: _reportType,
          onRetry: (attempt, max, wait) {
            if (!mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    'Gemini مزدحم — إعادة المحاولة تلقائياً بعد '
                    '${wait.inSeconds} ث (المحاولة $attempt من $max)',
                  ),
                  duration: wait,
                ),
              );
          },
        );
      } else {
        report = await _service.extract(
          imageBytes: bytes,
          mimeType: mimeType,
          reportType: _reportType,
        );
      }
      if (!mounted) return;
      setState(() {
        _report = report;
        _editedRows = report.rows.map((row) => [...row]).toList();
      });
    } on SocketException catch (error) {
      if (mounted) {
        final startupError = ReportBackendLauncher.instance.lastStartError;
        final startupHint = startupError == null ? '' : ' ($startupError)';
        setState(() {
          _error = 'انقطع اتصال التطبيق بالخدمة المحلية أثناء الطلب. '
              'رسالة النظام: ${error.message}. '
              'تحقق من تشغيل خدمة OCR المحلية ثم اضغط فحص الاتصال.$startupHint';
        });
        unawaited(_refreshBackendStatus(tryStartBackend: true));
      }
    } on HttpException catch (error) {
      if (mounted) {
        final isClosedConnection = error.message.toLowerCase().contains(
              'connection closed before full header',
            );
        setState(() {
          _error = isClosedConnection
              ? 'أغلقت خدمة OCR الاتصال قبل إرسال الرد. '
                  'أعد تشغيل التطبيق ثم جرّب مرة واحدة؛ إذا تكرر الخطأ '
                  'أرسل سجل التشخيص من '
                  r'%LOCALAPPDATA%\AmazonAffiliateERP\logs\report_extractor.log'
              : error.message;
        });
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on TimeoutException {
      if (mounted) {
        setState(() => _error = 'انتهت مهلة استخراج الصورة. حاول مرة أخرى.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'فشل استخراج الصورة: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _copyToClipboard() async {
    final report = _report;
    if (report == null || _editedRows.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: report.toTsv(_editedRows)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الجدول مع العناوين (TSV) إلى الحافظة.'),
      ),
    );
  }

  Future<void> _copyAmazonEarningsForSheet() async {
    final report = _report;
    if (report == null || _editedRows.isEmpty) return;
    try {
      final parsedRows = parseAmazonEarningsRows(report.columns, _editedRows);
      if (parsedRows.isEmpty) {
        throw const FormatException('لا توجد صفوف أرباح صالحة للنسخ.');
      }
      final tsv = formatAmazonEarningsForSheetTsv(parsedRows);
      await Clipboard.setData(ClipboardData(text: tsv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم نسخ صف الأرباح بالترتيب المطابق للأرباح (بدون عناوين: من النقرات إلى المكافآت). '
            'قف على خلية "النقرات" في الشيت واضغط Ctrl+V، أو الصقها مباشرة داخل شاشة الأرباح ✅',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } on FormatException catch (_) {
      await Clipboard.setData(
        ClipboardData(text: report.toRowsOnlyTsv(_editedRows)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ الصفوف بدون عناوين إلى الحافظة.')),
      );
    }
  }

  Future<void> _pasteReportFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text;
      if (text == null || text.trim().isEmpty) {
        throw const FormatException('الحافظة لا تحتوي على بيانات نصية.');
      }

      final copiedAmazonReport = _reportType == ReportImageType.amazonEarnings
          ? parseAmazonAssociatesClipboardReport(text)
          : null;
      late ExtractedReport report;
      if (_reportType == ReportImageType.adCampaigns &&
          RegExp(r'Name\s+Folders').hasMatch(text)) {
        final campaigns = parsePropellerCampaignClipboard(text);
        report = ExtractedReport(
          title: 'PropellerAds — إحصائيات يومية',
          columns: const ['تاريخ الإحصائيات', 'اسم الحملة', 'التكلفة'],
          rows: campaigns
              .map((r) => [r.date, r.campaignName, r.cost.toStringAsFixed(3)])
              .toList(),
          warnings: const [
            'التكلفة من Cost؛ الرصيد وCPM والميزانية ليست مصروفات. لا يتضمن النص عنوان نقرات موثوقاً؛ لن تتغير نقرات أمازون.',
          ],
        );
      } else if (copiedAmazonReport != null) {
        final columns = [
          'Date',
          'StoreID',
          'Clicks',
          'Ordered Items',
          'Conversion',
          'Ordered Revenue',
          'Shipped Items',
          'Returned Items',
          'Total Revenue',
          'Commission',
          'Bonus',
        ];
        report = ExtractedReport(
          title: 'Amazon Associates summary (clipboard)',
          columns: columns,
          rows: [
            [
              copiedAmazonReport.date ?? '',
              copiedAmazonReport.label,
              ...copiedAmazonReport.toSheetTsvRow().split('\t'),
            ],
          ],
          warnings: const [
            'تم استخراج القيم من النص المنسوخ بقواعد محلية، دون OCR أو إرسال إلى Gemini. راجع القيم قبل اعتمادها.',
          ],
        );
      } else {
        try {
          final candidate = ExtractedReport.fromDelimitedText(
            text,
            delimiter: text.contains('\t') ? '\t' : ',',
          );
          if (candidate.rows.isEmpty ||
              candidate.columns.any((column) => column.trim().isEmpty)) {
            throw const FormatException('بدون عناوين');
          }
          report = candidate;
        } on FormatException catch (_) {
          // Accept the app's own headerless earnings TSV as well.
          final earningsRows = parseAmazonEarningsFromClipboardText(text);
          report = ExtractedReport(
            title: 'بيانات أرباح أمازون من الحافظة',
            columns: const [
              'النقرات (Clicks)',
              'الطلبات المسجلة (Ordered Items)',
              'نسبة التحويل (Conversion %)',
              'قيمة الطلبات المقدرة (Ordered Revenue)',
              'المنتجات المشحونة (Shipped Items)',
              'المنتجات المرتجعة (Returned Items)',
              'إجمالي قيمة المبيعات (Total Revenue)',
              'عمولات أمازون (Commission)',
              'المكافآت الإضافية (Bonus)',
            ],
            rows:
                earningsRows.map((r) => r.toSheetTsvRow().split('\t')).toList(),
            warnings: const [],
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _report = report;
        _editedRows = report.rows.map((row) => [...row]).toList();
        _importedReport = null;
        _lastImportPath = null;
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم استبدال الجدول بـ ${report.rows.length} صف و'
            '${report.columns.length} عمود.',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _error = error.message ?? 'تعذرت قراءة نص الحافظة.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر لصق الجدول: $error');
    }
  }

  Future<void> _exportReport({required String format}) async {
    final report = _report;
    if (report == null || _editedRows.isEmpty) return;

    final extension = format.toLowerCase();
    final text =
        format == 'csv' ? report.toCsv(_editedRows) : report.toTsv(_editedRows);
    final safeTitle = report.title
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    final fileName =
        '${safeTitle.isEmpty ? 'report' : safeTitle}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    final defaultFolder = Directory(
      '${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.'}${Platform.pathSeparator}Documents${Platform.pathSeparator}amazon_affiliate_erp_exports',
    );
    if (!defaultFolder.existsSync()) {
      await defaultFolder.create(recursive: true);
    }

    late final String path;
    final chosenPath = await FilePicker.platform.saveFile(
      type: FileType.custom,
      allowedExtensions: [extension],
      fileName: fileName,
      dialogTitle: 'حفظ $format',
    );
    if (chosenPath != null && chosenPath.trim().isNotEmpty) {
      path = chosenPath;
    } else {
      path = '${defaultFolder.path}${Platform.pathSeparator}$fileName';
    }

    final exportFile = File(path);
    await exportFile.writeAsString(text, encoding: utf8);
    _lastExportPath = exportFile.path;

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('تم حفظ الملف: ${exportFile.path}')));
  }

  Future<void> _openExportFolder() async {
    final exportDirectory = _lastExportPath != null
        ? File(_lastExportPath!).parent
        : Directory(
            '${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.'}${Platform.pathSeparator}Documents${Platform.pathSeparator}amazon_affiliate_erp_exports',
          );
    if (!exportDirectory.existsSync()) {
      await exportDirectory.create(recursive: true);
    }
    if (Platform.isWindows) {
      await Process.start('explorer.exe', [exportDirectory.path]);
      return;
    }
    await Process.start('open', [exportDirectory.path]);
  }

  Future<void> _importSpreadsheet() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'tsv', 'txt', 'xls', 'xlsx'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final path = file.path;
      if (path == null) {
        throw const FormatException('تعذر قراءة المسار المحلي للملف.');
      }
      _lastImportPath = path;

      final extension = file.extension?.toLowerCase();
      if (extension == 'xls' || extension == 'xlsx') {
        if (Platform.isWindows) {
          await Process.start('explorer.exe', [path]);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم فتح الملف الخارجي. يمكن مقارنة محتواه يدويًا مع البيانات الحالية.',
            ),
          ),
        );
        return;
      }

      final text = await File(path).readAsString(encoding: utf8);
      final imported = ExtractedReport.fromDelimitedText(
        text,
        delimiter: extension == 'tsv' ? '\t' : ',',
      );

      if (!mounted) return;
      setState(() {
        _importedReport = imported;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم استيراد ${imported.columns.length} عموداً و${imported.rows.length} صفاً للمقارنة.',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'تعذر استيراد الملف: $error');
      }
    }
  }

  Future<void> _sendToCampaigns() async {
    final report = _report;
    final callback = widget.onImportCampaigns;
    if (report == null || callback == null) return;
    try {
      final rows = parseAdCampaignRows(
        report.columns,
        _editedRows,
        fallbackDate: DateTime.now().toIso8601String().substring(0, 10),
      );
      if (rows.isEmpty) {
        setState(() => _error = 'لا توجد صفوف صالحة للإضافة.');
        return;
      }
      await callback(rows);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _sendToAmazonEarnings() async {
    final report = _report;
    final callback = widget.onImportAmazonEarnings;
    if (report == null || callback == null) return;
    try {
      final rows = parseAmazonEarningsRows(report.columns, _editedRows);
      if (rows.isEmpty) {
        setState(() => _error = 'لا توجد صفوف أرباح صالحة للترحيل.');
        return;
      }
      await Clipboard.setData(
        ClipboardData(text: formatAmazonEarningsForSheetTsv(rows)),
      );
      await callback(rows);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  String _importComparisonSummary() {
    final importedReport = _importedReport;
    final report = _report;
    if (importedReport == null || report == null) {
      return 'لم يتم استيراد ملف للمقارنة.';
    }

    final comparison = ReportComparison(
      currentColumns: report.columns,
      currentRows: _editedRows,
      importedReport: importedReport,
    );
    return 'الصفوف المتطابقة: ${_editedRows.length - comparison.differingRows - comparison.currentOnlyRows} '
        '• الصفوف المختلفة: ${comparison.differingRows} '
        '• خلايا مختلفة: ${comparison.differingCells} '
        '• صفوف بلا مقابل في الملف: ${comparison.currentOnlyRows} '
        '• صفوف إضافية في الملف: ${comparison.importedOnlyRows} '
        '• أعمدة مفقودة: ${comparison.missingColumns.length} '
        '• أعمدة إضافية: ${comparison.extraColumns.length}';
  }

  void _clearImportedReport() {
    setState(() {
      _importedReport = null;
      _lastImportPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final comparison = _report != null && _importedReport != null
        ? ReportComparison(
            currentColumns: _report!.columns,
            currentRows: _editedRows,
            importedReport: _importedReport!,
          )
        : null;
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        final focusedWidget =
            FocusManager.instance.primaryFocus?.context?.widget;
        if (focusedWidget is EditableText) {
          return KeyEventResult.ignored;
        }
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyV &&
            HardwareKeyboard.instance.isControlPressed) {
          unawaited(_pasteImageFromClipboard());
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'استخراج بيانات التقارير من الصور',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'اختر لقطة شاشة التقطتها بنفسك من صفحة الأرباح أو الحملات، '
                  'استخرج القيم، راجعها ثم أكمل الاستيراد أو النسخ إلى الشيت.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (_extractionMode == ReportExtractionMode.gemini)
                  Card(
                    color: _activeGeminiProfile != null
                        ? colors.secondaryContainer
                        : colors.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _geminiKeyStatus ??
                                  'جارٍ فحص ملفات مفاتيح Gemini المحفوظة…',
                            ),
                          ),
                          if (_geminiProfileNames.isNotEmpty)
                            SizedBox(
                              width: 190,
                              child: DropdownButtonFormField<String>(
                                initialValue: _activeGeminiProfile,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'المفتاح النشط',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: _geminiProfileNames
                                    .map(
                                      (name) => DropdownMenuItem(
                                        value: name,
                                        child: Text(
                                          name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged:
                                    _isLoading ? null : _selectGeminiProfile,
                              ),
                            ),
                          TextButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => _configureGeminiKey(
                                      initialName: _activeGeminiProfile,
                                    ),
                            icon: const Icon(Icons.key_rounded),
                            label: const Text('إضافة / تحديث'),
                          ),
                          if (_activeGeminiProfile != null)
                            IconButton(
                              tooltip: 'حذف الملف النشط',
                              onPressed:
                                  _isLoading ? null : _deleteGeminiProfile,
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (_extractionMode == ReportExtractionMode.local)
                  Card(
                    color: _backendAvailable == true
                        ? colors.secondaryContainer
                        : _backendAvailable == false
                            ? colors.errorContainer
                            : colors.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(_backendStatus)),
                          IconButton(
                            tooltip: 'فحص الاتصال',
                            onPressed: _isLoading
                                ? null
                                : () => _refreshBackendStatus(
                                      tryStartBackend: true,
                                    ),
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _extractionMode == ReportExtractionMode.gemini
                          ? 'وضع Gemini السحابي: عند الاستخراج ستُرسل الصورة إلى Google عبر HTTPS. '
                              'قد تُطبّق رسوم أو حدود استخدام حسب إعدادات حسابك. '
                              'راجع النتائج قبل اعتمادها.'
                          : 'وضع OCR المحلي: تُعالج الصورة على هذا الجهاز عبر الخدمة المحلية، '
                              'ولا تُرسل إلى Google. راجع النتائج قبل اعتمادها.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<ReportExtractionMode>(
                          initialValue: _extractionMode,
                          decoration: const InputDecoration(
                            labelText: 'محرك استخراج البيانات',
                            border: OutlineInputBorder(),
                          ),
                          items: ReportExtractionMode.values
                              .map(
                                (mode) => DropdownMenuItem(
                                  value: mode,
                                  child: Text(mode.label),
                                ),
                              )
                              .toList(),
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => _extractionMode = value);
                                  if (value == ReportExtractionMode.local) {
                                    unawaited(
                                      _refreshBackendStatus(
                                        tryStartBackend: true,
                                      ),
                                    );
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<ReportImageType>(
                          initialValue: _reportType,
                          decoration: const InputDecoration(
                            labelText: 'نوع لقطة الشاشة',
                            border: OutlineInputBorder(),
                          ),
                          items: ReportImageType.values
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type.label),
                                ),
                              )
                              .toList(),
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() {
                                      _reportType = value;
                                      _report = null;
                                      _editedRows = [];
                                      _error = null;
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed:
                                  _isLoading ? null : _pasteImageFromClipboard,
                              icon: const Icon(Icons.content_paste_rounded),
                              label: const Text('لصق من الحافظة (Ctrl+V)'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _selectImage,
                              icon: const Icon(Icons.image_outlined),
                              label: Text(_imageName ?? 'اختيار لقطة شاشة'),
                            ),
                            FilledButton.icon(
                              onPressed: _isLoading || _imageBytes == null
                                  ? null
                                  : _extract,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.document_scanner_outlined),
                              label: Text(
                                _isLoading
                                    ? _extractionMode ==
                                            ReportExtractionMode.gemini
                                        ? 'جارٍ إرسال الصورة إلى Gemini…'
                                        : 'جارٍ الاستخراج محلياً…'
                                    : 'استخراج البيانات',
                              ),
                            ),
                            if (_report != null &&
                                _reportType == ReportImageType.adCampaigns &&
                                widget.onImportCampaigns != null)
                              FilledButton.icon(
                                onPressed: _sendToCampaigns,
                                icon: const Icon(Icons.playlist_add_rounded),
                                label: const Text('إرسال إلى الحملات اليومية'),
                              ),
                            if (_report != null &&
                                _reportType == ReportImageType.amazonEarnings &&
                                widget.onImportAmazonEarnings != null)
                              FilledButton.icon(
                                onPressed: _sendToAmazonEarnings,
                                icon: const Icon(
                                  Icons.assignment_returned_rounded,
                                ),
                                label: const Text(
                                  'لصق في المكان المناسب ضمن الأرباح',
                                ),
                              ),
                            if (_report != null &&
                                _reportType == ReportImageType.amazonEarnings)
                              FilledButton.tonalIcon(
                                onPressed: _copyAmazonEarningsForSheet,
                                icon: const Icon(Icons.table_rows_rounded),
                                label: const Text(
                                  'نسخ صف الأرباح فقط (للشيت والأرباح)',
                                ),
                              ),
                            if (_report != null) ...[
                              OutlinedButton.icon(
                                onPressed: _copyToClipboard,
                                icon: const Icon(Icons.content_copy_rounded),
                                label: const Text(
                                  'نسخ الجدول مع العناوين (TSV)',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _exportReport(format: 'csv'),
                                icon: const Icon(Icons.file_download_outlined),
                                label: const Text('تصدير CSV'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _exportReport(format: 'tsv'),
                                icon: const Icon(Icons.file_download_rounded),
                                label: const Text('تصدير TSV'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _openExportFolder,
                                icon: const Icon(Icons.folder_open_rounded),
                                label: const Text('فتح مجلد التصدير'),
                              ),
                            ],
                            OutlinedButton.icon(
                              onPressed: _importSpreadsheet,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('استيراد CSV/TSV/Excel'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pasteReportFromClipboard,
                              icon: const Icon(Icons.table_view_rounded),
                              label: const Text('لصق جدول من الحافظة'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_imageBytes != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _ZoomableImage(
                        bytes: Uint8List.fromList(_imageBytes!),
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: colors.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        _error!,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                  ),
                ],
                if (_report case final report?) ...[
                  const SizedBox(height: 16),
                  Text(
                    report.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (report.warnings.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...report.warnings.map(
                      (warning) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'مراجعة: $warning',
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (comparison != null) ...[
                    Card(
                      color: colors.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'نتيجة المقارنة',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'إزالة الملف المستورد',
                                  onPressed: _clearImportedReport,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            if (_lastImportPath != null)
                              Text(
                                'الملف: $_lastImportPath',
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            const SizedBox(height: 6),
                            Text(_importComparisonSummary()),
                            if (comparison.missingColumns.isNotEmpty)
                              Text(
                                'أعمدة غير موجودة في الملف: '
                                '${comparison.missingColumns.join('، ')}',
                              ),
                            if (comparison.extraColumns.isNotEmpty)
                              Text(
                                'أعمدة إضافية في الملف: '
                                '${comparison.extraColumns.join('، ')}',
                              ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                _ComparisonLegend(
                                  color: colors.errorContainer,
                                  label: 'خلية مختلفة أو بلا مقابل',
                                ),
                                _ComparisonLegend(
                                  color: colors.tertiaryContainer,
                                  label: 'صف موجود فقط في أحد الجدولين',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: AppTableScrollWrapper(
                      tableTitle: 'جدول التقرير المستخرج',
                      child: DataTable(
                        dataRowMinHeight: 64,
                        dataRowMaxHeight: 72,
                        columns: [
                          for (final column in report.columns)
                            DataColumn(label: Text(column)),
                        ],
                        rows: [
                          for (var rowIndex = 0;
                              rowIndex < _editedRows.length;
                              rowIndex++)
                            DataRow(
                              color: comparison == null ||
                                      !comparison.rowDiffers(rowIndex)
                                  ? null
                                  : WidgetStatePropertyAll(
                                      (rowIndex >= _importedReport!.rows.length
                                              ? colors.tertiaryContainer
                                              : colors.errorContainer)
                                          .withValues(alpha: 0.35),
                                    ),
                              cells: [
                                for (var columnIndex = 0;
                                    columnIndex < report.columns.length;
                                    columnIndex++)
                                  DataCell(
                                    Container(
                                      color: comparison?.cellDiffers(
                                                rowIndex,
                                                columnIndex,
                                              ) ??
                                              false
                                          ? colors.errorContainer.withValues(
                                              alpha: 0.55,
                                            )
                                          : null,
                                      padding: const EdgeInsets.all(4),
                                      child: SizedBox(
                                        width: 150,
                                        child: TextFormField(
                                          key: ValueKey(
                                            'report-${identityHashCode(_report)}-$rowIndex-$columnIndex',
                                          ),
                                          initialValue: _editedRows[rowIndex]
                                              [columnIndex],
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              _editedRows[rowIndex]
                                                  [columnIndex] = value;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (comparison != null &&
                      comparison.importedOnlyRows > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      'صفوف إضافية في الملف المستورد',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Card(
                      color: colors.tertiaryContainer.withValues(alpha: 0.45),
                      clipBehavior: Clip.antiAlias,
                      child: AppTableScrollWrapper(
                        tableTitle: 'صفوف إضافية في الملف المستورد',
                        child: DataTable(
                          columns: [
                            const DataColumn(label: Text('الصف')),
                            for (final column in _importedReport!.columns)
                              DataColumn(label: Text(column)),
                          ],
                          rows: [
                            for (var rowIndex = _editedRows.length;
                                rowIndex < _importedReport!.rows.length;
                                rowIndex++)
                              DataRow(
                                cells: [
                                  DataCell(Text('${rowIndex + 1}')),
                                  for (final value
                                      in _importedReport!.rows[rowIndex])
                                    DataCell(Text(value)),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (comparison != null && comparison.currentOnlyRows > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${comparison.currentOnlyRows} صف/صفوف في التقرير الحالي '
                        'لا يقابلها صف في الملف المستورد.',
                        style: TextStyle(color: colors.tertiary),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'راجع الأرقام يدوياً قبل اللصق. سيتم نسخ العناوين والصفوف الظاهرة بصيغة TSV.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 120),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.bytes});
  final Uint8List bytes;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _controller = TransformationController();
  double _height = 360;
  bool _ctrlDown = false;

  @override
  void initState() {
    super.initState();
    _ctrlDown = HardwareKeyboard.instance.isControlPressed;
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  bool _onKey(KeyEvent event) {
    final down = HardwareKeyboard.instance.isControlPressed;
    if (down != _ctrlDown && mounted) setState(() => _ctrlDown = down);
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _controller.dispose();
    super.dispose();
  }

  void _zoomBy(double factor) {
    final current = _controller.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(1.0, 8.0);
    final ratio = target / current;
    final size = context.size ?? const Size(400, 360);
    final center = Offset(size.width / 2, _height / 2);
    final m = _controller.value.clone();
    m.translate(center.dx, center.dy);
    m.scale(ratio, ratio);
    m.translate(-center.dx, -center.dy);
    _controller.value = m;
  }

  void _reset() => _controller.value = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.image_search_rounded, size: 18),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'اسحب لتحريك الصورة • Ctrl + عجلة الماوس للتكبير • نقر مزدوج للإعادة',
                style: TextStyle(fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: 'تصغير',
              icon: const Icon(Icons.zoom_out_rounded, size: 20),
              onPressed: () => _zoomBy(1 / 1.25),
            ),
            IconButton(
              tooltip: 'تكبير',
              icon: const Icon(Icons.zoom_in_rounded, size: 20),
              onPressed: () => _zoomBy(1.25),
            ),
            IconButton(
              tooltip: 'إعادة الضبط',
              icon: const Icon(Icons.fit_screen_rounded, size: 20),
              onPressed: _reset,
            ),
            IconButton(
              tooltip: 'زيادة ارتفاع العرض',
              icon: const Icon(Icons.unfold_more_rounded, size: 20),
              onPressed: () =>
                  setState(() => _height = (_height + 120).clamp(240, 840)),
            ),
            IconButton(
              tooltip: 'تقليل ارتفاع العرض',
              icon: const Icon(Icons.unfold_less_rounded, size: 20),
              onPressed: () =>
                  setState(() => _height = (_height - 120).clamp(240, 840)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: _height,
            child: GestureDetector(
              onDoubleTap: _reset,
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 1.0,
                maxScale: 8.0,
                scaleEnabled: _ctrlDown,
                constrained: true,
                child: Image.memory(
                  widget.bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text(
                      'تعذر عرض الصورة المختارة.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
