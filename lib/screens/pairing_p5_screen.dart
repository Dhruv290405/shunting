import 'package:flutter/material.dart';

class PairingP5Screen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onFinish;
  const PairingP5Screen({super.key, required this.onBack, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'PAIRING',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xff38d6ff)),
          ),
          const SizedBox(height: 12),
          const Text('Step 5 of 5', style: TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 60),
          const Text(
            'PAIRING COMPLETE',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xff22e05a)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Device D-01 successfully paired with tablet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white60),
          ),
          const SizedBox(height: 50),
          const Icon(Icons.device_hub, color: Color(0xff22e05a), size: 64),
          const SizedBox(height: 40),
          SizedBox(
            width: 260,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onFinish,
              icon: const Icon(Icons.done, size: 26),
              label: const Text('FINISH PAIRING',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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