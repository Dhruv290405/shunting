import 'package:flutter/material.dart';

class PairingP2Screen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  const PairingP2Screen({super.key, required this.onBack, required this.onNext});

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
          const Text('Step 2 of 5', style: TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 60),
          const Text(
            'ENABLE BLUETOOTH',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Turn on Bluetooth on the tablet to discover '
            'nearby shunting devices.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white60),
          ),
          const SizedBox(height: 60),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 140,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, size: 22),
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
                  icon: const Icon(Icons.bluetooth, size: 24),
                  label: const Text('ENABLE BLUETOOTH',
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