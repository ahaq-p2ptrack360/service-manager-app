import 'package:anwar/company_profile.dart';
import 'package:anwar/profile.dart';
import 'package:anwar/widget/notifications_popup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:anwar/constant.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anwar/chats.dart';

import 'notification_service.dart';
import 'notifications_screen.dart';
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<Ticket> tickets = [];
  List<Ticket> filteredTickets = [];
  bool isLoading = true;
  String errorMessage = '';
  List<NotificationModel> notificationsList = [];
  int unreadNotificationCount = 0;
  List<int> previousNotificationIds = [];
  bool _isFirstNotificationFetch = true;

  // Filter state variables
  String _selectedPriority = 'All Priorities';
  String _selectedImpact = 'All Impacts';
  String _selectedAgent = 'All Agents';
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _startResolvedDate;
  DateTime? _endResolvedDate;
  bool _areFiltersApplied = false;



  // Temporary filter state for bottom sheet
  String _tempSelectedPriority = 'All Priorities';
  String _tempSelectedImpact = 'All Impacts';
  String _tempSelectedAgent = 'All Agents';
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;
  DateTime? _tempStartResolvedDate;
  DateTime? _tempEndResolvedDate;

  // Filter options
  List<String> _priorityOptions = ['All Priorities'];
  List<String> _impactOptions = ['All Impacts'];
  List<String> _agentOptions = ['All Agents'];

  // Existing variables
  bool isFabExpanded = false;
  String currentSort = 'Newest First';
  String currentFilter = 'All'; // 'All', 'Assigned to Me', 'Created by Me'
  String username = "";

  // Graph and card selection filters
  int? selectedMonth;
  String? selectedStatus;
  String? selectedImpact;
  String? selectedType;
  String? selectedCard;

  @override
  void initState() {
    super.initState();
    loadUserData();
    fetchTickets();
    fetchNotifications();
    _startNotificationPolling();
  }
// Add periodic notification refresh (optional)
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
    });
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




  Future<void> fetchTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var company_id = prefs.getString("company");
      var api;
      if(company_id == "0")
      {
        api = "http://3.137.76.254/Service-Manager-main-Work/public/api/tickets";
      }
      else
      {
        var user_id = prefs.getString("id");
        api = "http://3.137.76.254/Service-Manager-main-Work/public/api/dashboard/get_all_tickets/$user_id";
      }
      final response = await http.get(
        Uri.parse(api),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          tickets = data.map((item) => Ticket.fromJson(item)).toList();
          filteredTickets = tickets; // Initially show all tickets
          isLoading = false;

          // Initialize filter options from tickets data
          _initializeFilterOptions();
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load tickets: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  void _initializeFilterOptions() {
    final priorities = <String>{};
    final impacts = <String>{};
    final agents = <String>{};

    for (final ticket in tickets) {
      priorities.add(ticket.priorityTitle);
      impacts.add(ticket.impactTitle);
      agents.add(ticket.reportedByName);
    }

    setState(() {
      _priorityOptions = ['All Priorities', ...priorities.toList()];
      _impactOptions = ['All Impacts', ...impacts.toList()];
      _agentOptions = ['All Agents', ...agents.toList()];
    });
  }

  void _applyAllFilters() {
    List<Ticket> result = tickets;

    // Apply priority filter
    if (_selectedPriority != 'All Priorities') {
      result = result.where((ticket) => ticket.priorityTitle == _selectedPriority).toList();
    }

    // Apply impact filter
    if (_selectedImpact != 'All Impacts') {
      result = result.where((ticket) => ticket.impactTitle == _selectedImpact).toList();
    }

    // Apply agent filter
    if (_selectedAgent != 'All Agents') {
      result = result.where((ticket) => ticket.reportedByName == _selectedAgent).toList();
    }

    // Apply creation date range filter
    if (_startDate != null && _endDate != null) {
      result = result.where((ticket) {
        try {
          final createdAt = DateTime.parse(ticket.createdAt);
          return createdAt.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
              createdAt.isBefore(_endDate!.add(const Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Apply resolved date range filter
    if (_startResolvedDate != null && _endResolvedDate != null &&
        _anyTicketHasCompletedDate()) {
      result = result.where((ticket) {
        try {
          if (ticket.completedDate.isEmpty) return false;
          final resolvedDate = DateTime.parse(ticket.completedDate);
          return resolvedDate.isAfter(_startResolvedDate!.subtract(const Duration(days: 1))) &&
              resolvedDate.isBefore(_endResolvedDate!.add(const Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Apply existing filters (All, Assigned to Me, Created by Me)
    switch (currentFilter) {
      case 'Assigned to Me':
        result = result.where((ticket) =>
        ticket.statusTitle.toLowerCase() != 'closed' &&
            ticket.priorityTitle.toLowerCase() == 'high').toList();
        break;
      case 'Created by Me':
        result = result.where((ticket) =>
        ticket.reportedByName.toLowerCase().contains('current user') ||
            ticket.companyName.toLowerCase().contains('my company')).toList();
        break;
      case 'All':
      default:
      // No additional filtering needed
        break;
    }

    setState(() {
      filteredTickets = result;
      _areFiltersApplied = _selectedPriority != 'All Priorities' ||
          _selectedImpact != 'All Impacts' ||
          _selectedAgent != 'All Agents' ||
          _startDate != null ||
          _endDate != null ||
          _startResolvedDate != null ||
          _endResolvedDate != null;
      _applySorting(currentSort);
    });
  }

  bool _anyTicketHasCompletedDate() {
    for (final ticket in tickets) {
      if (ticket.completedDate.isNotEmpty && ticket.completedDate != 'Unknown') {
        return true;
      }
    }
    return false;
  }

  void _applyFilter(String filter) {
    setState(() {
      currentFilter = filter;
      // Reset card selection when applying other filters
      selectedCard = null;
    });
    _applyAllFilters();
  }

  void _applySorting(String sortOption) {
    setState(() {
      currentSort = sortOption;
      switch (sortOption) {
        case 'Newest First':
          filteredTickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case 'Oldest First':
          filteredTickets.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case 'Priority (High to Low)':
          filteredTickets.sort((a, b) {
            final priorityOrder = {'high': 3, 'medium': 2, 'low': 1};
            final aPriority = priorityOrder[a.priorityTitle.toLowerCase()] ?? 0;
            final bPriority = priorityOrder[b.priorityTitle.toLowerCase()] ?? 0;
            return bPriority.compareTo(aPriority);
          });
          break;
        case 'Priority (Low to High)':
          filteredTickets.sort((a, b) {
            final priorityOrder = {'high': 3, 'medium': 2, 'low': 1};
            final aPriority = priorityOrder[a.priorityTitle.toLowerCase()] ?? 0;
            final bPriority = priorityOrder[b.priorityTitle.toLowerCase()] ?? 0;
            return aPriority.compareTo(bPriority);
          });
          break;
      }
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedPriority = 'All Priorities';
      _selectedImpact = 'All Impacts';
      _selectedAgent = 'All Agents';
      _startDate = null;
      _endDate = null;
      _startResolvedDate = null;
      _endResolvedDate = null;
      _areFiltersApplied = false;
      selectedCard = null;
      selectedMonth = null;
      selectedStatus = null;
      selectedImpact = null;
      selectedType = null;
      filteredTickets = tickets;
    });
  }

  void _showAdvancedFilterBottomSheet() {
    // Set temporary values to current values
    setState(() {
      _tempSelectedPriority = _selectedPriority;
      _tempSelectedImpact = _selectedImpact;
      _tempSelectedAgent = _selectedAgent;
      _tempStartDate = _startDate;
      _tempEndDate = _endDate;
      _tempStartResolvedDate = _startResolvedDate;
      _tempEndResolvedDate = _endResolvedDate;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Advanced Filters',
                    style: GoogleFonts.poppins(

                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff332757),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Priority Filter
                  _buildFilterDropdown(
                    'Priority',
                    _tempSelectedPriority,
                    _priorityOptions,
                        (value) {
                      setState(() {
                        _tempSelectedPriority = value!;
                      });
                    },
                  ),

                  // Impact Filter
                  _buildFilterDropdown(
                    'Impact',
                    _tempSelectedImpact,
                    _impactOptions,
                        (value) {
                      setState(() {
                        _tempSelectedImpact = value!;
                      });
                    },
                  ),

                  // Agent Filter
                  _buildFilterDropdown(
                    'Agent',
                    _tempSelectedAgent,
                    _agentOptions,
                        (value) {
                      setState(() {
                        _tempSelectedAgent = value!;
                      });
                    },
                  ),

                  // Creation Date Range
                  _buildDateRangeFilter(
                    'Creation Date',
                    _tempStartDate,
                    _tempEndDate,
                        (start, end) {
                      setState(() {
                        _tempStartDate = start;
                        _tempEndDate = end;
                      });
                    },
                  ),

                  // Resolved Date Range (only if tickets have completed date)
                  if (tickets.isNotEmpty && _anyTicketHasCompletedDate())
                    _buildDateRangeFilter(
                      'Completed Date',
                      _tempStartResolvedDate,
                      _tempEndResolvedDate,
                          (start, end) {
                        setState(() {
                          _tempStartResolvedDate = start;
                          _tempEndResolvedDate = end;
                        });
                      },
                    ),

                  const SizedBox(height: 8),

                  // Action Buttons
                  Row(
                    children: [

                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Apply filters
                            Navigator.pop(context);
                            setState(() {
                              _selectedPriority = _tempSelectedPriority;
                              _selectedImpact = _tempSelectedImpact;
                              _selectedAgent = _tempSelectedAgent;
                              _startDate = _tempStartDate;
                              _endDate = _tempEndDate;
                              _startResolvedDate = _tempStartResolvedDate;
                              _endResolvedDate = _tempEndResolvedDate;
                            });
                            _applyAllFilters();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff332757),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child:  Text('Apply Filters', style: GoogleFonts.poppins(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterDropdown(
      String label,
      String value,
      List<String> options,
      ValueChanged<String?> onChanged,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:  GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                items: options.map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeFilter(
      String label,
      DateTime? startDate,
      DateTime? endDate,
      Function(DateTime?, DateTime?) onDateSelected,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:  GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (selectedDate != null) {
                      onDateSelected(selectedDate, endDate);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      startDate != null
                          ? '${startDate.day}/${startDate.month}/${startDate.year}'
                          : 'Start Date',
                      style: GoogleFonts.poppins(
                        color: startDate != null ? Colors.black87 : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('to', style: GoogleFonts.poppins(color: Colors.grey)),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: endDate ?? DateTime.now(),
                      firstDate: startDate ?? DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (selectedDate != null) {
                      onDateSelected(startDate, selectedDate);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      endDate != null
                          ? '${endDate.day}/${endDate.month}/${endDate.year}'
                          : 'End Date',
                      style: GoogleFonts.poppins(
                        color: endDate != null ? Colors.black87 : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Filter Tickets',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff332757),
                  ),
                ),
                const SizedBox(height: 16),
                _buildFilterOption('All', Icons.all_inclusive),
                _buildFilterOption('Assigned to Me', Icons.assignment_ind),
                _buildFilterOption('Created by Me', Icons.person_add),
                // const SizedBox(height: 8),

                // Advanced Filters Button
                // ListTile(
                //   leading: const Icon(Icons.filter_alt, color: Color(0xff332757)),
                //   title:  Text('Advanced Filters'),
                //   trailing: _areFiltersApplied
                //       ? Container(
                //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                //     decoration: BoxDecoration(
                //       color: const Color(0xff332757),
                //       borderRadius: BorderRadius.circular(12),
                //     ),
                //     child:  Text(
                //       'Active',
                //       style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                //     ),
                //   )
                //       : null,
                //   onTap: () {
                //     Navigator.pop(context);
                //     _showAdvancedFilterBottomSheet();
                //   },
                // ),
                _buildFilterDropdown(
                  'Priority',
                  _tempSelectedPriority,
                  _priorityOptions,
                      (value) {
                    setState(() {
                      _tempSelectedPriority = value!;
                    });
                  },
                ),

                // Impact Filter
                _buildFilterDropdown(
                  'Impact',
                  _tempSelectedImpact,
                  _impactOptions,
                      (value) {
                    setState(() {
                      _tempSelectedImpact = value!;
                    });
                  },
                ),

                // Agent Filter
                _buildFilterDropdown(
                  'Agent',
                  _tempSelectedAgent,
                  _agentOptions,
                      (value) {
                    setState(() {
                      _tempSelectedAgent = value!;
                    });
                  },
                ),

                // Creation Date Range
                _buildDateRangeFilter(
                  'Creation Date',
                  _tempStartDate,
                  _tempEndDate,
                      (start, end) {
                    setState(() {
                      _tempStartDate = start;
                      _tempEndDate = end;
                    });
                  },
                ),

                // Resolved Date Range (only if tickets have completed date)
                if (tickets.isNotEmpty && _anyTicketHasCompletedDate())
                  _buildDateRangeFilter(
                    'Completed Date',
                    _tempStartResolvedDate,
                    _tempEndResolvedDate,
                        (start, end) {
                      setState(() {
                        _tempStartResolvedDate = start;
                        _tempEndResolvedDate = end;
                      });
                    },
                  ),

                const SizedBox(height: 8),

                // Action Buttons
                Row(
                  children: [

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Apply filters
                          Navigator.pop(context);
                          setState(() {
                            _selectedPriority = _tempSelectedPriority;
                            _selectedImpact = _tempSelectedImpact;
                            _selectedAgent = _tempSelectedAgent;
                            _startDate = _tempStartDate;
                            _endDate = _tempEndDate;
                            _startResolvedDate = _tempStartResolvedDate;
                            _endResolvedDate = _tempEndResolvedDate;
                          });
                          _applyAllFilters();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff332757),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child:  Text('Apply Filters', style: GoogleFonts.poppins(color: Colors.white)),
                      ),
                    ),
                  ],
                ),

                // const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sort Tickets',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff332757),
                ),
              ),
              const SizedBox(height: 16),
              _buildSortOption('Newest First', Icons.new_releases),
              _buildSortOption('Oldest First', Icons.history),
              _buildSortOption('Priority (High to Low)', Icons.arrow_upward),
              _buildSortOption('Priority (Low to High)', Icons.arrow_downward),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(String filter, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xff332757)),
      title: Text(
        filter,
        style: GoogleFonts.poppins(
          fontWeight: currentFilter == filter ? FontWeight.bold : FontWeight.normal,
          color: currentFilter == filter ? const Color(0xff332757) : Colors.black87,
        ),
      ),
      trailing: currentFilter == filter
          ? const Icon(Icons.check, color: Color(0xff332757))
          : null,
      onTap: () {
        Navigator.pop(context);
        _applyFilter(filter);
      },
    );
  }

  Widget _buildSortOption(String sortOption, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xff332757)),
      title: Text(
        sortOption,
        style: GoogleFonts.poppins(
          fontWeight: currentSort == sortOption ? FontWeight.bold : FontWeight.normal,
          color: currentSort == sortOption ? const Color(0xff332757) : Colors.black87,
        ),
      ),
      trailing: currentSort == sortOption
          ? const Icon(Icons.check, color: Color(0xff332757))
          : null,
      onTap: () {
        Navigator.pop(context);
        _applySorting(sortOption);
      },
    );
  }

  // NEW: Method to handle card clicks
  void _handleCardClick(String cardType) {
    setState(() {
      // If the same card is clicked again, clear the selection
      if (selectedCard == cardType) {
        selectedCard = null;
        filteredTickets = tickets;
      } else {
        // Set the selected card and filter tickets
        selectedCard = cardType;

        switch (cardType) {
          case 'total':
          // Show all tickets (no filtering needed)
            filteredTickets = tickets;
            break;
          case 'pending':
          // Show pending tickets
            filteredTickets = tickets.where((ticket) =>
            ticket.statusTitle.toLowerCase().contains('pending') ||
                ticket.statusTitle.toLowerCase().contains('open')).toList();
            break;
          case 'completed':
          // Show completed/closed tickets
            filteredTickets = tickets.where((ticket) =>
            ticket.statusTitle.toLowerCase().contains('closed') ||
                ticket.statusTitle.toLowerCase().contains('completed')).toList();
            break;
          case 'inProgress':
          // Show in-progress tickets
            filteredTickets = tickets.where((ticket) =>
            ticket.statusTitle.toLowerCase().contains('in progress') ||
                ticket.statusTitle.toLowerCase().contains('processing')).toList();
            break;
        }
      }

      // Clear other graph filters when selecting a card
      selectedMonth = null;
      selectedStatus = null;
      selectedImpact = null;
      selectedType = null;
    });
  }

  // UPDATED: Modified to reset card selection when handling graph clicks
  void _handleGraphClick({
    int? month,
    String? status,
    String? impact,
    String? type,
  }) {
    setState(() {
      // Reset card selection when clicking on graphs
      selectedCard = null;

      // Reset all filters first
      selectedMonth = month;
      selectedStatus = status;
      selectedImpact = impact;
      selectedType = type;

      // Apply filtering based on what was clicked
      if (month != null) {
        filteredTickets = tickets.where((ticket) {
          try {
            final date = DateTime.parse(ticket.createdAt);
            return date.month == month + 1; // month is 0-based in charts
          } catch (e) {
            return false;
          }
        }).toList();
      } else if (status != null) {
        filteredTickets = tickets.where((ticket) =>
        ticket.statusTitle == status).toList();
      } else if (impact != null) {
        filteredTickets = tickets.where((ticket) =>
        ticket.impactTitle == impact).toList();
      } else if (type != null) {
        filteredTickets = tickets.where((ticket) =>
        ticket.typeTitle == type).toList();
      } else {
        // Reset to all tickets if nothing is selected
        filteredTickets = tickets;
      }
    });
  }

  // UPDATED: Modified to reset card selection when clearing filters
  void _clearGraphFilters() {
    setState(() {
      selectedMonth = null;
      selectedStatus = null;
      selectedImpact = null;
      selectedType = null;
      selectedCard = null;
      filteredTickets = tickets;
    });
  }

  // Rest of your existing methods (getTotalTickets, getClosedTickets, etc.)
  int getTotalTickets() => filteredTickets.length;

  int getClosedTickets() =>
      filteredTickets
          .where((ticket) =>
          ticket.statusTitle.toLowerCase().contains('closed'))
          .length;

  int getHighPriorityTickets() =>
      filteredTickets
          .where((ticket) => ticket.priorityTitle.toLowerCase() == 'high')
          .length;

  int getMediumPriorityTickets() =>
      filteredTickets
          .where((ticket) => ticket.priorityTitle.toLowerCase() == 'medium')
          .length;

  int getLowPriorityTickets() =>
      filteredTickets
          .where((ticket) => ticket.priorityTitle.toLowerCase() == 'low')
          .length;

  Map<String, int> getTicketsByImpact() {
    final Map<String, int> impactCount = {};
    for (final ticket in filteredTickets) {
      impactCount.update(
          ticket.impactTitle,
              (value) => value + 1,
          ifAbsent: () => 1
      );
    }
    return impactCount;
  }

  Map<String, int> getTicketsByType() {
    final Map<String, int> typeCount = {};
    for (final ticket in filteredTickets) {
      typeCount.update(
          ticket.typeTitle,
              (value) => value + 1,
          ifAbsent: () => 1
      );
    }
    return typeCount;
  }

  Map<String, int> getTicketsByMonth() {
    final Map<String, int> monthlyCount = {};
    for (final ticket in filteredTickets) {
      final date = DateTime.parse(ticket.createdAt);
      final month = '${date.month}';
      monthlyCount.update(
          month,
              (value) => value + 1,
          ifAbsent: () => 1
      );
    }
    return monthlyCount;
  }

  Map<String, int> getTicketsByStatus() {
    final Map<String, int> statusCount = {};
    for (final ticket in filteredTickets) {
      statusCount.update(
          ticket.statusTitle,
              (value) => value + 1,
          ifAbsent: () => 1
      );
    }
    return statusCount;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Text(errorMessage),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final width = size.width;

    // Scale sizes proportionally
    final horizontalPadding = width * 0.02;
    final verticalPadding = width * 0.025;
    final containerRadius = width * 0.025;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xff332757),
        iconTheme: const IconThemeData(color: Colors.white),
        title:  Text(
          'Dashboard',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          // UPDATED: Show clear filter button when any filter is active
          if (_areFiltersApplied || selectedMonth != null || selectedStatus != null ||
              selectedImpact != null || selectedType != null || selectedCard != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off, color: Colors.white),
              onPressed: _clearAllFilters,
            ),
          // Update the notification icon in the AppBar
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
                onTap: (){
                  Navigator.push(context, MaterialPageRoute(builder: (context)=>ProfileViewScreen(userData: {},)));
                }),
          ),
        ],
      ),

      drawer: MyDrawer(),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: width * 0.02),

              // UPDATED: Pass the onCardClick callback
              _buildWelcomeSection(context, width, containerRadius),
              SizedBox(height: width * 0.02),

              Container(
                padding: EdgeInsets.all(width * 0.03),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(containerRadius),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ChartHeader(),
                    SizedBox(height: width * 0.04),

                    // Show active filter indicators
                    if (_areFiltersApplied)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xff332757),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child:  Text(
                                'Filters Active',
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getActiveFilterDescription(),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xff332757),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // UPDATED: Show active filter indicator for card selection too
                    if (selectedCard != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Showing ${_getCardFilterDescription(selectedCard!)}',
                          style: GoogleFonts.poppins(
                            color: const Color(0xff332757),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (selectedMonth != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Showing tickets for month: ${_getMonthName(selectedMonth!)}',
                          style: GoogleFonts.poppins(
                            color: const Color(0xff332757),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (selectedStatus != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Showing tickets with status: $selectedStatus',
                          style: GoogleFonts.poppins(
                            color: const Color(0xff332757),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (selectedImpact != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Showing tickets with impact: $selectedImpact',
                          style: GoogleFonts.poppins(
                            color: const Color(0xff332757),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (selectedType != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Showing tickets with type: $selectedType',
                          style: GoogleFonts.poppins(
                            color: const Color(0xff332757),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    SizedBox(
                      height: width < 700 ? 520 : width < 800 ? 280 : 340,
                      child: Column(
                        children: [
                          Expanded(
                            child: Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    Text('Tickets Completed (Trend)',
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _LegendItem(
                                            color: Colors.deepPurple.shade900,
                                            label: 'Ticket Created'),
                                        SizedBox(width: 12),
                                        _LegendItem(color: Colors.amber,
                                            label: 'Ticket Completed'),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(child: _LineChartWithBars(
                                        tickets: filteredTickets,
                                        onMonthSelected: (month) {
                                          _handleGraphClick(month: month);
                                        },
                                        selectedMonth: selectedMonth)),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),
                          Expanded(
                            child: Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    Text('Tickets Created (Monthly)',
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Expanded(child: _BarChartSample(
                                        tickets: filteredTickets,
                                        onStatusSelected: (status) {
                                          _handleGraphClick(status: status);
                                        },
                                        selectedStatus: selectedStatus)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _LeftContent(tickets: filteredTickets),

              _ImpactPieChartCard(
                tickets: filteredTickets,
                onImpactSelected: (impact) {
                  _handleGraphClick(impact: impact);
                },
                selectedImpact: selectedImpact,
              ),
              SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: UpcomingTicketCard(tickets: filteredTickets)),
                  SizedBox(width: 8),
                  Expanded(child: TopCreatorsCard(tickets: filteredTickets)),
                ],
              ),

              SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;

                  return Flex(
                    direction: isWide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: isWide ? 1 : 0,
                        child: _ChartCard(
                          title: 'Issue Type',
                          subtitle: 'This Month',
                          child: _IssueTypeChart(
                            tickets: filteredTickets,
                            onTypeSelected: (type) {
                              _handleGraphClick(type: type);
                            },
                            selectedType: selectedType,
                          ),
                        ),
                      ),
                      SizedBox(width: isWide ? 3 : 0, height: isWide ? 0 : 3),
                      Expanded(
                        flex: isWide ? 1 : 0,
                        child: _ChartCard(
                          title: 'Resolved Ratio',
                          subtitle: '',
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              _ResolvedGauge(tickets: filteredTickets),
                              SizedBox(height: 15),
                              _DynamicPriorityBar(tickets: filteredTickets),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: isWide ? 3 : 0, height: isWide ? 0 : 3),
                      Expanded(
                        flex: isWide ? 1 : 0,
                        child: _ChartCard(
                          title: 'Trend By Types',
                          subtitle: 'This Month',
                          child: _TrendByTypesChart(tickets: filteredTickets),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isFabExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: FloatingActionButton(
                heroTag: "filter_fab",
                onPressed: () {
                  setState(() {
                    isFabExpanded = false;
                  });
                  _showFilterBottomSheet();
                },
                backgroundColor: const Color(0xff332757),
                mini: true,
                child: const Icon(Icons.filter_alt_sharp, color: Colors.white),
              ),
            ),

          if (isFabExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: FloatingActionButton(
                heroTag: "sort_fab",
                onPressed: () {
                  setState(() {
                    isFabExpanded = false;
                  });
                  _showSortBottomSheet();
                },
                backgroundColor: const Color(0xff332757),
                mini: true,
                child: const Icon(Icons.sort, color: Colors.white),
              ),
            ),

          // NEW: Chat FAB - opens the existing Chats screen (same as MyDrawer's Chats menu item)
          if (isFabExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: FloatingActionButton(
                heroTag: "chat_fab",
                onPressed: () {
                  setState(() {
                    isFabExpanded = false;
                  });
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Chats()),
                  );
                },
                backgroundColor: const Color(0xff332757),
                mini: true,
                child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              ),
            ),

          // Main FAB
          FloatingActionButton(
            heroTag: "main_fab",
            onPressed: () {
              setState(() {
                isFabExpanded = !isFabExpanded;
              });
            },
            backgroundColor: const Color(0xff332757),
            child: Icon(
              isFabExpanded ? Icons.close : Icons.add,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _getActiveFilterDescription() {
    final filters = <String>[];

    if (_selectedPriority != 'All Priorities') {
      filters.add('Priority: $_selectedPriority');
    }

    if (_selectedImpact != 'All Impacts') {
      filters.add('Impact: $_selectedImpact');
    }

    if (_selectedAgent != 'All Agents') {
      filters.add('Agent: $_selectedAgent');
    }

    if (_startDate != null && _endDate != null) {
      filters.add('Date Range: ${_formatDate(_startDate!)} to ${_formatDate(_endDate!)}');
    }

    if (_startResolvedDate != null && _endResolvedDate != null) {
      filters.add('Resolved: ${_formatDate(_startResolvedDate!)} to ${_formatDate(_endResolvedDate!)}');
    }

    return filters.join(', ');
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getMonthName(int monthIndex) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return months[monthIndex];
  }

  // NEW: Helper method to get card filter description
  String _getCardFilterDescription(String cardType) {
    switch (cardType) {
      case 'total':
        return 'All Tickets';
      case 'pending':
        return 'Pending Tickets only';
      case 'completed':
        return 'Completed Tickets only';
      case 'inProgress':
        return 'In Progress Tickets only';
      default:
        return 'Tickets';
    }
  }

  // Update the _buildWelcomeSection method to use filteredTickets instead of tickets
  Widget _buildWelcomeSection(BuildContext context, double width, double radius) {
    // Use filteredTickets instead of tickets for counts
    final totalTickets = filteredTickets.length;
    final pendingTickets = filteredTickets
        .where((ticket) =>
    ticket.statusTitle.toLowerCase().contains('pending') ||
        ticket.statusTitle.toLowerCase().contains('open'))
        .length;
    final completedTickets = filteredTickets
        .where((ticket) =>
    ticket.statusTitle.toLowerCase().contains('closed') ||
        ticket.statusTitle.toLowerCase().contains('completed'))
        .length;
    final inProgressTickets = filteredTickets
        .where((ticket) =>
    ticket.statusTitle.toLowerCase().contains('in progress') ||
        ticket.statusTitle.toLowerCase().contains('processing'))
        .length;

    return Container(
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Welcome $username,',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: width < 400 ? 18 : width < 800 ? 22 : 26,
                ),
              ),
              // Add a filter indicator when filters are applied
              if (_areFiltersApplied || selectedCard != null ||
                  selectedMonth != null || selectedStatus != null ||
                  selectedImpact != null || selectedType != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xff332757),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Filtered',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: width * 0.025,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            "Here's an overview of your tickets",
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: width < 400 ? 12 : width < 800 ? 14 : 16,
            ),
          ),

          // Show filter summary when filters are applied
          if (_areFiltersApplied)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _getFilterSummary(),
                style: GoogleFonts.poppins(
                  color: const Color(0xff332757),
                  fontSize: width * 0.03,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          SizedBox(height: width * 0.05),
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: width > 1000
                ? 4
                : width > 700
                ? 3
                : 2,
            crossAxisSpacing: width * 0.03,
            mainAxisSpacing: width * 0.03,
            childAspectRatio: width > 900
                ? 3.6
                : width > 600
                ? 3.0
                : 2.2,
            children: [
              _StatCard(
                title: 'Total Tickets',
                value: totalTickets.toString(),
                color: selectedCard == 'total' ?
                const Color(0xff332757).withOpacity(0.2) :
                const Color(0xFFD1FAE5),
                icon: Icons.assignment,
                isSelected: selectedCard == 'total',
                onTap: () => _handleCardClick('total'),
              ),
              _StatCard(
                title: 'Pending Tickets',
                value: pendingTickets.toString(),
                color: selectedCard == 'pending' ?
                Colors.orange.withOpacity(0.2) :
                const Color(0xFFDBEAFE),
                icon: Icons.access_time,
                isSelected: selectedCard == 'pending',
                onTap: () => _handleCardClick('pending'),
              ),
              _StatCard(
                title: 'Completed Tickets',
                value: completedTickets.toString(),
                color: selectedCard == 'completed' ?
                Colors.green.withOpacity(0.2) :
                const Color(0xFFFFEDD5),
                icon: Icons.check_circle_outline,
                isSelected: selectedCard == 'completed',
                onTap: () => _handleCardClick('completed'),
              ),
              _StatCard(
                title: 'In Progress Tickets',
                value: inProgressTickets.toString(),
                color: selectedCard == 'inProgress' ?
                Colors.blue.withOpacity(0.2) :
                const Color(0xFFFCE7F3),
                icon: Icons.sync,
                isSelected: selectedCard == 'inProgress',
                onTap: () => _handleCardClick('inProgress'),
              ),
            ],
          ),
        ],
      ),
    );
  }

// Add this helper method to get filter summary
  String _getFilterSummary() {
    final filters = <String>[];
    final totalFiltered = filteredTickets.length;
    final totalAll = tickets.length;

    if (_selectedPriority != 'All Priorities') {
      filters.add('Priority: $_selectedPriority');
    }

    if (_selectedImpact != 'All Impacts') {
      filters.add('Impact: $_selectedImpact');
    }

    if (_selectedAgent != 'All Agents') {
      filters.add('Agent: $_selectedAgent');
    }

    if (_startDate != null && _endDate != null) {
      filters.add('Date Range');
    }

    if (_startResolvedDate != null && _endResolvedDate != null) {
      filters.add('Resolved Date Range');
    }

    if (selectedMonth != null) {
      filters.add('Month: ${_getMonthName(selectedMonth!)}');
    }

    if (selectedStatus != null) {
      filters.add('Status: $selectedStatus');
    }

    if (selectedImpact != null) {
      filters.add('Impact: $selectedImpact');
    }

    if (selectedType != null) {
      filters.add('Type: $selectedType');
    }

    if (selectedCard != null) {
      filters.add(_getCardFilterDescription(selectedCard!));
    }

    if (filters.isEmpty) {
      return 'Showing all $totalAll tickets';
    }

    final summary = 'Showing $totalFiltered of $totalAll tickets';
    if (filters.length <= 2) {
      return '$summary (${filters.join(', ')})';
    } else {
      return '$summary (${filters.length} filters applied)';
    }
  }

// Also update the _applyAllFilters method to ensure welcome section updates
//   void _applyAllFilters() {
//     List<Ticket> result = tickets;
//
//     // Apply priority filter
//     if (_selectedPriority != 'All Priorities') {
//       result = result.where((ticket) => ticket.priorityTitle == _selectedPriority).toList();
//     }
//
//     // Apply impact filter
//     if (_selectedImpact != 'All Impacts') {
//       result = result.where((ticket) => ticket.impactTitle == _selectedImpact).toList();
//     }
//
//     // Apply agent filter
//     if (_selectedAgent != 'All Agents') {
//       result = result.where((ticket) => ticket.reportedByName == _selectedAgent).toList();
//     }
//
//     // Apply creation date range filter
//     if (_startDate != null && _endDate != null) {
//       result = result.where((ticket) {
//         try {
//           final createdAt = DateTime.parse(ticket.createdAt);
//           return createdAt.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
//               createdAt.isBefore(_endDate!.add(const Duration(days: 1)));
//         } catch (e) {
//           return false;
//         }
//       }).toList();
//     }
//
//     // Apply resolved date range filter
//     if (_startResolvedDate != null && _endResolvedDate != null &&
//         tickets.isNotEmpty && ticketHasCompletedDate(tickets.first)) {
//       result = result.where((ticket) {
//         try {
//           if (ticket.completedDate.isEmpty) return false;
//           final resolvedDate = DateTime.parse(ticket.completedDate);
//           return resolvedDate.isAfter(_startResolvedDate!.subtract(const Duration(days: 1))) &&
//               resolvedDate.isBefore(_endResolvedDate!.add(const Duration(days: 1)));
//         } catch (e) {
//           return false;
//         }
//       }).toList();
//     }
//
//     // Apply existing filters (All, Assigned to Me, Created by Me)
//     switch (currentFilter) {
//       case 'Assigned to Me':
//         result = result.where((ticket) =>
//         ticket.statusTitle.toLowerCase() != 'closed' &&
//             ticket.priorityTitle.toLowerCase() == 'high').toList();
//         break;
//       case 'Created by Me':
//         result = result.where((ticket) =>
//         ticket.reportedByName.toLowerCase().contains('current user') ||
//             ticket.companyName.toLowerCase().contains('my company')).toList();
//         break;
//       case 'All':
//       default:
//       // No additional filtering needed
//         break;
//     }
//
//     setState(() {
//       filteredTickets = result;
//       _areFiltersApplied = _selectedPriority != 'All Priorities' ||
//           _selectedImpact != 'All Impacts' ||
//           _selectedAgent != 'All Agents' ||
//           _startDate != null ||
//           _endDate != null ||
//           _startResolvedDate != null ||
//           _endResolvedDate != null;
//       _applySorting(currentSort);
//     });
//   }

// Update the _clearAllFilters method to reset everything properly
//   void _clearAllFilters() {
//     setState(() {
//       _selectedPriority = 'All Priorities';
//       _selectedImpact = 'All Impacts';
//       _selectedAgent = 'All Agents';
//       _startDate = null;
//       _endDate = null;
//       _startResolvedDate = null;
//       _endResolvedDate = null;
//       _areFiltersApplied = false;
//       selectedCard = null;
//       selectedMonth = null;
//       selectedStatus = null;
//       selectedImpact = null;
//       selectedType = null;
//       filteredTickets = tickets;
//       currentFilter = 'All'; // Reset main filter too
//     });
//   }
}

class Ticket {
  final int id;
  final String companyName;
  final String title;
  final String description;
  final String statusTitle;
  final String priorityTitle;
  final String impactTitle;
  final String typeTitle;
  final String createdAt;
  final String reportedByName;
  final String completedDate;

  Ticket({
    required this.id,
    required this.companyName,
    required this.title,
    required this.description,
    required this.statusTitle,
    required this.priorityTitle,
    required this.impactTitle,
    required this.typeTitle,
    required this.createdAt,
    required this.reportedByName,
    required this.completedDate,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] ?? 0,
      companyName: json['company_name'] ?? 'Unknown',
      title: json['title'] ?? 'No Title',
      description: json['description'] ?? 'No Description',
      statusTitle: json['status_title'] ?? 'Unknown',
      priorityTitle: json['priority_title'] ?? 'Unknown',
      impactTitle: json['impact_title'] ?? 'Unknown',
      typeTitle: json['type_title'] ?? 'Unknown',
      createdAt: json['created_at'] ?? 'Unknown',
      reportedByName: json['reported_by_name'] ?? 'Unknown',
      completedDate: json['completed_date'] ?? '',
    );
  }
}

class _LineChartWithBars extends StatelessWidget {
  final List<Ticket> tickets;
  final Function(int)? onMonthSelected;
  final int? selectedMonth;

  const _LineChartWithBars({
    super.key,
    required this.tickets,
    this.onMonthSelected,
    this.selectedMonth,
  });

  List<FlSpot> _getMonthlySpots() {
    final monthlyData = <int, int>{};

    // Initialize all months with 0
    for (int i = 0; i < 12; i++) {
      monthlyData[i] = 0;
    }

    // Count tickets per month
    for (final ticket in tickets) {
      try {
        final date = DateTime.parse(ticket.createdAt);
        final month = date.month - 1; // Convert to 0-based index
        monthlyData[month] = monthlyData[month]! + 1;
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing date: ${ticket.createdAt}');
        }
      }
    }

    // Convert to FlSpot format using actual counts
    return monthlyData.entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.toDouble()))
        .toList();
  }

  List<double> _getMonthlyCounts() {
    final monthlyData = <int, int>{};

    // Initialize all months with 0
    for (int i = 0; i < 12; i++) {
      monthlyData[i] = 0;
    }

    // Count tickets per month
    for (final ticket in tickets) {
      try {
        final date = DateTime.parse(ticket.createdAt);
        final month = date.month - 1;
        monthlyData[month] = monthlyData[month]! + 1;
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing date: ${ticket.createdAt}');
        }
      }
    }

    return monthlyData.values.map((count) => count.toDouble()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final spots = _getMonthlySpots();
    final monthlyCounts = _getMonthlyCounts();
    final maxCount = monthlyCounts.reduce(math.max).toDouble();
    final dynamicMaxY = maxCount > 0 ? maxCount * 1.1 : 2;

    return SizedBox(
      height: 350,
      child: LineChart(
        LineChartData(
          minY: 0,
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value % 1 == 0 && value >= 0) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Text(
                        value.toInt().toString(),
                        style: GoogleFonts.poppins(fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  const months = [
                    'Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'
                  ];
                  if (value < 0 || value >= months.length) return const SizedBox.shrink();
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      months[value.toInt()],
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: selectedMonth == value.toInt() ?
                        Colors.deepPurple.shade900 : Colors.black,
                        fontWeight: selectedMonth == value.toInt() ?
                        FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            // NEW: Add touch interaction
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.white,
            ),
            handleBuiltInTouches: true,
            touchCallback: (event, touchResponse) {
              if (event is FlTapUpEvent && touchResponse != null) {
                final spot = touchResponse.lineBarSpots?.firstOrNull;
                if (spot != null && onMonthSelected != null) {
                  final monthIndex = spot.x.toInt();
                  onMonthSelected!(monthIndex);
                }
              }
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.amber,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [Colors.amber.withOpacity(0.3), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          extraLinesData: ExtraLinesData(
            verticalLines: List.generate(12, (index) {
              final count = monthlyCounts[index];
              if (count > 0) {
                final isSelected = selectedMonth == index;
                return VerticalLine(
                  x: index.toDouble(),
                  color: isSelected ?
                  Colors.deepPurple :
                  Colors.deepPurple.shade900.withOpacity(0.7),
                  strokeWidth: isSelected ? 12 : 8,
                  dashArray: null,
                );
              }
              return VerticalLine(
                x: index.toDouble(),
                color: Colors.transparent,
                strokeWidth: 0,
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const _StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final iconSize = width * 0.09;
    final fontSize = width * 0.05;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: width * 0.04,
          vertical: width * 0.035,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(width * 0.03),
          border: isSelected ? Border.all(
            color: _getIconColor(title),
            width: 2,
          ) : null,
          boxShadow: isSelected ? [
            BoxShadow(
              color: _getIconColor(title).withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            )
          ] : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Container(
                width: iconSize + 12,
                height: iconSize + 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(width * 0.02),
                  border: isSelected ? Border.all(
                    color: _getIconColor(title),
                    width: 2,
                  ) : null,
                ),
                child: Icon(icon, color: _getIconColor(title), size: iconSize),
              ),
              SizedBox(width: width * 0.03),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.black54,
                      fontSize: fontSize * 0.8,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  SizedBox(height: width * 0.01),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: fontSize * 1.2,
                      color: _getTextColor(title),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getIconColor(String title) {
    switch (title) {
      case 'Total Tickets':
        return const Color(0xff332757);
      case 'Pending Tickets':
        return Colors.orange;
      case 'Completed Tickets':
        return Colors.green;
      case 'In Progress Tickets':
        return Colors.blue;
      default:
        return const Color(0xff332757);
    }
  }

  Color _getTextColor(String title) {
    switch (title) {
      case 'Total Tickets':
        return const Color(0xff332757);
      case 'Pending Tickets':
        return Colors.orange.shade800;
      case 'Completed Tickets':
        return Colors.green.shade800;
      case 'In Progress Tickets':
        return Colors.blue.shade800;
      default:
        return Colors.black87;
    }
  }
}

class _DynamicPriorityBar extends StatelessWidget {
  final List<Ticket> tickets;

  const _DynamicPriorityBar({required this.tickets});

  Map<String, int> _getPriorityCounts() {
    final priorityCount = <String, int>{};
    for (final ticket in tickets) {
      priorityCount.update(
        ticket.priorityTitle,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return priorityCount;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final barHeight = width < 370 ? 12.0 : width < 400 ? 10.0 : 20.0;
    final fontSize = width < 400 ? 9.0 : width < 800 ? 11.0 : 13.0;

    final priorityCounts = _getPriorityCounts();
    final priorities = priorityCounts.keys.toList();
    final counts = priorityCounts.values.toList();

    final total = counts.isNotEmpty ? counts.reduce((a, b) => a + b) : 0;
    final percentages = counts.map((count) => total > 0 ? count / total : 0.0).toList();

    Color getPriorityColor(String priority) {
      switch (priority.toLowerCase()) {
        case 'high':
          return Colors.deepPurple.shade900;
        case 'medium':
          return Colors.deepPurple.shade700;
        case 'low':
          return Colors.deepPurple.shade300;
        default:
          return Colors.deepPurple;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('By Priority', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: fontSize + 1)),
        const SizedBox(height: 2),
        Container(
          height: barHeight,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: Colors.blue[50]),
          child: Row(
            children: List.generate(priorities.length, (index) {
              return Flexible(
                flex: (percentages[index] * 100).round(),
                child: Container(
                  decoration: BoxDecoration(
                    color: getPriorityColor(priorities[index]),
                    borderRadius: index == 0
                        ? const BorderRadius.horizontal(left: Radius.circular(6))
                        : index == priorities.length - 1
                        ? const BorderRadius.horizontal(right: Radius.circular(6))
                        : null,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(priorities.length, (index) {
            return Text('${priorities[index]} (${counts[index]})',
                style: GoogleFonts.poppins(fontSize: fontSize));
          }),
        ),
      ],
    );
  }
}

class _BarChartSample extends StatelessWidget {
  final List<Ticket> tickets;
  final Function(String)? onStatusSelected;
  final String? selectedStatus;

  const _BarChartSample({
    super.key,
    required this.tickets,
    this.onStatusSelected,
    this.selectedStatus,
  });

  List<int> _getStatusCounts() {
    final statusCount = <String, int>{};
    for (final ticket in tickets) {
      statusCount.update(
        ticket.statusTitle,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return statusCount.values.toList();
  }

  List<String> _getStatusLabels() {
    final statusCount = <String, int>{};
    for (final ticket in tickets) {
      statusCount.update(
        ticket.statusTitle,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return statusCount.keys.toList();
  }

  @override
  Widget build(BuildContext context) {
    final counts = _getStatusCounts();
    final labels = _getStatusLabels();

    if (counts.isEmpty || labels.isEmpty) {
      return SizedBox(
        height: 350,
        child: Center(
          child: Text(
            'No data available',
            style: GoogleFonts.poppins(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    final spots = List.generate(counts.length, (index) =>
        FlSpot(index.toDouble(), counts[index].toDouble())
    );

    final maxCount = counts.reduce(math.max).toDouble();
    final dynamicMaxY = maxCount > 0 ? maxCount * 1.1 : 2;

    return SizedBox(
      height: 350,
      child: LineChart(
        LineChartData(
          minY: 0,
          gridData: FlGridData(
            show: false,
            drawHorizontalLine: true,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value % 1 == 0 && value >= 0) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Text(
                        value.toInt().toString(),
                        style:  GoogleFonts.poppins(fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < labels.length) {
                    final isSelected = selectedStatus == labels[value.toInt()];
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Transform.rotate(
                        angle: -45 * 3.14159 / 180,
                        child: Text(
                          labels[value.toInt()],
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: isSelected ? Colors.deepPurple : Colors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.white,
            ),
            handleBuiltInTouches: true,
            touchCallback: (event, touchResponse) {
              if (event is FlTapUpEvent && touchResponse != null) {
                final spot = touchResponse.lineBarSpots?.firstOrNull;
                if (spot != null && onStatusSelected != null) {
                  final statusIndex = spot.x.toInt();
                  if (statusIndex >= 0 && statusIndex < labels.length) {
                    onStatusSelected!(labels[statusIndex]);
                  }
                }
              }
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.withOpacity(0.8),
                  Colors.deepPurple.withOpacity(0.3),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isSelected = selectedStatus == labels[index];
                  return FlDotCirclePainter(
                    radius: isSelected ? 6 : 4,
                    color: isSelected ? Colors.deepPurple : Colors.deepPurple,
                    strokeWidth: isSelected ? 3 : 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.withOpacity(0.5),
                    Colors.deepPurple.withOpacity(0.2),
                    Colors.deepPurple.withOpacity(0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartHeader extends StatelessWidget {
  const _ChartHeader();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Ticket Overview',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: width * 0.045),
        ),
        Text(
          'Monthly View',
          style: GoogleFonts.poppins(color: Colors.grey, fontSize: width * 0.03),
        ),
      ],
    );
  }
}

class _LeftContent extends StatelessWidget {
  final List<Ticket> tickets;

  const _LeftContent({required this.tickets});

  int _getHighPriorityCount() => tickets.where((ticket) => ticket.priorityTitle.toLowerCase() == 'high').length;
  int _getMediumPriorityCount() => tickets.where((ticket) => ticket.priorityTitle.toLowerCase() == 'medium').length;
  int _getLowPriorityCount() => tickets.where((ticket) => ticket.priorityTitle.toLowerCase() == 'low').length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'High',
                value: _getHighPriorityCount().toString(),
                color: const Color(0xFFD1FAE5),
                icon: Icons.rocket_launch,
                percent: '',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(
                label: 'Medium',
                value: _getMediumPriorityCount().toString(),
                percent: '',
                color: const Color(0xFFFEE2E2),
                icon: Icons.warning_amber_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(
                label: 'Low',
                value: _getLowPriorityCount().toString(),
                percent: '',
                color: const Color(0xFFE0F2FE),
                icon: Icons.arrow_downward_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String percent;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: color,
              child: Icon(icon, color: Colors.black54),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(label, style:  GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text(value, style:  GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Text(
                      percent,
                      style:  GoogleFonts.poppins(color: Colors.green, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactPieChartCard extends StatelessWidget {
  final List<Ticket> tickets;
  final Function(String)? onImpactSelected;
  final String? selectedImpact;

  const _ImpactPieChartCard({
    required this.tickets,
    this.onImpactSelected,
    this.selectedImpact,
  });

  List<PieChartSectionData> _getPieData() {
    final impactCount = <String, int>{};
    for (final ticket in tickets) {
      impactCount.update(
        ticket.impactTitle,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final colors = [
      Colors.deepPurple.shade900,
      Colors.deepPurple.shade700,
      Colors.deepPurple.shade400,
      Colors.deepPurple.shade300,
      Colors.deepPurple.shade200,
    ];

    final entries = impactCount.entries.toList();
    final total = tickets.length.toDouble();

    return List.generate(entries.length, (index) {
      final entry = entries[index];
      final isSelected = selectedImpact == entry.key;
      return PieChartSectionData(
        color: isSelected ? Colors.deepPurple : colors[index % colors.length],
        value: entry.value.toDouble(),
        title: '(${entry.value})',
        radius: isSelected ? 55 : 45,
        titleStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: isSelected ? 12 : 10,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      );
    });
  }

  List<Widget> _getLegendItems() {
    final impactCount = <String, int>{};
    for (final ticket in tickets) {
      impactCount.update(
        ticket.impactTitle,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final colors = [
      Colors.deepPurple.shade900,
      Colors.deepPurple.shade700,
      Colors.deepPurple.shade400,
      Colors.deepPurple.shade300,
      Colors.deepPurple.shade200,
    ];

    final entries = impactCount.entries.toList();
    return List.generate(entries.length, (index) {
      final isSelected = selectedImpact == entries[index].key;
      return GestureDetector(
        onTap: onImpactSelected != null ? () {
          onImpactSelected!(entries[index].key);
        } : null,
        child: _LegendItem(
          color: isSelected ? Colors.deepPurple : colors[index % colors.length],
          label: entries[index].key,
          isSelected: isSelected,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pieData = _getPieData();
    final legendItems = _getLegendItems();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('By Impact',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 13),
          GestureDetector(
            onTap: () {
              // Allow clicking on the chart to clear selection
              if (onImpactSelected != null && selectedImpact != null) {
                onImpactSelected!(selectedImpact!);
              }
            },
            child: SizedBox(
              height: 130,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 26,
                  sections: pieData,
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: legendItems,
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSelected;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: isSelected ? Border.all(color: color, width: 1) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          )),
        ],
      ),
    );
  }
}

class TopCreatorsCard extends StatelessWidget {
  final List<Ticket> tickets;

  const TopCreatorsCard({super.key, required this.tickets});

  Map<String, int> _getTopCreators() {
    final creatorCount = <String, int>{};
    for (final ticket in tickets) {
      creatorCount.update(
        ticket.reportedByName,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return creatorCount;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final fontSize = width < 400 ? 10 : width < 800 ? 12 : 12;
    final padding = math.max(8.0, width * 0.03);
    final topCreators = _getTopCreators();
    final topCreator = topCreators.isNotEmpty
        ? topCreators.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Top Creators", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: math.max(12.0, fontSize * 0.9))),
              Text("Reported By", style: GoogleFonts.poppins(fontSize: fontSize - 1, color: Colors.grey)),
            ],
          ),
          SizedBox(height: width * 0.02),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: width * 0.05,
                backgroundColor: const Color(0xFFE5E7EB),
                child: Icon(Icons.person, color: Colors.black54, size: width * 0.05),
              ),
              SizedBox(width: width * 0.03),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topCreator?.value.toString() ?? "0", style: GoogleFonts.poppins(fontSize: fontSize * 1.5, fontWeight: FontWeight.bold)),
                  Text("/ Tickets", style: GoogleFonts.poppins(fontSize: fontSize - 1, color: Colors.grey[600])),
                  if (topCreator != null)
                    Text(
                      topCreator.key,
                      style: GoogleFonts.poppins(fontSize: fontSize - 1, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class UpcomingTicketCard extends StatelessWidget {
  final List<Ticket> tickets;

  const UpcomingTicketCard({super.key, required this.tickets});

  List<Ticket> _getUpcomingTickets() {
    final now = DateTime.now();
    return tickets.where((ticket) {
      if (ticket.completedDate.isEmpty) return false;
      try {
        final dueDate = DateTime.parse(ticket.completedDate);
        return dueDate.isAfter(now) && dueDate.difference(now).inDays <= 30;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final fontSize = width < 400 ? 10 : width < 800 ? 12 : 12;
    final padding = math.max(8.0, width * 0.02);
    final upcomingTickets = _getUpcomingTickets();

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Upcoming \nTicket Deadlines", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: math.max(10.0, fontSize * 0.93))),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.02, vertical: width * 0.01,),
                  backgroundColor: const Color(0xFFEFF6FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  minimumSize: Size(width * 0.1, 0),
                ),
                onPressed: () {},
                child: Text("View More ", style: GoogleFonts.poppins(fontSize: fontSize * 0.7, color: const Color(0xFF2563EB))),
              ),
            ],
          ),
          SizedBox(height: width * 0.02),
          if (upcomingTickets.isEmpty)
            Row(
              children: [
                const Icon(Icons.check_box, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Flexible(child: Text("No upcoming tickets this month", style: GoogleFonts.poppins(color: Colors.black87))),
              ],
            )
          else
            ...upcomingTickets.take(3).map((ticket) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ticket.title, style:  GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        Text('Due: ${ticket.completedDate}', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style:  GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
              if (subtitle.isNotEmpty) Text(subtitle, style:  GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _IssueTypeChart extends StatelessWidget {
  final List<Ticket> tickets;
  final Function(String)? onTypeSelected;
  final String? selectedType;

  const _IssueTypeChart({
    required this.tickets,
    this.onTypeSelected,
    this.selectedType,
  });

  @override
  Widget build(BuildContext context) {
    final typeCount = <String, int>{};
    for (final ticket in tickets) {
      typeCount.update(
        ticket.typeTitle,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final types = typeCount.keys.toList();
    final values = typeCount.values.toList();

    if (values.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'No issue type data',
            style: GoogleFonts.poppins(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    final maxCount = values.reduce(math.max).toDouble();
    final dynamicMaxY = maxCount > 0 ? maxCount * 1.1 : 2;

    final spots = List.generate(types.length, (index) =>
        FlSpot(index.toDouble(), values[index].toDouble())
    );

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          gridData: FlGridData(
            show: false,
            drawHorizontalLine: true,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.1),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value % 1 == 0 && value >= 0) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Text(
                        value.toInt().toString(),
                        style:  GoogleFonts.poppins(fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < types.length) {
                    final isSelected = selectedType == types[value.toInt()];
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Transform.rotate(
                        angle: -45 * 3.14159 / 180,
                        child: Text(
                          types[value.toInt()],
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: isSelected ? Colors.amber : Colors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.white,
            ),
            handleBuiltInTouches: true,
            touchCallback: (event, touchResponse) {
              if (event is FlTapUpEvent && touchResponse != null) {
                final spot = touchResponse.lineBarSpots?.firstOrNull;
                if (spot != null && onTypeSelected != null) {
                  final typeIndex = spot.x.toInt();
                  if (typeIndex >= 0 && typeIndex < types.length) {
                    onTypeSelected!(types[typeIndex]);
                  }
                }
              }
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withOpacity(0.8),
                  Colors.amber.withOpacity(0.3),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isSelected = selectedType == types[index];
                  return FlDotCirclePainter(
                    radius: isSelected ? 5 : 3,
                    color: isSelected ? Colors.amber : Colors.amber,
                    strokeWidth: isSelected ? 2.5 : 1.5,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withOpacity(0.5),
                    Colors.amber.withOpacity(0.1),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolvedGauge extends StatelessWidget {
  final List<Ticket> tickets;

  const _ResolvedGauge({required this.tickets});

  double _getResolvedPercentage() {
    final resolvedCount = tickets.where((ticket) => ticket.statusTitle.toLowerCase().contains('closed') || ticket.statusTitle.toLowerCase().contains('resolved')).length;
    return tickets.isEmpty ? 0.0 : resolvedCount / tickets.length;
  }

  @override
  Widget build(BuildContext context) {
    final percentage = _getResolvedPercentage();

    return SizedBox(
      height: 95,
      width: double.infinity,
      child: Center(
        child: SizedBox(
          width: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(240, 120),
                painter: _HalfCirclePainter(
                  progress: 1.0,
                  color: Colors.grey.shade300,
                ),
              ),
              CustomPaint(
                size: const Size(240, 120),
                painter: _HalfCirclePainter(
                  progress: percentage.clamp(0.0, 1.0),
                  color: const Color(0xff332757),
                ),
              ),
              Positioned(
                bottom: 20,
                child: Text(
                  '${(percentage * 100).toStringAsFixed(0)}%',
                  style:  GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xff332757),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HalfCirclePainter extends CustomPainter {
  final double progress;
  final Color color;

  _HalfCirclePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    const double startAngle = math.pi;
    final double sweepAngle = math.pi * (progress.clamp(0.0, 1.0));
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _HalfCirclePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _TrendByTypesChart extends StatelessWidget {
  final List<Ticket> tickets;

  const _TrendByTypesChart({required this.tickets});

  @override
  Widget build(BuildContext context) {
    final typeCount = <String, int>{};
    for (final ticket in tickets) {
      typeCount.update(
        ticket.typeTitle,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final types = typeCount.keys.toList();
    final values = typeCount.values.toList();

    if (values.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'No trend data by types',
            style: GoogleFonts.poppins(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    final maxCount = values.reduce(math.max).toDouble();
    final dynamicMaxY = maxCount > 0 ? maxCount * 1.1 : 2;

    final spots = List.generate(types.length, (index) =>
        FlSpot(index.toDouble(), values[index].toDouble())
    );

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          gridData: FlGridData(
            show: false,
            drawHorizontalLine: true,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.1),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value % 1 == 0 && value >= 0) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Text(
                        value.toInt().toString(),
                        style:  GoogleFonts.poppins(fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < types.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Transform.rotate(
                        angle: -45 * 3.14159 / 180,
                        child: Text(
                          types[value.toInt()],
                          style:  GoogleFonts.poppins(fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.8),
                  Colors.green.withOpacity(0.3),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: Colors.green,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.green.withOpacity(0.6),
                    Colors.green.withOpacity(0.2),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.7, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
