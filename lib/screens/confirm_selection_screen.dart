import 'package:flutter/material.dart';
import '../models/device.dart';

class ConfirmSelectionScreen extends StatelessWidget {
  final ShuntingDevice? device;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmSelectionScreen({
    super.key,
    this.device,
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
          border: Border.all(color: const Color(0xff1e90ff), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.train, color: Color(0xff38d6ff), size: 80),
            const SizedBox(height: 20),
            Text(
              'CONFIRM DEVICE',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              device != null ? device!.name : '--',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xff38d6ff)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Confirm this device for shunting?',
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
                    icon: const Icon(Icons.check, size: 22),
                    label: const Text('CONFIRM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      ),
    );
  }
}