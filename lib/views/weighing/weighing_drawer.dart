import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:weighing_bridge/views/camera_management_screen.dart';
import 'package:weighing_bridge/views/log_viewer_screen.dart';
import 'package:weighing_bridge/views/ocr_screen.dart';
import 'package:weighing_bridge/views/settings_screen.dart';
import 'package:weighing_bridge/test_screen.dart';

class WeighingDrawer extends StatelessWidget {
  final VoidCallback? onCamerasUpdated;
  final VoidCallback? onSettingsUpdated;

  const WeighingDrawer({
    super.key,
    this.onCamerasUpdated,
    this.onSettingsUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1A1F25),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Colors.greenAccent.shade700.withOpacity(0.2),
            ),
            accountName: Text(
              'Weighbridge System',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            accountEmail: Text(
              'v2.0 • Serial & IP Camera Engine',
              style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 12),
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.greenAccent,
              child: Icon(
                Icons.factory_outlined,
                color: Colors.black,
                size: 32,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.dashboard_outlined,
              color: Colors.greenAccent,
            ),
            title: const Text(
              'Weighing Screen',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.videocam_outlined,
              color: Colors.blueAccent,
            ),
            title: const Text(
              'IP Camera Management',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CameraManagementScreen(),
                ),
              );
              onCamerasUpdated?.call();
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.bug_report_outlined,
              color: Colors.orangeAccent,
            ),
            title: const Text(
              'IP Camera Test Screen',
              style: TextStyle(color: Colors.white70),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TestScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.psychology,
              color: Colors.greenAccent,
            ),
            title: const Text(
              'AI OCR & Text Recognition',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OcrScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.settings_outlined,
              color: Colors.tealAccent,
            ),
            title: const Text(
              'System Settings',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              onSettingsUpdated?.call();
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.receipt_long_outlined,
              color: Colors.greenAccent,
            ),
            title: const Text(
              'System Diagnostic Logs',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LogViewerScreen(),
                ),
              );
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Antigravity Industrial POS System',
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
