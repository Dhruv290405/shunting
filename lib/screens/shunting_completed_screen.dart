import 'package:flutter/material.dart';

class ShuntingCompletedScreen extends StatelessWidget {
  final VoidCallback? onBack;
  const ShuntingCompletedScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Color(0xff22e05a), size: 100),
          const SizedBox(height: 24),
          const Text(
            'SHUNTING COMPLETED',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xff22e05a),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Dead-end device operation finished successfully.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.white60),
          ),
          const SizedBox(height: 50),
          if (onBack != null)
            SizedBox(
              width: 240,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.done, size: 24),
                label: const Text('RETURN TO DEVICES',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff1e90ff),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}