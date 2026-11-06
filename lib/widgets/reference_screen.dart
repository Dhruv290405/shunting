import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReferenceScreen extends StatelessWidget {
  final String asset;
  final VoidCallback? onPrimary;
  final VoidCallback? onBack;
  final VoidCallback? onPagePrevious;
  final VoidCallback? onPageNext;
  final VoidCallback? onRefresh;
  final VoidCallback? onVolumeDown;
  final VoidCallback? onVolumeUp;
  final Widget? overlay;
  final bool hidePageNumber;

  const ReferenceScreen({
    super.key,
    required this.asset,
    this.onPrimary,
    this.onBack,
    this.onPagePrevious,
    this.onPageNext,
    this.onRefresh,
    this.onVolumeDown,
    this.onVolumeUp,
    this.overlay,
    this.hidePageNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder<Uint8List>(
          future: _loadAsset(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Unable to render reference asset $asset: '
                  '${snapshot.error}');
              return const ColoredBox(color: Color(0xff02060c));
            }
            if (!snapshot.hasData) {
              return const ColoredBox(color: Color(0xff02060c));
            }
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.fill,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Unable to decode reference asset $asset: $error');
                return const ColoredBox(color: Color(0xff02060c));
              },
            );
          },
        ),
        if (hidePageNumber)
          const Positioned(
            right: 0,
            bottom: 0,
            width: 140,
            height: 48,
            child: ColoredBox(color: Color(0xff02060c)),
          ),
        if (onRefresh != null)
          Positioned(
            left: 675,
            top: 105,
            width: 145,
            height: 55,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRefresh,
              child: const SizedBox.expand(),
            ),
          ),
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

  Future<Uint8List> _loadAsset() async {
    final data = await rootBundle.load(asset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
