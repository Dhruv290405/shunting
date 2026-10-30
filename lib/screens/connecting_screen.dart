import 'package:flutter/material.dart';

class ConnectingScreen extends StatelessWidget {
  const ConnectingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xff050a12),
          border: Border.all(color: const Color(0xff1e90ff), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              color: Color(0xff38d6ff),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            const Text(
              'CONNECTING...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xff38d6ff),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Establishing connection with device...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white60),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}