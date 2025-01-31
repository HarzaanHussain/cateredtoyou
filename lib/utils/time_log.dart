import 'package:flutter/foundation.dart';

/// The `TimeLog` class is a utility for tracking and logging time intervals
/// in a Flutter application. It provides a simple way to measure the time
/// elapsed between different points in your code by adding marks with optional
/// names. Each mark logs the duration since the previous mark.
///
/// Example usage:
/// ```dart
/// final timeLog = TimeLog();
/// timeLog.mark("Start processing");
/// // Do some processing...
/// timeLog.mark("Processing complete");
/// timeLog.printLog();
/// ```
/// This outputs:
/// ```
/// TimeLog started
/// Start processing: +XXms
/// Processing complete: +YYms
/// --- TimeLog Summary ---
/// Start processing: +XXms
/// Processing complete: +YYms
/// -----------------------
/// ```
class TimeLog {
  final List<_LogEntry> _logEntries = []; // Stores the timestamps and names

  /// Initializes a new `TimeLog` and logs the start time.
  /// The constructor records the time when the log starts and adds a "TimeLog started" entry.
  TimeLog() {
    _logEntries.add(_LogEntry(timestamp: DateTime.now(), name: "TimeLog started"));
    debugPrint("TimeLog started");
  }

  /// Records a timestamp with an optional [name].
  ///
  /// If no [name] is provided, the mark is automatically numbered based
  /// on its position in the log.
  ///
  /// Example:
  /// ```dart
  /// timeLog.mark("Checkpoint 1");
  /// ```
  void mark([String? name]) {
    final now = DateTime.now();
    // Get the previous timestamp from the last entry or use the current time
    // if there are no previous entries
    final previousTimestamp = _logEntries.isNotEmpty ? _logEntries.last.timestamp : now;
    // Calculate the duration since the previous mark
    final durationSinceLast = now.difference(previousTimestamp);

    // Assign a name to the mark, defaulting to "Mark X" if no name is provided
    final entryName = name ?? "Mark ${_logEntries.length}";
    // Add the new log entry with the current timestamp and name
    _logEntries.add(_LogEntry(timestamp: now, name: entryName));

    // Print the log entry and the time difference in milliseconds
    debugPrint(
      name != null
          ? "$entryName: +${durationSinceLast.inMilliseconds}ms"
          : "Mark ${_logEntries.length - 1}: +${durationSinceLast.inMilliseconds}ms",
    );
  }

  /// Prints a summary of all recorded marks and their durations.
  ///
  /// If fewer than two marks exist, no meaningful summary is displayed.
  void printLog() {
    // Check if there are enough log entries to generate a summary
    if (_logEntries.length < 2) {
      debugPrint("No meaningful log entries to display.");
      return;
    }

    // Print the log summary header
    debugPrint("\n--- TimeLog Summary ---");
    // Iterate through the log entries starting from the second entry
    for (var i = 1; i < _logEntries.length; i++) {
      final previous = _logEntries[i - 1];
      final current = _logEntries[i];
      // Calculate the duration between the previous and current entry
      final duration = current.timestamp.difference(previous.timestamp);
      // Print the name of the current entry and the duration since the
      // previous entry
      debugPrint("${current.name}: +${duration.inMilliseconds}ms");
    }
    // Print the log summary footer
    debugPrint("-----------------------\n");
  }
}

/// Internal class representing a single log entry.
class _LogEntry {
  final DateTime timestamp; // The timestamp of the log entry
  final String name; // The name or description of the log entry

  // Constructor to initialize a log entry with a given timestamp and name
  _LogEntry({required this.timestamp, required this.name});
}
