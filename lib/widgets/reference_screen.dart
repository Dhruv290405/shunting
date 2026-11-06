import 'package:flutter/material.dart';

class ReferenceScreen extends StatelessWidget {
  final String asset;
  final VoidCallback? onPrimary;
  final VoidCallback? onBack;
  final VoidCallback? onPagePrevious;
  final VoidCallback? onPageNext;
  final VoidCallback? onVolumeDown;
  final VoidCallback? onVolumeUp;
  final Widget? overlay;

  const ReferenceScreen({
    super.key,
    required this.asset,
    this.onPrimary,
    this.onBack,
    this.onPagePrevious,
    this.onPageNext,
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
        if (onPagePrevious != null)
          Positioned(
            left: 0,
            top: 245,
            width: 82,
            height: 100,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPagePrevious,
              child: const SizedBox.expand(),
            ),
          ),
        if (onPageNext != null)
          Positioned(
            right: 0,
            top: 245,
            width: 82,
            height: 100,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPageNext,
              child: const SizedBox.expand(),
            ),
          ),
        if (onBack != null)
          Positioned(
            left: 48,
            bottom: 0,
            width: 105,
            height: 78,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: const SizedBox.expand(),
            ),
          ),
        if (onPrimary != null)
          Positioned(
            left: 790,
            width: 225,
            bottom: 5,
            height: 75,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPrimary,
              child: const SizedBox.expand(),
            ),
          ),
        if (onVolumeDown != null)
          Positioned(
            left: 300,
            bottom: 5,
            width: 135,
            height: 75,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onVolumeDown,
              child: const SizedBox.expand(),
            ),
          ),
        if (onVolumeUp != null)
          Positioned(
            left: 590,
            bottom: 5,
            width: 135,
            height: 75,
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
