import 'package:flutter/material.dart';

class PairingP3Screen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  const PairingP3Screen({super.key, required this.onBack, required this.onNext});

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
          const Text('Step 3 of 5', style: TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 60),
          const Text(
            'SCAN DEVICES',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Searching for available dead-end devices...',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white60),
          ),
          const SizedBox(height: 30),
          const CircularProgressIndicator(
            color: Color(0xff1e90ff),
            strokeWidth: 3,
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
                  icon: const Icon(Icons.search, size: 24),
                  label: const Text('DEVICES FOUND',
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