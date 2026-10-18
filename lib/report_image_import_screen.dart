import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:amazon_affiliate_erp/campaign_report_mapper.dart';
import 'package:amazon_affiliate_erp/gemini_api_key_vault.dart';
import 'package:image/image.dart' as img;
import 'package:pasteboard/pasteboard.dart';

const _reportExtractorBaseUrl = 'http://127.0.0.1:8765';

enum ReportImageType {
  amazonEarnings('amazon_earnings', 'أرباح Amazon'),
  adCampaigns('ad_campaigns', 'تقرير الحملات الإعلانية');

  const ReportImageType(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class ExtractedReport {
  const ExtractedReport({
    required this.title,
    required this.columns,
    required this.rows,
    required this.warnings,
  });

  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  final List<String> warnings;

  factory ExtractedReport.fromJson(Map<String, dynamic> json) {
    final columnsValue = json['columns'];
    final rowsValue = json['rows'];
    if (columnsValue is! List || rowsValue is! List) {
      throw const FormatException('استجابة Gemini لا تحتوي أعمدة وصفوفاً.');
    }

    final columns = columnsValue.map((value) => value.toString()).toList();
    if (columns.isEmpty) {
      throw const FormatException('لم يتم استخراج أعمدة من الصورة.');
    }
    final rows = <List<String>>[];
    for (final rowValue in rowsValue) {
      if (rowValue is! List) {
        throw const FormatException('صيغة أحد صفوف التقرير غير صحيحة.');
      }
      final row = rowValue.map((value) => value?.toString() ?? '').toList();
      if (row.length != columns.length) {
        throw const FormatException(
          'عدد خلايا أحد الصفوف لا يطابق عدد الأعمدة.',
        );
      }
      rows.add(row);
    }
    if (rows.isEmpty) {
      throw const FormatException('لم يتم استخراج أي صف من الصورة.');
    }

    final warningValue = json['warnings'];
    return ExtractedReport(
      title: (json['title'] ?? 'نتيجة استخراج التقرير').toString(),
      columns: columns,
      rows: rows,
      warnings: warningValue is List
          ? warningValue.map((value) => value.toString()).toList()
          : const [],
    );
  }

  String toTsv(List<List<String>> editedRows) {
    String cleanCell(String value) =>
        value.replaceAll(RegExp(r'[\t\r\n]+'), ' ').trim();
    return [
      columns.map(cleanCell).join('\t'),
      ...editedRows.map((row) => row.map(cleanCell).join('\t')),
    ].join('\r\n');
  }

  String toCsv(List<List<String>> editedRows) {
    final rows = [
      columns.map(_quoteCsvCell).join(','),
      ...editedRows.map((row) => row.map(_quoteCsvCell).join(',')),
    ];
    return rows.join('\r\n');
  }

  static String _quoteCsvCell(String value) {
    final normalized = value.replaceAll('"', '""');
    if (normalized.contains(',') ||
        normalized.contains('"') ||
        normalized.contains('\n') ||
        normalized.contains('\r')) {
      return '"$normalized"';
    }
    return normalized;
  }

  factory ExtractedReport.fromDelimitedText(String text,
      {required String delimiter}) {
    final sanitized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = sanitized
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      throw const FormatException('الملف المستورد فارغ.');
    }

    final columns = _splitDelimitedLine(lines.first, delimiter: delimiter);
    final rows = <List<String>>[];
    for (var i = 1; i < lines.length; i++) {
      final row = _splitDelimitedLine(lines[i], delimiter: delimiter);
      if (row.length != columns.length) {
        throw const FormatException(
            'عدد أعمدة الملف المستورد لا يطابق الصفوف.');
      }
      rows.add(row);
    }

    return ExtractedReport(
      title: 'استيراد ملف',
      columns: columns,
      rows: rows,
      warnings: const [],
    );
  }

  static List<String> _splitDelimitedLine(String line,
      {required String delimiter}) {
    if (delimiter.isEmpty) {
      return [line];
    }

    final cells = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (char == '"') {
        if (inQuotes && index + 1 < line.length && line[index + 1] == '"') {
          buffer.write('"');
          index++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        cells.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    cells.add(buffer.toString());
    return cells;
  }
}

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
          (column) => !_importedColumnIndexes.containsKey(
            column.trim().toLowerCase(),
          ),
        )
        .toSet();
    extraColumns = importedReport.columns
        .where(
          (column) => !_currentColumnIndexes.containsKey(
            column.trim().toLowerCase(),
          ),
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
    required this.model,
  });

  final bool isAvailable;
  final String model;
}

class ReportImageImportService {
  ReportImageImportService({
    HttpClient? httpClient,
    this.baseUrl = _reportExtractorBaseUrl,
  }) : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  final String baseUrl;

  static Map<String, String> authenticationHeaders(String apiKey) {
    final normalized = apiKey.trim();
    if (normalized.isEmpty || normalized.contains(RegExp(r'[\r\n\t]'))) {
      throw const FormatException('اختر مفتاح Gemini صالحاً قبل التحليل.');
    }
    return {'X-Gemini-API-Key': normalized};
  }

  Future<ReportExtractorHealth> checkHealth() async {
    final uri = Uri.tryParse('$baseUrl/health');
    if (uri == null || !uri.hasAuthority || uri.scheme != 'http') {
      throw const FormatException('عنوان خدمة الاستخراج غير صالح.');
    }

    final request =
        await _httpClient.getUrl(uri).timeout(const Duration(seconds: 5));
    final response = await request.close().timeout(
          const Duration(seconds: 5),
        );
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
    if (decoded['service_version'] != 5) {
      throw const FormatException(
        'نسخة خدمة الخلفية قديمة. أوقفها بـ Ctrl+C ثم أعد تشغيل run_report_extractor.ps1.',
      );
    }
    return ReportExtractorHealth(
      isAvailable: true,
      model: (decoded['model'] ?? 'غير محدد').toString(),
    );
  }

  Future<ExtractedReport> extract({
    required List<int> imageBytes,
    required String mimeType,
    required ReportImageType reportType,
    required String apiKey,
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

    final headers = authenticationHeaders(apiKey);
    final request =
        await _httpClient.postUrl(uri).timeout(const Duration(seconds: 15));
    final requestBody = ReportImageRequestBody.create(
      imageBytes: imageBytes,
      mimeType: mimeType,
      reportType: reportType,
    );
    request.headers.contentType = ContentType.json;
    for (final header in headers.entries) {
      request.headers.set(header.key, header.value);
    }
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
  const ReportImageImportScreen({super.key, this.onImportCampaigns});

  /// Receives the parsed ad-campaign rows so the host app can add them to
  /// its daily campaign records.
  final Future<void> Function(List<ParsedCampaignRow> rows)? onImportCampaigns;

  @override
  State<ReportImageImportScreen> createState() =>
      _ReportImageImportScreenState();
}

class _ReportImageImportScreenState extends State<ReportImageImportScreen> {
  final ReportImageImportService _service = ReportImageImportService();
  final GeminiApiKeyVault _keyVault = GeminiApiKeyVault();
  ReportImageType _reportType = ReportImageType.amazonEarnings;
  GeminiApiKeyCollection _keyCollection =
      const GeminiApiKeyCollection(keys: [], activeId: null);
  List<int>? _imageBytes;
  String? _imageName;
  String? _mimeType;
  ExtractedReport? _report;
  ExtractedReport? _importedReport;
  List<List<String>> _editedRows = [];
  String? _lastExportPath;
  String? _lastImportPath;
  bool _hasConsent = false;
  bool _isLoading = false;
  bool _isKeyVaultLoading = true;
  String? _error;
  String? _keyError;
  String _backendStatus = 'جارٍ فحص خدمة Gemini المحلية…';
  bool? _backendAvailable;

  @override
  void initState() {
    super.initState();
    unawaited(_loadGeminiKeys());
    unawaited(_refreshBackendStatus());
  }

  Future<void> _loadGeminiKeys() async {
    try {
      final collection = await _keyVault.load();
      if (!mounted) return;
      setState(() {
        _keyCollection = collection;
        _isKeyVaultLoading = false;
        _keyError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isKeyVaultLoading = false;
        _keyError = 'تعذر قراءة مخزن مفاتيح Gemini الآمن: $error';
      });
    }
  }

  Future<void> _addGeminiKey() async {
    final nameController = TextEditingController();
    final keyController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('إضافة مفتاح Gemini'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'اسم تعريفي',
                      hintText: 'مثال: المفتاح الأساسي',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'أدخل اسماً للمفتاح.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: keyController,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Gemini API key',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final key = value?.trim() ?? '';
                      if (key.isEmpty) return 'أدخل المفتاح.';
                      if (key.contains('\r') || key.contains('\n')) {
                        return 'تحقق من قيمة المفتاح.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'يُحفظ المفتاح مشفراً على هذا الجهاز ولا يظهر كاملاً بعد الحفظ.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('حفظ بأمان'),
            ),
          ],
        ),
      );
      if (shouldSave != true || !mounted) return;
      final collection = await _keyVault.add(
        name: nameController.text,
        secret: keyController.text,
      );
      if (!mounted) return;
      setState(() {
        _keyCollection = collection;
        _keyError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _keyError = 'تعذر حفظ مفتاح Gemini بأمان: $error');
    } finally {
      nameController.dispose();
      keyController.dispose();
    }
  }

  Future<void> _selectGeminiKey(String? id) async {
    if (id == null || id == _keyCollection.activeId) return;
    try {
      final collection = await _keyVault.select(id);
      if (!mounted) return;
      setState(() {
        _keyCollection = collection;
        _keyError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _keyError = 'تعذر تبديل مفتاح Gemini: $error');
      }
    }
  }

  Future<void> _removeActiveGeminiKey() async {
    final activeKey = _keyCollection.activeKey;
    if (activeKey == null) return;
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف مفتاح Gemini؟'),
        content: Text('سيتم حذف "${activeKey.name}" من التخزين الآمن.'),
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
    if (shouldRemove != true) return;
    try {
      final collection = await _keyVault.remove(activeKey.id);
      if (!mounted) return;
      setState(() {
        _keyCollection = collection;
        _keyError = null;
      });
    } catch (error) {
      if (mounted) setState(() => _keyError = 'تعذر حذف مفتاح Gemini: $error');
    }
  }

  Future<void> _refreshBackendStatus() async {
    try {
      final health = await _service.checkHealth();
      if (!mounted) return;
      setState(() {
        _backendAvailable = health.isAvailable;
        _backendStatus = 'الخدمة المحلية متصلة (النموذج: ${health.model}). '
            'يُستخدم المفتاح النشط المحفوظ في التطبيق.';
      });
    } on SocketException {
      if (mounted) {
        setState(() {
          _backendAvailable = false;
          _backendStatus =
              'خدمة الخلفية غير متصلة على 127.0.0.1:8765. شغّل backend أولاً.';
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
      _hasConsent = false;
    });
  }

  Future<void> _pasteImageFromClipboard() async {
    if (_isLoading) return;
    try {
      final clipboardImage = await Pasteboard.image;
      if (clipboardImage == null || clipboardImage.isEmpty) {
        setState(() {
          _error =
              'لا توجد صورة في الحافظة. اضغط Print Screen أولاً ثم حاول اللصق.';
        });
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
            () => _error = error.message ?? 'تعذر قراءة الصورة من الحافظة.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر لصق صورة الحافظة: $error');
    }
  }

  @override
  void dispose() {
    _service.close();
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
    final apiKey = _keyCollection.activeKey?.secret;
    if (bytes == null ||
        mimeType == null ||
        apiKey == null ||
        !_hasConsent ||
        _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _report = null;
      _editedRows = [];
    });

    try {
      final report = await _service.extract(
        imageBytes: bytes,
        mimeType: mimeType,
        reportType: _reportType,
        apiKey: apiKey,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _editedRows = report.rows.map((row) => [...row]).toList();
      });
    } on SocketException catch (error) {
      if (mounted) {
        setState(() {
          _error = 'انقطع اتصال التطبيق بالخدمة المحلية أثناء الطلب. '
              'رسالة النظام: ${error.message}. '
              'تحقق من نافذة PowerShell: إذا ظهر فيها "sending ... image to Gemini" '
              'فالمشكلة في رد Gemini/الشبكة، وإذا لم يظهر فالمشكلة بين التطبيق والخدمة. '
              'اضغط فحص الاتصال بعد ذلك.';
        });
        unawaited(_refreshBackendStatus());
      }
    } on HttpException catch (error) {
      if (mounted) setState(() => _error = error.message);
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
      const SnackBar(content: Text('تم نسخ البيانات. الصقها الآن في الشيت.')),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حفظ الملف: ${exportFile.path}'),
      ),
    );
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
                  'تم فتح الملف الخارجي. يمكن مقارنة محتواه يدويًا مع البيانات الحالية.')),
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
                  'استخرج البيانات عبر Gemini، راجعها ثم انسخها إلى الشيت.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
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
                          onPressed: _isLoading ? null : _refreshBackendStatus,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'مفاتيح Gemini',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _keyCollection.activeId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'المفتاح المستخدم للتحليل',
                            border: OutlineInputBorder(),
                          ),
                          hint: Text(
                            _isKeyVaultLoading
                                ? 'جارٍ تحميل المفاتيح الآمنة…'
                                : 'أضف مفتاح Gemini للبدء',
                          ),
                          items: _keyCollection.keys
                              .map(
                                (key) => DropdownMenuItem(
                                  value: key.id,
                                  child: Text(
                                    '${key.name} (${key.maskedSecret})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged:
                              _isKeyVaultLoading ? null : _selectGeminiKey,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isKeyVaultLoading || _isLoading
                                  ? null
                                  : _addGeminiKey,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('إضافة مفتاح'),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  _keyCollection.activeKey == null || _isLoading
                                      ? null
                                      : _removeActiveGeminiKey,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('حذف المفتاح المحدد'),
                            ),
                          ],
                        ),
                        if (_keyError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _keyError!,
                            style: TextStyle(color: colors.error),
                          ),
                        ],
                      ],
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
                                    setState(() => _reportType = value);
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
                              onPressed: _isLoading ||
                                      _imageBytes == null ||
                                      _keyCollection.activeKey == null ||
                                      !_hasConsent
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
                                    ? 'جارٍ تحليل الصورة…'
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
                            if (_report != null) ...[
                              OutlinedButton.icon(
                                onPressed: _copyToClipboard,
                                icon: const Icon(Icons.content_copy_rounded),
                                label: const Text('نسخ TSV إلى الحافظة'),
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
                          ],
                        ),
                        if (_imageBytes != null) ...[
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _hasConsent,
                            onChanged: _isLoading
                                ? null
                                : (value) => setState(
                                    () => _hasConsent = value ?? false),
                            title: const Text(
                              'أوافق على إرسال هذه الصورة إلى Gemini لتحليلها.',
                            ),
                            subtitle: const Text(
                              'راجع الصورة أولاً. إذا ظهرت بيانات شخصية، قصّها أو أخفِها بأداة خارجية ثم اختر النسخة المنقحة قبل الإرسال.',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_imageBytes != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: Image.memory(
                          Uint8List.fromList(_imageBytes!),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text(
                            'تعذر عرض الصورة المختارة.',
                            textAlign: TextAlign.center,
                          ),
                        ),
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
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
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
                                      (rowIndex >=
                                                  _importedReport!.rows.length
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
                                                  rowIndex, columnIndex) ??
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
                                            'report-$rowIndex-$columnIndex',
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
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
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
                  const SizedBox(height: 8),
                  Text(
                    'راجع الأرقام يدوياً قبل اللصق. سيتم نسخ العناوين والصفوف الظاهرة بصيغة TSV.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
