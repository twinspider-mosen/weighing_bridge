import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsViewerScreen extends StatefulWidget {
  const SharedPrefsViewerScreen({super.key});

  @override
  State<SharedPrefsViewerScreen> createState() => _SharedPrefsViewerScreenState();
}

class _SharedPrefsViewerScreenState extends State<SharedPrefsViewerScreen> {
  Map<String, dynamic> _prefsData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final Map<String, dynamic> data = {};
    for (String key in keys) {
      data[key] = prefs.get(key);
    }
    setState(() {
      _prefsData = data;
      _isLoading = false;
    });
  }

  Future<void> _clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _loadPrefs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shared Prefs Data', style: GoogleFonts.inter()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPrefs,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1F25),
                  title: const Text('Clear All Prefs?', style: TextStyle(color: Colors.white)),
                  content: const Text(
                    'This will delete all shared preferences data, including active sessions. Are you sure?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('CLEAR ALL', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                _clearPrefs();
              }
            },
            tooltip: 'Clear All Data',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : _prefsData.isEmpty
              ? Center(
                  child: Text(
                    'No data found in SharedPreferences.',
                    style: GoogleFonts.inter(color: Colors.white54),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _prefsData.keys.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white12),
                  itemBuilder: (context, index) {
                    final key = _prefsData.keys.elementAt(index);
                    final value = _prefsData[key];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          key,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: Colors.greenAccent,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: SelectableText(
                            value.toString(),
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
