import 'dart:convert';

enum RecurringInterval {
  daily,
  weekly,
  monthly,
  quarterly,
  yearly
}

class RecurringNotification {
  final String id; // Unique identifier
  final String title; // Notification title
  final String body; // Notification body
  final String screen; // Target screen
  final Map<String, dynamic>? extraData; // Extra data for navigation
  final RecurringInterval interval; // How often to repeat
  final DateTime startDate; // When to start
  final DateTime? endDate; // When to end (optional)
  final bool isActive; // Whether this recurring notification is active
  final DateTime createdAt; // When this configuration was created
  final DateTime nextScheduledDate; // When the next notification will be sent
  
  RecurringNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.screen,
    this.extraData,
    required this.interval,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    required this.createdAt,
    required this.nextScheduledDate,
  });
  
  // Create a copy with updated fields
  RecurringNotification copyWith({
    String? title,
    String? body,
    String? screen,
    Map<String, dynamic>? extraData,
    RecurringInterval? interval,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? nextScheduledDate,
  }) {
    return RecurringNotification(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      screen: screen ?? this.screen,
      extraData: extraData ?? this.extraData,
      interval: interval ?? this.interval,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      nextScheduledDate: nextScheduledDate ?? this.nextScheduledDate,
    );
  }
  
  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'screen': screen,
      'extraData': extraData != null ? json.encode(extraData) : null,
      'interval': interval.toString().split('.').last,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'nextScheduledDate': nextScheduledDate.toIso8601String(),
    };
  }
  
  // Create from JSON from storage
  factory RecurringNotification.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? extraData;
    if (json['extraData'] != null) {
      try {
        extraData = Map<String, dynamic>.from(jsonDecode(json['extraData']));
      } catch (_) {
        extraData = null;
      }
    }
    
    return RecurringNotification(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      screen: json['screen'],
      extraData: extraData,
      interval: _stringToInterval(json['interval']),
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
      nextScheduledDate: DateTime.parse(json['nextScheduledDate']),
    );
  }
  
  // Calculate the next scheduled date based on the interval
  DateTime calculateNextDate(DateTime fromDate) {
    switch (interval) {
      case RecurringInterval.daily:
        return DateTime(fromDate.year, fromDate.month, fromDate.day + 1, 
                        fromDate.hour, fromDate.minute);
      case RecurringInterval.weekly:
        return DateTime(fromDate.year, fromDate.month, fromDate.day + 7, 
                        fromDate.hour, fromDate.minute);
      case RecurringInterval.monthly:
        // Handle month rollover
        int month = fromDate.month + 1;
        int year = fromDate.year;
        if (month > 12) {
          month = 1;
          year += 1;
        }
        return DateTime(year, month, fromDate.day, 
                        fromDate.hour, fromDate.minute);
      case RecurringInterval.quarterly:
        // Add 3 months
        int month = fromDate.month + 3;
        int year = fromDate.year;
        while (month > 12) {
          month -= 12;
          year += 1;
        }
        return DateTime(year, month, fromDate.day, 
                        fromDate.hour, fromDate.minute);
      case RecurringInterval.yearly:
        return DateTime(fromDate.year + 1, fromDate.month, fromDate.day, 
                        fromDate.hour, fromDate.minute);
    }
  }
  
  // Helper to convert string to interval enum
  static RecurringInterval _stringToInterval(String value) {
    switch (value) {
      case 'daily':
        return RecurringInterval.daily;
      case 'weekly':
        return RecurringInterval.weekly;
      case 'quarterly':
        return RecurringInterval.quarterly;
      case 'yearly':
        return RecurringInterval.yearly;
      case 'monthly':
      default:
        return RecurringInterval.monthly;
    }
  }
  
  // Get a human readable interval description
  String get intervalDescription {
    switch (interval) {
      case RecurringInterval.daily:
        return 'Daily';
      case RecurringInterval.weekly:
        return 'Weekly';
      case RecurringInterval.monthly:
        return 'Monthly';
      case RecurringInterval.quarterly:
        return 'Quarterly';
      case RecurringInterval.yearly:
        return 'Yearly';
    }
  }
}