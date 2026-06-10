import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:weighing_bridge/components/action_button.dart';
import 'package:weighing_bridge/components/live_camera_player.dart';
import 'package:weighing_bridge/components/upload_dialog.dart';
import 'package:weighing_bridge/model/command_model.dart';
import 'package:weighing_bridge/model/user_model.dart';
import 'package:weighing_bridge/services/camera_service.dart';
import 'package:weighing_bridge/services/firebase_service.dart';
import 'package:weighing_bridge/services/logger_service.dart';
import 'package:weighing_bridge/services/ocr_service.dart';
import 'package:weighing_bridge/services/scale_service.dart';
import 'package:weighing_bridge/services/session_service.dart';
import 'package:weighing_bridge/services/settings_service.dart';
import 'package:weighing_bridge/utils/helper_functions.dart';
import 'package:weighing_bridge/views/camera_management_screen.dart';
import 'weighing/weighing_drawer.dart';
import 'weighing/weighing_control_panel.dart';
import 'weighing/weight_display_card.dart';
import 'weighing/camera_feed_panel.dart';
import 'weighing/weighing_status_header.dart';

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

  final CameraStorageService _cameraStorage = CameraStorageService();
  List<CameraConfig> _savedCameras = [];
  CameraConfig? _selectedCamera;
  final GlobalKey<LiveCameraPlayerState> _cameraPlayerKey =
      GlobalKey<LiveCameraPlayerState>();
  bool _isCapturingSnap = false;
  double _currentCameraZoom = 1.0;

  final SettingsService _settingsService = SettingsService();
  bool _uploadOnCapture = true;
  bool _requireApprovalForRecords = false;
  StreamSubscription? _commandSubscription;
  String? _lastCommandId;
  UserModel? _activeUser;

  @override
  void initState() {
    super.initState();
    _refreshPorts();
    _loadSavedCameras();
    _loadSettings();
    _loadUser();
    _scaleService.weightStream.listen(_handleNewData);

    initStream();
  }

  Future<void> _loadUser() async {
    final user = await SessionService.getActiveUser();
    if (mounted) {
      setState(() {
        _activeUser = user;
      });
    }
  }

  // initStream()async{
  //    final details = await HelperFunctions.getSystemDetails();

  // _commandSubscription = FirebaseService.getCommandStream(
  //   scaleID: details['scale_id'] ?? '',
  //   subdomain: details['subdomain'] ?? '',
  // ).listen(_handleCommandStream);
  // }

  Future<void> initStream() async {
    final details = await HelperFunctions.getSystemDetails();
    final scaleID = details['scale_id'] as String? ?? '';
    final subdomains = details['subdomains'] as List<String>? ?? [];

    if (scaleID.isEmpty || subdomains.isEmpty) {
      print("Firestore listener skipped: scaleID or subdomains is empty.");
      return;
    }

    _commandSubscription =
        FirebaseService.getCommandStream(
          scaleID: scaleID,
          subdomains: subdomains,
        ).listen(
          (snapshot) async {
            for (final change in snapshot.docChanges) {
              // ONLY react to newly added docs
              if (change.type == DocumentChangeType.added) {
                final command = CommandModel.fromMap(change.doc.data()!);

                print("NEW COMMAND RECEIVED");
                print(command.requestID);

                // prevent duplicates
                // if (_lastCommandId == command.requestID) {
                //   print("Duplicate ignored");
                //   return;
                // }

                _lastCommandId = command.requestID;

                // Load Settings again to check the current value
                final approvalRequired = await _settingsService
                    .getRequireApprovalForRecords();

                if (approvalRequired) {
                  if (!mounted) return;
                  final approved = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) {
                      return AlertDialog(
                        backgroundColor: const Color(0xFF1A1F25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: Row(
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              color: Colors.greenAccent,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Approval Required',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'An incoming weight record has been received:',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Scale Name: ${command.scaleName}',
                              style: GoogleFonts.inter(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Subdomain: ${command.subdomain}',
                              style: GoogleFonts.inter(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Request ID: ${command.requestID}',
                              style: GoogleFonts.inter(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Do you want to accept this request, capture the camera feed, and submit the data?',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              'Reject',
                              style: GoogleFonts.inter(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              'Accept',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );

                  if (approved == true) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green.shade800,
                        content: const Text(
                          "Request approved. Capturing and sending data...",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                    await CameraCaptureService.captureAndHandle(
                      context: context,
                      autoUpload: true,
                      cameraPlayerKey: _cameraPlayerKey,
                      uploadOnCapture: _uploadOnCapture,
                      currentWeight: _currentWeight,
                      unit: _unit,
                      scaleName: command.scaleName,
                      requestID: command.requestID,
                      subdomain: command.subdomain,
                      onLoadingChanged: (loading) {
                        if (mounted) {
                          setState(() {
                            _isCapturingSnap = loading;
                          });
                        }
                      },
                      recordType: '',
                      scaleStockId: '',
                    );
                  } else {
                    try {
                      await FirebaseFirestore.instance
                          .collection('ScaleRequests')
                          .doc(change.doc.id)
                          .update({'status': 'rejected'});
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.red.shade800,
                            content: const Text(
                              "Request rejected. Status updated to rejected.",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      print("Error updating status to rejected: $e");
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.teal.shade800,
                        content: const Text(
                          "Incoming request received. Capturing and sending data...",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  }

                  await CameraCaptureService.captureAndHandle(
                    context: context,
                    autoUpload: true,
                    cameraPlayerKey: _cameraPlayerKey,
                    uploadOnCapture: _uploadOnCapture,
                    currentWeight: _currentWeight,
                    unit: _unit,
                    scaleName: command.scaleName,
                    requestID: command.requestID,
                    subdomain: command.subdomain,
                    onLoadingChanged: (loading) {
                      if (mounted) {
                        setState(() {
                          _isCapturingSnap = loading;
                        });
                      }
                    },
                    recordType: command.recordType,
                    scaleStockId: command.scaleStockId,
                  );
                }
              }
            }
          },
          onError: (e) {
            print("Firestore listener stream error: $e");
          },
        );
  }

  Future<void> _handleCommandStream(dynamic snapshot) async {
    if (!mounted) return;

    final commands = snapshot.docs
        .map<CommandModel>((doc) => CommandModel.fromMap(doc.data()))
        .toList();

    if (commands.isEmpty) return;

    final command = commands.first;

    // prevent duplicate processing
    if (_lastCommandId == command.requestID) return;

    _lastCommandId = command.requestID;

    await CameraCaptureService.captureAndHandle(
      context: context,
      autoUpload: true,
      cameraPlayerKey: _cameraPlayerKey,
      uploadOnCapture: _uploadOnCapture,
      currentWeight: _currentWeight,
      unit: _unit,
      scaleName: command.scaleName,
      requestID: command.requestID,
      subdomain: command.subdomain,
      onLoadingChanged: (loading) {
        if (mounted) {
          setState(() {
            _isCapturingSnap = loading;
          });
        }
      },
      recordType: command.recordType,
      scaleStockId: command.scaleStockId,
    );
  }

  @override
  void dispose() {
    _commandSubscription?.cancel();
    _scaleService.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final value = await _settingsService.getUploadOnCapture();
    final approvalValue = await _settingsService.getRequireApprovalForRecords();
    if (mounted) {
      setState(() {
        _uploadOnCapture = value;
        _requireApprovalForRecords = approvalValue;
      });
    }
  }

  Future<void> _loadSavedCameras() async {
    final cameras = await _cameraStorage.getCameras();
    setState(() {
      _savedCameras = cameras;
      if (_selectedCamera != null &&
          !cameras.any((c) => c.id == _selectedCamera!.id)) {
        _selectedCamera = null;
      }
      if (_selectedCamera == null && cameras.isNotEmpty) {
        _selectedCamera = cameras.first;
      }
    });
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
      setState(() => _status = 'Error loading ports: $e');
    }
  }

  void _handleNewData(String data) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) return;
    final match = RegExp(r'([0-9]+\.[0-9]+|[0-9]+)').firstMatch(trimmed);
    final unitMatch = RegExp(
      r'(kg|lb|g)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    setState(() {
      if (match != null) {
        final raw = match.group(0)!;
        try {
          _currentWeight = raw.contains('.')
              ? double.parse(raw).toStringAsFixed(2)
              : int.parse(raw).toString();
        } catch (_) {
          _currentWeight = raw;
        }
      }
      if (unitMatch != null) _unit = unitMatch.group(0)!.toLowerCase();
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
      final config = await _scaleService
          .scanPort(_selectedPort!)
          .timeout(const Duration(seconds: 45));
      if (config != null) {
        final success = await _scaleService.startListening(
          _selectedPort!,
          config,
        );
        setState(() {
          _activeConfig = config;
          _isListening = success;
          _status = success ? 'Connected' : 'Connection Failed';
        });
      } else {
        setState(() => _status = 'Scan Failed (No Signal)');
      }
    } catch (e) {
      setState(() => _status = 'Scan Error: $e');
    } finally {
      setState(() => _isScanning = false);
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
        final success = await _scaleService.startListening(
          _selectedPort!,
          _activeConfig!,
        );
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: OcrService(),
      builder: (context, _) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A1F25),
            elevation: 0,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.scale, color: Colors.greenAccent),
                const SizedBox(width: 12),
                Text(
                  'WEIGHING BRIDGE DASHBOARD',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            actions: [
              if (_activeUser != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: Text(
                      _activeUser!.company.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          drawer: WeighingDrawer(
            onCamerasUpdated: _loadSavedCameras,
            onSettingsUpdated: _loadSettings,
          ),
          body: FutureBuilder(
            future: HelperFunctions.getSystemDetails(),
            builder: (context, snap) {
              if (!snap.hasData || snap.hasError) {
                return Text('');
              }
              return StreamBuilder(
                stream: FirebaseService.getCommandStream(
                  scaleID: snap.data!['scale_id'] ?? '',
                  subdomains: snap.data!['subdomains'] ?? [],
                ),
                builder: (context, snapshot) {
                  // print(snapshot.data?.docs.toList().first.data());
                  print(snapshot.data?.docs);
                  // print("snapshot data"+snapshot.data?.docs);
                  if (!snapshot.hasData || snapshot.hasError) {
                    print(snapshot.error);
                  }
                  List<CommandModel> commands = [];
                  CommandModel command = CommandModel(
                    subdomain: '',
                    requestID: '',

                    image: File('/'),
                    weight: 0.0,
                    status: 'pending',
                    scaleName: '',
                    scaleStockId: '',
                    recordType: '',
                  );
                  if (snapshot.data != null) {
                    commands = List<CommandModel>.from(
                      snapshot.data.docs.map(
                        (doc) => CommandModel.fromMap(doc.data()),
                      ),
                    ).toList();
                    command = commands.isNotEmpty ? commands.first : command;
                  }

                  return Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.5,
                        colors: [Color(0xFF1A1F25), Color(0xFF0A0E12)],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 950;
                            return SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  WeighingStatusHeader(
                                    isListening: _isListening,
                                    status: _status,
                                    requireApproval: _requireApprovalForRecords,
                                  ),
                                  const SizedBox(height: 24),
                                  if (isWide)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: _buildWeighingColumn(),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          flex: 2,
                                          child: _buildCameraColumn(
                                            shrinkWrap: false,
                                            scaleName: command.scaleName,
                                            requestID: command.requestID,
                                            subdomain: command.subdomain,
                                            scaleStockId: command.scaleStockId,
                                            recordType: command.recordType,
                                          ),
                                        ),
                                      ],
                                    )
                                  else ...[
                                    _buildWeighingColumn(),
                                    const SizedBox(height: 32),
                                    const Divider(color: Colors.white24),
                                    const SizedBox(height: 32),
                                    _buildCameraColumn(
                                      shrinkWrap: true,
                                      requestID: command.requestID,
                                      subdomain: command.subdomain,
                                      scaleName: command.scaleName,
                                      scaleStockId: command.scaleStockId,
                                      recordType: command.recordType,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildWeighingColumn() {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          //  SizedBox(height: 300
          WeightDisplayCard(
            currentWeight: _currentWeight,
            unit: _unit,
            activeConfig: _activeConfig,
          ),
          const SizedBox(height: 100),
          WeighingControlPanel(
            selectedPort: _selectedPort,
            ports: _scaleService.getAvailablePorts(),
            isScanning: _isScanning,
            isListening: _isListening,
            onPortChanged: (val) => setState(() => _selectedPort = val),
            onRefreshPorts: _refreshPorts,
            onStartScan: _startScan,
            onToggleListener: _toggleListener,
          ),
        ],
      ),
    );
  }

  Widget _buildCameraColumn({
    required bool shrinkWrap,
    required String scaleName,
    required String scaleStockId,
    required String recordType,
    required String requestID,
    required String subdomain,
  }) {
    return CameraFeedPanel(
      savedCameras: _savedCameras,
      selectedCamera: _selectedCamera,
      cameraPlayerKey: _cameraPlayerKey,
      currentCameraZoom: _currentCameraZoom,
      isCapturingSnap: _isCapturingSnap,
      shrinkWrap: shrinkWrap,
      onCameraChanged: (val) {
        setState(() {
          _selectedCamera = val;
          _currentCameraZoom = 1.0;
        });
        _cameraPlayerKey.currentState?.resetZoom();
      },
      onRefreshStream: () async {
        await _cameraPlayerKey.currentState?.refreshStream();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Refreshing live stream for '${_selectedCamera!.name}'...",
              ),
            ),
          );
      },
      onCaptureSnap: () {
        CameraCaptureService.captureAndHandle(
          context: context,
          cameraPlayerKey: _cameraPlayerKey,
          uploadOnCapture: _uploadOnCapture,
          currentWeight: _currentWeight,
          unit: _unit,
          requestID: requestID,
          subdomain: subdomain,
          onLoadingChanged: (loading) {
            if (mounted) {
              setState(() {
                _isCapturingSnap = loading;
              });
            }
          },
          scaleName: scaleName,
          scaleStockId: scaleStockId,
          recordType: recordType,
        );
      },
      onZoomIn: () {
        _cameraPlayerKey.currentState?.zoomIn();
        if (mounted)
          setState(() {
            _currentCameraZoom = _cameraPlayerKey.currentState?.zoom ?? 1.0;
          });
      },
      onZoomOut: () {
        _cameraPlayerKey.currentState?.zoomOut();
        if (mounted)
          setState(() {
            _currentCameraZoom = _cameraPlayerKey.currentState?.zoom ?? 1.0;
          });
      },
      onResetZoom: () {
        _cameraPlayerKey.currentState?.resetZoom();
        if (mounted) setState(() => _currentCameraZoom = 1.0);
      },
      onManageCameras: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CameraManagementScreen(),
          ),
        );
        _loadSavedCameras();
      },
    );
  }
}
