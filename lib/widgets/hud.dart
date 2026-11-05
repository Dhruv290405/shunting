import 'package:flutter/material.dart';

class HUD extends StatelessWidget {
  final int battery;
  final String signal;
  final bool network;
  final bool deviceOk;
  final int volume;
  final VoidCallback onVolumeDown;
  final VoidCallback onVolumeUp;

  const HUD({
    super.key,
    required this.battery,
    required this.signal,
    required this.network,
    required this.deviceOk,
    required this.volume,
    required this.onVolumeDown,
    required this.onVolumeUp,
  });

  Widget _item(IconData icon, String label) => Expanded(
        child: Row(
          children: [
            Icon(icon, color: const Color(0xff38d6ff), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 15, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 14,
      left: 60,
      right: 60,
      child: Row(
        children: [
          _item(Icons.battery_full, '$battery%'),
          _item(Icons.signal_cellular_alt, signal),
          _item(Icons.favorite, deviceOk ? 'DEVICE OK' : 'DEVICE ERR'),
          _item(Icons.wifi, network ? 'CONNECTED' : 'OFFLINE'),
          const Spacer(),
          IconButton(
            onPressed: onVolumeDown,
            icon: const Icon(Icons.volume_down, color: Color(0xff38d6ff)),
          ),
          Text('VOL $volume',
              style: const TextStyle(fontSize: 16, color: Colors.white)),
          IconButton(
            onPressed: onVolumeUp,
            icon: const Icon(Icons.volume_up, color: Color(0xff38d6ff)),
          ),
        ],
      ),
    );
  }
}