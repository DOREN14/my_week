import 'package:flutter/material.dart';

import 'logic.dart';
import 'models.dart';
import 'weather.dart';

void main() {
  runApp(const MyWeekApp());
}

class MyWeekApp extends StatelessWidget {
  const MyWeekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Week',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const WeekScreen(),
    );
  }
}

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
  final timetable = Timetable(); // the one shared set of data
  bool ready = false; // false while the saved data loads
  int selected = 0; // index of the chosen day

  @override
  void initState() {
    super.initState();
    final today = DateTime.now().weekday; // 1 = Monday ... 7 = Sunday
    if (today <= 5) {
      selected = today - 1;
    }
    loadSaved();
  }

  Future<void> loadSaved() async {
    await timetable.load();
    if (!mounted) return;
    setState(() {
      ready = true;
    });
  }

  void openEditor({Course? course}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseScreen(
          timetable: timetable,
          course: course,
          day: days[selected],
        ),
      ),
    ).then((result) {
      // result is the day of the saved course, or null if the user went back
      timetable.save();
      setState(() {
        if (result is String) {
          selected = days.indexOf(result);
        }
      });
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
              onPressed: () {
                timetable.deleteCourse(course);
                timetable.save();
                setState(() {});
                Navigator.pop(dialogContext);
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
    final shown = timetable.coursesOn(day);
    return Scaffold(
      appBar: AppBar(title: const Text('My Week')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openEditor(),
        tooltip: 'Add course',
        child: const Icon(Icons.add),
      ),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
      ),
    );
  }
}

// ---------------- Screen 2: Add or edit a course ----------------

class CourseScreen extends StatefulWidget {
  const CourseScreen({
    super.key,
    required this.timetable,
    required this.day,
    this.course, // null = adding a new course
  });

  final Timetable timetable;
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

  void save() {
    final course = widget.course;
    final String? error;
    if (course == null) {
      error = widget.timetable.addCourse(
        nameController.text,
        day,
        startController.text,
        endController.text,
      );
    } else {
      error = widget.timetable.updateCourse(
        course,
        nameController.text,
        day,
        startController.text,
        endController.text,
      );
    }
    if (error != null) {
      showMessage(context, error);
      return;
    }
    Navigator.pop(context, day);
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
                onPressed: save,
                child: Text(editing ? 'Save changes' : 'Add course'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}