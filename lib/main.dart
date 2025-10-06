import 'package:flutter/material.dart';
import 'routes.dart';

void main() => runApp(const BeeApp());

class BeeApp extends StatelessWidget {
  const BeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asistente Apícola',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.amber,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.amber,
        brightness: Brightness.dark,
      ),
      initialRoute: Routes.home,
      routes: appRoutes,
    );
  }
}
