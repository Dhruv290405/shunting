import 'package:flutter/material.dart';
import '../models/device.dart';

class DeviceCard extends StatelessWidget {
  final ShuntingDevice device;
  final VoidCallback? onTap;

  const DeviceCard({super.key, required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = device.statusColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.8)),
          color: const Color(0xff050a12),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 8, spreadRadius: 1),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.train, color: color, size: 34),
            const SizedBox(height: 10),
            Text(
              device.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              device.online ? 'ONLINE • ${device.battery}%' : 'OFFLINE',
              style: const TextStyle(fontSize: 13, color: Color(0xff94a3b8)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              device.status,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}