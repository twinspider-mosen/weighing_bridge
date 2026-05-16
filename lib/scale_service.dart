import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';

class ScaleConfig {
  final int baudRate;
  final int parity;
  final int dataBits;
  final int stopBits;

  ScaleConfig({
    required this.baudRate,
    required this.parity,
    required this.dataBits,
    this.stopBits = 1,
  });

  @override
  String toString() => '$baudRate Baud, Parity $parity, $dataBits DataBits';
}

class ScaleService {
  SerialPort? _currentPort;
  SerialPortReader? _reader;
  final _weightController = StreamController<String>.broadcast();

  Stream<String> get weightStream => _weightController.stream;

  static const List<int> bauds = [9600, 4800, 2400, 1200, 19200];
  
  // Parity constants from libserialport
  // 0: None, 1: Odd, 2: Even, 3: Mark, 4: Space
  static const List<int> parities = [
    SerialPortParity.none,
    SerialPortParity.even,
    SerialPortParity.odd,
  ];

  /// Cleanup conflicting processes (Windows specific)
  Future<void> cleanupProcesses() async {
    if (!Platform.isWindows) return;
    
    try {
      final results = await Process.run('tasklist', []);
      final output = results.stdout.toString().toLowerCase();
      
      final targets = ['winscale', 'pos'];
      for (final target in targets) {
        if (output.contains(target)) {
          print('Closing conflicting process: $target');
          await Process.run('taskkill', ['/F', '/IM', '$target*']);
        }
      }
    } catch (e) {
      print('Error cleaning up processes: $e');
    }
  }

  /// Scan a specific port to find working configuration
  Future<ScaleConfig?> scanPort(String portName) async {
    try {
      await cleanupProcesses().timeout(const Duration(seconds: 5));
    } catch (e) {
      print('Process cleanup timed out: $e');
    }

    for (final baud in bauds) {
      for (final parity in parities) {
        final dataBits = parity == SerialPortParity.none ? 8 : 7;
        
        print('Testing: $portName at $baud Baud, Parity $parity, $dataBits DataBits');
        
        SerialPort? port;
        try {
          port = SerialPort(portName);
          if (!port.openReadWrite()) {
            print('Could not open port $portName');
            continue;
          }

          final config = port.config;
          config.baudRate = baud;
          config.parity = parity;
          config.bits = dataBits;
          config.stopBits = 1;
          port.config = config;

          // Wait for some data to arrive with a timeout
          bool foundData = false;
          int attempts = 0;
          while (attempts < 3 && !foundData) {
            await Future.delayed(const Duration(milliseconds: 300));
            if (port.bytesAvailable > 0) {
              final data = port.read(port.bytesAvailable);
              final text = _cleanData(data);
              
              if (RegExp(r'[0-9]').hasMatch(text)) {
                print('!!! SUCCESS !!! Found data: ${text.trim()}');
                foundData = true;
                return ScaleConfig(
                  baudRate: baud,
                  parity: parity,
                  dataBits: dataBits,
                );
              }
            }
            attempts++;
          }
        } catch (e) {
          print('Error testing $baud/$parity: $e');
        } finally {
          try {
            port?.close();
          } catch (e) {
            print('Error closing port during scan: $e');
          }
        }
      }
    }
    return null;
  }

  /// Start listening on a port with specific config
  Future<bool> startListening(String portName, ScaleConfig config) async {
    await stopListening();

    try {
      _currentPort = SerialPort(portName);
      if (!_currentPort!.openReadWrite()) {
        return false;
      }

      final portConfig = _currentPort!.config;
      portConfig.baudRate = config.baudRate;
      portConfig.parity = config.parity;
      portConfig.bits = config.dataBits;
      portConfig.stopBits = config.stopBits;
      _currentPort!.config = portConfig;

      _reader = SerialPortReader(_currentPort!);
      _reader!.stream.listen((Uint8List data) {
        final cleaned = _cleanData(data);
        if (cleaned.trim().isNotEmpty) {
          _weightController.add(cleaned);
        }
      }, onError: (e) {
        print('Serial error: $e');
        stopListening();
      });

      return true;
    } catch (e) {
      print('Error starting listener: $e');
      return false;
    }
  }

  Future<void> stopListening() async {
    _reader?.close();
    _reader = null;
    _currentPort?.close();
    _currentPort = null;
  }

  String _cleanData(Uint8List data) {
    try {
      // Strip 8th bit (Mask 0x7F) to handle parity bit interference
      final stripped = data.map((b) => b & 0x7F).toList();
      final text = ascii.decode(stripped, allowInvalid: true);
      
      // Filter for weight-related characters (numbers, decimals, units, whitespace)
      final regex = RegExp(r'[^0-9\. kglwb\r\n]');
      return text.replaceAll(regex, '');
    } catch (e) {
      print('Data cleaning error: $e');
      return '';
    }
  }

  List<String> getAvailablePorts() {
    try {
      return SerialPort.availablePorts;
    } catch (e) {
      print('Error listing ports: $e');
      return [];
    }
  }

  void dispose() {
    stopListening();
    _weightController.close();
  }
}
