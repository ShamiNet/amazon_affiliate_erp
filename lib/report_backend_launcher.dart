import 'dart:async';
import 'dart:io';

class ReportBackendLauncher {
  ReportBackendLauncher._();

  static final ReportBackendLauncher instance = ReportBackendLauncher._();

  static const _healthUrl = 'http://127.0.0.1:8765/health';

  Process? _process;

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
    if (!Platform.isWindows || _process != null) return;
    try {
      if (await _isRunning()) return;
      final script = _findScript();
      if (script == null) return;
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
      // Drain output so the child never blocks on a full pipe.
      unawaited(_process!.stdout.drain<void>());
      unawaited(_process!.stderr.drain<void>());
      unawaited(_process!.exitCode.then((_) => _process = null));
    } catch (_) {
      _process = null;
    }
  }

  void stop() {
    final process = _process;
    if (process == null) return;
    _process = null;
    // Kill the whole tree (powershell + python).
    Process.runSync('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
  }
}
