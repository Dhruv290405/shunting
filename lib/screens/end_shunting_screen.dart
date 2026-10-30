import 'package:flutter/material.dart';

class EndShuntingScreen extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const EndShuntingScreen({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xff050a12),
          border: Border.all(color: Colors.orange, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stop, color: Colors.orange, size: 80),
            const SizedBox(height: 20),
            const Text(
              'END SHUNTING',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Are you sure you want to end the shunting operation?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white60),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel, size: 22),
                    label: const Text('CANCEL', style: TextStyle(fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xff1e90ff)),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 160,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.stop, size: 22),
                    label: const Text('END', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
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