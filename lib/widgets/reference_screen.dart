import 'package:flutter/material.dart';

class ReferenceScreen extends StatelessWidget {
  final String asset;
  final VoidCallback? onPrimary;
  final VoidCallback? onBack;
  final Widget? overlay;

  const ReferenceScreen({
    super.key,
    required this.asset,
    this.onPrimary,
    this.onBack,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(asset, fit: BoxFit.fill),
        if (onBack != null)
          Positioned(
            left: 0,
            bottom: 0,
            width: 180,
            height: 110,
            child: GestureDetector(onTap: onBack),
          ),
        if (onPrimary != null)
          Positioned(
            left: 80,
            right: 80,
            bottom: 25,
            height: 120,
            child: GestureDetector(onTap: onPrimary),
          ),
        if (overlay != null) overlay!,
      ],
    );
  }
}
