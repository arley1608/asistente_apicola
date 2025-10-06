import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/record_screen.dart';
import 'screens/recordings_screen.dart';

class Routes {
  static const home = '/';
  static const record = '/record';
  static const recordings = '/recordings';
}

final Map<String, WidgetBuilder> appRoutes = {
  Routes.home: (_) => const HomeScreen(),
  Routes.record: (_) => const RecordScreen(),
  Routes.recordings: (_) => const RecordingsScreen(),
};
