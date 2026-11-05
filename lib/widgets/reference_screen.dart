import 'package:flutter/material.dart';

class ReferenceScreen extends StatelessWidget {
  final String asset;
  final VoidCallback? onPrimary;
  final VoidCallback? onBack;
  final VoidCallback? onVolumeDown;
  final VoidCallback? onVolumeUp;
  final Widget? overlay;

  const ReferenceScreen({
    super.key,
    required this.asset,
    this.onPrimary,
    this.onBack,
    this.onVolumeDown,
    this.onVolumeUp,
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
            left: 45,
            bottom: 0,
            width: 120,
            height: 90,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: const SizedBox.expand(),
            ),
          ),
        if (onPrimary != null)
          Positioned(
            left: 180,
            right: 20,
            bottom: 0,
            height: 100,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPrimary,
              child: const SizedBox.expand(),
            ),
          ),
        if (onVolumeDown != null)
          Positioned(
            left: 285,
            bottom: 0,
            width: 155,
            height: 90,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onVolumeDown,
              child: const SizedBox.expand(),
            ),
          ),
        if (onVolumeUp != null)
          Positioned(
            left: 575,
            bottom: 0,
            width: 155,
            height: 90,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onVolumeUp,
              child: const SizedBox.expand(),
            ),
          ),
        if (overlay != null) overlay!,
      ],
    );
  }
}
