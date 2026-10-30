import 'package:flutter/material.dart';
import '../widgets/train_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TrainLogo(size: 160),
          SizedBox(height: 24),
          Text(
            'INDIAN RAILWAYS',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xff38d6ff),
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Shunting Tablet Console',
            style: TextStyle(fontSize: 20, color: Colors.white70),
          ),
          SizedBox(height: 40),
          CircularProgressIndicator(
            color: Color(0xff1e90ff),
            strokeWidth: 3,
          ),
        ],
      ),
    );
  }
}