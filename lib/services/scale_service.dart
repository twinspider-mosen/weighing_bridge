import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'logger_service.dart';

/// Defines the serial data framing protocol used by the connected scale.
///
/// - [binaryAutoDetect]: Default. Handles Yaohua (STX...ETX 12-byte) and
///   Toledo (STX...CR 17/18-byte) binary packet formats, with a plain-ASCII
///   newline fallback. Use this for all previously working systems.
///
/// - [csvPlainText]: For scales that output comma-separated ASCII lines,
///   such as the PMS-style scale used at Sihala Flour Mill. The parser
///   extracts the first plausible numeric weight field from each
///   newline-terminated CSV record.
enum ScaleProtocol {
  binaryAutoDetect,
  csvPlainText,
}

class ScaleConfig {
  final int baudRate;
  final int parity;
  final int dataBits;
  final int stopBits;

  /// The framing protocol this scale uses.
  /// Defaults to [ScaleProtocol.binaryAutoDetect] so no existing system is affected.
  final ScaleProtocol protocol;

  ScaleConfig({
    required this.baudRate,
    required this.parity,
    required this.dataBits,
    this.stopBits = 1,
    this.protocol = ScaleProtocol.binaryAutoDetect,
  });

  @override
  String toString() =>
      '$baudRate Baud, Parity $parity, $dataBits DataBits, Protocol: ${protocol.name}';
}

class ScaleService {
  SerialPort? _currentPort;
  SerialPortReader? _reader;
  final _weightController = StreamController<String>.broadcast();

  // Raw byte accumulator buffer to temporarily store incomplete serial data packets
  // between stream chunks to prevent partial packets/strings from being parsed.
  final List<int> _rawBuffer = [];

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
          await LoggerService().log('Closing conflicting process: $target');
          await Process.run('taskkill', ['/F', '/IM', '$target*']);
        }
      }
    } catch (e, stack) {
      await LoggerService().log('Error cleaning up processes', e, stack);
    }
  }

  /// Scan a specific port to find working configuration
  Future<ScaleConfig?> scanPort(String portName) async {
    await LoggerService().log('Starting dynamic scan on port: $portName');
    try {
      await cleanupProcesses().timeout(const Duration(seconds: 5));
    } catch (e, stack) {
      await LoggerService().log('Process cleanup timed out during scan', e, stack);
    }

    final available = getAvailablePorts();
    await LoggerService().log('Available COM ports detected: $available');

    for (final baud in bauds) {
      for (final parity in parities) {
        final dataBits = parity == SerialPortParity.none ? 8 : 7;
        
        await LoggerService().log('Testing $portName: $baud Baud, Parity $parity, $dataBits DataBits');
        
        SerialPort? port;
        try {
          port = SerialPort(portName);
          if (!port.openReadWrite()) {
            await LoggerService().log('Failed to open port $portName at $baud/$parity during scan. Port might be locked by another process.');
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
              final rawData = port.read(port.bytesAvailable);
              final text = _cleanData(rawData);
              await LoggerService().log('Data read attempt ${attempts + 1} on $baud/$parity: RawBytesLength=${rawData.length}, CleanedText="${text.trim()}"');
              
              if (RegExp(r'[0-9]').hasMatch(text)) {
                await LoggerService().log('!!! SCAN SUCCESS !!! Found readable digit data on $portName at $baud Baud, Parity $parity.');
                foundData = true;
                return ScaleConfig(
                  baudRate: baud,
                  parity: parity,
                  dataBits: dataBits,
                );
              }
            } else {
              await LoggerService().log('No bytes available on $portName at $baud/$parity (attempt ${attempts + 1}/3)');
            }
            attempts++;
          }
        } catch (e, stack) {
          await LoggerService().log('Error testing $baud/$parity on $portName', e, stack);
        } finally {
          try {
            port?.close();
          } catch (e) {
            // Keep silent or minimal logging on secondary cleanup failures
          }
        }
      }
    }
    await LoggerService().log('Scan complete for $portName. No working configuration was found.');
    return null;
  }

  /// Start listening on a port with specific config
  Future<bool> startListening(String portName, ScaleConfig config) async {
    await LoggerService().log('Attempting to start listener on $portName with config: $config');
    await stopListening();

    try {
      _currentPort = SerialPort(portName);
      if (!_currentPort!.openReadWrite()) {
        await LoggerService().log('Failed to open port $portName for listening. Access Denied / Exclusive Lock active.');
        return false;
      }

      final portConfig = _currentPort!.config;
      portConfig.baudRate = config.baudRate;
      portConfig.parity = config.parity;
      portConfig.bits = config.dataBits;
      portConfig.stopBits = config.stopBits;
      _currentPort!.config = portConfig;

      // Initialize/clear the buffer accumulator before starting the listener stream.
      _rawBuffer.clear();

      _reader = SerialPortReader(_currentPort!);
      await LoggerService().log('SerialPortReader created successfully on $portName.');

      int chunkCount = 0;
      _reader!.stream.listen((Uint8List data) {
        chunkCount++;
        if (chunkCount <= 100 || chunkCount % 100 == 0) {
          final asciiCleaned = data.map((b) => b & 0x7F).toList();
          final asciiStr = ascii.decode(asciiCleaned, allowInvalid: true).replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '.');
          LoggerService().log('Stream raw data chunk #$chunkCount [${config.protocol.name}]: len=${data.length}, bytes=$data, text="$asciiStr"');
        }

        // Safety Guard: prevent raw buffer from growing boundlessly.
        // CSV packets can be longer so we allow a larger ceiling for that mode.
        final int bufferLimit = config.protocol == ScaleProtocol.csvPlainText ? 2048 : 512;
        if (_rawBuffer.length > bufferLimit) {
          _rawBuffer.clear();
        }

        // Step 1: Append newly received raw bytes to our raw buffer
        _rawBuffer.addAll(data);

        // Step 2: Continuously extract and parse complete packets from the raw buffer
        bool foundPacket = true;
        while (foundPacket) {
          foundPacket = false;

          // ────────────────────────────────────────────────────────────────────
          // PATH A  –  Binary Auto-Detect  (Yaohua / Toledo)
          // This is the ORIGINAL, UNCHANGED path for all previously working
          // systems. Do not modify this block.
          // ────────────────────────────────────────────────────────────────────
          if (config.protocol == ScaleProtocol.binaryAutoDetect) {

            // A1: Try parsing as Toledo or Yaohua Continuous Packet with dynamic framing (STX ... ETX/CR)
            // Search for STX (0x02) in the raw buffer (masking parity bit to handle Even/Odd parity frames)
            int stxIndex = -1;
            for (int i = 0; i < _rawBuffer.length; i++) {
              if ((_rawBuffer[i] & 0x7F) == 0x02) {
                stxIndex = i;
                break;
              }
            }

            if (stxIndex != -1) {
              // Find the packet terminator following this STX.
              // In Yaohua continuous format, the packet is exactly 12 bytes and ends with ETX (0x03).
              // In Toledo continuous format, the packet is typically 17/18 bytes and ends with CR (0x0D).
              // We search for ETX (0x03) or CR (0x0D) starting from stxIndex + 8 to stxIndex + 22.
              int termIndex = -1;
              int termByte = -1;
              for (int i = stxIndex + 8; i < _rawBuffer.length && i <= stxIndex + 22; i++) {
                final int b = _rawBuffer[i] & 0x7F;
                if (b == 0x03 || b == 0x0D) {
                  termIndex = i;
                  termByte = b;
                  break;
                }
              }

              if (termIndex != -1) {
                foundPacket = true;
                final int packetLength = termIndex - stxIndex + 1;
                final packet = _rawBuffer.sublist(stxIndex, stxIndex + packetLength);

                // Remove the packet (and any leading garbage prior to STX) from the raw buffer
                _rawBuffer.removeRange(0, stxIndex + packetLength);

                try {
                  // Scenario 1: Yaohua 12-byte Continuous Packet ending with ETX (0x03)
                  if (termByte == 0x03 && packetLength == 12) {
                    // Gross Weight digits are at packet indices 2 to 7 (6 characters)
                    final weightBytes = packet.sublist(2, 8);
                    final cleanWeightBytes = weightBytes.map((b) => b & 0x7F).toList();
                    final weightStr = ascii.decode(cleanWeightBytes).trim();

                    // Sign: packet index 1 (+ or -)
                    final int signByte = packet[1] & 0x7F;
                    final bool isNegative = signByte == 0x2D; // '-' is 0x2D

                    // Decimal point position: packet index 8 (ASCII digit '0'-'4')
                    final int decChar = packet[8] & 0x7F;
                    final int decimalPower = decChar >= 0x30 && decChar <= 0x39 ? decChar - 0x30 : 0;

                    double? weightValue = double.tryParse(weightStr);
                    if (weightValue != null) {
                      if (decimalPower > 0 && decimalPower <= 6) {
                        weightValue = weightValue / math.pow(10, decimalPower);
                      }
                      if (isNegative) {
                        weightValue = -weightValue;
                      }

                      final String formattedWeight = weightValue.toStringAsFixed(decimalPower);
                      _weightController.add(formattedWeight);
                    }
                  }
                  // Scenario 2: Toledo Continuous Packet ending with CR (0x0D) (length usually 17/18)
                  else if (termByte == 0x0D && packetLength >= 10) {
                    final weightBytes = packet.sublist(4, math.min(10, packetLength));
                    final cleanWeightBytes = weightBytes.map((b) => b & 0x7F).toList();
                    final weightStr = ascii.decode(cleanWeightBytes).trim();

                    // Sign: Bit 1 of Status Word B (index 2 of packet) - Mask parity bit
                    // 1 = negative, 0 = positive
                    final int swb = packet[2] & 0x7F;
                    final bool isNegative = (swb & 0x02) != 0;

                    // Decimal position: lower 3 bits of Status Word A (index 1 of packet) - Mask parity bit
                    final int swa = packet[1] & 0x7F;
                    final int decimalPower = swa & 0x07;

                    double? weightValue = double.tryParse(weightStr);
                    if (weightValue != null) {
                      if (decimalPower > 0 && decimalPower <= 6) {
                        weightValue = weightValue / math.pow(10, decimalPower);
                      }
                      if (isNegative) {
                        weightValue = -weightValue;
                      }

                      final String formattedWeight = weightValue.toStringAsFixed(
                        decimalPower > 0 && decimalPower <= 6 ? decimalPower : 0
                      );
                      _weightController.add(formattedWeight);
                    }
                  }
                } catch (e, stack) {
                  LoggerService().log('Dynamic continuous decoding failed', e, stack);
                }

                continue; // Move to the next packet in the loop
              } else {
                // If we have at least 22 bytes after STX and still no terminator, it is invalid framing!
                // Discard the invalid STX start byte so we do not lock up the buffer!
                if (_rawBuffer.length >= stxIndex + 22) {
                  _rawBuffer.removeRange(0, stxIndex + 1);
                  foundPacket = true;
                  continue;
                }
              }
            }

            // A2: Fallback – Standard ASCII newline-delimited parser
            // (for simple non-Toledo scales sending weight\r\n)
            int newlineIndex = -1;
            for (int i = 0; i < _rawBuffer.length; i++) {
              final byte = _rawBuffer[i] & 0x7F;
              if (byte == 0x0A || byte == 0x0D) {
                newlineIndex = i;
                break;
              }
            }

            if (newlineIndex != -1) {
              foundPacket = true;

              // Extract the raw bytes up to the newline
              final rawLineBytes = _rawBuffer.sublist(0, newlineIndex);

              // Remove from the raw buffer
              _rawBuffer.removeRange(0, newlineIndex + 1);

              // Decode and clean using standard ASCII cleaner
              final String lineText = _cleanData(Uint8List.fromList(rawLineBytes));
              if (lineText.trim().isNotEmpty) {
                _weightController.add(lineText);
              }
            }

          // ────────────────────────────────────────────────────────────────────
          // PATH B  –  CSV / Plain-Text Protocol
          // For scales that send comma-separated ASCII lines terminated by
          // CR and/or LF, such as the PMS/Sihala Flour Mill system.
          // Each line is decoded and fed into _parseCSVLine(); the first
          // plausible numeric weight value (>= 1.0) is emitted.
          // ────────────────────────────────────────────────────────────────────
          } else if (config.protocol == ScaleProtocol.csvPlainText) {

            // Find the next line terminator (CR or LF)
            int newlineIndex = -1;
            for (int i = 0; i < _rawBuffer.length; i++) {
              final byte = _rawBuffer[i] & 0x7F;
              if (byte == 0x0A || byte == 0x0D) {
                newlineIndex = i;
                break;
              }
            }

            if (newlineIndex != -1) {
              foundPacket = true;

              // Extract raw bytes for this line (strip 8th parity bit)
              final rawLineBytes = _rawBuffer.sublist(0, newlineIndex);
              _rawBuffer.removeRange(0, newlineIndex + 1);

              // Consume a following \n after \r (CRLF pair) so it isn't
              // treated as an extra empty line next iteration.
              if (_rawBuffer.isNotEmpty && (_rawBuffer[0] & 0x7F) == 0x0A) {
                _rawBuffer.removeAt(0);
              }

              final String lineText = ascii.decode(
                rawLineBytes.map((b) => b & 0x7F).toList(),
                allowInvalid: true,
              );

              final String? parsed = _parseCSVLine(lineText);
              if (parsed != null) {
                LoggerService().log('CSV weight parsed: "$parsed" from line: "${lineText.trim()}"');
                _weightController.add(parsed);
              }
            }
          }
        }
      }, onError: (e, stack) {
        LoggerService().log('Stream encountered serial read error on $portName', e, stack);
        stopListening();
      });

      return true;
    } catch (e, stack) {
      await LoggerService().log('Fatal exception while starting listener on $portName', e, stack);
      return false;
    }
  }

  Future<void> stopListening() async {
    await LoggerService().log('Stopping listener and closing active port/reader references.');
    try {
      _reader?.close();
    } catch (e) {
      // Ignored
    }
    _reader = null;
    try {
      _currentPort?.close();
    } catch (e) {
      // Ignored
    }
    _currentPort = null;
    // Safely clear the accumulator buffer when the serial listener is stopped/disconnected.
    _rawBuffer.clear();
  }
  String _cleanData(Uint8List data) {
    try {
      // Strip 8th bit (Mask 0x7F) to handle parity bit interference
      final stripped = data.map((b) => b & 0x7F).toList();
      final text = ascii.decode(stripped, allowInvalid: true);
      
      // Filter for weight-related characters (numbers, decimals, units, whitespace)
      final regex = RegExp(r'[^0-9\. kglwb\r\n]', caseSensitive: false);
      return text.replaceAll(regex, '');
    } catch (e, stack) {
      LoggerService().log('Data cleaning failed', e, stack);
      return '';
    }
  }

  List<String> getAvailablePorts() {
    try {
      return SerialPort.availablePorts;
    } catch (e, stack) {
      LoggerService().log('Error listing available COM ports', e, stack);
      return [];
    }
  }

  /// Parses a weight value from a PMS/Sihala-style CSV line.
  ///
  /// The scale sends lines like:
  ///   `1,ST,   ,       ,   4000,   105,   0,   0,...,kg\r\n`
  ///
  /// Field layout (confirmed from live logs):
  ///   [0] Machine/sequence number (e.g. "1")  ← SKIP — always a small integer
  ///   [1] Status code (e.g. "ST", "US")       ← SKIP — not numeric
  ///   [2] Sub-status / empty
  ///   [3] empty / padding
  ///   [4] Gross weight  ← TARGET (e.g. "4000", "930")
  ///   [5] Tare weight
  ///   [6+] Other zeroed fields
  ///   last field: unit ("kg")
  ///
  /// Strategy:
  ///   1. Skip fields [0] and [1] entirely (machine ID + status code).
  ///   2. From field [2] onward, strip sign/unit chars; accept first value
  ///      that is purely numeric AND >= 10 (weight values are never single-digit).
  ///   3. Fallback regex on the whole line for formats without commas.
  ///
  /// Returns `null` when no usable weight is found so the caller skips the line.
  String? _parseCSVLine(String line) {
    try {
      final fields = line.split(',');

      // We need at least 5 fields for a complete record; shorter lines are
      // partial / garbage (the scale sends very long lines split across chunks).
      if (fields.length < 5) return null;

      // Scan from field index 2 onward — skip machine-ID[0] and status-code[1]
      for (int i = 2; i < fields.length; i++) {
        final field = fields[i];

        // Strip leading sign (+/-), all whitespace, and trailing unit letters
        final cleaned = field
            .trim()
            .replaceAll(RegExp(r'^[+\-\s]+'), '')    // leading sign/spaces
            .replaceAll(RegExp(r'[a-zA-Z\s]+$'), '') // trailing unit letters
            .trim();

        if (cleaned.isEmpty) continue;

        // Must be a pure number — any leftover letters means it's a status field
        if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(cleaned)) continue;

        final double? val = double.tryParse(cleaned);

        // Weight must be >= 10 to distinguish from machine IDs (1) and
        // the many zero-padding fields in this scale's protocol.
        if (val != null && val >= 10.0) {
          final dotIndex = cleaned.indexOf('.');
          final decPlaces = dotIndex == -1 ? 0 : cleaned.length - dotIndex - 1;
          final result = val.toStringAsFixed(decPlaces);
          LoggerService().log('_parseCSVLine: field[$i]="$cleaned" → weight=$result');
          return result;
        }
      }

      // Fallback: find the first standalone 3+-digit number anywhere in the line.
      // Requires 3+ digits to avoid matching machine IDs like "1".
      final match = RegExp(r'(?<![0-9])(\d{3,}\.?\d*)(?![0-9])').firstMatch(line);
      if (match != null) {
        final numStr = match.group(1)!;
        final double? val = double.tryParse(numStr);
        if (val != null && val >= 10.0) {
          final dotIndex = numStr.indexOf('.');
          final decPlaces = dotIndex == -1 ? 0 : numStr.length - dotIndex - 1;
          return val.toStringAsFixed(decPlaces);
        }
      }
    } catch (e, stack) {
      LoggerService().log('CSV line parsing failed', e, stack);
    }
    return null;
  }

  void dispose() {
    stopListening();
    _weightController.close();
  }
}
