import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// Decoupled, global logging utility designed to store diagnostic details
/// for serial connections and system errors in both debug and release builds.
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  File? _logFile;
  int _logCountSinceTrimCheck = 0;

  /// Initializes the logger and sets up the file path.
  Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/spider_weighbridge_errors.log');
      await _checkAndTrimLogFile();
      await log('Logger initialized. Log file path: ${_logFile!.path}');
    } catch (e) {
      print('Failed to initialize logger: $e');
    }
  }

  /// Appends a new diagnostic or error log entry with a timestamp.
  Future<void> log(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) async {
    final timestamp = DateFormat(
      'yyyy-MM-dd HH:mm:ss.SSS',
    ).format(DateTime.now());
    var logLine = '[$timestamp] $message';
    if (error != null) {
      logLine += ' | Error: $error';
    }
    if (stackTrace != null) {
      logLine += '\n$stackTrace';
    }
    print(logLine); // Fallback to stdout for debug consoles

    try {
      if (_logFile == null) {
        final directory = await getApplicationDocumentsDirectory();
        _logFile = File('${directory.path}/spider_weighbridge_errors.log');
      }
      await _logFile!.writeAsString(
        '$logLine\n',
        mode: FileMode.append,
        flush: true,
      );

      _logCountSinceTrimCheck++;
      if (_logCountSinceTrimCheck > 200) {
        _logCountSinceTrimCheck = 0;
        _checkAndTrimLogFile();
      }
    } catch (e) {
      print('Failed to write to log file: $e');
    }
  }

  /// Ensures the log file doesn't grow indefinitely by capping max file size to 5MB.
  Future<void> _checkAndTrimLogFile() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        final length = await _logFile!.length();
        const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
        if (length > maxFileSizeBytes) {
          final lines = await readLastLogLines(maxLines: 2000);
          await _logFile!.writeAsString('${lines.join('\n')}\n');
        }
      }
    } catch (e) {
      print('Failed to trim log file: $e');
    }
  }

  /// Reads only the last [maxLines] lines from the log file efficiently.
  Future<List<String>> readLastLogLines({int maxLines = 500}) async {
    try {
      if (_logFile == null) {
        final directory = await getApplicationDocumentsDirectory();
        _logFile = File('${directory.path}/spider_weighbridge_errors.log');
      }
      if (!await _logFile!.exists()) {
        return [];
      }

      final length = await _logFile!.length();
      if (length == 0) return [];

      // Read only tail bytes (max 1 MB) to prevent loading massive files into RAM
      const int maxBytesToRead = 1024 * 1024; // 1 MB buffer
      List<String> lines = [];

      if (length > maxBytesToRead) {
        final raf = await _logFile!.open(mode: FileMode.read);
        try {
          await raf.setPosition(length - maxBytesToRead);
          final bytes = await raf.read(maxBytesToRead);
          final text = utf8.decode(bytes, allowMalformed: true);
          lines = text.split('\n');
          // Discard first partial line from byte offset cut
          if (lines.isNotEmpty) {
            lines.removeAt(0);
          }
        } finally {
          await raf.close();
        }
      } else {
        lines = await _logFile!.readAsLines();
      }

      // Filter empty trailing lines
      while (lines.isNotEmpty && lines.last.trim().isEmpty) {
        lines.removeLast();
      }

      if (lines.length > maxLines) {
        return lines.sublist(lines.length - maxLines);
      }
      return lines;
    } catch (e) {
      return ['Error reading logs: $e'];
    }
  }

  /// Reads the logs limited to the last [maxLines] lines (defaults to 500).
  Future<String> readLogs({int maxLines = 500}) async {
    final lines = await readLastLogLines(maxLines: maxLines);
    if (lines.isEmpty) {
      return 'No logs found.';
    }
    return lines.join('\n');
  }

  /// Resets the log file to an empty state.
  Future<void> clearLogs() async {
    try {
      if (_logFile == null) {
        final directory = await getApplicationDocumentsDirectory();
        _logFile = File('${directory.path}/spider_weighbridge_errors.log');
      }
      if (await _logFile!.exists()) {
        await _logFile!.writeAsString('');
      }
      await log('Logs cleared by user.');
    } catch (e) {
      print('Error clearing logs: $e');
    }
  }

  /// Gets the absolute disk path where the log file is located.
  Future<String> getLogFilePath() async {
    if (_logFile == null) {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/spider_weighbridge_errors.log';
    }
    return _logFile!.path;
  }
}
