import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'camera_service.dart';
import 'live_camera_player.dart';

class CameraManagementScreen extends StatefulWidget {
  const CameraManagementScreen({super.key});

  @override
  State<CameraManagementScreen> createState() => _CameraManagementScreenState();
}

class _CameraManagementScreenState extends State<CameraManagementScreen> {
  final CameraStorageService _storageService = CameraStorageService();
  List<CameraConfig> _cameras = [];
  bool _isLoading = true;
  bool _allStreamsPaused = true;

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    setState(() => _isLoading = true);
    final cameras = await _storageService.getCameras();
    setState(() {
      _cameras = cameras;
      _isLoading = false;
    });
  }

  void _showAddCameraDialog() {
    final nameController = TextEditingController();
    final ipController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1F25),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Add IP Camera',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Camera Name (e.g. Weighbridge Entry)',
                      labelStyle: const TextStyle(color: Colors.white54),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.greenAccent),
                      ),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: ipController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'IP Address / RTSP URL',
                      hintText: '192.168.0.31 or rtsp://...',
                      hintStyle: const TextStyle(color: Colors.white24),
                      labelStyle: const TextStyle(color: Colors.white54),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.greenAccent),
                      ),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tip: Enter an IP like 192.168.0.31 to automatically configure standard Dahua/Hikvision RTSP stream, or enter full rtsp:// URL.',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final name = nameController.text.trim();
                  final ipInput = ipController.text.trim();
                  String rtspUrl = ipInput;
                  String ipAddress = ipInput;

                  if (!rtspUrl.startsWith('rtsp://') && !rtspUrl.startsWith('http://')) {
                    rtspUrl = "rtsp://admin:admin%4012345@$ipInput:554/cam/realmonitor?channel=1&subtype=0";
                  } else {
                    // Extract IP for friendly display if possible
                    final uri = Uri.tryParse(rtspUrl);
                    if (uri != null && uri.host.isNotEmpty) {
                      ipAddress = uri.host;
                    }
                  }

                  final newCamera = CameraConfig(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    ipAddress: ipAddress,
                    rtspUrl: rtspUrl,
                  );

                  await _storageService.saveCamera(newCamera);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    _loadCameras();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Add Camera'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCamera(CameraConfig camera) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F25),
        title: const Text('Remove Camera?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove "${camera.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storageService.deleteCamera(camera.id);
      _loadCameras();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'IP Camera Management',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A1F25),
        actions: [
          if (_cameras.isNotEmpty) ...[
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _allStreamsPaused = !_allStreamsPaused;
                });
              },
              icon: Icon(
                _allStreamsPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 18,
              ),
              label: Text(
                _allStreamsPaused ? 'STREAM ALL' : 'PAUSE ALL',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _allStreamsPaused ? Colors.greenAccent.shade700 : Colors.orangeAccent.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 16),
          ],
          IconButton(
            icon: const Icon(Icons.add_a_photo),
            tooltip: 'Add New Camera',
            onPressed: _showAddCameraDialog,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [Color(0xFF1A1F25), Color(0xFF0A0E12)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
            : _cameras.isEmpty
                ? _buildEmptyState()
                : _buildGrid(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCameraDialog,
        backgroundColor: Colors.greenAccent.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Camera'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off_outlined, size: 80, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'No IP Cameras Added Yet',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'Click below to add a network camera and monitor live feeds.',
            style: GoogleFonts.inter(color: Colors.white54),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddCameraDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add IP Camera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 700) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 16 / 10,
          ),
          itemCount: _cameras.length,
          itemBuilder: (context, index) {
            final camera = _cameras[index];
            return Card(
              color: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              elevation: 8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LiveCameraPlayer(
                    rtspUrl: camera.rtspUrl,
                    cameraName: camera.name,
                    paused: _allStreamsPaused,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        tooltip: 'Remove Camera',
                        onPressed: () => _deleteCamera(camera),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
