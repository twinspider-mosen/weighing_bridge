import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_service.dart';

/// A premium, custom-styled Settings Screen built to match the high-fidelity dark dashboard aesthetic.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  bool _uploadOnCapture = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final value = await _settingsService.getUploadOnCapture();
    if (mounted) {
      setState(() {
        _uploadOnCapture = value;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleUploadOnCapture(bool value) async {
    setState(() {
      _uploadOnCapture = value;
    });
    await _settingsService.setUploadOnCapture(value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.teal.shade800,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                value 
                    ? "Settings updated: Upload on capture enabled" 
                    : "Settings updated: Direct saving to gallery enabled",
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F25),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SYSTEM SETTINGS',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [Color(0xFF1A1F25), Color(0xFF0A0E12)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.greenAccent),
                )
              : ListView(
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    Text(
                      "SNAPSHOT & DATA FLOW",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // The Capture Option Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.01),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          activeColor: Colors.greenAccent,
                          activeTrackColor: Colors.greenAccent.withOpacity(0.3),
                          inactiveThumbColor: Colors.white30,
                          inactiveTrackColor: Colors.white10,
                          secondary: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _uploadOnCapture
                                  ? Colors.greenAccent.withOpacity(0.08)
                                  : Colors.white.withOpacity(0.04),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _uploadOnCapture
                                    ? Colors.greenAccent.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Icon(
                              _uploadOnCapture
                                  ? Icons.cloud_upload_outlined
                                  : Icons.save_alt_outlined,
                              color: _uploadOnCapture
                                  ? Colors.greenAccent
                                  : Colors.white54,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            "Upload on Capture",
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _uploadOnCapture
                                  ? "Prompt with a secure popup to upload captured snapshots and scale weight readings directly to the API server."
                                  : "Skip server uploads completely. Automatically save captured snapshots locally on this machine.",
                              style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                          value: _uploadOnCapture,
                          onChanged: _toggleUploadOnCapture,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Informative Footer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.01),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.04),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.white38, size: 16),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "All settings are saved locally and persist automatically when restarting the weighing application.",
                              style: GoogleFonts.inter(
                                color: Colors.white24,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
