import 'dart:async';

import 'package:flutter/material.dart';

import '../services/kiosk.dart';
import '../services/pin_store.dart';

const Color _cyan = Color(0xff38d6ff);
const Color _panelBg = Color(0xf002060c);
const Color _amber = Color(0xfff5b301);
const Color _green = Color(0xff22e05a);
const Color _red = Color(0xffff4d4d);

/// Invisible hot corner: press and hold it for [holdDuration] to start the
/// maintenance unlock. Lifting the finger early cancels it.
class KioskCornerGate extends StatefulWidget {
  final VoidCallback onOpen;
  final Duration holdDuration;

  const KioskCornerGate({
    super.key,
    required this.onOpen,
    this.holdDuration = const Duration(seconds: 5),
  });

  @override
  State<KioskCornerGate> createState() => _KioskCornerGateState();
}

class _KioskCornerGateState extends State<KioskCornerGate> {
  Timer? _timer;

  void _start() {
    _timer?.cancel();
    _timer = Timer(widget.holdDuration, widget.onOpen);
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      width: 70,
      height: 60,
      child: Listener(
        key: const Key('kiosk-gate'),
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _cancel(),
        onPointerCancel: (_) => _cancel(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Swallows touches so nothing underneath can be pressed while a panel is up.
class _Barrier extends StatelessWidget {
  const _Barrier();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: const ColoredBox(color: Color(0xb3000000)),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;

  /// Distance from the top; centred vertically when null.
  final double? top;

  const _Panel({
    required this.width,
    required this.height,
    required this.child,
    this.top,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: (1024 - width) / 2,
      top: top ?? (600 - height) / 2,
      width: width,
      height: height,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panelBg,
          border: Border.all(color: _cyan, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }
}

class _KButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Key? buttonKey;
  final double height;

  const _KButton({
    required this.label,
    required this.onTap,
    this.color = _cyan,
    this.buttonKey,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: buttonKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withAlpha(onTap == null ? 20 : 45),
          border: Border.all(color: color.withAlpha(onTap == null ? 90 : 255)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: onTap == null ? Colors.white38 : Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Numeric PIN entry. [onSubmit] returns an error message to show, or null
/// when the PIN was accepted (the caller then closes or replaces this pad).
class PinPad extends StatefulWidget {
  final String title;
  final String? hint;
  final Future<String?> Function(String pin) onSubmit;
  final VoidCallback onCancel;

  const PinPad({
    super.key,
    required this.title,
    this.hint,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _digits = '';
  String? _error;
  bool _busy = false;

  void _add(String d) {
    if (_busy || _digits.length >= PinStore.maxLength) return;
    setState(() {
      _digits += d;
      _error = null;
    });
  }

  void _back() {
    if (_busy || _digits.isEmpty) return;
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_digits.length < PinStore.minLength) {
      setState(() => _error = 'AT LEAST ${PinStore.minLength} DIGITS');
      return;
    }
    setState(() => _busy = true);
    final error = await widget.onSubmit(_digits);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error != null) {
        _error = error;
        _digits = '';
      }
    });
  }

  Widget _digitKey(String d) => Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: _KButton(
            label: d,
            buttonKey: Key('pin-$d'),
            onTap: () => _add(d),
          ),
        ),
      );

  Widget _row(List<Widget> keys) => Expanded(child: Row(children: keys));

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _Barrier(),
        _Panel(
          width: 380,
          height: 540,
          child: Column(
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    widget.hint!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              const SizedBox(height: 10),
              Container(
                key: const Key('pin-dots'),
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: _cyan.withAlpha(150)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '● ' * _digits.length,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    letterSpacing: 2,
                  ),
                ),
              ),
              SizedBox(
                height: 28,
                child: Center(
                  child: Text(
                    _error ?? '',
                    key: const Key('pin-error'),
                    style: const TextStyle(
                      color: _red,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _row([_digitKey('1'), _digitKey('2'), _digitKey('3')]),
                    _row([_digitKey('4'), _digitKey('5'), _digitKey('6')]),
                    _row([_digitKey('7'), _digitKey('8'), _digitKey('9')]),
                    _row([
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _KButton(
                            label: '⌫',
                            buttonKey: const Key('pin-back'),
                            onTap: _back,
                          ),
                        ),
                      ),
                      _digitKey('0'),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _KButton(
                            label: 'OK',
                            buttonKey: const Key('pin-ok'),
                            color: _green,
                            onTap: _busy ? null : _submit,
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _KButton(
                label: 'CANCEL',
                buttonKey: const Key('pin-cancel'),
                color: Colors.white54,
                onTap: widget.onCancel,
                height: 44,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The maintenance menu, shown after the PIN is accepted.
class MaintenanceMenu extends StatelessWidget {
  final KioskStatus status;
  final VoidCallback onLock;
  final VoidCallback onWifi;
  final VoidCallback onSettings;
  final VoidCallback onChangePin;
  final VoidCallback onDecommission;
  final VoidCallback onClose;
  final String? message;

  const MaintenanceMenu({
    super.key,
    required this.status,
    required this.onLock,
    required this.onWifi,
    required this.onSettings,
    required this.onChangePin,
    required this.onDecommission,
    required this.onClose,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _Barrier(),
        _Panel(
          width: 560,
          height: 556,
          top: 34, // leaves the maintenance banner visible above the menu
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'MAINTENANCE MODE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _amber,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'The tablet stays unlocked until you press LOCK TABLET NOW.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              if (!status.deviceOwner)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Kiosk lock is not set up on this tablet.',
                    key: Key('menu-not-provisioned'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _red, fontSize: 14),
                  ),
                ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    message!,
                    key: const Key('menu-message'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _green, fontSize: 15),
                  ),
                ),
              const SizedBox(height: 10),
              _KButton(
                label: 'LOCK TABLET NOW',
                buttonKey: const Key('menu-lock'),
                color: _green,
                onTap: onLock,
                height: 56,
              ),
              const SizedBox(height: 8),
              _KButton(
                  label: 'WI-FI SETTINGS',
                  buttonKey: const Key('menu-wifi'),
                  onTap: onWifi),
              const SizedBox(height: 8),
              _KButton(
                  label: 'ANDROID SETTINGS',
                  buttonKey: const Key('menu-settings'),
                  onTap: onSettings),
              const SizedBox(height: 8),
              _KButton(
                  label: 'CHANGE PIN',
                  buttonKey: const Key('menu-change-pin'),
                  onTap: onChangePin),
              const SizedBox(height: 8),
              _KButton(
                label: 'REMOVE KIOSK (DECOMMISSION)',
                buttonKey: const Key('menu-decommission'),
                color: _red,
                onTap: onDecommission,
              ),
              const Spacer(),
              _KButton(
                label: 'CLOSE MENU (STAY UNLOCKED)',
                buttonKey: const Key('menu-close'),
                color: Colors.white54,
                onTap: onClose,
                height: 44,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Yes/No confirmation for removing the kiosk.
class ConfirmPanel extends StatelessWidget {
  final String title;
  final String text;
  final VoidCallback onYes;
  final VoidCallback onNo;

  const ConfirmPanel({
    super.key,
    required this.title,
    required this.text,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _Barrier(),
        _Panel(
          width: 560,
          height: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _red,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _KButton(
                      label: 'YES, REMOVE',
                      buttonKey: const Key('confirm-yes'),
                      color: _red,
                      onTap: onYes,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KButton(
                      label: 'NO, KEEP',
                      buttonKey: const Key('confirm-no'),
                      onTap: onNo,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Always visible while the tablet is unlocked, so nobody forgets to lock it.
class MaintenanceBanner extends StatelessWidget {
  final VoidCallback onLock;

  const MaintenanceBanner({super.key, required this.onLock});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: 26,
      child: Container(
        key: const Key('maintenance-banner'),
        color: _amber,
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'MAINTENANCE MODE – TABLET NOT LOCKED',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GestureDetector(
              key: const Key('banner-lock'),
              behavior: HitTestBehavior.opaque,
              onTap: onLock,
              child: Container(
                width: 130,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LOCK NOW',
                  style: TextStyle(
                    color: _amber,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
