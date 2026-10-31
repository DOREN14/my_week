import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'logic.dart';
import 'models.dart';
import 'weather.dart';

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

// ---------------- Live weather badge (API, three states) ----------------

class WeatherBadge extends StatefulWidget {
  const WeatherBadge({super.key});

  @override
  State<WeatherBadge> createState() => _WeatherBadgeState();
}

class _WeatherBadgeState extends State<WeatherBadge> {
  Weather? weather;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await fetchWeather();
      if (!mounted) return;
      setState(() {
        weather = result;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Weather unavailable';
      });
    }
  }

  void retry() {
    setState(() {
      loading = true;
      error = null;
    });
    load();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (loading) {
      content = const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Loading the weather...'),
        ],
      );
    } else if (error != null) {
      content = Row(
        children: [
          const Icon(Icons.wifi_off),
          const SizedBox(width: 12),
          Expanded(child: Text(error!)),
          TextButton(onPressed: retry, child: const Text('Retry')),
        ],
      );
    } else {
      final w = weather!;
      content = Row(
        children: [
          Icon(w.code == 0 ? Icons.wb_sunny : Icons.cloud),
          const SizedBox(width: 12),
          Text('Today in Kigali: ${w.temperature.round()}°C, ${describe(w.code)}'),
        ],
      );
    }
    return Card(
      child: Padding(padding: const EdgeInsets.all(12), child: content),
    );
  }
}

// ---------------- Screen 1: Week ----------------

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  // The live list from Firestore: users/{uid}/courses, sorted by start time.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      myCourses().orderBy('start').snapshots();

  int selected = 0; // index of the chosen day

  @override
  void initState() {
    super.initState();
    final today = DateTime.now().weekday; // 1 = Monday ... 7 = Sunday
    if (today <= 5) {
      selected = today - 1;
    }
  }

  void openEditor({Course? course}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseScreen(
          course: course,
          day: days[selected],
        ),
      ),
    ).then((result) {
      // result is the day of the saved course, or null if the user went back
      if (result is String && mounted) {
        setState(() {
          selected = days.indexOf(result);
        });
      }
    });
  }

  void confirmDelete(Course course) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Delete ${course.name}?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await myCourses().doc(course.id).delete();
                } catch (e) {
                  if (!mounted) return;
                  showMessage(context, 'Could not delete: $e');
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = days[selected];
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Week'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openEditor(),
        tooltip: 'Add course',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          // ERROR state (for example, the rules refused)
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load your courses.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          // LOADING state
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final timetable =
              Timetable(snapshot.data!.docs.map(Course.fromDoc).toList());
          final shown = timetable.coursesOn(day);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WeatherBadge(),
                const SizedBox(height: 12),
                Text(
                  'Week total: ${formatDuration(timetable.weekMinutes)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (int i = 0; i < days.length; i++)
                      ChoiceChip(
                        label: Text(dayShort[i]),
                        selected: i == selected,
                        onSelected: (_) {
                          setState(() {
                            selected = i;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$day · ${formatDuration(timetable.dayMinutes(day))}',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Expanded(
                  // EMPTY state
                  child: shown.isEmpty
                      ? Center(child: Text('No classes on $day'))
                      : ListView.builder(
                          itemCount: shown.length,
                          itemBuilder: (context, index) {
                            final course = shown[index];
                            final clashes = timetable.clashesWith(course);
                            final clash = clashes.isNotEmpty;
                            final times =
                                '${formatTime(course.start)} – ${formatTime(course.end)}';
                            return Card(
                              color: clash ? Colors.red.shade100 : null,
                              child: ListTile(
                                isThreeLine: clash,
                                title: Text(course.name),
                                subtitle: Text(
                                  clash
                                      ? '$times\nClashes with ${clashes.map((c) => c.name).join(', ')}'
                                      : times,
                                  style: TextStyle(
                                    color: clash ? Colors.red.shade900 : null,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => confirmDelete(course),
                                ),
                                onTap: () => openEditor(course: course),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------- Screen 2: Add or edit a course ----------------

class CourseScreen extends StatefulWidget {
  const CourseScreen({
    super.key,
    required this.day,
    this.course, // null = adding a new course
  });

  final String day;
  final Course? course;

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  final nameController = TextEditingController();
  final startController = TextEditingController();
  final endController = TextEditingController();
  late String day;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    day = widget.day;
    final course = widget.course;
    if (course != null) {
      nameController.text = course.name;
      startController.text = formatTime(course.start);
      endController.text = formatTime(course.end);
      day = course.day;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    startController.dispose();
    endController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final error = checkCourse(
      nameController.text,
      startController.text,
      endController.text,
    );
    if (error != null) {
      showMessage(context, error);
      return;
    }

    final data = Course(
      name: nameController.text.trim(),
      day: day,
      start: parseTime(startController.text)!,
      end: parseTime(endController.text)!,
    ).toMap();

    setState(() => saving = true);
    try {
      final course = widget.course;
      if (course == null) {
        await myCourses().add({...data, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        await myCourses().doc(course.id).update(data);
      }
      if (!mounted) return;
      Navigator.pop(context, day);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      showMessage(context, 'Could not save: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.course != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit course' : 'Add course')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Course name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (int i = 0; i < days.length; i++)
                  ChoiceChip(
                    label: Text(dayShort[i]),
                    selected: days[i] == day,
                    onSelected: (_) {
                      setState(() {
                        day = days[i];
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startController,
                    decoration: const InputDecoration(
                      labelText: 'Start (08:00)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: endController,
                    decoration: const InputDecoration(
                      labelText: 'End (10:00)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saving ? null : save,
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(editing ? 'Save changes' : 'Add course'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
