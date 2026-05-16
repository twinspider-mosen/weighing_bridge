import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'scale_service.dart';

void main() {
  runApp(const WeighingBridgeApp());
}

class WeighingBridgeApp extends StatelessWidget {
  const WeighingBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Industrial Weighing Bridge',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF0A0E12),
        useMaterial3: true,
      ),
      home: const WeighingScreen(),
    );
  }
}

class WeighingScreen extends StatefulWidget {
  const WeighingScreen({super.key});

  @override
  State<WeighingScreen> createState() => _WeighingScreenState();
}

class _WeighingScreenState extends State<WeighingScreen> {
  final ScaleService _scaleService = ScaleService();
  String _currentWeight = '0.00';
  String _unit = 'kg';
  String? _selectedPort;
  bool _isScanning = false;
  bool _isListening = false;
  String _status = 'Disconnected';
  ScaleConfig? _activeConfig;

  @override
  void initState() {
    super.initState();
    _refreshPorts();
    _scaleService.weightStream.listen(_handleNewData);
  }

  void _refreshPorts() {
    try {
      final ports = _scaleService.getAvailablePorts();
      setState(() {
        if (ports.isNotEmpty) {
          if (_selectedPort == null || !ports.contains(_selectedPort)) {
            _selectedPort = ports.first;
          }
        } else {
          _selectedPort = null;
          _status = 'No ports found';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Error loading ports: $e';
      });
    }
  }

  void _handleNewData(String data) {
    // Data is already cleaned by service. We just need to extract the number part.
    final match = RegExp(r'([0-9]+\.[0-9]+|[0-9]+)').firstMatch(data);
    final unitMatch = RegExp(r'(kg|lb|g)').firstMatch(data.toLowerCase());

    setState(() {
      if (match != null) {
        _currentWeight = match.group(0)!;
      }
      if (unitMatch != null) {
        _unit = unitMatch.group(0)!;
      }
    });
  }

  Future<void> _startScan() async {
    if (_selectedPort == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a COM port first')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _status = 'Scanning...';
    });

    try {
      // Add a total timeout for the entire scan process
      final config = await _scaleService.scanPort(_selectedPort!)
          .timeout(const Duration(seconds: 45));

      if (config != null) {
        final success = await _scaleService.startListening(_selectedPort!, config);
        setState(() {
          _activeConfig = config;
          _isListening = success;
          _status = success ? 'Connected' : 'Connection Failed';
        });
      } else {
        setState(() {
          _status = 'Scan Failed (No Signal)';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Scan Error: $e';
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _toggleListener() async {
    if (_isListening) {
      await _scaleService.stopListening();
      setState(() {
        _isListening = false;
        _status = 'Disconnected';
      });
    } else {
      if (_activeConfig != null && _selectedPort != null) {
        final success = await _scaleService.startListening(_selectedPort!, _activeConfig!);
        setState(() {
          _isListening = success;
          _status = success ? 'Connected' : 'Connection Failed';
        });
      } else {
        _startScan();
      }
    }
  }

  @override
  void dispose() {
    _scaleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              const Color(0xFF1A1F25),
              const Color(0xFF0A0E12),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const Spacer(),
                _buildWeightDisplay(),
                const Spacer(),
                _buildControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WEIGHING BRIDGE',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: Colors.greenAccent.withOpacity(0.7),
              ),
            ),
            Text(
              'System Active',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isListening ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isListening ? Colors.greenAccent : Colors.redAccent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.greenAccent : Colors.redAccent,
                  boxShadow: [
                    BoxShadow(
                      color: _isListening ? Colors.greenAccent : Colors.redAccent,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _status.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: _isListening ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeightDisplay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.05),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _currentWeight,
                  style: GoogleFonts.robotoMono(
                    fontSize: 120,
                    fontWeight: FontWeight.w500,
                    color: Colors.greenAccent,
                    shadows: [
                      Shadow(
                        color: Colors.greenAccent.withOpacity(0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  _unit,
                  style: GoogleFonts.inter(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          if (_activeConfig != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'SIGNAL: ${_activeConfig.toString()}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  letterSpacing: 2,
                  color: Colors.white24,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final ports = _scaleService.getAvailablePorts();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SERIAL PORT',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedPort,
                          items: ports.map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p, style: GoogleFonts.inter(fontSize: 16)),
                          )).toList(),
                          onChanged: _isScanning || _isListening ? null : (val) {
                            setState(() => _selectedPort = val);
                          },
                          dropdownColor: const Color(0xFF1A1F25),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20, color: Colors.white38),
                      onPressed: _isScanning || _isListening ? null : _refreshPorts,
                      tooltip: 'Refresh Ports',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          _buildActionButton(
            label: _isScanning ? 'SCANNING...' : 'AUTO-SCAN',
            icon: Icons.search,
            color: Colors.blueAccent,
            onPressed: _isListening || _isScanning ? null : _startScan,
          ),
          const SizedBox(width: 16),
          _buildActionButton(
            label: _isListening ? 'STOP' : 'START',
            icon: _isListening ? Icons.stop_rounded : Icons.play_arrow_rounded,
            color: _isListening ? Colors.redAccent : Colors.greenAccent,
            onPressed: _isScanning ? null : _toggleListener,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool isPrimary = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? color : color.withOpacity(0.1),
        foregroundColor: isPrimary ? Colors.black : color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isPrimary ? BorderSide.none : BorderSide(color: color.withOpacity(0.3)),
        ),
        elevation: isPrimary ? 8 : 0,
        shadowColor: color.withOpacity(0.4),
      ),
    );
  }
}
