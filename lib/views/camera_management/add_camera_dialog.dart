import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spider_weighbridge/components/custom_text_field.dart';
import 'package:spider_weighbridge/services/camera_service.dart';
import 'package:spider_weighbridge/utils/constants.dart';

class AddCameraDialog extends StatefulWidget {
  final Function(CameraConfig) onCameraAdded;
  final CameraConfig? cameraToEdit;

  const AddCameraDialog({
    super.key,
    required this.onCameraAdded,
    this.cameraToEdit,
  });

  @override
  State<AddCameraDialog> createState() => _AddCameraDialogState();
}

class _AddCameraDialogState extends State<AddCameraDialog> {
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _enableAnpr = false;

  @override
  void initState() {
    super.initState();
    if (widget.cameraToEdit != null) {
      _nameController.text = widget.cameraToEdit!.name;
      _ipController.text = widget.cameraToEdit!.ipAddress.isNotEmpty
          ? widget.cameraToEdit!.ipAddress
          : widget.cameraToEdit!.rtspUrl;
      _enableAnpr = widget.cameraToEdit!.enableAnpr;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.cameraToEdit != null;
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1F25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isEditing ? 'Edit IP Camera' : 'Add IP Camera',
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
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _ipController,
                labelText: 'IP Address / RTSP URL',
                hintText: '192.168.0.31 or rtsp://...',
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Tip: Enter an IP like 192.168.0.31 to automatically configure standard Dahua/Hikvision RTSP stream, or enter full rtsp:// URL.',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _enableAnpr
                        ? Colors.greenAccent.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      color: _enableAnpr ? Colors.greenAccent : Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enable ANPR',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Extract number plate image and text via Dahua/Hikvision API',
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _enableAnpr,
                      activeColor: Colors.greenAccent,
                      onChanged: (val) => setState(() => _enableAnpr = val),
                    ),
                  ],
                ),
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
            if (_formKey.currentState?.validate() ?? false) {
              final name = _nameController.text.trim();
              final ipInput = _ipController.text.trim();
              String rtspUrl = ipInput;
              String ipAddress = ipInput;

              if (!rtspUrl.startsWith('rtsp://') &&
                  !rtspUrl.startsWith('http://')) {
                rtspUrl = CameraConstants.buildRtspUrl(ipInput);
              } else {
                final uri = Uri.tryParse(rtspUrl);
                if (uri != null && uri.host.isNotEmpty) {
                  ipAddress = uri.host;
                }
              }

              final cameraId =
                  widget.cameraToEdit?.id ??
                  DateTime.now().millisecondsSinceEpoch.toString();

              final newCamera = CameraConfig(
                id: cameraId,
                name: name,
                ipAddress: ipAddress,
                rtspUrl: rtspUrl,
                enableAnpr: _enableAnpr,
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
          child: Text(isEditing ? 'Save Changes' : 'Add Camera'),
        ),
      ],
    );
  }
}
