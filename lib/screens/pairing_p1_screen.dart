import 'package:flutter/material.dart';

class PairingP1Screen extends StatelessWidget {
  final VoidCallback onNext;
  const PairingP1Screen({super.key, required this.onNext});

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
          const Text(
            'Step 1 of 5',
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
          const SizedBox(height: 60),
          const Text(
            'POWER ON DEVICE',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ensure the dead-end device is powered on '
            'and within range before proceeding.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white60),
          ),
          const SizedBox(height: 60),
          SizedBox(
            width: 320,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.power_settings_new, size: 26),
              label: const Text('DEVICE POWERED ON',
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