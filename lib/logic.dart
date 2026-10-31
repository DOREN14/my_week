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

// All the checks live here, so add and edit use the same rules.
// null = success, otherwise an error message.
String? checkCourse(String name, String startText, String endText) {
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

// The data now lives in Firestore. A Timetable is built from the list that
// arrives, and only COMPUTES things (nothing is saved here).
class Timetable {
  Timetable(this.courses);

  final List<Course> courses;

  // The courses of one day, ALWAYS sorted by start time (a sorted copy).
  List<Course> coursesOn(String day) {
    final list = courses.where((c) => c.day == day).toList();
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  // Two courses clash if EACH starts before the other ends.
  List<Course> clashesWith(Course course) {
    return courses.where((other) {
      if (other.id == course.id) return false;
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
}
