import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The maintenance PIN. Only a salted hash is stored on the tablet.
///
/// Until the PIN is changed from the maintenance menu the factory PIN
/// applies. Set your own with `--dart-define=KIOSK_PIN=<digits>` when building.
class PinStore {
  static const String factoryPin =
      String.fromEnvironment('KIOSK_PIN', defaultValue: '2580');

  static const int minLength = 4;
  static const int maxLength = 8;

  static const String _hashKey = 'kiosk_pin_hash';
  static const String _saltKey = 'kiosk_pin_salt';

  static String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<bool> verify(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_hashKey);
    final salt = prefs.getString(_saltKey);
    if (stored == null || salt == null) return pin == factoryPin;
    return _hash(salt, pin) == stored;
  }

  Future<void> change(String newPin) async {
    assert(newPin.length >= minLength && newPin.length <= maxLength);
    final prefs = await SharedPreferences.getInstance();
    final random = Random.secure();
    final salt = base64Url
        .encode(List<int>.generate(16, (_) => random.nextInt(256)));
    await prefs.setString(_saltKey, salt);
    await prefs.setString(_hashKey, _hash(salt, newPin));
  }
}
