import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationModel {
  final int id;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final String ticketId;
  bool isRead;
  final int companyId;
  final String createdAt;
  final String? readAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    required this.ticketId,
    required this.isRead,
    required this.companyId,
    required this.createdAt,
    this.readAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      data: json['data'] ?? {},
      ticketId: json['ticket_id']?.toString() ?? '',
      isRead: json['is_read'] ?? false,
      companyId: json['company_id'] ?? 0,
      createdAt: json['created_at'] ?? '',
      readAt: json['read_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'data': data,
      'ticket_id': ticketId,
      'is_read': isRead,
      'company_id': companyId,
      'created_at': createdAt,
      'read_at': readAt,
    };
  }
}

class NotificationService {
  static const String baseUrl = 'https://demo.p2ptrack360.com:8888/api';

  Future<List<NotificationModel>> fetchNotifications(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications?user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['data'];
          return data.map((item) => NotificationModel.fromJson(item)).toList();
        } else {
          throw Exception('Failed to load notifications: ${responseData['message']}');
        }
      } else {
        throw Exception('Failed to load notifications: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching notifications: $e');
    }
  }

  Future<bool> markAsRead(int notificationId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markAllAsRead(int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/mark-all-read?user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}



// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
//
// class NotificationModel {
//   final int id;
//   final String type;
//   final String title;
//   final String message;
//   final Map<String, dynamic> data;
//   final String ticketId;
//   bool isRead; // Changed from final to bool (mutable)
//   final int companyId;
//   final String createdAt;
//   final String? readAt;
//
//   NotificationModel({
//     required this.id,
//     required this.type,
//     required this.title,
//     required this.message,
//     required this.data,
//     required this.ticketId,
//     required this.isRead,
//     required this.companyId,
//     required this.createdAt,
//     this.readAt,
//   });
//
//   factory NotificationModel.fromJson(Map<String, dynamic> json) {
//     return NotificationModel(
//       id: json['id'] ?? 0,
//       type: json['type'] ?? '',
//       title: json['title'] ?? '',
//       message: json['message'] ?? '',
//       data: json['data'] ?? {},
//       ticketId: json['ticket_id']?.toString() ?? '',
//       isRead: json['is_read'] ?? false,
//       companyId: json['company_id'] ?? 0,
//       createdAt: json['created_at'] ?? '',
//       readAt: json['read_at'],
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'type': type,
//       'title': title,
//       'message': message,
//       'data': data,
//       'ticket_id': ticketId,
//       'is_read': isRead,
//       'company_id': companyId,
//       'created_at': createdAt,
//       'read_at': readAt,
//     };
//   }
// }
//
// class NotificationService {
//   static const String baseUrl = 'https://demo.p2ptrack360.com:8888/api';
//
//   Future<List<NotificationModel>> fetchNotifications(int userId) async {
//     try {
//       final response = await http.get(
//         Uri.parse('$baseUrl/notifications?user_id=$userId'),
//         headers: {
//           'Content-Type': 'application/json',
//         },
//       );
//
//       if (response.statusCode == 200) {
//         final Map<String, dynamic> responseData = json.decode(response.body);
//         if (responseData['success'] == true) {
//           final List<dynamic> data = responseData['data'];
//           return data.map((item) => NotificationModel.fromJson(item)).toList();
//         } else {
//           throw Exception('Failed to load notifications: ${responseData['message']}');
//         }
//       } else {
//         throw Exception('Failed to load notifications: ${response.statusCode}');
//       }
//     } catch (e) {
//       throw Exception('Error fetching notifications: $e');
//     }
//   }
//
//   Future<bool> markAsRead(int notificationId) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/notifications/$notificationId/read'),
//         headers: {
//           'Content-Type': 'application/json',
//         },
//       );
//       return response.statusCode == 200;
//     } catch (e) {
//       return false;
//     }
//   }
//
//   Future<bool> markAllAsRead(int userId) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/notifications/mark-all-read?user_id=$userId'),
//         headers: {
//           'Content-Type': 'application/json',
//         },
//       );
//       return response.statusCode == 200;
//     } catch (e) {
//       return false;
//     }
//   }
// }