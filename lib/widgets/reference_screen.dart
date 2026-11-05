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
            left: 20,
            bottom: 0,
            width: 180,
            height: 130,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: const SizedBox.expand(),
            ),
          ),
        if (onPrimary != null)
          Positioned(
            left: 80,
            right: 80,
            bottom: 0,
            height: 160,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPrimary,
              child: const SizedBox.expand(),
            ),
          ),
        if (overlay != null) overlay!,
      ],
    );
  }
}
