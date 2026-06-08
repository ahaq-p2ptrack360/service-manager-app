import 'package:anwar/notification_service.dart';
import 'package:anwar/profile.dart';
import 'package:anwar/widget/notifications_popup.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:anwar/constant.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Viewmoretickets extends StatefulWidget {
  final int ticketId;
  const Viewmoretickets({super.key, required this.ticketId});

  @override
  State<Viewmoretickets> createState() => _ViewmoreticketsState();
}

class _ViewmoreticketsState extends State<Viewmoretickets>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<NotificationModel> notificationsList = []; // Changed variable name
  int unreadNotificationCount = 0;
  List<int> previousNotificationIds = [];
  bool _isFirstNotificationFetch = true;
  int _currentStep = 0;
  List<PlatformFile> selectedFiles = [];
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
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    fetchNotifications();

    _startNotificationPolling();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery
        .of(context)
        .size
        .width;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff4b3a79), Color(0xff332757)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title:  Text(
          "Ticket Details",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(1, 2),
                ),
              ],
            ),
            child:  GestureDetector(
                child: const Icon(Icons.person_outline, color: Colors.black87),
                onTap: (){
                  Navigator.push(context, MaterialPageRoute(builder: (context)=>ProfileViewScreen(userData: {},)));
                }),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.black87,
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: "Detail"),
                Tab(text: "Quotation"),
                Tab(text: "Activity"),
              ],
            ),
          ),
        ),
      ),
      drawer: MyDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailTab(), //  dynamically fetches ticket details
          _buildQuotationTab(),
          _buildActivityTab(),
        ],
      ),
    );
  }

  // ------------------- FETCH TICKET DETAIL -------------------
  Future<Map<String, dynamic>> fetchTicketDetail(int id) async {
    final url = Uri.parse('http://3.137.76.254/Service-Manager-main-Work/public/api/tickets/$id');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        return data[0];
      } else {
        throw Exception('Ticket not found');
      }
    } else {
      throw Exception('Failed to fetch ticket details: ${response.statusCode}');
    }
  }

  // ------------------- DETAIL TAB -------------------
  Widget _buildDetailTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchTicketDetail(widget.ticketId),
      // ✅ dynamic based on passed ID
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
              child: Text('Error loading ticket: ${snapshot.error}',
                  style:  GoogleFonts.poppins(color: Colors.red)));
        } else if (!snapshot.hasData) {
          return  Center(child: Text('No ticket details found.',style:  GoogleFonts.poppins(color: Colors.red)));
        }

        final ticket = snapshot.data!;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Color(0xff332757)),
                      const SizedBox(width: 8),
                      Text(
                        'Ticket Detail',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xff332757),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(thickness: 1, height: 24),

                  // Dynamic details
                  buildRow('Title', ticket['title'] ?? '-'),
                  buildRow('Created By', ticket['bu_email'] ?? '-'),
                  buildRow('Assigned To', ticket['resolved_name'] ?? '-'),
                  buildRow('Reported By', ticket['reported_by_name'] ?? '-'),
                  buildRow('Description', ticket['description'] ?? '-'),
                  buildRow('Issue Sub Type', ticket['type_title'] ?? '-'),
                  buildRow('Resolved By', ticket['resolved_name'] ?? '-'),
                  buildRow('Resolved Date', ticket['completed_date'] ?? '-'),
                  buildRow('Due Date', ticket['due_date'] ?? '-'),
                  buildRow('Priority', ticket['priority_title'] ?? '-'),
                  buildRow('Impact', ticket['impact_title'] ?? '-'),
                  buildRow('Status', ticket['status_title'] ?? '-'),
                  buildRow('BU/Store', ticket['bu_name'] ?? '-'),
                  buildRow('Company', ticket['company_name'] ?? '-'),
                  buildRow('Store Contact', ticket['store_contact'] ?? '-'),
                  buildRow('Vendor', ticket['vname'] ?? '-'),

                  const SizedBox(height: 30),

                   Text(
                    'Attached Files',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff332757)),
                  ),
                  const SizedBox(height: 12),

                  if (ticket['file'] != null && ticket['file']
                      .toString()
                      .isNotEmpty)
                    _buildFileCard(ticket['file'])
                  else
                    const Text('No files attached.'),

                  const SizedBox(height: 30),

                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Handle update button here
                      },
                      icon: const Icon(Icons.edit, color: Colors.white),
                      label:  Text(
                        'Update Ticket',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff332757),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        shadowColor: Colors.black38,
                        elevation: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style:  GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style:  GoogleFonts.poppins(
                color: Colors.black54,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(String filename) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade100, Colors.grey.shade200],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xff332757).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                      Icons.insert_drive_file, color: Color(0xff332757)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    filename,
                    overflow: TextOverflow.ellipsis,
                    style:  GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Open file logic (optional)
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff332757),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child:  Text('View', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }


// ------------------- OTHER TABS -------------------

  Widget _buildQuotationTab() {
    Future<List<Map<String, dynamic>>> fetchQuotations(int id) async {
      final url = Uri.parse('http://3.137.76.254/Service-Manager-main-Work/public/api/qutationsbyticket/$id');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          // Normalize each item to a clean Map
          return data.map<Map<String, dynamic>>((q) {
            return {
              'S.No': data.indexOf(q) + 1,
              'Ticket Id': q['ticket_id']?.toString() ?? '-',
              'Vendor': q['vendor_name'] ?? '-',
              'Amount': q['amount']?.toString() ?? '-',
              'Approve': q['approve'] == true ? 'Yes' : 'No',
            };
          }).toList();
        } else {
          throw Exception('Unexpected response format');
        }
      } else {
        throw Exception('Failed to load quotations (${response.statusCode})');
      }
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchQuotations(widget.ticketId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error fetching quotations: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return  Center(
            child: Text(
              'No quotations found for this ticket.',
              style: GoogleFonts.poppins(color: Colors.black54),
            ),
          );
        }

        final quotations = snapshot.data!;

        return Scaffold(
          backgroundColor: Colors.grey[100],
          body: Column(
            children: [
              Card(
                margin: const EdgeInsets.all(12),
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children:  [
                      Text('S.No',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      Text('Ticket Id',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      Text('Vendor',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      Text('Amount',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      Text('Approve',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: quotations.length,
                  itemBuilder: (context, index) {
                    final item = quotations[index];
                    return Card(
                      margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text(item['S.No'].toString()),
                            Text(item['Ticket Id']),
                            Text(item['Vendor']),
                            Text(item['Amount']),
                            Text(item['Approve']),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityTab() {
    Future<List<Map<String, dynamic>>> fetchActivity(int id) async {
      final url = Uri.parse(
          'http://3.137.76.254/Service-Manager-main-Work/public/api/tickets/activity/$id');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List && data.isNotEmpty) {
          return data.map<Map<String, dynamic>>((item) {
            final createdAt = DateTime.tryParse(item["created_at"] ?? "");

            String formattedDate = "-";
            String formattedTime = "";

            if (createdAt != null) {
              formattedDate =
              "${createdAt.day.toString().padLeft(2, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.year}";
              formattedTime =
              "${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}";
            }

            return {
              'date': formattedDate,
              'time': formattedTime,
              'remarks': item['remarks'] ?? 'No description',
            };
          }).toList();
        } else {
          return [];
        }
      } else {
        throw Exception("Failed to load activity (${response.statusCode})");
      }
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchActivity(widget.ticketId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          );
        }

        final activityList = snapshot.data ?? [];

        if (activityList.isEmpty) {
          return  Center(
            child: Text(
              "No activity found",
              style: GoogleFonts.poppins(color: Colors.black54),
            ),
          );
        }

        // Using StatefulBuilder avoids rebuilding entire screen on tap
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: StatefulBuilder(
                builder: (context, setInnerState) {
                  return Column(
                    children: [
                       Text(
                        "Ticket Activity Timeline",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff332757),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(),
                      Expanded(
                        child: Stepper(
                          type: StepperType.vertical,
                          physics: const BouncingScrollPhysics(),
                          currentStep: _currentStep,
                          onStepTapped: (index) {
                            //  Lightweight setState inside inner builder
                            setInnerState(() {
                              _currentStep = index;
                            });
                          },
                          controlsBuilder: (context, details) => const SizedBox(),
                          steps: activityList.asMap().entries.map((entry) {
                            final index = entry.key;
                            final activity = entry.value;

                            return Step(
                              title: Text(
                                "${activity['date']} - ${activity['time']}",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              content: Text(
                                activity['remarks'],
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                              isActive: _currentStep >= index,
                              state: _currentStep > index
                                  ? StepState.complete
                                  : StepState.indexed,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
