import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'dart:async';
import 'i18n/strings.dart';
import 'models/device.dart';
import 'services/api_service.dart';
import 'services/beeper.dart';
import 'services/kiosk.dart';
import 'services/pin_store.dart';
import 'services/settings_store.dart';
import 'screens/splash_screen.dart';
import 'theme/hmi_colors.dart';
import 'widgets/hmi_widgets.dart';
import 'widgets/kiosk_ui.dart';

enum _KioskOverlay { none, pin, menu, newPin, confirmPin, confirmDecommission }

enum TabletScreen {
  splash,
  devices,
  confirmSelection,
  connecting,
  telemetry,
  error,
  changeDevice,
  endShunting,
  shuntingCompleted,
  charger,
  obstacleWarning,
}

class ShuntingApp extends StatefulWidget {
  /// Override to supply a different telemetry source (used by tests).
  final ApiService? apiService;

  /// Override to replace the speaker beeper (used by tests).
  final Beeper? beeper;

  /// Override the kiosk (lock / maintenance) layer (used by tests).
  final KioskController? kiosk;

  /// Override where the maintenance PIN is kept (used by tests).
  final PinStore? pinStore;

  /// Override where language / brightness choices are kept (used by tests).
  final SettingsStore? settingsStore;

  const ShuntingApp({
    super.key,
    this.apiService,
    this.beeper,
    this.kiosk,
    this.pinStore,
    this.settingsStore,
  });

  @override
  State<ShuntingApp> createState() => _ShuntingAppState();
}

/// The tablet follows the shunting receiver firmware (Receiver
/// `screen_sm.c`, `buzzer.c`). Constants below are taken from it unless a
/// comment says otherwise.
class _ShuntingAppState extends State<ShuntingApp> with WidgetsBindingObserver {
  static const int _devicesPerPage = 9;
  static const int _maxPages = 5;

  /// Main-loop tick: drives timeouts and the beeper.
  static const int _tickMs = 250;

  /// LINK_STALE_TIMEOUT_MS: no transmitter message for this long = link down.
  static const int _linkStaleMs = 15000;

  /// Communication health: a message this recent is BEST, otherwise GOOD
  /// (the receiver's GSM thresholds: 2 s, then the stale timeout).
  static const int _healthBestMs = 2000;

  /// CONNECTING_TIMEOUT_MS / ERROR_HOLD_MS / SHUNTING_COMPLETED_HOLD_MS.
  static const int _connectingTimeoutMs = 20000;
  static const int _errorHoldMs = 3000;
  static const int _completedHoldMs = 2000;

  /// The receiver never accepts a cloud link in the first 3 s of connecting
  /// (LORA_NO_SIGNAL_GRACE_MS); kept so Connecting behaves the same.
  static const int _connectingMinMs = 3000;

  /// Tablet start-up splash. (The receiver holds 5 s only to read its
  /// battery, which does not apply here.)
  static const int _splashMs = 3000;


  TabletScreen screen = TabletScreen.splash;
  late final ApiService api = widget.apiService ?? ApiService();
  late final Beeper _beeper = widget.beeper ?? AudioBeeper();
  final Battery _tabletBattery = Battery();
  Timer? _telemetryTimer;
  Timer? _tickTimer;
  Timer? _tabletStatusTimer;
  Timer? _splashTimer;
  Timer? _completedTimer;

  // Session / selection state.
  final List<ShuntingDevice> _liveDevices = [];
  ShuntingDevice? _liveDevice; // the transmitter reported online right now
  ShuntingDevice? candidate; // selected, awaiting confirm / connecting
  String? _connectedName; // set only once the connection is real
  bool _sessionActive = false;
  int page = 0;

  // Volume, as the receiver: 0..100 in steps of 10, default 50.
  int volume = 50;
  bool muted = false;

  // Telemetry.
  int battery = 0; // the transmitter's battery (0 = not reported)
  int tabletBattery = 0;
  bool _tabletCharging = false;
  StreamSubscription<BatteryState>? _batterySub;
  int distanceCm = 0;
  bool network = false; // transmitter link_state OK
  bool obstacle = false;
  bool charger = false;
  bool shuntingCompleted = false;
  bool _prevCompleted = false;

  // Link freshness, driven by the tick (not the wall clock) so it behaves the
  // same in tests: age of the newest transmitter message = the age the server
  // reported at fetch time + time since that fetch.
  bool _hasFetched = false;
  int _ageMsAtFetch = 0;
  int _msSinceFetch = 0;

  // Obstacle detection from the distance stream.
  bool _localObstacle = false;
  int? _lastReadingCm;
  int? _lastReadingId;

  // True while the Error page is shown because the transmitter went silent
  // during a session (not because a connection attempt failed).
  bool _linkLostError = false;

  // Screen timers (in ticks of wall-independent time).
  int _screenMs = 0;
  int _uiTick = 0;
  bool _polling = false;
  bool _refreshing = false;

  // Language / brightness. Operator-reachable, kept isolated in their own
  // overlay so no other screen's layout depends on them.
  late final SettingsStore _settingsStore =
      widget.settingsStore ?? SettingsStore();
  AppLang _lang = AppLang.en;
  double _brightness = 0.8;
  bool _showQuickSettings = false;

  // Kiosk / maintenance mode.
  late final KioskController _kiosk = widget.kiosk ?? PlatformKioskController();
  late final PinStore _pinStore = widget.pinStore ?? PinStore();
  KioskStatus _kioskStatus = const KioskStatus();
  _KioskOverlay _overlay = _KioskOverlay.none;
  int _pinFailures = 0;
  int _pinLockoutMs = 0;
  String? _pendingPin;
  String? _menuMessage;

  /// Five wrong PINs lock PIN entry for 30 s.
  static const int _maxPinFailures = 5;
  static const int _pinLockoutTotalMs = 30000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _kiosk.setOnChanged(_refreshKiosk);
    _refreshKiosk();
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshKiosk();
  }

  Future<void> _init() async {
    // The splash duration must not depend on the network.
    _splashTimer = Timer(const Duration(milliseconds: _splashMs), () {
      if (mounted && screen == TabletScreen.splash) {
        setState(() => _goto(TabletScreen.devices));
      }
    });
    _telemetryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollTelemetry(),
    );
    _tickTimer = Timer.periodic(
      const Duration(milliseconds: _tickMs),
      (_) => _tick(),
    );
    _tabletStatusTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshTabletStatus(),
    );
    await _refreshTabletStatus();
    await _pollTelemetry();
    await _loadSettings();
    _watchTabletCharging();
  }

  /// Live charging-bolt indicator for the tablet's own battery (the 30 s
  /// poll above is too coarse to catch a plug-in right away).
  void _watchTabletCharging() {
    try {
      _batterySub = _tabletBattery.onBatteryStateChanged.listen((state) {
        if (!mounted) return;
        setState(() => _tabletCharging = _isChargingState(state));
      });
    } catch (e) {
      debugPrint('Unable to watch tablet battery state: $e');
    }
  }

  static bool _isChargingState(BatteryState state) =>
      state == BatteryState.charging || state == BatteryState.full;

  Future<void> _loadSettings() async {
    final lang = await _settingsStore.loadLang();
    final savedBrightness = await _settingsStore.loadBrightness();
    if (!mounted) return;
    setState(() {
      _lang = lang;
      if (savedBrightness != null) _brightness = savedBrightness;
    });
    if (savedBrightness != null) await _applyBrightness(savedBrightness);
  }

  // ---- brightness / language ---------------------------------------------
  //
  // Both live in their own overlay (QuickSettingsPanel), opened from the
  // status bar's gear icon. They only ever touch that overlay and the text
  // on screen; no screen's layout or sizing changes because of them.

  Future<void> _applyBrightness(double value) async {
    try {
      await ScreenBrightness().setApplicationScreenBrightness(value);
    } catch (e) {
      debugPrint('Unable to set screen brightness: $e');
    }
  }

  Future<void> _setBrightness(double value) async {
    setState(() => _brightness = value);
    await _applyBrightness(value);
    await _settingsStore.saveBrightness(value);
  }

  Future<void> _setLanguage(AppLang lang) async {
    setState(() => _lang = lang);
    await _settingsStore.saveLang(lang);
  }

  void _openQuickSettings() => setState(() => _showQuickSettings = true);
  void _closeQuickSettings() => setState(() => _showQuickSettings = false);

  String _t(String key, [Map<String, String>? args]) =>
      Strings.t(_lang, key, args);

  Future<void> _refreshTabletStatus() async {
    try {
      final level = await _tabletBattery.batteryLevel;
      final state = await _tabletBattery.batteryState;
      if (mounted) {
        setState(() {
          tabletBattery = level;
          _tabletCharging = _isChargingState(state);
        });
      }
    } catch (error) {
      debugPrint('Unable to read tablet battery: $error');
    }
  }

  // ---- kiosk / maintenance mode ------------------------------------------
  //
  // The tablet is locked into this app (Android lock task mode, once it is
  // provisioned as device owner). A railway user unlocks it by pressing and
  // holding the hidden top-left corner for 5 s and entering the PIN. It then
  // stays unlocked - no timer, even across restarts - until they press LOCK
  // NOW (menu, banner or notification).

  Future<void> _refreshKiosk() async {
    final status = await _kiosk.status();
    if (!mounted) return;
    setState(() => _kioskStatus = status);
    _applySystemUi();
  }

  /// Immersive while locked; normal system bars while unlocked so Settings and
  /// the notification are reachable.
  void _applySystemUi() {
    SystemChrome.setEnabledSystemUIMode(
      _kioskStatus.maintenance
          ? SystemUiMode.edgeToEdge
          : SystemUiMode.immersiveSticky,
    );
  }

  void _openPin() {
    if (_overlay != _KioskOverlay.none) return;
    setState(() => _overlay = _KioskOverlay.pin);
  }

  void _setOverlay(_KioskOverlay next, {String? message}) {
    setState(() {
      _overlay = next;
      _menuMessage = message;
      if (next != _KioskOverlay.confirmPin) _pendingPin = null;
    });
  }

  String get _lockoutText =>
      'TOO MANY TRIES – WAIT ${(_pinLockoutMs / 1000).ceil()} s';

  Future<String?> _submitUnlockPin(String pin) async {
    if (_pinLockoutMs > 0) return _lockoutText;
    if (await _pinStore.verify(pin)) {
      _pinFailures = 0;
      final status = await _kiosk.enterMaintenance();
      if (!mounted) return null;
      setState(() => _kioskStatus = status);
      _applySystemUi();
      _setOverlay(_KioskOverlay.menu);
      return null;
    }
    if (!mounted) return null;
    if (++_pinFailures >= _maxPinFailures) {
      _pinFailures = 0;
      setState(() => _pinLockoutMs = _pinLockoutTotalMs);
      return _lockoutText;
    }
    return 'WRONG PIN';
  }

  Future<String?> _submitNewPin(String pin) async {
    _pendingPin = pin; // kept by _setOverlay only while confirming
    _setOverlay(_KioskOverlay.confirmPin);
    return null;
  }

  Future<String?> _submitConfirmPin(String pin) async {
    if (pin != _pendingPin) return 'PINS DO NOT MATCH';
    await _pinStore.change(pin);
    if (!mounted) return null;
    _setOverlay(_KioskOverlay.menu, message: 'PIN CHANGED');
    return null;
  }

  /// LOCK NOW: manual, needs no PIN.
  Future<void> _lockNow() async {
    final status = await _kiosk.lockNow();
    if (!mounted) return;
    setState(() {
      _kioskStatus = status;
      _overlay = _KioskOverlay.none;
      _menuMessage = null;
    });
    _applySystemUi();
  }

  Future<void> _decommission() async {
    final status = await _kiosk.decommission();
    if (!mounted) return;
    setState(() => _kioskStatus = status);
    _applySystemUi();
    _setOverlay(_KioskOverlay.menu, message: 'KIOSK REMOVED');
  }

  List<Widget> _kioskLayer() {
    return [
      if (_kioskStatus.maintenance) MaintenanceBanner(onLock: _lockNow),
      if (_overlay == _KioskOverlay.none) KioskCornerGate(onOpen: _openPin),
      switch (_overlay) {
        _KioskOverlay.none => const SizedBox.shrink(),
        _KioskOverlay.pin => PinPad(
            key: const ValueKey('pad-unlock'),
            title: 'ENTER PIN',
            hint: 'Maintenance access',
            onSubmit: _submitUnlockPin,
            onCancel: () => _setOverlay(_KioskOverlay.none),
          ),
        _KioskOverlay.menu => MaintenanceMenu(
            status: _kioskStatus,
            message: _menuMessage,
            onLock: _lockNow,
            onWifi: () => _kiosk.openWifiSettings(),
            onSettings: () => _kiosk.openSettings(),
            onChangePin: () => _setOverlay(_KioskOverlay.newPin),
            onDecommission: () =>
                _setOverlay(_KioskOverlay.confirmDecommission),
            onClose: () => _setOverlay(_KioskOverlay.none),
          ),
        _KioskOverlay.newPin => PinPad(
            key: const ValueKey('pad-new'),
            title: 'NEW PIN',
            hint: '${PinStore.minLength}-${PinStore.maxLength} digits',
            onSubmit: _submitNewPin,
            onCancel: () => _setOverlay(_KioskOverlay.menu),
          ),
        _KioskOverlay.confirmPin => PinPad(
            key: const ValueKey('pad-confirm'),
            title: 'CONFIRM NEW PIN',
            onSubmit: _submitConfirmPin,
            onCancel: () => _setOverlay(_KioskOverlay.menu),
          ),
        _KioskOverlay.confirmDecommission => ConfirmPanel(
            title: 'REMOVE KIOSK?',
            text: 'The tablet will no longer be locked to this app and '
                'will not start it by itself after a restart.',
            onYes: _decommission,
            onNo: () => _setOverlay(_KioskOverlay.menu),
          ),
      },
    ];
  }

  /// Switches screen and restarts the per-screen timer.
  void _goto(TabletScreen next) {
    screen = next;
    _screenMs = 0;
  }

  // ---- volume ------------------------------------------------------------

  /// Volume buttons: 10% steps, shown as a number in the centre pill. There is
  /// no sound on touch; the level only sets how loud the distance-driven
  /// beeps are.
  void _changeVolume(int delta) {
    setState(() {
      volume = (volume + delta * 10).clamp(0, 100);
      muted = false;
    });
    _syncBeeper();
  }

  void _toggleMute() {
    setState(() => muted = !muted);
    _syncBeeper();
  }

  // ---- telemetry ---------------------------------------------------------

  Future<void> _pollTelemetry() async {
    if (_polling) return;
    _polling = true;
    try {
      final listed = await api.fetchDevices();
      if (listed.isNotEmpty && mounted) {
        setState(() {
          _liveDevices
            ..clear()
            ..addAll(listed.asMap().entries.map((entry) {
              final item = entry.value;
              return ShuntingDevice(
                number: entry.key + 1,
                name: (item['deviceId'] ?? item['device'] ?? '').toString(),
                online: item['online'] != false,
                inUse: _sessionActive &&
                    (item['deviceId'] ?? item['device']) == _connectedName,
                battery: (item['battery'] as num?)?.toInt() ?? 0,
              );
            }));
        });
      } else if (mounted) {
        setState(() => _liveDevices.clear());
      }
      final telemetryDevice = _connectedName ??
          (listed.isNotEmpty
              ? (listed.first['deviceId'] ?? listed.first['device'])?.toString()
              : null);
      if (telemetryDevice == null || telemetryDevice.isEmpty) return;
      final data = await api.fetchTelemetry(telemetryDevice);
      if (!mounted) return;
      _onTelemetryUpdate(data);
    } catch (e) {
      // A failed request just lets the link age; it is declared down by the
      // 15 s stale rule, exactly like a transmitter that stopped talking.
      debugPrint('Telemetry poll failed: $e');
    } finally {
      _polling = false;
    }
  }

  Future<void> _manualRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _pollTelemetry();
    if (mounted) setState(() => _refreshing = false);
  }

  static bool _asFlag(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == '1' || v == 'yes';
    }
    return false;
  }

  static bool _flagIn(List<Map<String, dynamic>> sources, String key) =>
      sources.any((source) => _asFlag(source[key]));

  void _onTelemetryUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    final readings = data['readings'] is Map
        ? Map<String, dynamic>.from(data['readings'] as Map)
        : <String, dynamic>{};
    final diagnostics = data['diagnostics'] is Map
        ? Map<String, dynamic>.from(data['diagnostics'] as Map)
        : <String, dynamic>{};
    final sources = [data, readings, diagnostics];
    final deviceName = data['deviceId'] ?? data['device'] ?? 'UNKNOWN';
    final linkState = diagnostics['link_state']?.toString().toUpperCase();
    final linkOk = linkState == 'OK' || linkState == 'CONNECTED';
    final isOnline =
        diagnostics['status']?.toString().toUpperCase() == 'ONLINE' && linkOk;
    if (deviceName == 'UNKNOWN' || !isOnline) {
      // The server only reports OFFLINE once the transmitter has been silent
      // for its stale window. Not listed any more; the link age keeps growing.
      setState(() {
        _liveDevice = null;
        _liveDevices.clear();
        network = false;
      });
      return;
    }

    final latestCm = (readings['distance_cm'] as num?)?.toInt() ?? 0;
    final ageMs = (data['ageMs'] as num?)?.toInt() ??
        (((data['ageSeconds'] as num?)?.toInt() ?? 0) * 1000);
    setState(() {
      _liveDevice = ShuntingDevice(
        number: 1,
        name: deviceName.toString(),
        online: true,
        inUse: _sessionActive,
        battery: (diagnostics['battery_pct'] as num?)?.toInt() ?? 0,
      );
      final index = _liveDevices.indexWhere((d) => d.name == deviceName);
      if (index >= 0) {
        _liveDevices[index] = _liveDevice!;
      } else {
        _liveDevices
          ..clear()
          ..add(_liveDevice!);
      }
      battery = _liveDevice!.battery;
      distanceCm = latestCm;
      network = linkOk;
      _hasFetched = true;
      _ageMsAtFetch = ageMs;
      _msSinceFetch = 0;
      _ingestReadings(data, latestCm);
      obstacle = _flagIn(sources, 'obstacle') || _localObstacle;
      charger = _flagIn(sources, 'is_charging') || _flagIn(sources, 'charger');
      shuntingCompleted = _flagIn(sources, 'completed');
      _route();
    });
  }

  // ---- receiver-compatible rules -----------------------------------------

  /// Readings above this are out of range ("OR", silent). 44 m by default;
  /// the receiver overrides it for units fitted with a longer LiDAR.
  static int _maxActiveCmFor(int? deviceNum) {
    switch (deviceNum) {
      case 9:
      case 12:
        return 17900; // 180 m LiDAR
      case 10:
      case 11:
        return 9900; // 100 m LiDAR
      default:
        return 4400;
    }
  }

  /// The "NN" of a device id such as "TX-12".
  static int? _deviceNumber(String? id) {
    final m = RegExp(r'(\d+)$').firstMatch(id ?? '');
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  int get _maxActiveCm =>
      _maxActiveCmFor(_deviceNumber(_connectedName ?? _liveDevice?.name));

  static const int _obstacleDropCm = 500; // a drop this big is "sudden"
  static const int _obstacleTriggerMaxCm = 500; // warn only at/below 5 m
  static const int _obstacleClearAboveCm = 600; // warning clears above 6 m

  /// Feeds every new transmitter reading, in order, through the obstacle
  /// rules (the transmitter sends one every 500 ms and the receiver checks
  /// each of them). The server returns the last few readings with ids so none
  /// are missed between polls; against an older server only the latest
  /// reading is available.
  void _ingestReadings(Map<String, dynamic> data, int latestCm) {
    final inSession = screen == TabletScreen.telemetry ||
        screen == TabletScreen.obstacleWarning;
    final recent = data['recent'];
    if (recent is List && recent.isNotEmpty) {
      for (final item in recent) {
        if (item is! Map) continue;
        final cm = (item['cm'] as num?)?.toInt();
        if (cm == null) continue;
        final id = (item['id'] as num?)?.toInt();
        if (id != null) {
          final last = _lastReadingId;
          if (last != null && id <= last) continue; // already processed
          _lastReadingId = id;
        }
        _evaluateReading(cm, inSession);
      }
    } else {
      _evaluateReading(latestCm, inSession);
    }
  }

  /// Obstacle warning, same rules as the receiver's TickObstacleOverlay(): a
  /// sudden drop of 5 m or more landing at 5 m or less raises it; it clears
  /// above 6 m or on a sudden rise. The first reading of a session is only a
  /// baseline. Only evaluated while viewing live telemetry.
  void _evaluateReading(int cm, bool inSession) {
    if (!inSession) {
      _lastReadingCm = null;
      _localObstacle = false;
      return;
    }
    final prev = _lastReadingCm;
    _lastReadingCm = cm;
    if (prev == null || prev == cm) return; // baseline / no new reading
    if (!_localObstacle) {
      if (prev - cm >= _obstacleDropCm && cm <= _obstacleTriggerMaxCm) {
        _localObstacle = true;
      }
    } else if (cm > _obstacleClearAboveCm || cm - prev >= _obstacleDropCm) {
      _localObstacle = false;
    }
  }

  /// Age of the newest transmitter message in ms.
  int get _dataAgeMs =>
      _hasFetched ? _ageMsAtFetch + _msSinceFetch : _linkStaleMs + 1;

  /// A message arrived within the stale window (the receiver's "link up").
  bool get _dataFresh => _dataAgeMs <= _linkStaleMs;

  /// The transmitters shown on the pairing screens: only live ones.
  List<ShuntingDevice> get devices {
    if (!_dataFresh) return const [];
    return List.unmodifiable(_liveDevices);
  }

  /// The link to the connected transmitter is up.
  bool get _linkUp => _sessionActive && _dataFresh && network;

  /// Distance text as on the receiver: whole metres, "OR" beyond range, "DC"
  /// when the transmitter is gone.
  String get _distanceText {
    if (!_dataFresh) return 'DC';
    if (distanceCm > _maxActiveCm) return 'OR';
    return '${(distanceCm + 50) ~/ 100}';
  }

  /// Drives the proximity beeper like the receiver's TickBuzzer(): only while
  /// viewing live telemetry (the obstacle overlay counts, it is drawn over
  /// telemetry), faster as the dead-end gets closer, silent beyond range, and
  /// a steady alarm tone when the link to the transmitter is lost.
  void _syncBeeper() {
    var interval = 0;
    var continuous = false;
    final onTelemetry = _sessionActive &&
        (screen == TabletScreen.telemetry ||
            screen == TabletScreen.obstacleWarning);
    if (_linkLostError && screen == TabletScreen.error) {
      continuous = true; // the transmitter is gone: keep the alarm sounding
    } else if (onTelemetry) {
      if (!_dataFresh) {
        continuous = true; // total link loss
      } else if (distanceCm <= _maxActiveCm) {
        interval = Beeper.intervalForDistanceCm(distanceCm);
      }
    }
    _beeper.update(
      intervalMs: interval,
      continuous: continuous,
      volume: muted ? 0 : volume,
    );
  }

  /// Applies the telemetry-driven screen transitions. Call inside setState.
  void _route() {
    final completedRose = shuntingCompleted && !_prevCompleted;
    _prevCompleted = shuntingCompleted;

    const sessionScreens = {
      TabletScreen.telemetry,
      TabletScreen.obstacleWarning,
      TabletScreen.charger,
      TabletScreen.endShunting,
      TabletScreen.changeDevice,
    };

    // The device reported completion (edge triggered so a stale flag does not
    // bounce the operator back into this screen after they dismissed it).
    if (completedRose && sessionScreens.contains(screen)) {
      _disconnect();
      _enterCompleted();
      return;
    }
    // The obstacle overlay only covers live telemetry (as on the receiver).
    if (obstacle && screen == TabletScreen.telemetry) {
      _goto(TabletScreen.obstacleWarning);
      return;
    }
    if (charger && screen == TabletScreen.telemetry) {
      _goto(TabletScreen.charger);
      return;
    }
    if (screen == TabletScreen.obstacleWarning && !obstacle) {
      _goto(charger ? TabletScreen.charger : TabletScreen.telemetry);
      return;
    }
    if (screen == TabletScreen.charger && !charger) {
      _goto(TabletScreen.telemetry);
    }
  }

  // ---- timers (the receiver's TickTimers) --------------------------------

  void _tick() {
    if (!mounted) return;
    _msSinceFetch += _tickMs;
    _screenMs += _tickMs;
    if (_pinLockoutMs > 0) {
      _pinLockoutMs = (_pinLockoutMs - _tickMs).clamp(0, _pinLockoutTotalMs);
    }
    _syncBeeper();

    var changed = false;
    // The transmitter went silent during a session: show the Error page
    // ("Can't connect to the dead-end, please check if device is turned on")
    // and keep the alarm going until it is heard again.
    if (_sessionActive &&
        !_dataFresh &&
        (screen == TabletScreen.telemetry ||
            screen == TabletScreen.obstacleWarning)) {
      _linkLostError = true;
      _goto(TabletScreen.error);
      changed = true;
    }
    switch (screen) {
      case TabletScreen.connecting:
        if (_screenMs >= _connectingMinMs && _candidateReady) {
          _commitConnection();
          changed = true;
        } else if (_screenMs >= _connectingTimeoutMs) {
          _goto(TabletScreen.error);
          changed = true;
        }
      case TabletScreen.error:
        if (_linkLostError) {
          // Stays until the transmitter is heard again (or the operator
          // leaves with Back); then straight back to live telemetry.
          if (_dataFresh && _sessionActive) {
            _linkLostError = false;
            _goto(TabletScreen.telemetry);
            changed = true;
          }
          break;
        }
        // Like the receiver, keep trying while the error is shown: a slow
        // (not failed) connection still recovers by itself.
        if (_candidateReady) {
          _commitConnection();
          changed = true;
        } else if (_screenMs >= _errorHoldMs) {
          _disconnect();
          _goto(TabletScreen.devices);
          changed = true;
        }
      default:
        break;
    }
    // Refresh the on-screen ages / labels about once a second.
    if (changed || ++_uiTick % 4 == 0) setState(() {});
  }

  bool get _candidateReady {
    final target = candidate;
    final live = _liveDevice;
    return target != null &&
        live != null &&
        live.name == target.name &&
        _dataFresh &&
        network;
  }

  /// The connection is real: show it in the status bar and go to telemetry.
  void _commitConnection() {
    _connectedName = candidate?.name;
    _sessionActive = true;
    _goto(TabletScreen.telemetry);
    _route();
  }

  /// Severs the connection (receiver: GSM_Disconnect + "--").
  void _disconnect() {
    _linkLostError = false;
    _sessionActive = false;
    _connectedName = null;
    candidate = null;
    _localObstacle = false;
    _lastReadingCm = null;
  }

  /// SHUNTING_COMPLETED_HOLD_MS, then back to the start-up screen and on to
  /// the pairing list, as the receiver does.
  void _enterCompleted() {
    _goto(TabletScreen.shuntingCompleted);
    _completedTimer?.cancel();
    _completedTimer = Timer(const Duration(milliseconds: _completedHoldMs), () {
      if (!mounted || screen != TabletScreen.shuntingCompleted) return;
      setState(() => _goto(TabletScreen.splash));
      _splashTimer?.cancel();
      _splashTimer = Timer(const Duration(milliseconds: _splashMs), () {
        if (mounted && screen == TabletScreen.splash) {
          setState(() => _goto(TabletScreen.devices));
        }
      });
    });
  }

  // ---- actions -----------------------------------------------------------

  void _selectDevice(ShuntingDevice device) {
    if (!device.online) return;
    setState(() {
      candidate = device;
      _goto(TabletScreen.confirmSelection);
    });
  }

  /// Confirm YES: start connecting. The connection is only committed once
  /// real telemetry from that transmitter is flowing.
  void _connectCandidate() {
    if (candidate == null) {
      setState(() => _goto(TabletScreen.devices));
      return;
    }
    setState(() => _goto(TabletScreen.connecting));
  }

  /// End Shunting YES.
  void _finishShunting() {
    setState(() {
      _disconnect();
      distanceCm = 0;
      _enterCompleted();
    });
  }

  /// Change Device YES: the connection is closed right away.
  void _changeDeviceYes() {
    setState(() {
      _disconnect();
      page = 0;
      _goto(TabletScreen.devices);
    });
  }

  /// Back to the pairing list, abandoning any attempt in progress.
  void _goDevices() {
    setState(() {
      _disconnect();
      _goto(TabletScreen.devices);
    });
  }

  void _changePage(int delta) {
    final next = page + delta;
    if (next < 0 || next >= _pageCount) return;
    setState(() => page = next);
  }

  int get _pageCount =>
      (((devices.length - 1) ~/ _devicesPerPage) + 1).clamp(1, _maxPages);

  // ---- UI (native widgets matching the official HMI prototype) ------------

  void _toChangeDevice() => setState(() => _goto(TabletScreen.changeDevice));
  void _toEndShunting() => setState(() => _goto(TabletScreen.endShunting));
  void _toTelemetry() => setState(() => _goto(TabletScreen.telemetry));

  int get _fullScaleM {
    final max = _maxActiveCm;
    if (max >= 17000) return 180;
    if (max >= 9000) return 100;
    return 45;
  }

  bool get _outOfRange => distanceCm > _maxActiveCm;
  double get _distanceFraction =>
      (distanceCm / (_fullScaleM * 100)).clamp(0.0, 1.0);

  String? get _statusDevice => _sessionActive ? _connectedName : null;

  int get _healthBars {
    if (!_linkUp) return 0;
    return _dataAgeMs <= _healthBestMs ? 3 : 2;
  }

  String get _healthText {
    if (!_linkUp) return '';
    return _t(_dataAgeMs <= _healthBestMs ? 'link_excellent' : 'link_good');
  }

  TabletScreen get _baseScreen {
    switch (screen) {
      case TabletScreen.confirmSelection:
        return TabletScreen.devices;
      case TabletScreen.changeDevice:
      case TabletScreen.endShunting:
        return TabletScreen.telemetry;
      default:
        return screen;
    }
  }

  bool get _isDialogScreen =>
      screen == TabletScreen.confirmSelection ||
      screen == TabletScreen.changeDevice ||
      screen == TabletScreen.endShunting;

  bool get _showStatusBar =>
      screen != TabletScreen.splash &&
      screen != TabletScreen.charger &&
      screen != TabletScreen.obstacleWarning;

  Widget _buildNativeScreen(TabletScreen s) {
    switch (s) {
      case TabletScreen.splash:
        return SplashScreen(lang: _lang);
      case TabletScreen.devices:
      case TabletScreen.confirmSelection:
        return _buildDevices();
      case TabletScreen.connecting:
        return _buildConnecting();
      case TabletScreen.telemetry:
      case TabletScreen.changeDevice:
      case TabletScreen.endShunting:
      case TabletScreen.obstacleWarning:
      case TabletScreen.charger:
        return _buildTelemetry();
      case TabletScreen.error:
        return _buildError();
      case TabletScreen.shuntingCompleted:
        return _buildCompleted();
    }
  }

  Widget _buildDevices() {
    final live = devices;
    return Container(
      color: Hmi.bg,
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 20),
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_t('devices_title'),
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Hmi.ink)),
                      Text(
                        live.isEmpty
                            ? _t('devices_subtitle_empty')
                            : _t('devices_subtitle_count',
                                {'n': '${live.length}'}),
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w500,
                            color: Hmi.muted),
                      ),
                    ],
                  ),
                ),
                HmiBtn(
                  label: _refreshing ? _t('refreshing') : _t('refresh'),
                  leading: _refreshing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Hmi.ink),
                        )
                      : const Icon(Icons.refresh, size: 26, color: Hmi.ink),
                  onTap: _refreshing ? null : _manualRefresh,
                  height: 60,
                  fontSize: 22,
                  borderRadius: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: live.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sensors_off,
                            size: 64, color: Hmi.hair),
                        const SizedBox(height: 16),
                        Text(_t('devices_empty_title'),
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Hmi.ink)),
                        Text(_t('devices_empty_subtitle'),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Hmi.muted)),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 3.0,
                    ),
                    itemCount: live.length,
                    itemBuilder: (context, index) => HmiSlot(
                      name: live[index].name,
                      online: live[index].online,
                      lang: _lang,
                      onTap: () => _selectDevice(live[index]),
                    ),
                  ),
          ),
          if (_pageCount > 1)
            SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  HmiBtn(
                    label: _t('previous'),
                    leading: Icon(Icons.chevron_left,
                        size: 24,
                        color: page > 0 ? Hmi.ink : Hmi.muted),
                    onTap: page > 0 ? () => _changePage(-1) : null,
                    height: 60,
                    fontSize: 22,
                    borderRadius: 18,
                  ),
                  Text(
                      _t('page_of',
                          {'a': '${page + 1}', 'b': '$_pageCount'}),
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: Hmi.muted)),
                  HmiBtn(
                    label: _t('next'),
                    trailing: Icon(Icons.chevron_right,
                        size: 24,
                        color:
                            page < _pageCount - 1 ? Hmi.ink : Hmi.muted),
                    onTap: page < _pageCount - 1 ? () => _changePage(1) : null,
                    height: 60,
                    fontSize: 22,
                    borderRadius: 18,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnecting() {
    final secondsLeft =
        ((_connectingTimeoutMs - _screenMs) / 1000).ceil().clamp(0, 20);
    final progress = (_screenMs / _connectingTimeoutMs).clamp(0.0, 1.0);
    return Container(
      color: Hmi.bg,
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 92,
            height: 92,
            child: CircularProgressIndicator(
              strokeWidth: 9,
              valueColor: AlwaysStoppedAnimation(Hmi.accent),
              backgroundColor: Hmi.off,
            ),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _t('connecting_to', {'name': candidate?.name ?? 'device'}),
              style: const TextStyle(
                  fontSize: 40, fontWeight: FontWeight.w700, color: Hmi.ink),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _t('seconds_left', {'n': '$secondsLeft'}),
            style: const TextStyle(
                fontSize: 23, fontWeight: FontWeight.w500, color: Hmi.muted),
          ),
          const SizedBox(height: 18),
          HmiProgressBar(value: progress),
        ],
      ),
    );
  }

  Widget _buildTelemetry() {
    final oor = _outOfRange;
    final dm = _distanceText;
    return Container(
      color: Hmi.bg,
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 20),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: Hmi.cardBox(28),
              padding: const EdgeInsets.fromLTRB(36, 18, 36, 16),
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _t('distance_label'),
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.3,
                          color: Hmi.muted),
                    ),
                  ),
                  SizedBox(
                    height: 229,
                    child: Center(
                      child: oor
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(_t('out_of_range'),
                                      style: const TextStyle(
                                          fontSize: 112,
                                          fontWeight: FontWeight.w700,
                                          color: Hmi.ink,
                                          letterSpacing: -3)),
                                ),
                                const SizedBox(height: 10),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                      _t('no_train_within',
                                          {'n': '$_fullScaleM'}),
                                      style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w500,
                                          color: Hmi.muted)),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment:
                                  CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  dm,
                                  style: const TextStyle(
                                    fontSize: 248,
                                    fontWeight: FontWeight.w700,
                                    height: 0.9,
                                    color: Hmi.ink,
                                    letterSpacing: -10,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 16),
                                  child: Text(_t('unit_m'),
                                      style: const TextStyle(
                                          fontSize: 64,
                                          fontWeight: FontWeight.w600,
                                          color: Hmi.muted)),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const Spacer(),
                  Center(
                      child: HmiTrack(
                          fraction: _distanceFraction, outOfRange: oor)),
                  const SizedBox(height: 6),
                  Center(
                      child:
                          HmiTicks(fullScale: _fullScaleM, lang: _lang)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 84,
            child: Row(
              children: [
                HmiBtn(
                  label: _t('back'),
                  leading: const Icon(Icons.chevron_left,
                      size: 24, color: Hmi.ink),
                  onTap: _toChangeDevice,
                  width: 170,
                  height: 84,
                ),
                const Spacer(),
                HmiVolumeControl(
                  volume: volume,
                  muted: muted,
                  onMute: _toggleMute,
                  onDown: () => _changeVolume(-1),
                  onUp: () => _changeVolume(1),
                  lang: _lang,
                ),
                const Spacer(),
                HmiBtn(
                  label: _t('end_shunting'),
                  leading: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  onTap: _toEndShunting,
                  width: 260,
                  height: 84,
                  background: Hmi.red,
                  textColor: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: Hmi.bg,
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 108,
            height: 108,
            decoration:
                const BoxDecoration(shape: BoxShape.circle, color: Hmi.red),
            child: const Icon(Icons.close, size: 56, color: Colors.white),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_t('cant_connect'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: Hmi.ink)),
          ),
          const SizedBox(height: 10),
          Text(_t('check_device_on'),
              style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w500,
                  color: Hmi.muted)),
          const SizedBox(height: 24),
          HmiBtn(
            label: _t('back_to_list'),
            leading:
                const Icon(Icons.chevron_left, size: 24, color: Hmi.ink),
            onTap: _goDevices,
          ),
        ],
      ),
    );
  }

  Widget _buildCompleted() {
    final progress = (_screenMs / _completedHoldMs).clamp(0.0, 1.0);
    return Container(
      color: Hmi.bg,
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 108,
            height: 108,
            decoration:
                const BoxDecoration(shape: BoxShape.circle, color: Hmi.accent),
            child: const Icon(Icons.check, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_t('shunting_completed'),
                style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: Hmi.ink)),
          ),
          const SizedBox(height: 10),
          Text(_t('thank_you'),
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Hmi.accent)),
          const SizedBox(height: 6),
          Text(_t('device_disconnected'),
              style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w500,
                  color: Hmi.muted)),
          const SizedBox(height: 18),
          HmiProgressBar(value: progress),
        ],
      ),
    );
  }

  Widget _buildDialog() {
    late String title;
    late String body;
    String? chipText;
    String? note;
    late Color yesColor;
    late VoidCallback yesAction;
    late VoidCallback noAction;

    switch (screen) {
      case TabletScreen.confirmSelection:
        title = _t('confirm_selection_title');
        body = _t('confirm_selection_body');
        chipText = candidate?.name;
        yesColor = Hmi.accent;
        yesAction = _connectCandidate;
        noAction = _goDevices;
      case TabletScreen.changeDevice:
        title = _t('change_device_title');
        body = _t('change_device_body');
        chipText = _connectedName;
        note = _t('change_device_note');
        yesColor = Hmi.accent;
        yesAction = _changeDeviceYes;
        noAction = _toTelemetry;
      case TabletScreen.endShunting:
        title = _t('end_shunting_title');
        body = _t('end_shunting_body');
        yesColor = Hmi.red;
        yesAction = _finishShunting;
        noAction = _toTelemetry;
      default:
        return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          color: const Color(0x800F1F1B),
          alignment: Alignment.center,
          child: Container(
            width: 640,
            padding: const EdgeInsets.fromLTRB(36, 34, 36, 30),
            decoration: BoxDecoration(
              color: Hmi.card,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Hmi.ink,
                        height: 1.15)),
                const SizedBox(height: 10),
                Text(body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w500,
                        color: Hmi.muted)),
                if (chipText != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 4),
                    decoration: BoxDecoration(
                      color: Hmi.accentSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(chipText,
                        style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            color: Hmi.ink)),
                  ),
                ],
                if (note != null) ...[
                  const SizedBox(height: 10),
                  Text(note,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w500,
                          color: Hmi.muted)),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: HmiBtn(
                        label: _t('yes'),
                        onTap: yesAction,
                        height: 84,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        background: yesColor,
                        textColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: HmiBtn(
                        label: _t('no'),
                        onTap: noAction,
                        height: 84,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        background: Hmi.off,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildObstacle() {
    final dt = _distanceText;
    return Positioned.fill(
      child: Container(
        color: Hmi.red,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const WarningTriangle(),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_t('warning'),
                  style: const TextStyle(
                      fontSize: 92,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 3)),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_t('human_obstacle'),
                  style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                dt == 'OR'
                    ? _t('near_dead_end_range')
                    : _t('near_dead_end_at', {'n': dt}),
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HmiVolumeControl(
                  volume: volume,
                  muted: muted,
                  onMute: _toggleMute,
                  onDown: () => _changeVolume(-1),
                  onUp: () => _changeVolume(1),
                  onDark: true,
                  lang: _lang,
                ),
                const SizedBox(width: 20),
                HmiBtn(
                  label: _t('end_shunting'),
                  leading: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                        color: Hmi.red,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  onTap: _toEndShunting,
                  background: Colors.white,
                  textColor: Hmi.red,
                  fontWeight: FontWeight.w700,
                  height: 84,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharger() {
    return Positioned.fill(
      child: Container(
        color: Hmi.bg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 380,
              height: 150,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 340,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Hmi.ink, width: 8),
                      borderRadius: BorderRadius.circular(36),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: LayoutBuilder(
                      builder: (ctx, box) {
                        final fillW =
                            box.maxWidth * (battery / 100).clamp(0.0, 1.0);
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: fillW,
                            decoration: BoxDecoration(
                              color: Hmi.accent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    left: 340,
                    top: 39,
                    child: Container(
                      width: 14,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Hmi.ink,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: Center(
                        child: Icon(Icons.bolt,
                            size: 56, color: Color(0x990F1F1B))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_t('charger_plugged'),
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: Hmi.ink)),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${battery > 0 ? battery : "--"}%',
                  style: const TextStyle(
                      fontSize: 84,
                      fontWeight: FontWeight.w700,
                      color: Hmi.ink,
                      letterSpacing: -2),
                ),
                const SizedBox(width: 12),
                Text(_t('charged'),
                    style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        color: Hmi.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return HmiStatusBar(
      deviceName: _statusDevice,
      linkMode: 'GSM',
      healthBars: _healthBars,
      healthText: _healthText,
      batteryPct: tabletBattery,
      isCharging: _tabletCharging,
      isMuted: muted,
      lang: _lang,
      onSettings: _openQuickSettings,
    );
  }

  void _handleSystemBack() {
    if (_kioskStatus.maintenance) {
      SystemNavigator.pop();
      return;
    }
    if (_showQuickSettings) {
      _closeQuickSettings();
      return;
    }
    switch (screen) {
      case TabletScreen.telemetry:
      case TabletScreen.obstacleWarning:
        _toChangeDevice();
      case TabletScreen.endShunting:
      case TabletScreen.changeDevice:
        _toTelemetry();
      case TabletScreen.confirmSelection:
      case TabletScreen.connecting:
      case TabletScreen.error:
      case TabletScreen.shuntingCompleted:
        _goDevices();
      case TabletScreen.devices:
      case TabletScreen.splash:
      case TabletScreen.charger:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Indian Railways – Shunting Tablet',
      theme: ThemeData(
        scaffoldBackgroundColor: Hmi.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Hmi.accent,
          brightness: Brightness.light,
        ),
      ),
      home: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _handleSystemBack();
        },
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => Center(
                child: AspectRatio(
                  aspectRatio: 1024 / 600,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: 1024,
                      height: 600,
                      child: Stack(
                        children: [
                          Positioned.fill(child: _buildNativeScreen(_baseScreen)),
                          if (_isDialogScreen) _buildDialog(),
                          if (screen == TabletScreen.obstacleWarning)
                            _buildObstacle(),
                          if (screen == TabletScreen.charger)
                            _buildCharger(),
                          if (_showStatusBar) _buildStatusBar(),
                          if (_showQuickSettings)
                            QuickSettingsPanel(
                              lang: _lang,
                              brightness: _brightness,
                              onLangChanged: _setLanguage,
                              onBrightnessChanged: _setBrightness,
                              onClose: _closeQuickSettings,
                            ),
                          ..._kioskLayer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _kiosk.setOnChanged(null);
    _batterySub?.cancel();
    _tickTimer?.cancel();
    _beeper.dispose();
    _telemetryTimer?.cancel();
    _tabletStatusTimer?.cancel();
    _splashTimer?.cancel();
    _completedTimer?.cancel();
    api.dispose();
    super.dispose();
  }
}
