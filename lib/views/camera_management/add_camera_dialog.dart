import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:weighing_bridge/components/custom_text_field.dart';
import 'package:weighing_bridge/services/camera_service.dart';

class AddCameraDialog extends StatefulWidget {
  final Function(CameraConfig) onCameraAdded;

  const AddCameraDialog({super.key, required this.onCameraAdded});

  @override
  State<AddCameraDialog> createState() => _AddCameraDialogState();
}

class _AddCameraDialogState extends State<AddCameraDialog> {
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1F25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'Add IP Camera',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _nameController,
                labelText: 'Camera Name (e.g. Weighbridge Entry)',
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _ipController,
                labelText: 'IP Address / RTSP URL',
                hintText: '192.168.0.31 or rtsp://...',
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Tip: Enter an IP like 192.168.0.31 to automatically configure standard Dahua/Hikvision RTSP stream, or enter full rtsp:// URL.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState?.validate() ?? false) {
              final name = _nameController.text.trim();
              final ipInput = _ipController.text.trim();
              String rtspUrl = ipInput;
              String ipAddress = ipInput;

              if (!rtspUrl.startsWith('rtsp://') && !rtspUrl.startsWith('http://')) {
                rtspUrl = "rtsp://admin:admin%4012345@$ipInput:554/cam/realmonitor?channel=1&subtype=1";
              } else {
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

              widget.onCameraAdded(newCamera);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Add Camera'),
        ),
      ],
    );
  }
}
