import 'package:suggest_it/services/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:suggest_it/navigation/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SuggestItApp());
}

class SuggestItApp extends StatelessWidget {
  const SuggestItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SuggestIt',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainNavigation(),
    );
  }
}