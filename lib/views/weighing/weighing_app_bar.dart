import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spider_weighbridge/model/user_model.dart';

class WeighingAppBar extends StatelessWidget implements PreferredSizeWidget {
  final UserModel? activeUser;
  final List<UserModel> availableUsers;
  final VoidCallback onTitleLongPress;
  final ValueChanged<String?> onUserChanged;

  const WeighingAppBar({
    super.key,
    required this.activeUser,
    required this.availableUsers,
    required this.onTitleLongPress,
    required this.onUserChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFF1A1F25),
      elevation: 0,
      title: GestureDetector(
        onLongPress: onTitleLongPress,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Row(
            children: [
              const Icon(Icons.scale, color: Colors.greenAccent),
              const SizedBox(width: 12),
              Text(
                'Spider Weighbridge'.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (activeUser != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: availableUsers.isEmpty
                  ? Text(
                      activeUser!.company.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: const Color(0xFF1A1F25),
                        value: availableUsers.any((u) => u.id == activeUser!.id)
                            ? activeUser!.id
                            : null,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.greenAccent,
                        ),
                        style: GoogleFonts.inter(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                        selectedItemBuilder: (context) => availableUsers
                            .map<Widget>((u) => Center(
                                  child: Text(
                                    u.company.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ))
                            .toList(),
                        items: availableUsers
                            .map((u) => DropdownMenuItem<String>(
                                  value: u.id,
                                  child: Text(
                                    u.company.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: onUserChanged,
                      ),
                    ),
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
