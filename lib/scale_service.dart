import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'logger_service.dart';

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
          LoggerService().log('Stream raw data chunk #$chunkCount: len=${data.length}, bytes=$data, text="$asciiStr"');
        }

        // Safety Guard: prevent raw buffer from growing boundlessly due to constant garbage/unaligned bytes
        if (_rawBuffer.length > 512) {
          _rawBuffer.clear();
        }
        
        // Step 1: Append newly received raw bytes to our raw buffer
        _rawBuffer.addAll(data);

        // Step 2: Continuously extract and parse complete packets from the raw buffer
        bool foundPacket = true;
        while (foundPacket) {
          foundPacket = false;

          // A: Try parsing as Toledo or Yaohua Continuous Packet with dynamic framing (STX ... ETX/CR)
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

          // B: Fallback - Standard ASCII string delimiter parser (for simple non-Toledo scales sending weight\r\n)
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

  void dispose() {
    stopListening();
    _weightController.close();
  }
}
