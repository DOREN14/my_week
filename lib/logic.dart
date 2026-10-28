import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
const dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

// '08:30' -> 510. Returns null if the text is not a valid time.
int? parseTime(String raw) {
  final parts = raw.trim().split(':');
  if (parts.length != 2) return null;
  if (parts[0].isEmpty || parts[0].length > 2) return null;
  if (parts[1].length != 2) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null || minutes == null) return null;
  if (hours < 0 || hours > 23) return null;
  if (minutes < 0 || minutes > 59) return null;
  return hours * 60 + minutes;
}

// 510 -> '08:30'
String formatTime(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

// 210 -> '3h 30m'
String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

class Timetable {
  final List<Course> courses = [
    Course(name: 'Math', day: 'Monday', start: 480, end: 600),
    Course(name: 'Physics', day: 'Monday', start: 540, end: 660), // clashes with Math
    Course(name: 'Programming', day: 'Tuesday', start: 600, end: 720),
    Course(name: 'English', day: 'Wednesday', start: 840, end: 930),
    Course(name: 'Networks', day: 'Friday', start: 480, end: 600),
    Course(name: 'Databases', day: 'Friday', start: 600, end: 690),
  ];

  // ---------- Saving ----------

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = courses.map((c) => c.toJson()).toList();
    await prefs.setString('courses', jsonEncode(list));
  }

  // First time: nothing saved, so the sample courses stay.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('courses');
    if (saved == null) return;
    final list = jsonDecode(saved) as List;
    courses.clear();
    for (final x in list) {
      courses.add(Course.fromJson(x as Map<String, dynamic>));
    }
  }

  // ---------- Reading ----------

  // The courses of one day, ALWAYS sorted by start time (a sorted copy).
  List<Course> coursesOn(String day) {
    final list = courses.where((c) => c.day == day).toList();
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  // Two courses clash if EACH starts before the other ends.
  List<Course> clashesWith(Course course) {
    return courses.where((other) {
      if (identical(other, course)) return false;
      if (other.day != course.day) return false;
      return course.start < other.end && other.start < course.end;
    }).toList();
  }

  int dayMinutes(String day) {
    int total = 0;
    for (final c in courses.where((c) => c.day == day)) {
      total += c.end - c.start;
    }
    return total;
  }

  int get weekMinutes {
    int total = 0;
    for (final c in courses) {
      total += c.end - c.start;
    }
    return total;
  }

  // ---------- Rules (null = success, otherwise an error message) ----------

  // All the checks live here, so add and edit use the same rules.
  String? check(String name, String startText, String endText) {
    if (name.trim().isEmpty) return 'Course name cannot be empty';
    final start = parseTime(startText);
    if (start == null) {
      return 'Start time must look like 08:00 (hours 00-23, minutes 00-59)';
    }
    final end = parseTime(endText);
    if (end == null) {
      return 'End time must look like 10:30 (hours 00-23, minutes 00-59)';
    }
    if (end <= start) return 'End time must be after the start time';
    return null;
  }

  String? addCourse(String name, String day, String startText, String endText) {
    final error = check(name, startText, endText);
    if (error != null) return error;
    courses.add(
      Course(
        name: name.trim(),
        day: day,
        start: parseTime(startText)!,
        end: parseTime(endText)!,
      ),
    );
    return null;
  }

  String? updateCourse(
      Course course,
      String name,
      String day,
      String startText,
      String endText,
      ) {
    final error = check(name, startText, endText);
    if (error != null) return error; // nothing changes
    course.name = name.trim();
    course.day = day;
    course.start = parseTime(startText)!;
    course.end = parseTime(endText)!;
    return null;
  }

  void deleteCourse(Course course) {
    courses.remove(course);
  }
}