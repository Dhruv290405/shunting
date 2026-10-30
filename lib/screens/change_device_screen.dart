import 'package:flutter/material.dart';
import '../models/device.dart';

class ChangeDeviceScreen extends StatelessWidget {
  final List<ShuntingDevice> devices;
  final ShuntingDevice? current;
  final ValueChanged<ShuntingDevice> onSelect;
  final VoidCallback onBack;

  const ChangeDeviceScreen({
    super.key,
    required this.devices,
    required this.current,
    required this.onSelect,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final available = devices.where((d) => d.online && !d.inUse).toList();
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 30),
          const Text(
            'CHANGE DEVICE',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xff38d6ff)),
          ),
          const SizedBox(height: 10),
          const Text(
            'Select a new dead-end device',
            style: TextStyle(fontSize: 16, color: Colors.white60),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: GridView.builder(
              itemCount: available.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 2.6,
              ),
              itemBuilder: (context, index) {
                final d = available[index];
                final isCurrent = current != null && d.name == current!.name;
                return InkWell(
                  onTap: () => onSelect(d),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isCurrent ? const Color(0xff38d6ff) : d.statusColor.withValues(alpha: 0.8),
                        width: isCurrent ? 2 : 1,
                      ),
                      color: const Color(0xff050a12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.train, color: d.statusColor, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          d.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          d.status,
                          style: TextStyle(fontSize: 12, color: d.statusColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 22),
              label: const Text('BACK',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff1e90ff),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}