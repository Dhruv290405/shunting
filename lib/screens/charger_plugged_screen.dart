import 'package:flutter/material.dart';

class ChargerPluggedScreen extends StatelessWidget {
  final int battery;
  final bool plugged;
  final VoidCallback onToggle;
  final VoidCallback onBack;

  const ChargerPluggedScreen({
    super.key,
    required this.battery,
    required this.plugged,
    required this.onToggle,
    required this.onBack,
  });

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
            Icon(
              plugged ? Icons.battery_charging_full : Icons.battery_full,
              color: const Color(0xff38d6ff),
              size: 80,
            ),
            const SizedBox(height: 20),
            Text(
              plugged ? 'CHARGER PLUGGED IN' : 'CHARGER REMOVED',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$battery% CHARGED',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xff38d6ff)),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: onToggle,
                    icon: Icon(plugged ? Icons.battery_full : Icons.battery_charging_full, size: 22),
                    label: Text(plugged ? 'UNPLUG' : 'PLUG IN', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff1e90ff),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 160,
                  height: 50,
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}