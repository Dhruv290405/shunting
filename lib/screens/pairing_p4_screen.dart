import 'package:flutter/material.dart';

class PairingP4Screen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  const PairingP4Screen({super.key, required this.onBack, required this.onNext});

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
          const Text('Step 4 of 5', style: TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 60),
          const Text(
            'SELECT DEVICE',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Choose the dead-end device to pair with.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white60),
          ),
          const SizedBox(height: 30),
          Container(
            width: 400,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xff050a12),
              border: Border.all(color: const Color(0xff1e90ff), width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              children: [
                Icon(Icons.train, color: Color(0xff38d6ff), size: 48),
                SizedBox(height: 12),
                Text('D-01', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('AVAILABLE', style: TextStyle(fontSize: 14, color: Color(0xff22e05a))),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 140,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.undo, size: 22),
                  label: const Text('BACK', style: TextStyle(fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xff1e90ff)),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 160,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.check_circle, size: 24),
                  label: const Text('SELECT',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff1e90ff),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}