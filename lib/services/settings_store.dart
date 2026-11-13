import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/strings.dart';

/// Persists the operator's language and screen-brightness choice across
/// restarts. Both default to the tablet's out-of-the-box behaviour (English,
/// whatever brightness the system already had) when nothing is stored yet.
class SettingsStore {
  static const String _langKey = 'app_lang';
  static const String _brightnessKey = 'app_brightness';

  Future<AppLang> loadLang() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_langKey) == 'hi' ? AppLang.hi : AppLang.en;
  }

  Future<void> saveLang(AppLang lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang == AppLang.hi ? 'hi' : 'en');
  }

  /// Null means "unset": the caller should leave the system brightness alone.
  Future<double?> loadBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_brightnessKey);
  }

  Future<void> saveBrightness(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_brightnessKey, value);
  }
}
