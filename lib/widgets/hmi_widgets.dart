import 'package:flutter/material.dart';
import '../i18n/strings.dart';
import '../theme/hmi_colors.dart';

/// Rounded button matching the HMI prototype.
class HmiBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final double height;
  final double borderRadius;
  final Color background;
  final Color textColor;
  final double fontSize;
  final FontWeight fontWeight;
  final double? width;

  const HmiBtn({
    super.key,
    required this.label,
    this.onTap,
    this.leading,
    this.trailing,
    this.height = 76,
    this.borderRadius = 22,
    this.background = Hmi.card,
    this.textColor = Hmi.ink,
    this.fontSize = 24,
    this.fontWeight = FontWeight.w600,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        decoration: BoxDecoration(
          color: onTap == null ? background.withValues(alpha: 0.38) : background,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: onTap == null
              ? null
              : [
                  BoxShadow(
                    color: background == Hmi.accent
                        ? const Color(0x4D0B7A61)
                        : background == Hmi.red
                            ? const Color(0x47C62828)
                            : const Color(0x170F1F1B),
                    blurRadius: background == Hmi.card ? 10 : 14,
                    offset: Offset(0, background == Hmi.card ? 2 : 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      onTap == null ? textColor.withValues(alpha: 0.38) : textColor,
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}

// ─── Status bar ──────────────────────────────────────────────────────────────

class HmiStatusBar extends StatelessWidget {
  final String? deviceName;
  final String linkMode;
  final int healthBars;
  final String healthText;
  final int batteryPct;
  final bool isMuted;
  final bool isCharging;
  final AppLang lang;
  final VoidCallback? onSettings;

  const HmiStatusBar({
    super.key,
    this.deviceName,
    this.linkMode = 'GSM',
    this.healthBars = 0,
    this.healthText = '',
    required this.batteryPct,
    this.isMuted = false,
    this.isCharging = false,
    this.lang = AppLang.en,
    this.onSettings,
  });

  static const _ts = TextStyle(
    color: Hmi.ink,
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    final hasDevice = deviceName != null;
    return Positioned(
      left: 32,
      right: 32,
      top: 14,
      height: 48,
      child: DefaultTextStyle(
        style: _ts,
        child: Row(
          children: [
            const Icon(Icons.train, size: 24, color: Hmi.ink),
            const SizedBox(width: 9),
            Text(hasDevice ? deviceName! : Strings.t(lang, 'no_device')),
            if (hasDevice) ...[
              _sep(),
              const Icon(Icons.cell_tower, size: 24, color: Hmi.ink),
              const SizedBox(width: 9),
              Text(linkMode),
              _sep(),
              _SignalBars(level: healthBars),
              const SizedBox(width: 9),
              Text(healthText),
            ],
            const Spacer(),
            if (isMuted) ...[
              const Icon(Icons.volume_off, size: 24, color: Hmi.red),
              const SizedBox(width: 6),
              Text(Strings.t(lang, 'muted'),
                  style: const TextStyle(color: Hmi.red)),
              const SizedBox(width: 8),
              _sep(),
              const SizedBox(width: 10),
            ],
            Text('$batteryPct%'),
            const SizedBox(width: 8),
            _BatteryIcon(level: batteryPct, charging: isCharging),
            if (onSettings != null) ...[
              const SizedBox(width: 14),
              GestureDetector(
                onTap: onSettings,
                child: const Icon(Icons.settings, size: 24, color: Hmi.ink),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _sep() => Container(
        width: 2,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: 18),
        color: Hmi.hair,
      );
}

class _SignalBars extends StatelessWidget {
  final int level;
  const _SignalBars({required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        return Container(
          width: 6,
          height: [8.0, 15.0, 22.0][i],
          margin: EdgeInsets.only(left: i > 0 ? 3 : 0),
          decoration: BoxDecoration(
            color: i < level ? Hmi.ink : Hmi.hair,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _BatteryIcon extends StatelessWidget {
  final int level;
  final bool charging;
  const _BatteryIcon({required this.level, this.charging = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(painter: _BatteryPainter(level)),
          if (charging)
            const Icon(Icons.bolt,
                size: 15, color: Colors.white, shadows: [
              Shadow(color: Hmi.ink, blurRadius: 2),
            ]),
        ],
      ),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  final int level;
  _BatteryPainter(this.level);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Hmi.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final bodyW = size.width - 6;
    canvas.drawRRect(
      RRect.fromLTRBR(1, 0, bodyW, size.height, const Radius.circular(5)),
      stroke,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
          bodyW, 4, bodyW + 4, size.height - 4, const Radius.circular(2)),
      Paint()..color = Hmi.ink,
    );
    final fillW = (bodyW - 4) * level.clamp(0, 100) / 100;
    if (fillW > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(
            3, 2, 3 + fillW, size.height - 2, const Radius.circular(2)),
        Paint()..color = level < 20 ? Hmi.red : Hmi.ink,
      );
    }
  }

  @override
  bool shouldRepaint(_BatteryPainter old) => old.level != level;
}

// ─── Volume control pill ─────────────────────────────────────────────────────

class HmiVolumeControl extends StatelessWidget {
  final int volume;
  final bool muted;
  final VoidCallback onMute;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final bool onDark;
  final AppLang lang;

  const HmiVolumeControl({
    super.key,
    required this.volume,
    required this.muted,
    required this.onMute,
    required this.onDown,
    required this.onUp,
    this.onDark = false,
    this.lang = AppLang.en,
  });

  @override
  Widget build(BuildContext context) {
    final bg = onDark ? Colors.white.withValues(alpha: 0.2) : Hmi.off;
    final btnBg = onDark ? Colors.white.withValues(alpha: 0.15) : Hmi.card;
    final fg = onDark ? Colors.white : Hmi.ink;
    final barBg = onDark ? Colors.white.withValues(alpha: 0.35) : Hmi.hair;
    final barFill = onDark ? Colors.white : Hmi.accent;

    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _vBtn(
            child: Icon(
              muted ? Icons.volume_off : Icons.volume_up,
              size: 32,
              color: muted ? Colors.white : fg,
            ),
            onTap: onMute,
            bg: muted ? fg : btnBg,
          ),
          const SizedBox(width: 6),
          _vBtn(
            child: Icon(Icons.remove, size: 32, color: fg),
            onTap: onDown,
            bg: btnBg,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 156,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  muted
                      ? Strings.t(lang, 'muted')
                      : Strings.t(lang, 'volume_pct', {'n': '$volume'}),
                  style: TextStyle(
                      color: fg, fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 7),
                Container(
                  width: 120,
                  height: 8,
                  decoration: BoxDecoration(
                    color: barBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: muted ? 0 : volume / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: barFill,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _vBtn(
            child: Icon(Icons.add, size: 32, color: fg),
            onTap: onUp,
            bg: btnBg,
          ),
        ],
      ),
    );
  }

  Widget _vBtn(
      {required Widget child,
      required VoidCallback onTap,
      required Color bg}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        height: 72,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ─── Train track visualisation ───────────────────────────────────────────────

class HmiTrack extends StatelessWidget {
  final double fraction;
  final bool outOfRange;

  const HmiTrack({super.key, required this.fraction, required this.outOfRange});

  static const double _w = 888;
  static const double _range = 792;

  @override
  Widget build(BuildContext context) {
    final x = _range * fraction.clamp(0.0, 1.0);
    final clr = outOfRange ? Hmi.muted : Hmi.accent;
    final stopClr = outOfRange ? Hmi.muted : Hmi.ink;
    return SizedBox(
      width: _w,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 4,
            child: Container(
              width: 12,
              height: 48,
              decoration: BoxDecoration(
                color: stopClr,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 0,
            top: 22,
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: Hmi.off,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          if (x > 0)
            Positioned(
              left: 12,
              top: 22,
              child: Container(
                width: (x + 24).clamp(0, _w - 12),
                height: 12,
                decoration: BoxDecoration(
                  color: clr,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          Positioned(
            left: 12 + x,
            top: 4,
            child: Container(
              width: 84,
              height: 48,
              decoration: BoxDecoration(
                color: clr,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Hmi.ink.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Center(
                  child: Icon(Icons.train, size: 28, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class HmiTicks extends StatelessWidget {
  final int fullScale;
  final AppLang lang;

  const HmiTicks({super.key, required this.fullScale, this.lang = AppLang.en});

  static const _vals = {
    45: [0, 15, 30, 45],
    100: [0, 25, 50, 75, 100],
    180: [0, 45, 90, 135, 180],
  };

  @override
  Widget build(BuildContext context) {
    final ticks = _vals[fullScale] ?? _vals[100]!;
    final unit = Strings.t(lang, 'unit_m');
    return SizedBox(
      width: 888,
      height: 24,
      child: Stack(
        children: [
          for (int i = 0; i < ticks.length; i++)
            Positioned(
              left: 12.0 + 792 * ticks[i] / fullScale,
              top: 0,
              child: Text(
                i == 0
                    ? Strings.t(lang, 'buffer_stop')
                    : (i == ticks.length - 1
                        ? '${ticks[i]} $unit'
                        : '${ticks[i]}'),
                style: const TextStyle(
                    color: Hmi.muted,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Device slot in pairing grid ─────────────────────────────────────────────

class HmiSlot extends StatelessWidget {
  final String name;
  final bool online;
  final VoidCallback? onTap;
  final AppLang lang;

  const HmiSlot({
    super.key,
    required this.name,
    required this.online,
    this.onTap,
    this.lang = AppLang.en,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: online ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: online ? Hmi.card : Hmi.off,
          borderRadius: BorderRadius.circular(22),
          boxShadow: online
              ? const [
                  BoxShadow(
                      color: Color(0x170F1F1B),
                      blurRadius: 10,
                      offset: Offset(0, 2))
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: online ? Hmi.accentSoft : Hmi.hair,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.train,
                  size: 28, color: online ? Hmi.accent : Hmi.muted),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Hmi.ink)),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: online ? Hmi.accent : null,
                          border: online
                              ? null
                              : Border.all(color: Hmi.muted, width: 2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Strings.t(lang, online ? 'online' : 'offline'),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: online ? Hmi.accent : Hmi.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Warning triangle with human figure ──────────────────────────────────────

class WarningTriangle extends StatelessWidget {
  const WarningTriangle({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 150,
      child: CustomPaint(painter: _TrianglePainter()),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // White triangle
    final tri = Path()
      ..moveTo(cx, 14)
      ..lineTo(cx + 68, 134)
      ..lineTo(cx - 68, 134)
      ..close();
    canvas.drawPath(
        tri,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        tri,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeJoin = StrokeJoin.round);

    final fp = Paint()..color = Hmi.red;
    canvas.drawCircle(Offset(cx, 62), 9, fp);
    final lp = Paint()
      ..color = Hmi.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, 76), Offset(cx, 100), lp);
    canvas.drawLine(Offset(cx, 84), Offset(cx - 14, 93), lp);
    canvas.drawLine(Offset(cx, 84), Offset(cx + 13, 92), lp);
    canvas.drawLine(Offset(cx, 100), Offset(cx - 9, 122), lp);
    canvas.drawLine(Offset(cx, 100), Offset(cx + 11, 121), lp);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── HMI progress bar ────────────────────────────────────────────────────────

class HmiProgressBar extends StatelessWidget {
  final double value;
  const HmiProgressBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 8,
      decoration: BoxDecoration(
        color: Hmi.off,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: Hmi.accent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

// ─── Quick settings (brightness + language) ─────────────────────────────────

/// Operator-reachable overlay for brightness and language, opened from the
/// gear icon in the status bar. Self-contained: it is only ever added to the
/// Stack conditionally, so no other screen's layout changes because it exists.
class QuickSettingsPanel extends StatelessWidget {
  final AppLang lang;
  final double brightness;
  final ValueChanged<AppLang> onLangChanged;
  final ValueChanged<double> onBrightnessChanged;
  final VoidCallback onClose;

  const QuickSettingsPanel({
    super.key,
    required this.lang,
    required this.brightness,
    required this.onLangChanged,
    required this.onBrightnessChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          color: const Color(0x800F1F1B),
          alignment: Alignment.center,
          child: Container(
            width: 520,
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
            decoration: BoxDecoration(
              color: Hmi.card,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Strings.t(lang, 'brightness'),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Hmi.ink),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.brightness_low,
                        size: 22, color: Hmi.muted),
                    Expanded(
                      child: Slider(
                        value: brightness.clamp(0.1, 1.0),
                        min: 0.1,
                        max: 1.0,
                        activeColor: Hmi.accent,
                        onChanged: onBrightnessChanged,
                      ),
                    ),
                    const Icon(Icons.brightness_high,
                        size: 22, color: Hmi.muted),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  Strings.t(lang, 'language'),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Hmi.ink),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: HmiBtn(
                        label: 'English',
                        onTap: () => onLangChanged(AppLang.en),
                        height: 64,
                        background: lang == AppLang.en ? Hmi.accent : Hmi.off,
                        textColor:
                            lang == AppLang.en ? Colors.white : Hmi.ink,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: HmiBtn(
                        label: 'हिंदी',
                        onTap: () => onLangChanged(AppLang.hi),
                        height: 64,
                        background: lang == AppLang.hi ? Hmi.accent : Hmi.off,
                        textColor:
                            lang == AppLang.hi ? Colors.white : Hmi.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: HmiBtn(
                    label: 'OK',
                    onTap: onClose,
                    height: 60,
                    background: Hmi.ink,
                    textColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
