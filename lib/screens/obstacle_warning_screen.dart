import 'package:flutter/material.dart';
import '../models/device.dart';

class ObstacleWarningScreen extends StatelessWidget {
  final ShuntingDevice? device;
  final VoidCallback onClear;

  const ObstacleWarningScreen({super.key, this.device, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xff050a12),
          border: Border.all(color: Colors.red, width: 3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber, color: Colors.red, size: 100),
            const SizedBox(height: 20),
            const Text(
              'WARNING',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'HUMAN / OBSTACLE DETECTED',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (device != null) ...[
              const SizedBox(height: 12),
              Text(
                'Device: ${device!.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white60),
              ),
            ],
            const SizedBox(height: 30),
            SizedBox(
              width: 200,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.check, size: 24),
                label: const Text('CLEAR WARNING',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}