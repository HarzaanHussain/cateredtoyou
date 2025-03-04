import 'dart:convert';

class AppNotification {
  final int id;
  final String title;
  final String body;
  final DateTime timestamp;
  final DateTime? scheduledTime;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.scheduledTime,
    this.isRead = false,
  });

  // Converts a notification to JSON for storage
  Map<String, dynamic> storeAsJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'scheduledTime': scheduledTime?.toIso8601String(),
      'isRead': isRead,
    };
  }

  // Creates a notification from JSON file
  factory AppNotification.createFromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      timestamp: DateTime.parse(json['timestamp']),
      scheduledTime: json['scheduledTime'] != null
          ? DateTime.parse(json['scheduledTime'])
          : null,
      isRead: json['isRead'] ?? false,
    );
  }

  // Create a copy with updated fields
  AppNotification copyWith({
    int? id,
    String? title,
    String? body,
    DateTime? timestamp,
    DateTime? scheduledTime,
    bool? isRead,
  }) {
    return AppNotification(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        timestamp: timestamp ?? this.timestamp,
        scheduledTime: scheduledTime ?? this.scheduledTime,
        isRead: isRead ?? this.isRead);
  }
}
