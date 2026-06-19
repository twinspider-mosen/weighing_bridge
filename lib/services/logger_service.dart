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

  /// Initializes the logger and sets up the file path.
  Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/spider_weighbridge_errors.log');
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
    } catch (e) {
      print('Failed to write to log file: $e');
    }
  }

  /// Reads the entire contents of the log file.
  Future<String> readLogs() async {
    try {
      if (_logFile == null) {
        final directory = await getApplicationDocumentsDirectory();
        _logFile = File('${directory.path}/spider_weighbridge_errors.log');
      }
      if (await _logFile!.exists()) {
        return await _logFile!.readAsString();
      }
      return 'No logs found.';
    } catch (e) {
      return 'Error reading logs: $e';
    }
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
