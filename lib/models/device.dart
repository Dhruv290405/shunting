import 'package:flutter/material.dart';

/// Dead-end device model matching the backend.
class ShuntingDevice {
  final int number;
  final String name;
  final bool online;
  bool inUse;
  final int battery;

  ShuntingDevice({
    required this.number,
    required this.name,
    required this.online,
    required this.inUse,
    required this.battery,
  });

  factory ShuntingDevice.fromJson(Map<String, dynamic> json) => ShuntingDevice(
        number: json['number'] as int,
        name: json['name'] as String,
        online: json['online'] as bool,
        inUse: json['in_use'] as bool,
        battery: json['battery'] as int,
      );

  String get status {
    if (!online) return 'OFFLINE';
    if (inUse) return 'IN USE';
    return 'AVAILABLE';
  }

  Color get statusColor {
    if (!online) return const Color(0xff64748b);
    if (inUse) return const Color(0xfff59e0b);
    return const Color(0xff22e05a);
  }
}