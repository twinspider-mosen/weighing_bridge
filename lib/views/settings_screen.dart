import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weighing_bridge/components/action_button.dart';
import 'package:weighing_bridge/components/custom_text_field.dart';
import 'package:weighing_bridge/services/settings_service.dart';
import 'package:weighing_bridge/utils/helper_functions.dart';

/// A premium, custom-styled Settings Screen built to match the high-fidelity dark dashboard aesthetic.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  bool _uploadOnCapture = true;
  bool _requireApprovalForRecords = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final value = await _settingsService.getUploadOnCapture();
    final approvalValue = await _settingsService.getRequireApprovalForRecords();
    if (mounted) {
      setState(() {
        _uploadOnCapture = value;
        _requireApprovalForRecords = approvalValue;
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

  Future<void> _toggleRequireApprovalForRecords(bool value) async {
    setState(() {
      _requireApprovalForRecords = value;
    });
    await _settingsService.setRequireApprovalForRecords(value);

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
                    ? "Settings updated: Approval required for records enabled"
                    : "Settings updated: Approval required for records disabled",
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
                    reusableCard(
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 18,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'System Configureation',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                ),
                              ),
                              FutureBuilder(
                                future: HelperFunctions.getSystemDetails(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData || snapshot.hasError) {
                                    return SizedBox();
                                  }
                                  return Text(
                                    'Name: ${snapshot.data!['scale_id']}      |      Subdomain: ${snapshot.data!['subdomains']}',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w400,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          ActionButton(
                            label: 'Update',
                            icon: Icons.edit,
                            color: Colors.greenAccent,
                            onPressed: () async {
  bool isLoading = false;

  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController subdomainController =
      TextEditingController();

  final pref = await SharedPreferences.getInstance();

  nameController.text =
      pref.getString('scale_id') ?? '';

  List<String> subdomains =
      pref.getStringList('subdomains') ?? [];

  final result = await showDialog(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1F25),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),

            title: Text(
              'System Details',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  /// SCALE ID
                  CustomTextField(
                    controller: nameController,
                    labelText: "Scale ID",
                  ),

                  const SizedBox(height: 20),

                  /// ADD SUBDOMAIN
                  Text(
                    "Subdomains",
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller:
                              subdomainController,
                          labelText:
                              "Add Subdomain",
                        ),
                      ),

                      const SizedBox(width: 8),

                      IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: Colors.greenAccent,
                          size: 30,
                        ),
                        onPressed: () {
                          final value =
                              subdomainController.text
                                  .trim();

                          if (value.isEmpty) return;

                          if (!subdomains
                              .contains(value)) {
                            setState(() {
                              subdomains.add(value);
                            });
                          }

                          subdomainController.clear();
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  /// SUBDOMAIN LIST
                  Container(
                    constraints:
                        const BoxConstraints(
                      maxHeight: 220,
                    ),

                    child: subdomains.isEmpty
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(
                                      20),
                              child: Text(
                                "No subdomains added",
                                style:
                                    GoogleFonts.inter(
                                  color:
                                      Colors.white38,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount:
                                subdomains.length,
                            itemBuilder:
                                (context, index) {
                              final item =
                                  subdomains[index];

                              return Container(
                                margin:
                                    const EdgeInsets
                                        .only(
                                  bottom: 10,
                                ),

                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),

                                decoration:
                                    BoxDecoration(
                                  color: Colors.white
                                      .withOpacity(
                                          0.04),

                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                              12),

                                  border: Border.all(
                                    color: Colors
                                        .white
                                        .withOpacity(
                                            0.08),
                                  ),
                                ),

                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons
                                          .domain_outlined,
                                      color: Colors
                                          .greenAccent,
                                      size: 18,
                                    ),

                                    const SizedBox(
                                        width: 10),

                                    Expanded(
                                      child: Text(
                                        item,
                                        style:
                                            GoogleFonts
                                                .inter(
                                          color: Colors
                                              .white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),

                                    IconButton(
                                      icon:
                                          const Icon(
                                        Icons.delete,
                                        color:
                                            Colors.red,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          subdomains
                                              .removeAt(
                                                  index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 20),

                  /// UPDATE BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ActionButton(
                      label: isLoading
                          ? 'Saving...'
                          : 'Update',

                      color: Colors.green,

                      isPrimary: true,

                      onPressed: () async {
                        setState(() {
                          isLoading = true;
                        });

                        await pref.setString(
                          'scale_id',
                          nameController.text
                              .trim(),
                        );

                        await pref.setStringList(
                          'subdomains',
                          subdomains,
                        );

                        setState(() {
                          isLoading = false;
                        });

                        Navigator.pop(
                          context,
                          true,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (result == true) {
    setState(() {});
  }
},
                            isPrimary: true,
                          ),
                        ],
                      ),
                    ),

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
                    ReusableSettingTile(
                      value: _uploadOnCapture,
                      onChanged: _toggleUploadOnCapture,
                      title: "Upload on Capture",
                      enabledDescription:
                          "Prompt with a secure popup to upload captured snapshots and scale weight readings directly to the API server.",
                      disabledDescription:
                          "Skip server uploads completely. Automatically save captured snapshots locally on this machine.",
                      enabledIcon: Icons.cloud_upload_outlined,
                      disabledIcon: Icons.save_alt_outlined,
                    ),
                    const SizedBox(height: 12),
                    ReusableSettingTile(
                      value: _requireApprovalForRecords,
                      onChanged: _toggleRequireApprovalForRecords,
                      title: "Require Approval for Records",
                      enabledDescription:
                          "Show an approval dialog when a record is received from the Firebase stream. If rejected, it updates the record to 'rejected'.",
                      disabledDescription:
                          "Automatically process incoming Firebase stream records without requiring user approval.",
                      enabledIcon: Icons.verified_user_outlined,
                      disabledIcon: Icons.gpp_bad_outlined,
                    ),

                    ////
                    const SizedBox(height: 24),
                    ////
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
                          const Icon(
                            Icons.info_outline,
                            color: Colors.white38,
                            size: 16,
                          ),
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

Widget reusableCard({
  required Widget child,
  EdgeInsets padding = const EdgeInsets.all(0),
}) {
  return Container(
    padding: padding,
    margin: EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.01),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    ),
    child: child,
  );
}

class ReusableSettingTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  final String title;
  final String enabledDescription;
  final String disabledDescription;

  final IconData enabledIcon;
  final IconData disabledIcon;

  final Color activeColor;

  const ReusableSettingTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    required this.enabledDescription,
    required this.disabledDescription,
    required this.enabledIcon,
    required this.disabledIcon,
    this.activeColor = Colors.greenAccent,
  });

  @override
  Widget build(BuildContext context) {
    return reusableCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          activeColor: activeColor,
          activeTrackColor: activeColor.withOpacity(0.3),
          inactiveThumbColor: Colors.white30,
          inactiveTrackColor: Colors.white10,

          secondary: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value
                  ? activeColor.withOpacity(0.08)
                  : Colors.white.withOpacity(0.04),
              shape: BoxShape.circle,
              border: Border.all(
                color: value
                    ? activeColor.withOpacity(0.2)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Icon(
              value ? enabledIcon : disabledIcon,
              color: value ? activeColor : Colors.white54,
              size: 24,
            ),
          ),

          title: Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),

          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              value ? enabledDescription : disabledDescription,
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),

          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
