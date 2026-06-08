import 'dart:convert';
import 'package:anwar/dashboard.dart';
import 'package:anwar/notification_service.dart' show NotificationModel, NotificationService;
import 'package:anwar/profile.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:anwar/constant.dart';
import 'package:anwar/create_tickets.dart';
import 'package:anwar/viewmoreTickets.dart' show Viewmoretickets;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'widget/notifications_popup.dart' show NotificationsPopup;

class Tickets extends StatefulWidget {
  const Tickets({super.key});

  @override
  State<Tickets> createState() => _TicketsState();
}

class _TicketsState extends State<Tickets> {
  List<dynamic> _allTickets = [];
  List<dynamic> _displayedTickets = [];
  List<dynamic> _filteredTickets = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 10;
  int _totalTickets = 0;
  List<NotificationModel> notificationsList = [];
  int unreadNotificationCount = 0;
  List<int> previousNotificationIds = [];
  bool _isFirstNotificationFetch = true;
  final ScrollController _scrollController = ScrollController();




  final TextEditingController _searchController = TextEditingController();

  // Filter state
  String _searchQuery = '';
  String _selectedPriority = 'All Priorities';
  String _selectedImpact = 'All Impacts';
  String _selectedAgent = 'All Agents';
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _startResolvedDate;
  DateTime? _endResolvedDate;

  // Temporary filter state for bottom sheet
  String _tempSelectedPriority = 'All Priorities';
  String _tempSelectedImpact = 'All Impacts';
  String _tempSelectedAgent = 'All Agents';
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;
  DateTime? _tempStartResolvedDate;
  DateTime? _tempEndResolvedDate;

  // Filter options (populated from API data)
  List<String> _priorityOptions = ['All Priorities'];
  List<String> _impactOptions = ['All Impacts'];
  List<String> _agentOptions = ['All Agents'];

  // Keep track of whether filters are applied
  bool _areFiltersApplied = false;

  @override
  void initState() {
    super.initState();
    fetchTickets(page: _currentPage);
    fetchNotifications();
    _startNotificationPolling();

    // Listen for scroll events to load more
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        if (_hasMore && !_isLoadingMore && !_areFiltersApplied) {
          _loadMoreTickets();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  void _startNotificationPolling() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        fetchNotifications();
        _startNotificationPolling(); // Continue polling
      }
    });
  }
  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _selectedPriority = 'All Priorities';
      _selectedImpact = 'All Impacts';
      _selectedAgent = 'All Agents';
      _startDate = null;
      _endDate = null;
      _startResolvedDate = null;
      _endResolvedDate = null;
      _areFiltersApplied = false;

      // Reset temporary filter values
      _tempSelectedPriority = 'All Priorities';
      _tempSelectedImpact = 'All Impacts';
      _tempSelectedAgent = 'All Agents';
      _tempStartDate = null;
      _tempEndDate = null;
      _tempStartResolvedDate = null;
      _tempEndResolvedDate = null;
    });

    // Show all tickets
    _filteredTickets = List.from(_displayedTickets);
  }

  Future<void> fetchTickets({int page = 1, String? searchQuery}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var company_id = prefs.getString("company");
      var api;

      // Build base API URL
      if (company_id == "0") {
        api = "http://3.137.76.254/Service-Manager-main-Work/public/api/tickets";
      } else {
        var user_id = prefs.getString("id");
        api = "http://3.137.76.254/Service-Manager-main-Work/public/api/dashboard/get_all_tickets/$user_id";
      }

      // Add pagination parameters
      Uri uri;
      if (searchQuery != null && searchQuery.isNotEmpty) {
        uri = Uri.parse(api).replace(queryParameters: {
          'page': page.toString(),
          'per_page': _pageSize.toString(),
          'search': searchQuery,
        });
      } else {
        uri = Uri.parse(api).replace(queryParameters: {
          'page': page.toString(),
          'per_page': _pageSize.toString(),
        });
      }

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle different API response structures
        List<dynamic> tickets = [];
        int total = 0;

        if (data is Map) {
          // If API returns paginated response with metadata
          if (data.containsKey('data') && data.containsKey('total')) {
            tickets = List.from(data['data']);
            total = data['total'];
          } else if (data.containsKey('tickets') && data.containsKey('total')) {
            tickets = List.from(data['tickets']);
            total = data['total'];
          } else {
            // Assume the response is a list of tickets
            tickets = List.from(data as Iterable);
            total = tickets.length;
          }
        } else if (data is List) {
          tickets = List.from(data);
          total = tickets.length;
        }

        setState(() {
          if (page == 1) {
            _allTickets.clear();
            _displayedTickets.clear();
            _filteredTickets.clear();
          }

          _allTickets.addAll(tickets);
          _displayedTickets.addAll(tickets);
          _filteredTickets = List.from(_displayedTickets);
          _totalTickets = total;
          _hasMore = _displayedTickets.length < _totalTickets;
          _isLoading = false;
          _isLoadingMore = false;

          // Extract filter options from tickets data
          _extractFilterOptions();
        });
      } else {
        throw Exception('Failed to load tickets');
      }
    } catch (e) {
      print('Error fetching tickets: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  // Helper method to clean agent name
  String _cleanAgentName(String name) {
    if (name.isEmpty) return '';

    // Remove digits and special characters except spaces
    String cleaned = name.replaceAll(RegExp(r'[0-9]'), ''); // Remove digits
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s]'), ''); // Remove special characters

    // Trim extra whitespace
    cleaned = cleaned.trim();

    // Remove multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    // Capitalize first letter of each word
    if (cleaned.isNotEmpty) {
      cleaned = cleaned.split(' ').map((word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }

    return cleaned;
  }

  void _extractFilterOptions() {
    final priorities = <String>{};
    final impacts = <String>{};
    final agents = <String>{};

    for (final ticket in _allTickets) {
      final priority = (ticket['priority_title'] ?? '').toString();
      if (priority.trim().isNotEmpty) priorities.add(priority);

      final impact = (ticket['impact_title'] ?? '').toString();
      if (impact.trim().isNotEmpty) impacts.add(impact);

      // Try to get agent name from multiple possible fields
      String agentName = '';

      // First try resolved_name
      if (ticket['resolved_name'] != null && ticket['resolved_name'].toString().trim().isNotEmpty) {
        agentName = ticket['resolved_name'].toString().trim();
      }
      // Then try agent_name
      else if (ticket['agent_name'] != null && ticket['agent_name'].toString().trim().isNotEmpty) {
        agentName = ticket['agent_name'].toString().trim();
      }
      // Then try assigned_to_name
      else if (ticket['assigned_to_name'] != null && ticket['assigned_to_name'].toString().trim().isNotEmpty) {
        agentName = ticket['assigned_to_name'].toString().trim();
      }
      // Then try assigned_to (might be name or email)
      else if (ticket['assigned_to'] != null) {
        final assignedTo = ticket['assigned_to'].toString().trim();
        // Check if it's an email, extract name before @
        if (assignedTo.contains('@')) {
          final namePart = assignedTo.split('@')[0];
          agentName = namePart.replaceAll('.', ' ').replaceAll('_', ' ');
        } else if (assignedTo.isNotEmpty) {
          agentName = assignedTo;
        }
      }

      if (agentName.isNotEmpty) {
        // Clean the agent name (remove digits and special characters)
        agentName = _cleanAgentName(agentName);
        if (agentName.isNotEmpty) {
          agents.add(agentName);
        }
      }
    }

    setState(() {
      _priorityOptions = ['All Priorities', ...priorities.toList()..sort()];
      _impactOptions = ['All Impacts', ...impacts.toList()..sort()];
      _agentOptions = ['All Agents', ...agents.toList()..sort()];
    });
  }

  void _applyFilters() {
    setState(() {
      // Apply the temporary filter values
      _selectedPriority = _tempSelectedPriority;
      _selectedImpact = _tempSelectedImpact;
      _selectedAgent = _tempSelectedAgent;
      _startDate = _tempStartDate;
      _endDate = _tempEndDate;
      _startResolvedDate = _tempStartResolvedDate;
      _endResolvedDate = _tempEndResolvedDate;

      // Mark that filters are applied
      _areFiltersApplied = true;
    });

    // Apply the filters
    _performFiltering();
  }

  void _performFiltering() {
    setState(() {
      _filteredTickets = _allTickets.where((ticket) {
        final title = (ticket["title"] ?? '').toString().toLowerCase();
        final desc = (ticket["description"] ?? '').toString().toLowerCase();
        final company = (ticket["company_name"] ?? '').toString().toLowerCase();
        final status = (ticket["status_title"] ?? '').toString().toLowerCase();
        final priority = (ticket["priority_title"] ?? '').toString();
        final impact = (ticket["impact_title"] ?? '').toString();

        // Get agent name from multiple fields - including resolved_name
        String agentName = '';

        // First check resolved_name
        if (ticket['resolved_name'] != null && ticket['resolved_name'].toString().trim().isNotEmpty) {
          agentName = ticket['resolved_name'].toString().trim();
        }
        // Then try agent_name
        else if (ticket['agent_name'] != null && ticket['agent_name'].toString().trim().isNotEmpty) {
          agentName = ticket['agent_name'].toString().trim();
        }
        // Then try assigned_to_name
        else if (ticket['assigned_to_name'] != null && ticket['assigned_to_name'].toString().trim().isNotEmpty) {
          agentName = ticket['assigned_to_name'].toString().trim();
        }
        // Then try assigned_to (might be name or email)
        else if (ticket['assigned_to'] != null) {
          final assignedTo = ticket['assigned_to'].toString().trim();
          if (assignedTo.contains('@')) {
            final namePart = assignedTo.split('@')[0];
            agentName = namePart.replaceAll('.', ' ').replaceAll('_', ' ');
          } else if (assignedTo.isNotEmpty) {
            agentName = assignedTo;
          }
        }

        // Clean the agent name (remove digits and special characters)
        agentName = _cleanAgentName(agentName);

        // Get date strings
        final createdDateStr = (ticket["created_at"] ?? '').toString();
        final resolvedDateStr = (ticket["resolved_at"] ?? '').toString();

        DateTime? createdDate;
        DateTime? resolvedDate;

        try {
          if (createdDateStr.isNotEmpty) {
            createdDate = DateTime.parse(createdDateStr.split(' ')[0]);
          }
          if (resolvedDateStr.isNotEmpty) {
            resolvedDate = DateTime.parse(resolvedDateStr.split(' ')[0]);
          }
        } catch (e) {
          print('Error parsing date: $e');
        }

        // Search query matching
        final matchesSearch = _searchQuery.isEmpty ||
            title.contains(_searchQuery.toLowerCase()) ||
            desc.contains(_searchQuery.toLowerCase()) ||
            company.contains(_searchQuery.toLowerCase()) ||
            status.contains(_searchQuery.toLowerCase()) ||
            agentName.toLowerCase().contains(_searchQuery.toLowerCase());

        // Priority filter
        final matchesPriority = (_selectedPriority == 'All Priorities') ||
            (priority == _selectedPriority);

        // Impact filter
        final matchesImpact = (_selectedImpact == 'All Impacts') ||
            (impact == _selectedImpact);

        // Agent filter
        final matchesAgent = (_selectedAgent == 'All Agents') ||
            (agentName == _selectedAgent);

        // Date Created filter
        bool matchesDateCreated = true;
        if (_startDate != null || _endDate != null) {
          if (createdDate == null) {
            matchesDateCreated = false;
          } else {
            if (_startDate != null && createdDate.isBefore(_startDate!)) {
              matchesDateCreated = false;
            }
            if (_endDate != null && createdDate.isAfter(_endDate!)) {
              matchesDateCreated = false;
            }
          }
        }

        // Date Resolved filter
        bool matchesDateResolved = true;
        if (_startResolvedDate != null || _endResolvedDate != null) {
          if (resolvedDate == null) {
            matchesDateResolved = false;
          } else {
            if (_startResolvedDate != null && resolvedDate.isBefore(_startResolvedDate!)) {
              matchesDateResolved = false;
            }
            if (_endResolvedDate != null && resolvedDate.isAfter(_endResolvedDate!)) {
              matchesDateResolved = false;
            }
          }
        }

        return matchesSearch &&
            matchesPriority &&
            matchesImpact &&
            matchesAgent &&
            matchesDateCreated &&
            matchesDateResolved;
      }).toList();
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


  Future<void> _loadMoreTickets() async {
    if (_isLoadingMore || !_hasMore || _areFiltersApplied) return;

    setState(() {
      _isLoadingMore = true;
    });

    final nextPage = _currentPage + 1;

    try {
      await fetchTickets(page: nextPage);
      setState(() {
        _currentPage = nextPage;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _openFilterMenu() {
    // Set temporary values to current selected values
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return FilterBottomSheet(
          priorityOptions: _priorityOptions,
          impactOptions: _impactOptions,
          agentOptions: _agentOptions,
          tempSelectedPriority: _tempSelectedPriority,
          tempSelectedImpact: _tempSelectedImpact,
          tempSelectedAgent: _tempSelectedAgent,
          tempStartDate: _tempStartDate,
          tempEndDate: _tempEndDate,
          tempStartResolvedDate: _tempStartResolvedDate,
          tempEndResolvedDate: _tempEndResolvedDate,
          onPriorityChanged: (value) {
            setState(() => _tempSelectedPriority = value ?? 'All Priorities');
          },
          onImpactChanged: (value) {
            setState(() => _tempSelectedImpact = value ?? 'All Impacts');
          },
          onAgentChanged: (value) {
            setState(() => _tempSelectedAgent = value ?? 'All Agents');
          },
          onStartDateChanged: (date) {
            setState(() => _tempStartDate = date);
          },
          onEndDateChanged: (date) {
            setState(() => _tempEndDate = date);
          },
          onStartResolvedDateChanged: (date) {
            setState(() => _tempStartResolvedDate = date);
          },
          onEndResolvedDateChanged: (date) {
            setState(() => _tempEndResolvedDate = date);
          },
          onResetFilters: () {
            setState(() {
              _tempSelectedPriority = 'All Priorities';
              _tempSelectedImpact = 'All Impacts';
              _tempSelectedAgent = 'All Agents';
              _tempStartDate = null;
              _tempEndDate = null;
              _tempStartResolvedDate = null;
              _tempEndResolvedDate = null;
            });
            Navigator.pop(context);
          },
          onApplyFilters: () {
            Navigator.pop(context);
            _applyFilters();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xff332757),
        iconTheme: const IconThemeData(color: Colors.white),

        title: Text(
          'Tickets',
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
                Icon(Icons.notifications_none, size: screenHeight * 0.04, color: Colors.white),
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
            width: screenWidth * 0.1,
            height: screenWidth * 0.1,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(screenWidth * 0.05),
            ),
            child: GestureDetector(
              child: const Icon(Icons.person_outline, color: Colors.black87),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileViewScreen(userData: {},)));
              },
            ),
          ),
        ],
      ),
      drawer: MyDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xff332757),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => CreateTickets()));
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Create Tickets',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: screenHeight * 0.06,
                          child: TextFormField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value.trim();
                              });
                              _performFiltering();
                            },
                            style: GoogleFonts.poppins(color: Colors.black, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search Tickets (title, description, company, status, agent)',
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                              fillColor: Colors.white,
                              filled: true,
                              prefixIcon: const Icon(Icons.search_outlined, color: Colors.black54),
                              suffixIcon: _searchQuery.isNotEmpty || _areFiltersApplied
                                  ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.black54),
                                onPressed: () {
                                  _searchController.clear();
                                  _resetFilters();
                                },
                              )
                                  : null,
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Colors.black),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Colors.black),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: screenHeight * 0.06,
                        width: screenHeight * 0.06,
                        decoration: BoxDecoration(
                          color: const Color(0xff332757),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.filter_alt_sharp, color: Colors.white),
                          onPressed: _openFilterMenu,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),

          // Active Filters Indicator
          if (_areFiltersApplied)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_selectedPriority != 'All Priorities')
                        _FilterChip(
                          label: 'Priority: $_selectedPriority',
                          onRemove: () {
                            setState(() {
                              _selectedPriority = 'All Priorities';
                            });
                            _performFiltering();
                          },
                        ),
                      if (_selectedImpact != 'All Impacts')
                        _FilterChip(
                          label: 'Impact: $_selectedImpact',
                          onRemove: () {
                            setState(() {
                              _selectedImpact = 'All Impacts';
                            });
                            _performFiltering();
                          },
                        ),
                      if (_selectedAgent != 'All Agents')
                        _FilterChip(
                          label: 'Agent: $_selectedAgent',
                          onRemove: () {
                            setState(() {
                              _selectedAgent = 'All Agents';
                            });
                            _performFiltering();
                          },
                        ),
                      if (_startDate != null)
                        _FilterChip(
                          label: 'Created From: ${DateFormat('yyyy-MM-dd').format(_startDate!)}',
                          onRemove: () {
                            setState(() {
                              _startDate = null;
                            });
                            _performFiltering();
                          },
                        ),
                      if (_endDate != null)
                        _FilterChip(
                          label: 'Created To: ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                          onRemove: () {
                            setState(() {
                              _endDate = null;
                            });
                            _performFiltering();
                          },
                        ),
                      if (_startResolvedDate != null)
                        _FilterChip(
                          label: 'Resolved From: ${DateFormat('yyyy-MM-dd').format(_startResolvedDate!)}',
                          onRemove: () {
                            setState(() {
                              _startResolvedDate = null;
                            });
                            _performFiltering();
                          },
                        ),
                      if (_endResolvedDate != null)
                        _FilterChip(
                          label: 'Resolved To: ${DateFormat('yyyy-MM-dd').format(_endResolvedDate!)}',
                          onRemove: () {
                            setState(() {
                              _endResolvedDate = null;
                            });
                            _performFiltering();
                          },
                        ),
                    ],
                  ),
                  if (_areFiltersApplied)
                    GestureDetector(
                      onTap: _resetFilters,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Clear all filters',
                          style: GoogleFonts.poppins(
                            color: Color(0xff332757),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Results Count
          if (!_isLoading && !_hasError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${_filteredTickets.length} of $_totalTickets tickets',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  if (_areFiltersApplied || _searchQuery.isNotEmpty)
                    Text(
                      '${_areFiltersApplied ? 'Filtered' : 'Searched'} Results',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Color(0xff332757),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),

          // Tickets List
          Expanded(
            child: _isLoading && _displayedTickets.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xff332757)))
                : _hasError && _displayedTickets.isEmpty
                ? Center(child: Text("Failed to load tickets.", style: GoogleFonts.poppins(color: Colors.black54, fontSize: 14)))
                : RefreshIndicator(
              onRefresh: () => fetchTickets(page: 1),
              child: _filteredTickets.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 50),
                  child: Text(
                    "No tickets found.",
                    style: GoogleFonts.poppins(color: Colors.black54, fontSize: 14),
                  ),
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _filteredTickets.length + (_hasMore && !_areFiltersApplied ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _filteredTickets.length) {
                    return _buildLoadMoreIndicator();
                  }

                  final ticket = _filteredTickets[index];
                  return _TicketCard(
                    id: ticket["id"].toString(),
                    company: ticket["company_name"] ?? 'N/A',
                    title: ticket["title"] ?? 'No Title',
                    desc: ticket["description"] ?? '',
                    status: ticket["status_title"] ?? 'Unknown',
                    priority: ticket["priority_title"] ?? 'N/A',
                    impact: ticket["impact_title"] ?? 'N/A',
                    created: ticket["created_at"] ?? '',
                    resolved: ticket["resolved_at"] ?? '',
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: _isLoadingMore
            ? const CircularProgressIndicator(color: Color(0xff332757))
            : TextButton(
          onPressed: _loadMoreTickets,
          child: Text(
            'Load More Tickets',
            style: GoogleFonts.poppins(
              color: Color(0xff332757),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class FilterBottomSheet extends StatefulWidget {
  final List<String> priorityOptions;
  final List<String> impactOptions;
  final List<String> agentOptions;
  final String tempSelectedPriority;
  final String tempSelectedImpact;
  final String tempSelectedAgent;
  final DateTime? tempStartDate;
  final DateTime? tempEndDate;
  final DateTime? tempStartResolvedDate;
  final DateTime? tempEndResolvedDate;
  final ValueChanged<String?> onPriorityChanged;
  final ValueChanged<String?> onImpactChanged;
  final ValueChanged<String?> onAgentChanged;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<DateTime?> onStartResolvedDateChanged;
  final ValueChanged<DateTime?> onEndResolvedDateChanged;
  final VoidCallback onResetFilters;
  final VoidCallback onApplyFilters;

  const FilterBottomSheet({
    super.key,
    required this.priorityOptions,
    required this.impactOptions,
    required this.agentOptions,
    required this.tempSelectedPriority,
    required this.tempSelectedImpact,
    required this.tempSelectedAgent,
    required this.tempStartDate,
    required this.tempEndDate,
    required this.tempStartResolvedDate,
    required this.tempEndResolvedDate,
    required this.onPriorityChanged,
    required this.onImpactChanged,
    required this.onAgentChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onStartResolvedDateChanged,
    required this.onEndResolvedDateChanged,
    required this.onResetFilters,
    required this.onApplyFilters,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Filter Tickets',
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 25),

                  // Priority Dropdown
                  Text('Priority', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: widget.tempSelectedPriority,
                    decoration: _dropdownDecoration('Select Priority'),
                    items: widget.priorityOptions.map((p) {
                      return DropdownMenuItem(value: p, child: Text(p));
                    }).toList(),
                    onChanged: widget.onPriorityChanged,
                  ),
                  const SizedBox(height: 20),

                  // Impact Dropdown
                  Text('Impact', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: widget.tempSelectedImpact,
                    decoration: _dropdownDecoration('Select Impact'),
                    items: widget.impactOptions.map((i) {
                      return DropdownMenuItem(value: i, child: Text(i));
                    }).toList(),
                    onChanged: widget.onImpactChanged,
                  ),
                  const SizedBox(height: 20),

                  // Agent Dropdown
                  Text('Agent', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: widget.tempSelectedAgent,
                    decoration: _dropdownDecoration('Select Agent'),
                    items: widget.agentOptions.map((agent) {
                      return DropdownMenuItem(value: agent, child: Text(agent));
                    }).toList(),
                    onChanged: widget.onAgentChanged,
                  ),
                  const SizedBox(height: 20),

                  // Date Created Range
                  Text('Date Created Range', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerField(
                          label: 'From',
                          selectedDate: widget.tempStartDate,
                          onDateSelected: widget.onStartDateChanged,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DatePickerField(
                          label: 'To',
                          selectedDate: widget.tempEndDate,
                          onDateSelected: widget.onEndDateChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Date Resolved Range
                  Text('Date Completed Range', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerField(
                          label: 'From',
                          selectedDate: widget.tempStartResolvedDate,
                          onDateSelected: widget.onStartResolvedDateChanged,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DatePickerField(
                          label: 'To',
                          selectedDate: widget.tempEndResolvedDate,
                          onDateSelected: widget.onEndResolvedDateChanged,
                        ),
                      ),
                    ],
                  ),

                  // Show Selected Dates
                  if (widget.tempStartDate != null || widget.tempEndDate != null ||
                      widget.tempStartResolvedDate != null || widget.tempEndResolvedDate != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          'Selected Date Ranges:',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        if (widget.tempStartDate != null || widget.tempEndDate != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Created: ${widget.tempStartDate != null ? DateFormat('yyyy-MM-dd').format(widget.tempStartDate!) : 'Any'} to ${widget.tempEndDate != null ? DateFormat('yyyy-MM-dd').format(widget.tempEndDate!) : 'Any'}',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        if (widget.tempStartResolvedDate != null || widget.tempEndResolvedDate != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Resolved: ${widget.tempStartResolvedDate != null ? DateFormat('yyyy-MM-dd').format(widget.tempStartResolvedDate!) : 'Any'} to ${widget.tempEndResolvedDate != null ? DateFormat('yyyy-MM-dd').format(widget.tempEndResolvedDate!) : 'Any'}',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),

                  const SizedBox(height: 40),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xff332757),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xff332757), width: 1.5),
                            ),
                          ),
                          onPressed: () {
                            widget.onResetFilters();
                          },
                          child: Text(
                            'Reset Filters',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff332757),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff332757),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: widget.onApplyFilters,
                          child: Text(
                            'Apply Filters',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _dropdownDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xff332757), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateSelected;

  const _DatePickerField({
    required this.label,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Container(
          height: 50,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Color(0xff332757),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (pickedDate != null) {
                  onDateSelected(pickedDate);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedDate != null
                          ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                          : 'Select Date',
                      style: GoogleFonts.poppins(
                        color: selectedDate != null ? Colors.black : Colors.grey.shade500,
                      ),
                    ),
                    Icon(Icons.calendar_today, size: 20, color: const Color(0xff332757)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xff332757).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff332757).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xff332757),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 14,
              color: const Color(0xff332757),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final String id, company, title, desc, status, priority, impact, created, resolved;

  const _TicketCard({
    required this.id,
    required this.company,
    required this.title,
    required this.desc,
    required this.status,
    required this.priority,
    required this.impact,
    required this.created,
    required this.resolved,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xfffaf8ff), Color(0xfff3f0fa)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.deepPurple.withOpacity(0.1), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.assignment, color: Color(0xff332757), size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: const Color(0xff332757),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(status),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),
          Text(
            desc,
            style: GoogleFonts.poppins(color: Colors.black87, fontSize: 13, height: 1.4),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _InfoChip(label: 'Priority', value: priority),
              _InfoChip(label: 'Impact', value: impact),
            ],
          ),

          const SizedBox(height: 5),
          Divider(color: Colors.deepPurple.withOpacity(0.2), thickness: 0.8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Created: ${created.isNotEmpty ? created.split(' ')[0] : 'N/A'}',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.account_circle, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    company,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (resolved.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 13, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'Resolved: ${resolved.split(' ')[0]}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 6),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xff332757),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Viewmoretickets(ticketId: int.parse(id)),
                  ),
                );
              },
              icon: const Icon(Icons.visibility_outlined, color: Colors.white, size: 16),
              label: Text(
                'View More',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'closed':
        return Colors.green;
      case 'open':
        return Colors.orange;
      case 'pending':
        return Colors.amber;
      default:
        return const Color(0xff332757);
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
