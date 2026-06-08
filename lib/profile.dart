import 'package:anwar/constant.dart';
import 'package:anwar/notification_service.dart';
import 'package:anwar/widget/notifications_popup.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileViewScreen extends StatefulWidget {
  final Map<String, dynamic> userData; // Receive user data from login API

  const ProfileViewScreen({super.key, required this.userData});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  String username = "";
  String email = "";
  String company = "";
  String phone = "";
  String address = "";
  List<NotificationModel> notificationsList = [];
  int unreadNotificationCount = 0;

  // For tracking new notifications
  List<int> previousNotificationIds = [];
  bool _isFirstNotificationFetch = true;

  @override
  void initState() {
    super.initState();
    loadUserData();
    fetchNotifications();
    _startNotificationPolling();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> fetchNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = int.parse(prefs.getString("id") ?? "0");

      final fetchedNotifications = await NotificationService().fetchNotifications(userId);

      // Check for new notifications (only after first fetch)
      if (!_isFirstNotificationFetch && previousNotificationIds.isNotEmpty) {
        final newNotifications = fetchedNotifications.where(
                (n) => !previousNotificationIds.contains(n.id)
        ).toList();

        // Show toast/snackbar for new notifications
        if (newNotifications.isNotEmpty) {
          _showNewNotificationToast(newNotifications.length);
        }
      }

      // Store current notification IDs for next comparison
      previousNotificationIds = fetchedNotifications.map((n) => n.id).toList();
      _isFirstNotificationFetch = false;

      setState(() {
        notificationsList = fetchedNotifications;
        unreadNotificationCount = notificationsList.where((n) => !n.isRead).length;
      });
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  // Method to show toast for new notifications
  void _showNewNotificationToast(int count) {
    // Using SnackBar (built-in Flutter)
    final snackBar = SnackBar(
      content: Row(
        children: [
          const Icon(Icons.notifications_active, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count new notification${count != 1 ? 's' : ''} received!',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xff332757),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'VIEW',
        textColor: Colors.white,
        onPressed: _showNotificationsPopup,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Method to show notifications popup
  Future<void> _showNotificationsPopup() async {
    // Refresh notifications before showing
    await fetchNotifications();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return NotificationsPopup(
          notifications: notificationsList,
          onRefresh: () {
            // Refresh notifications when marked as read
            fetchNotifications();
          },
        );
      },
    );
  }

  void _startNotificationPolling() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        fetchNotifications();
        _startNotificationPolling(); // Continue polling
      }
    });
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString("name") ?? "User";
      email = prefs.getString("email") ?? "Email";
      company = prefs.getString("company") ?? "company_id";
      phone = prefs.getString("phone") ?? "phone";
      address = prefs.getString("address") ?? "address";
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xff332757),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.notifications_none, size: width * 0.06, color: Colors.white),
                if (unreadNotificationCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadNotificationCount > 9 ? '9+' : '$unreadNotificationCount',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showNotificationsPopup,
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: width * 0.1,
            height: width * 0.1,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(width * 0.05),
            ),
            child: GestureDetector(
              child: const Icon(Icons.person_outline, color: Colors.black87),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileViewScreen(userData: {})));
              },
            ),
          ),
        ],
      ),
      drawer: MyDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Profile Fields
              _buildInfoRow(
                label: "Name",
                value: Text(widget.userData['name'] ?? username),
                icon: Icons.person_outline,
              ),

              const SizedBox(height: 16),
              _buildInfoRow(
                label: "Email",
                value: Text(widget.userData['email'] ?? email),
                icon: Icons.email_outlined,
              ),

              const SizedBox(height: 16),
              _buildInfoRow(
                label: "Phone",
                value: Text(widget.userData['phone']?.toString() ?? phone),
                icon: Icons.phone_outlined,
              ),

              const SizedBox(height: 16),
              _buildInfoRow(
                label: "Address",
                value: Text(widget.userData['address']?.toString() ?? address),
                icon: Icons.location_on_outlined,
              ),

              const SizedBox(height: 16),
              _buildInfoRow(
                label: "Company ID",
                value: Text(widget.userData['company_id']?.toString() ?? company),
                icon: Icons.business_outlined,
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required Widget value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FAF5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xff332757), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: value,
              ),
            ],
          ),
        ),
      ],
    );
  }
}


// import 'package:anwar/constant.dart';
// import 'package:anwar/notification_service.dart';
// import 'package:anwar/widget/notifications_popup.dart';
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class ProfileViewScreen extends StatefulWidget {
//   final Map<String, dynamic> userData; // Receive user data from login API
//
//   const ProfileViewScreen({super.key, required this.userData});
//
//   @override
//   State<ProfileViewScreen> createState() => _ProfileViewScreenState();
// }
//
// class _ProfileViewScreenState extends State<ProfileViewScreen> {
//   String username = "";
//   String email = "";
//   String company = "";
//   String phone = "";
//   String address = "";
//   List<NotificationModel> notificationsList = []; // Changed variable name
//   int unreadNotificationCount = 0;
//
//   @override
//   void initState() {
//     super.initState();
//     loadUserData();
//     fetchNotifications();
//     _startNotificationPolling();
//   }
//   Future<void> fetchNotifications() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final userId = int.parse(prefs.getString("id") ?? "0");
//
//       final fetchedNotifications = await NotificationService().fetchNotifications(userId);
//       setState(() {
//         notificationsList = fetchedNotifications;
//         unreadNotificationCount = notificationsList.where((n) => !n.isRead).length;
//       });
//     } catch (e) {
//       print('Error fetching notifications: $e');
//     }
//   }
//
// // Add this method to show notifications popup
//   Future<void> _showNotificationsPopup() async {
//     // Refresh notifications before showing
//     await fetchNotifications();
//
//     showDialog(
//       context: context,
//       barrierDismissible: true,
//       builder: (BuildContext context) {
//         return NotificationsPopup(
//           notifications: notificationsList,
//           onRefresh: () {
//             // Refresh notifications when marked as read
//             fetchNotifications();
//           },
//         );
//       },
//     );
//   }
//   void _startNotificationPolling() {
//     Future.delayed(const Duration(seconds: 30), () {
//       if (mounted) {
//         fetchNotifications();
//         _startNotificationPolling(); // Continue polling
//       }
//     });
//   }
//
//   Future<void> loadUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       username = prefs.getString("name") ?? "User";
//       email = prefs.getString("email") ?? "Email";
//       company = prefs.getString("company") ?? "company_id";
//       phone = prefs.getString("phone") ?? "phone";
//       address = prefs.getString("address") ?? "address";
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final width = size.width;
//
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: const Color(0xff332757),
//         iconTheme: const IconThemeData(color: Colors.white),
//         title:  Text(
//           'Profile',
//           style: GoogleFonts.poppins(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//           ),
//         ),
//         actions: [
//           IconButton(
//             icon: Stack(
//               children: [
//                 Icon(Icons.notifications_none, size: width * 0.06, color: Colors.white),
//                 if (unreadNotificationCount > 0)
//                   Positioned(
//                     right: 0,
//                     top: 0,
//                     child: Container(
//                       padding: const EdgeInsets.all(2),
//                       decoration: BoxDecoration(
//                         color: Colors.red,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       constraints: const BoxConstraints(
//                         minWidth: 16,
//                         minHeight: 16,
//                       ),
//                       child: Text(
//                         unreadNotificationCount > 9 ? '9+' : '$unreadNotificationCount',
//                         style: GoogleFonts.poppins(
//                           color: Colors.white,
//                           fontSize: 10,
//                           fontWeight: FontWeight.bold,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//             onPressed: _showNotificationsPopup,
//           ),
//           Container(
//             margin: const EdgeInsets.only(right: 16),
//             width: width * 0.1,
//             height: width * 0.1,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(width * 0.05),
//             ),
//             child:  GestureDetector(
//                 child: const Icon(Icons.person_outline, color: Colors.black87),
//                 onTap: (){
//                   Navigator.push(context, MaterialPageRoute(builder: (context)=>ProfileViewScreen(userData: {},)));
//                 }),
//           ),
//         ],
//       ),
//       drawer: MyDrawer(),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const SizedBox(height: 20),
//
//               // Profile Fields
//               _buildInfoRow(
//                 label: "Name",
//                 value: Text(widget.userData['name'] ?? username), // Use widget.userData directly
//                 icon: Icons.person_outline,
//               ),
//
//               const SizedBox(height: 16),
//               _buildInfoRow(
//                 label: "Email",
//                 value: Text(widget.userData['email'] ?? email), // Use widget.userData directly
//                 icon: Icons.email_outlined,
//               ),
//
//               const SizedBox(height: 16),
//               _buildInfoRow(
//                 label: "Phone",
//                 value: Text(widget.userData['phone']?.toString() ?? phone),
//                 icon: Icons.phone_outlined,
//               ),
//
//               const SizedBox(height: 16),
//               _buildInfoRow(
//                 label: "Address",
//                 value: Text(widget.userData['address']?.toString() ?? address),
//                 icon: Icons.location_on_outlined,
//               ),
//
//               const SizedBox(height: 16),
//               _buildInfoRow(
//                 label: "Company ID",
//                 value: Text(widget.userData['company_id']?.toString() ?? company), // Use widget.userData directly
//                 icon: Icons.business_outlined,
//               ),
//
//               const SizedBox(height: 30),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildInfoRow({
//     required String label,
//     required Widget value, // Changed from String to Widget to accept Text widget
//     required IconData icon,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style:  GoogleFonts.poppins(
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//             color: Colors.black54,
//           ),
//         ),
//         const SizedBox(height: 6),
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//           decoration: BoxDecoration(
//             color: const Color(0xFFF0FAF5),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.grey[300]!),
//           ),
//           child: Row(
//             children: [
//               Icon(icon, color: const Color(0xff332757), size: 20),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: value, // Use the value widget directly
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }
//
//
