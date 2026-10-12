import 'package:flutter/material.dart';

import 'config.dart';
import 'web_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IqTrainingApp());
}

class IqTrainingApp extends StatelessWidget {
  const IqTrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppConfig.brandColor),
      ),
      home: const WebShell(),
    );
  }
}
