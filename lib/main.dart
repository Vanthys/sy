import 'package:flutter/material.dart';
import 'data/database.dart';
import 'screens/tracker_list_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppDatabase _database;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
  }

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }

    @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Streak Tracker',
      theme: lightTheme,          
      darkTheme: darkTheme,       
      themeMode: ThemeMode.system,
      home: TrackerListScreen(database: _database),
    );
  }
}
