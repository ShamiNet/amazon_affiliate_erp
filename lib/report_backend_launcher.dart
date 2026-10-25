import 'dart:async';
import 'dart:io';

class ReportBackendLauncher {
  ReportBackendLauncher._();

  static final ReportBackendLauncher instance = ReportBackendLauncher._();

  static const _healthUrl = 'http://127.0.0.1:8765/health';

  Process? _process;
  String? _lastStartError;

  String? get lastStartError => _lastStartError;

  Future<bool> _isRunning() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.getUrl(Uri.parse(_healthUrl));
      final response = await request.close().timeout(
            const Duration(seconds: 2),
          );
      await response.drain<void>();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  File? _findScript() {
    final starts = <Directory>[
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ];
    for (final start in starts) {
      var dir = start.absolute;
      for (var i = 0; i < 8; i++) {
        final script = File(
          '${dir.path}${Platform.pathSeparator}backend'
          '${Platform.pathSeparator}run_report_extractor.ps1',
        );
        if (script.existsSync()) return script;
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    return null;
  }

  /// Starts run_report_extractor.ps1 unless the service already responds.
  Future<void> start() async {
    if (!Platform.isWindows) return;
    try {
      if (await _isRunning()) {
        _lastStartError = null;
        return;
      }
      if (_process != null) return;
      final script = _findScript();
      if (script == null) {
        _lastStartError =
            'تعذر العثور على ملف backend\\run_report_extractor.ps1 بجوار التطبيق.';
        return;
      }
      _process = await Process.start(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-WindowStyle',
          'Hidden',
          '-File',
          script.path,
        ],
        workingDirectory: script.parent.path,
      );
      final process = _process!;
      final outputBuffer = StringBuffer();
      unawaited(
        process.stdout
            .transform(SystemEncoding().decoder)
            .listen(outputBuffer.write)
            .asFuture<void>(),
      );
      unawaited(
        process.stderr
            .transform(SystemEncoding().decoder)
            .listen(outputBuffer.write)
            .asFuture<void>(),
      );
      unawaited(
        process.exitCode.then((code) {
          if (identical(_process, process)) {
            _process = null;
          }
          if (code != 0 && _lastStartError == null) {
            _lastStartError = _formatStartupError(
              outputBuffer.toString(),
              code,
            );
          }
        }),
      );
      _lastStartError = null;
    } catch (error) {
      _lastStartError = 'تعذر تشغيل خدمة OCR المحلية: $error';
      _process = null;
    }
  }

  String _formatStartupError(String output, int exitCode) {
    final trimmed = output.trim();
    final lower = trimmed.toLowerCase();
    if (lower.contains("python") &&
        (lower.contains("not recognized") ||
            lower.contains("could not find") ||
            lower.contains("not found"))) {
      return 'تعذر تشغيل Python. ثبّت Python 3.10+ أو أضفه إلى PATH ثم أعد التشغيل.';
    }
    if (trimmed.contains('Bundled Tesseract OCR executable is missing')) {
      return 'ملفات Tesseract المحلية غير مكتملة. أعد تثبيت التطبيق.';
    }
    if (trimmed.contains('Bundled Arabic and English Tesseract language data')) {
      return 'بيانات اللغتين العربية/الإنجليزية لـ Tesseract غير مكتملة.';
    }
    if (trimmed.isEmpty) {
      return 'تعذر تشغيل خدمة OCR المحلية (Exit Code: $exitCode).';
    }
    return 'تعذر تشغيل خدمة OCR المحلية: $trimmed';
  }

  void stop() {
    final process = _process;
    if (process == null) return;
    _process = null;
    // Kill the whole tree (powershell + python).
    Process.runSync('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
  }
}
