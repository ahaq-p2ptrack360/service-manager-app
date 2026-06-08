import 'package:anwar/company_profile.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anwar/profile.dart';
import 'package:anwar/chats.dart';
import 'package:anwar/dashboard.dart';
import 'package:anwar/main.dart';
import 'package:anwar/tickets.dart';

class MyDrawer extends StatefulWidget {
  const MyDrawer({super.key});

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  String username = "User";
  String isSuperAdmin = "0";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString("name");
    final superAdminStatus = prefs.getString("is_super_admin") ?? "0";

    if (mounted) {
      setState(() {
        username = name ?? "User";
        isSuperAdmin = superAdminStatus;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xff332757),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 15),
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const CircleAvatar(
                      radius: 25,
                      backgroundImage: AssetImage("assets/avatarpic.jpg"),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          height: 45,
                          width: 51,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 5),
                        // Show Company Profile button only when is_super_admin is "1"
                        if (isSuperAdmin == "0")
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CompanyProfile(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xff332757),
                                borderRadius: BorderRadius.circular(15),
                                border:
                                Border.all(color: Colors.white, width: 1),
                              ),
                              child: Text(
                                "Company Profile",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Username
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    isLoading ? 'Loading...' : username,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white54, height: 1),
          const SizedBox(height: 10),

          // Menu Items
          _buildMenuItem(
            title: 'Home',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const Dashboard()),
              );
            },
          ),
          _buildMenuItem(
            title: 'Tickets',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const Tickets()),
              );
            },
          ),
          _buildMenuItem(
            title: 'Chats',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const Chats()),
              );
            },
          ),
          _buildMenuItem(
            title: 'Profile',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileViewScreen(userData: {}),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white54, height: 1),
          const SizedBox(height: 10),
          _buildMenuItem(
            title: 'Logout',
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            },
            isLogout: true,
          ),
          // const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            // color: Colors.white54
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}



Widget myAppBar(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final width = size.width;

  return AppBar(
    backgroundColor: const Color(0xff332757),
    iconTheme: const IconThemeData(color: Colors.white),
    title:  Text(
      'P2P Track Dashboard',
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    actions: [
      IconButton(
        icon: Icon(Icons.notifications_none, size: width * 0.06, color: Colors.white),
        onPressed: () {},
      ),
      Container(
        margin: const EdgeInsets.only(right: 16),
        width: width * 0.1,
        height: width * 0.1,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(width * 0.05),
        ),
        child: const Icon(Icons.person_outline, color: Colors.black87),
      ),
    ],
  );
}


