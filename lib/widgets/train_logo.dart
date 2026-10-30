import 'package:flutter/material.dart';

/// Train logo widget — renders the logo from your UI reference image.
/// Falls back to a stylized train icon if the asset is unavailable.
class TrainLogo extends StatelessWidget {
  final double size;
  const TrainLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/00_Startup.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.train,
        size: size,
        color: const Color(0xff38d6ff),
      ),
    );
  }
}