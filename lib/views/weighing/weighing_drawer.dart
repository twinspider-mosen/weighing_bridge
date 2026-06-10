import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:weighing_bridge/model/user_model.dart';
import 'package:weighing_bridge/services/session_service.dart';
import 'package:weighing_bridge/views/auth/login_screen.dart';
import 'package:weighing_bridge/views/camera_management_screen.dart';
import 'package:weighing_bridge/views/log_viewer_screen.dart';
import 'package:weighing_bridge/views/ocr_screen.dart';
import 'package:weighing_bridge/views/settings_screen.dart';
import 'package:weighing_bridge/views/shared_prefs_viewer_screen.dart';
import 'package:weighing_bridge/test_screen.dart';
import 'package:weighing_bridge/views/tflite_detection_screen.dart';
import 'package:weighing_bridge/views/weighing_screen.dart';

class WeighingDrawer extends StatefulWidget {
  final VoidCallback? onCamerasUpdated;
  final VoidCallback? onSettingsUpdated;

  const WeighingDrawer({
    super.key,
    this.onCamerasUpdated,
    this.onSettingsUpdated,
  });

  @override
  State<WeighingDrawer> createState() => _WeighingDrawerState();
}

class _WeighingDrawerState extends State<WeighingDrawer> {
  UserModel? _activeUser;
  List<UserModel> _availableUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final active = await SessionService.getActiveUser();
    final available = await SessionService.getAvailableUsers();
    if (mounted) {
      setState(() {
        _activeUser = active;
        _availableUsers = available;
      });
    }
  }

  Future<void> _switchUser(UserModel user) async {
    await SessionService.switchActiveUser(user.id);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WeighingScreen()),
    );
  }

  Future<void> _logout() async {
    final stillLoggedIn = await SessionService.logoutActiveUser();
    if (!mounted) return;
    if (stillLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WeighingScreen()),
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _addNewUser() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

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
              _activeUser?.name ?? 'Weighbridge System',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            accountEmail: Text(
              _activeUser?.email ?? 'v2.0 • Serial & IP Camera Engine',
              style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 12),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.greenAccent,
              child: Text(
                _activeUser?.name.substring(0, 1).toUpperCase() ?? 'W',
                style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            otherAccountsPictures: _availableUsers
                .where((u) => u.id != _activeUser?.id)
                .map(
                  (u) => GestureDetector(
                    onTap: () => _switchUser(u),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey.shade800,
                      child: Text(
                        u.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                )
                .toList(),
            onDetailsPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1A1F25),
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._availableUsers.map((u) => ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(u.name, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(u.email, style: const TextStyle(color: Colors.white70)),
                          trailing: u.id == _activeUser?.id
                              ? const Icon(Icons.check, color: Colors.greenAccent)
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            _switchUser(u);
                          },
                        )),
                    const Divider(color: Colors.white24),
                    ListTile(
                      leading: const Icon(Icons.person_add, color: Colors.greenAccent),
                      title: const Text('Add Another User', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(context);
                        _addNewUser();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.redAccent),
                      title: const Text('Log Out', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(context);
                        _logout();
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
          // ListTile(
          //   leading: const Icon(
          //     Icons.dashboard_outlined,
          //     color: Colors.greenAccent,
          //   ),
          //   title: const Text(
          //     'Weighing Screen',
          //     style: TextStyle(color: Colors.white),
          //   ),
          //   onTap: () {
          //     Navigator.pop(context);
          //   },
          // ),
          // ListTile(
          //   leading: const Icon(
          //     Icons.videocam_outlined,
          //     color: Colors.blueAccent,
          //   ),
          //   title: const Text(
          //     'IP Camera Management',
          //     style: TextStyle(color: Colors.white),
          //   ),
          //   onTap: () async {
          //     Navigator.pop(context);
          //     await Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) => const CameraManagementScreen(),
          //       ),
          //     );
          //     widget.onCamerasUpdated?.call();
          //   },
          // ),
          // ListTile(
          //   leading: const Icon(
          //     Icons.bug_report_outlined,
          //     color: Colors.orangeAccent,
          //   ),
          //   title: const Text(
          //     'IP Camera Test Screen',
          //     style: TextStyle(color: Colors.white70),
          //   ),
          //   onTap: () {
          //     Navigator.pop(context);
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => const TestScreen()),
          //     );
          //   },
          // ),
          // ListTile(
          //   leading: const Icon(
          //     Icons.psychology,
          //     color: Colors.greenAccent,
          //   ),
          //   title: const Text(
          //     'AI OCR & Text Recognition',
          //     style: TextStyle(color: Colors.white),
          //   ),
          //   onTap: () async {
          //     Navigator.pop(context);
          //     await Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => const OcrScreen()),
          //     );
          //   },
          // ),
          // ListTile(
          //   leading: const Icon(
          //     Icons.filter_center_focus_outlined,
          //     color: Colors.cyanAccent,
          //   ),
          //   title: const Text(
          //     'TFLite Plate Detection',
          //     style: TextStyle(color: Colors.white),
          //   ),
          //   onTap: () async {
          //     Navigator.pop(context);
          //     await Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => const TfliteDetectionScreen()),
          //     );
          //   },
          // ),
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
              widget.onSettingsUpdated?.call();
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
          ListTile(
            leading: const Icon(
              Icons.storage_outlined,
              color: Colors.orangeAccent,
            ),
            title: const Text(
              'Shared Prefs Viewer',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SharedPrefsViewerScreen(),
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
