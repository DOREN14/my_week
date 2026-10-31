import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'auth_gate.dart';

// Used only when the app runs in Chrome (web).
// On Android, Firebase reads google-services.json instead.
const webFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyBu5PCrFk_s3NGg_mnl4HZg-RMA0txv1BQ',
  authDomain: 'my-week-1ee78.firebaseapp.com',
  projectId: 'my-week-1ee78',
  storageBucket: 'my-week-1ee78.firebasestorage.app',
  messagingSenderId: '404501960985',
  appId: '1:404501960985:web:0e339f22b431bc33474d88',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(options: webFirebaseOptions);
  } else {
    await Firebase.initializeApp();
  }
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
      home: const AuthGate(),
    );
  }
}
