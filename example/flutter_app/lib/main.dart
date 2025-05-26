import 'package:flutter/material.dart';
import 'package:vutelemetry/flutter_sdk.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize OpenTelemetry SDK
  VuTelemetry.initialise(
    params: InitialisationParams(
      logsIngestUrl: 'http://10.0.2.2:4318/v1/logs',
      tracesIngestUrl: 'http://10.0.2.2:4318/v1/traces',
      appName: 'Example Flutter App',
      appType: 'Flutter',
      enableSlowFrameTracking: true,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Home Page')));
  }
}
