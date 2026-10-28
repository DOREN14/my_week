class Course {
  String name; // these change when a course is edited, so NOT final
  String day;
  int start; // minutes since midnight, 08:00 = 480
  int end;

  Course({
    required this.name,
    required this.day,
    required this.start,
    required this.end,
  });

  Map<String, dynamic> toJson() {
    return {'name': name, 'day': day, 'start': start, 'end': end};
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      name: json['name'] as String,
      day: json['day'] as String,
      start: json['start'] as int,
      end: json['end'] as int,
    );
  }
}