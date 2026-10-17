
import 'package:flutter/material.dart';

void main() {
  runApp(const HaftepoolApp());
}

class HaftepoolApp extends StatelessWidget {
  const HaftepoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'هفته‌پول PRIME',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('هفته‌پول PRIME'),
        ),
        body: const Center(
          child: Text('به هفته‌پول PRIME خوش آمدید'),
        ),
      ),
    );
  }
}
