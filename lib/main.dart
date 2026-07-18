import 'package:flutter/material.dart';
import 'package:p2p_chat/screens/setup_screen.dart';

void main() => runApp(const P2PChatApp());

class P2PChatApp extends StatelessWidget {
  const P2PChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P2P 聊天',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SetupScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
