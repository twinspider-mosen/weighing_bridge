import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:weighing_bridge/services/camera_service.dart';
import 'camera_management/add_camera_dialog.dart';
import 'camera_management/camera_grid_view.dart';

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
    showDialog(
      context: context,
      builder: (context) {
        return AddCameraDialog(
          onCameraAdded: (newCamera) async {
            await _storageService.saveCamera(newCamera);
            if (context.mounted) {
              Navigator.of(context).pop();
              _loadCameras();
            }
          },
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
        content: Text('Are you sure you want to remove "${camera.name}"?', style: const TextStyle(color: Colors.white70)),
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
        title: Text('IP Camera Management', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1F25),
        actions: [
          if (_cameras.isNotEmpty) ...[
            ElevatedButton.icon(
              onPressed: () => setState(() => _allStreamsPaused = !_allStreamsPaused),
              icon: Icon(_allStreamsPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18),
              label: Text(_allStreamsPaused ? 'STREAM ALL' : 'PAUSE ALL', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
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
                : CameraGridView(
                    cameras: _cameras,
                    allStreamsPaused: _allStreamsPaused,
                    onDeleteCamera: _deleteCamera,
                  ),
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
          Text('No IP Cameras Added Yet', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 8),
          Text('Click below to add a network camera and monitor live feeds.', style: GoogleFonts.inter(color: Colors.white54)),
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
}
