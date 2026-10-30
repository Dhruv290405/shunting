import 'package:flutter/material.dart';
import '../models/device.dart';

class TelemetryScreen extends StatelessWidget {
  final ShuntingDevice? device;
  final double distance;
  final int battery;
  final bool network;
  final VoidCallback onEnd;
  final VoidCallback onObstacle;
  final VoidCallback onChangeDevice;
  final VoidCallback onCharger;

  const TelemetryScreen({
    super.key,
    this.device,
    required this.distance,
    required this.battery,
    required this.network,
    required this.onEnd,
    required this.onObstacle,
    required this.onChangeDevice,
    required this.onCharger,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.train, color: Color(0xff38d6ff), size: 32),
              const SizedBox(width: 12),
              Text(
                device?.name ?? '--',
                style: const TextStyle(
                  color: Color(0xff38d6ff),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xff050a12),
              border: Border.all(color: const Color(0xff22e05a), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              device != null ? device!.status : 'DISCONNECTED',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: device != null && device!.inUse ? const Color(0xff22e05a) : Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 50),
          Text(
            distance.toStringAsFixed(1),
            style: const TextStyle(fontSize: 96, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Text('meter', style: TextStyle(fontSize: 20, color: Colors.white60)),
          const SizedBox(height: 40),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 180,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onObstacle,
                  icon: const Icon(Icons.warning, size: 24),
                  label: const Text('OBSTACLE',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 180,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onChangeDevice,
                  icon: const Icon(Icons.sync, size: 24),
                  label: const Text('CHANGE DEVICE',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff1e90ff),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 180,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onCharger,
                  icon: Icon(
                    Icons.battery_charging_full,
                    size: 24,
                    color: Colors.white,
                  ),
                  label: const Text('CHARGER',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff1e90ff),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 180,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onEnd,
                  icon: const Icon(Icons.stop, size: 24),
                  label: const Text('END SHUNTING',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    );
  }
}