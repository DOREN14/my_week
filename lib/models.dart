import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Course {
  String id; // the Firestore document id ('' for a new course)
  String name; // these change when a course is edited, so NOT final
  String day;
  int start; // minutes since midnight, 08:00 = 480
  int end;

  Course({
    this.id = '',
    required this.name,
    required this.day,
    required this.start,
    required this.end,
  });

  Map<String, dynamic> toMap() {
    return {'name': name, 'day': day, 'start': start, 'end': end};
  }

  factory Course.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Course(
      id: doc.id,
      name: data['name'] as String,
      day: data['day'] as String,
      start: (data['start'] as num).toInt(),
      end: (data['end'] as num).toInt(),
    );
  }
}

// The signed-in user's courses: users/{uid}/courses
CollectionReference<Map<String, dynamic>> myCourses() {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('courses');
}
