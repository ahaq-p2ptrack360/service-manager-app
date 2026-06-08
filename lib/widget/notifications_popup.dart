import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../notification_service.dart';

class NotificationsPopup extends StatefulWidget {
  final List<NotificationModel> notifications;
  final VoidCallback onRefresh;

  const NotificationsPopup({
    super.key,
    required this.notifications,
    required this.onRefresh,
  });

  @override
  State<NotificationsPopup> createState() => _NotificationsPopupState();
}

class _NotificationsPopupState extends State<NotificationsPopup> {
  late List<NotificationModel> notificationsList;
  bool isLoading = false;
  Set<int> selectedNotifications = {}; // Track selected notification IDs
  bool isSelectAll = false; // Track select all state

  @override
  void initState() {
    super.initState();
    notificationsList = List.from(widget.notifications);
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (!notification.isRead) {
      setState(() {
        isLoading = true;
      });
      final success = await NotificationService().markAsRead(notification.id);
      if (success) {
        setState(() {
          final index = notificationsList.indexWhere((n) => n.id == notification.id);
          if (index != -1) {
            notificationsList[index].isRead = true;
          }
        });
        widget.onRefresh();
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final userId = int.parse(prefs.getString("id") ?? "0");
    final success = await NotificationService().markAllAsRead(userId);
    if (success) {
      setState(() {
        for (var notification in notificationsList) {
          notification.isRead = true;
        }
      });
      widget.onRefresh();
    }
    setState(() {
      isLoading = false;
    });
  }

  // ==================== DELETE SELECTED NOTIFICATIONS ====================
  Future<void> _deleteSelectedNotifications() async {
    if (selectedNotifications.isEmpty) return;

    // Show confirmation dialog
    final confirmDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 10),
            Text(
              'Delete Notifications',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to delete ${selectedNotifications.length} notification${selectedNotifications.length != 1 ? 's' : ''}?',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${selectedNotifications.length} notification${selectedNotifications.length != 1 ? 's' : ''} will be permanently deleted.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. Selected notifications will be permanently deleted.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmDelete != true) return;

    // Show loading indicator
    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString("id") ?? "1";

      final response = await http.delete(
        Uri.parse('https://demo.p2ptrack360.com:8888/api/notifications/delete'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'user_id': userId,
          'ids': selectedNotifications.toList(),
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Remove selected notifications from list
          setState(() {
            notificationsList.removeWhere((n) => selectedNotifications.contains(n.id));
            selectedNotifications.clear();
            isSelectAll = false;
            isLoading = false;
          });

          // Refresh parent
          widget.onRefresh();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${selectedNotifications.length} notification${selectedNotifications.length != 1 ? 's' : ''} deleted successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'Failed to delete notifications'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notifications. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      print('Error deleting notifications: $e');
    }
  }

  // ==================== TOGGLE SELECT ALL ====================
  void _toggleSelectAll() {
    setState(() {
      if (isSelectAll) {
        selectedNotifications.clear();
        isSelectAll = false;
      } else {
        selectedNotifications = Set.from(notificationsList.map((n) => n.id));
        isSelectAll = true;
      }
    });
  }

  // ==================== TOGGLE SELECTION ====================
  void _toggleSelection(int notificationId) {
    setState(() {
      if (selectedNotifications.contains(notificationId)) {
        selectedNotifications.remove(notificationId);
        isSelectAll = false;
      } else {
        selectedNotifications.add(notificationId);
        if (selectedNotifications.length == notificationsList.length) {
          isSelectAll = true;
        }
      }
    });
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return DateFormat('MMM d, yyyy').format(date);
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'ticket_created':
        return Icons.add_circle_outline;
      case 'ticket_updated':
        return Icons.update;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'ticket_created':
        return Colors.green;
      case 'ticket_updated':
        return Colors.orange;
      default:
        return const Color(0xff332757);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = notificationsList.where((n) => !n.isRead).length;
    final totalCount = notificationsList.length;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xff332757),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.notifications, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              'Notifications',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Stats row showing unread and total counts
                  Row(
                    children: [
                      _buildStatChip(
                        'Unread: $unreadCount',
                        Colors.red,
                        unreadCount > 0,
                      ),
                      const SizedBox(width: 12),
                      _buildStatChip(
                        'Total: $totalCount',
                        Colors.grey,
                        false,
                      ),
                      if (selectedNotifications.isNotEmpty)
                        const SizedBox(width: 12),
                      if (selectedNotifications.isNotEmpty)
                        _buildStatChip(
                          'Selected: ${selectedNotifications.length}',
                          Colors.blue,
                          true,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            if (notificationsList.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Show filter/summary text
                    Text(
                      'Showing $totalCount notification${totalCount != 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Row(
                      children: [
                        // Select All checkbox
                        Row(
                          children: [
                            Checkbox(
                              value: isSelectAll && notificationsList.isNotEmpty,
                              onChanged: notificationsList.isEmpty ? null : (_) => _toggleSelectAll(),
                              activeColor: const Color(0xff332757),
                              checkColor: Colors.white,
                            ),
                            Text(
                              'Select All',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff332757),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        // Mark all as read button
                        TextButton(
                          onPressed: isLoading ? null : _markAllAsRead,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xff332757),
                          ),
                          child: isLoading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : Text(
                            unreadCount > 0 ? 'Mark all as read' : 'All read',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Notifications List
            Expanded(
              child: notificationsList.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: notificationsList.length,
                itemBuilder: (context, index) {
                  final notification = notificationsList[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: notification.isRead
                          ? Colors.white
                          : const Color(0xff332757).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: notification.isRead
                            ? Colors.grey[200]!
                            : const Color(0xff332757).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Checkbox
                        Checkbox(
                          value: selectedNotifications.contains(notification.id),
                          onChanged: (_) => _toggleSelection(notification.id),
                          activeColor: const Color(0xff332757),
                          checkColor: Colors.white,
                        ),
                        // Notification content
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _markAsRead(notification),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _getNotificationColor(notification.type).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _getNotificationIcon(notification.type),
                                      color: _getNotificationColor(notification.type),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notification.title,
                                          style: GoogleFonts.poppins(
                                            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          notification.message,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDate(notification.createdAt),
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!notification.isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Footer with Remove button
            if (notificationsList.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tap to mark as read',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        if (selectedNotifications.isNotEmpty)
                          ElevatedButton(
                            onPressed: isLoading ? null : _deleteSelectedNotifications,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.delete_outline, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Remove (${selectedNotifications.length})',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (unreadCount > 0)
                      Text(
                        '$unreadCount unread notification${unreadCount != 1 ? 's' : ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, Color color, bool isHighlighted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withOpacity(0.2) : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.white,
          fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}



// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../notification_service.dart';
//
//
// class NotificationsPopup extends StatefulWidget {
//   final List<NotificationModel> notifications;
//   final VoidCallback onRefresh;
//
//   const NotificationsPopup({
//     super.key,
//     required this.notifications,
//     required this.onRefresh,
//   });
//
//   @override
//   State<NotificationsPopup> createState() => _NotificationsPopupState();
// }
//
// class _NotificationsPopupState extends State<NotificationsPopup> {
//   late List<NotificationModel> notificationsList; // Changed variable name to avoid confusion
//   bool isLoading = false;
//
//   @override
//   void initState() {
//     super.initState();
//     notificationsList = List.from(widget.notifications); // Create a mutable copy
//   }
//
//   Future<void> _markAsRead(NotificationModel notification) async {
//     if (!notification.isRead) {
//       setState(() {
//         isLoading = true;
//       });
//       final success = await NotificationService().markAsRead(notification.id);
//       if (success) {
//         setState(() {
//           final index = notificationsList.indexWhere((n) => n.id == notification.id);
//           if (index != -1) {
//             notificationsList[index].isRead = true;
//           }
//         });
//         widget.onRefresh();
//       }
//       setState(() {
//         isLoading = false;
//       });
//     }
//   }
//
//   Future<void> _markAllAsRead() async {
//     setState(() {
//       isLoading = true;
//     });
//     // Get user_id from shared preferences
//     final prefs = await SharedPreferences.getInstance();
//     final userId = int.parse(prefs.getString("id") ?? "0");
//     final success = await NotificationService().markAllAsRead(userId);
//     if (success) {
//       setState(() {
//         for (var notification in notificationsList) {
//           notification.isRead = true;
//         }
//       });
//       widget.onRefresh();
//     }
//     setState(() {
//       isLoading = false;
//     });
//   }
//
//   String _formatDate(String dateString) {
//     try {
//       final date = DateTime.parse(dateString);
//       final now = DateTime.now();
//       final difference = now.difference(date);
//
//       if (difference.inDays > 7) {
//         return DateFormat('MMM d, yyyy').format(date);
//       } else if (difference.inDays > 0) {
//         return '${difference.inDays}d ago';
//       } else if (difference.inHours > 0) {
//         return '${difference.inHours}h ago';
//       } else if (difference.inMinutes > 0) {
//         return '${difference.inMinutes}m ago';
//       } else {
//         return 'Just now';
//       }
//     } catch (e) {
//       return dateString;
//     }
//   }
//
//   IconData _getNotificationIcon(String type) {
//     switch (type) {
//       case 'ticket_created':
//         return Icons.add_circle_outline;
//       case 'ticket_updated':
//         return Icons.update;
//       default:
//         return Icons.notifications;
//     }
//   }
//
//   Color _getNotificationColor(String type) {
//     switch (type) {
//       case 'ticket_created':
//         return Colors.green;
//       case 'ticket_updated':
//         return Colors.orange;
//       default:
//         return const Color(0xff332757);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final unreadCount = notificationsList.where((n) => !n.isRead).length;
//
//     return Dialog(
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Container(
//         width: MediaQuery.of(context).size.width * 0.9,
//        height: MediaQuery.of(context).size.height * 0.8,
//         padding: const EdgeInsets.all(0),
//         child: Column(
//           children: [
//             // Header
//             Container(
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: const Color(0xff332757),
//                 borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
//               ),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Row(
//                       children: [
//                         const Icon(Icons.notifications, color: Colors.white, size: 28),
//                         const SizedBox(width: 12),
//                         Text(
//                           'Notifications',
//                           style: GoogleFonts.poppins(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.white,
//                           ),
//                         ),
//                         if (unreadCount > 0)
//                           Container(
//                             margin: const EdgeInsets.only(left: 8),
//                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                             decoration: BoxDecoration(
//                               color: Colors.red,
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Text(
//                               '$unreadCount',
//                               style: GoogleFonts.poppins(
//                                 color: Colors.white,
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.close, color: Colors.white),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ],
//               ),
//             ),
//
//             // Actions
//             if (notificationsList.isNotEmpty)
//               Padding(
//                 padding: const EdgeInsets.all(12),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.end,
//                   children: [
//                     TextButton(
//                       onPressed: isLoading ? null : _markAllAsRead,
//                       style: TextButton.styleFrom(
//                         foregroundColor: const Color(0xff332757),
//                       ),
//                       child: isLoading
//                           ? const SizedBox(
//                         width: 20,
//                         height: 20,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       )
//                           : Text(
//                         'Mark all as read',
//                         style: GoogleFonts.poppins(
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//             // Notifications List
//             Expanded(
//               child: notificationsList.isEmpty
//                   ? Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(
//                       Icons.notifications_off,
//                       size: 64,
//                       color: Colors.grey[400],
//                     ),
//                     const SizedBox(height: 16),
//                     Text(
//                       'No notifications',
//                       style: GoogleFonts.poppins(
//                         fontSize: 16,
//                         color: Colors.grey[600],
//                       ),
//                     ),
//                   ],
//                 ),
//               )
//                   : ListView.builder(
//                 itemCount: notificationsList.length,
//                 itemBuilder: (context, index) {
//                   final notification = notificationsList[index];
//                   return GestureDetector(
//                     onTap: () => _markAsRead(notification),
//                     child: Container(
//                       margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//                       decoration: BoxDecoration(
//                         color: notification.isRead
//                             ? Colors.white
//                             : const Color(0xff332757).withOpacity(0.05),
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(
//                           color: notification.isRead
//                               ? Colors.grey[200]!
//                               : const Color(0xff332757).withOpacity(0.2),
//                         ),
//                       ),
//                       child: ListTile(
//                         contentPadding: const EdgeInsets.all(12),
//                         leading: Container(
//                           padding: const EdgeInsets.all(8),
//                           decoration: BoxDecoration(
//                             color: _getNotificationColor(notification.type).withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           child: Icon(
//                             _getNotificationIcon(notification.type),
//                             color: _getNotificationColor(notification.type),
//                             size: 24,
//                           ),
//                         ),
//                         title: Text(
//                           notification.title,
//                           style: GoogleFonts.poppins(
//                             fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
//                             fontSize: 14,
//                           ),
//                         ),
//                         subtitle: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             const SizedBox(height: 4),
//                             Text(
//                               notification.message,
//                               style: GoogleFonts.poppins(
//                                 fontSize: 12,
//                                 color: Colors.grey[600],
//                               ),
//                               maxLines: 2,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               _formatDate(notification.createdAt),
//                               style: GoogleFonts.poppins(
//                                 fontSize: 10,
//                                 color: Colors.grey[500],
//                               ),
//                             ),
//                           ],
//                         ),
//                         trailing: !notification.isRead
//                             ? Container(
//                           width: 8,
//                           height: 8,
//                           decoration: const BoxDecoration(
//                             color: Colors.blue,
//                             shape: BoxShape.circle,
//                           ),
//                         )
//                             : null,
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//
//             // Footer
//             if (notificationsList.isNotEmpty)
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   border: Border(
//                     top: BorderSide(color: Colors.grey[200]!),
//                   ),
//                 ),
//                 child: Center(
//                   child: Text(
//                     'Tap on notification to mark as read',
//                     style: GoogleFonts.poppins(
//                       fontSize: 11,
//                       color: Colors.grey[500],
//                       fontStyle: FontStyle.italic,
//                     ),
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
