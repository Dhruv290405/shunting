import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Kiosk state reported by the Android side.
@immutable
class KioskStatus {
  /// The tablet was provisioned with this app as device owner, so the kiosk
  /// lock really works. When false every lock call is a harmless no-op.
  final bool deviceOwner;

  /// Someone unlocked the tablet with the PIN and has not locked it again.
  /// Locking is always manual and never times out.
  final bool maintenance;

  /// Lock task mode is active right now.
  final bool locked;

  const KioskStatus({
    this.deviceOwner = false,
    this.maintenance = false,
    this.locked = false,
  });

  static KioskStatus fromMap(Map<Object?, Object?>? map) => KioskStatus(
        deviceOwner: map?['deviceOwner'] == true,
        maintenance: map?['maintenance'] == true,
        locked: map?['locked'] == true,
      );

  @override
  bool operator ==(Object other) =>
      other is KioskStatus &&
      other.deviceOwner == deviceOwner &&
      other.maintenance == maintenance &&
      other.locked == locked;

  @override
  int get hashCode => Object.hash(deviceOwner, maintenance, locked);
}

/// What the app needs from the kiosk layer (a fake is used in tests).
abstract class KioskController {
  Future<KioskStatus> status();

  /// PIN accepted: leave kiosk until [lockNow] is called.
  Future<KioskStatus> enterMaintenance();

  /// Back to kiosk. Needs no PIN.
  Future<KioskStatus> lockNow();

  Future<bool> openSettings();
  Future<bool> openWifiSettings();

  /// Remove kiosk (device owner) completely.
  Future<KioskStatus> decommission();

  /// Called when the Android side changed state (e.g. LOCK NOW was tapped in
  /// the notification).
  void setOnChanged(VoidCallback? callback);
}

/// Talks to `KioskManager.kt`. Where there is no Android side (Chrome, tests,
/// desktop) it keeps the maintenance flag in memory so the whole flow can
/// still be tried out.
class PlatformKioskController implements KioskController {
  static const MethodChannel _channel = MethodChannel('shunting/kiosk');

  VoidCallback? _onChanged;
  bool _memoryMaintenance = false;

  PlatformKioskController() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stateChanged') _onChanged?.call();
      return null;
    });
  }

  @override
  void setOnChanged(VoidCallback? callback) => _onChanged = callback;

  Future<KioskStatus> _call(String method) async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(method);
      return KioskStatus.fromMap(result);
    } on MissingPluginException {
      return _fallback(method);
    } on PlatformException catch (e) {
      debugPrint('Kiosk $method failed: $e');
      return status();
    }
  }

  KioskStatus _fallback(String method) {
    switch (method) {
      case 'enterMaintenance':
        _memoryMaintenance = true;
      case 'lockNow':
      case 'decommission':
        _memoryMaintenance = false;
    }
    return KioskStatus(maintenance: _memoryMaintenance);
  }

  @override
  Future<KioskStatus> status() => _call('status');

  @override
  Future<KioskStatus> enterMaintenance() => _call('enterMaintenance');

  @override
  Future<KioskStatus> lockNow() => _call('lockNow');

  @override
  Future<KioskStatus> decommission() => _call('decommission');

  Future<bool> _bool(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('Kiosk $method failed: $e');
      return false;
    }
  }

  @override
  Future<bool> openSettings() => _bool('openSettings');

  @override
  Future<bool> openWifiSettings() => _bool('openWifiSettings');
}
