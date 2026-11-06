import 'package:audioplayers/audioplayers.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'models/device.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'widgets/reference_screen.dart';

enum TabletScreen {
  splash,
  pairingP1,
  pairingP2,
  pairingP3,
  pairingP4,
  pairingP5,
  connecting,
  telemetry,
  error,
  changeDevice,
  confirmSelection,
  endShunting,
  shuntingCompleted,
  charger,
  obstacleWarning,
  devices,
}

class ShuntingApp extends StatefulWidget {
  const ShuntingApp({super.key});

  @override
  State<ShuntingApp> createState() => _ShuntingAppState();
}

class _ShuntingAppState extends State<ShuntingApp> {
  TabletScreen screen = TabletScreen.splash;
  final api = ApiService();
  final AudioPlayer _volumePlayer = AudioPlayer();
  final Battery _tabletBattery = Battery();
  final Connectivity _connectivity = Connectivity();
  Timer? _telemetryTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  List<ShuntingDevice> devices = [];
  ShuntingDevice? current;
  int page = 0;
  int volume = 5;
  int battery = 0;
  int tabletBattery = 0;
  int gsmRssi = 0;
  bool network = false;
  bool tabletNetwork = false;
  double distance = 0;
  bool obstacle = false;
  bool charger = false;
  bool shuntingCompleted = false;
  DateTime? _lastTelemetryAt;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _volumePlayer.setAudioContext(
      AudioContextConfig(
        route: AudioContextConfigRoute.speaker,
        focus: AudioContextConfigFocus.gain,
        respectSilence: false,
      ).build(),
    );
    _init();
  }

  Future<void> _playVolumeSound(String asset) async {
    try {
      await SystemSound.play(SystemSoundType.click);
      final player = AudioPlayer();
      await player.setAudioContext(
        AudioContextConfig(
          route: AudioContextConfigRoute.speaker,
          focus: AudioContextConfigFocus.gain,
          respectSilence: false,
        ).build(),
      );
      await player.play(AssetSource(asset), volume: 1.0);
      Future<void>.delayed(const Duration(milliseconds: 500), player.dispose);
    } catch (error, stackTrace) {
      debugPrint('Unable to play volume feedback: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _init() async {
    await _refreshTabletStatus();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() => tabletNetwork = results.any(
              (result) => result != ConnectivityResult.none,
            ));
      }
    });
    await _pollTelemetry();
    _telemetryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollTelemetry(),
    );
    if (mounted) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            screen = current == null
                ? TabletScreen.devices
                : TabletScreen.pairingP1;
          });
        }
      });
    }
  }

  Future<void> _refreshTabletStatus() async {
    try {
      final level = await _tabletBattery.batteryLevel;
      final results = await _connectivity.checkConnectivity();
      if (mounted) {
        setState(() {
          tabletBattery = level;
          tabletNetwork =
              results.any((result) => result != ConnectivityResult.none);
        });
      }
    } catch (error) {
      debugPrint('Unable to read tablet status: $error');
    }
  }

  Future<void> _pollTelemetry() async {
    try {
      final data = await api.fetchTelemetry();
      if (mounted) {
        _onTelemetryUpdate(data);
        setState(() {
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          devices = [];
          current = null;
          battery = 0;
          gsmRssi = 0;
          network = false;
          _lastTelemetryAt = null;
          if (screen != TabletScreen.splash) {
            screen = TabletScreen.devices;
          }
        });
      }
    }
  }

  void _onTelemetryUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    final readings = data['readings'] is Map
        ? Map<String, dynamic>.from(data['readings'] as Map)
        : <String, dynamic>{};
    final diagnostics = data['diagnostics'] is Map
        ? Map<String, dynamic>.from(data['diagnostics'] as Map)
        : <String, dynamic>{};
    final deviceName = data['deviceId'] ?? data['device'] ?? 'UNKNOWN';
    final linkState = diagnostics['link_state']?.toString().toUpperCase();
    final isOnline = diagnostics['status']?.toString().toUpperCase() == 'ONLINE' &&
        (linkState == 'OK' || linkState == 'CONNECTED');
    if (deviceName == 'UNKNOWN' || !isOnline) {
      setState(() {
        devices = [];
        current = null;
        battery = 0;
        gsmRssi = 0;
        network = false;
        _lastTelemetryAt = null;
        if (screen != TabletScreen.splash) {
          screen = TabletScreen.devices;
        }
      });
      return;
    }
    final device = ShuntingDevice(
      number: 1,
      name: deviceName.toString(),
      online: isOnline,
      inUse: true,
      battery: (diagnostics['battery_pct'] as num?)?.toInt() ?? 0,
    );
    setState(() {
      devices = [device];
      current = device;
      distance = ((readings['distance_cm'] as num?)?.toDouble() ?? 0) / 100;
      battery = (diagnostics['battery_pct'] as num?)?.toInt() ?? 0;
      gsmRssi = (diagnostics['gsm_rssi'] as num?)?.toInt() ?? 0;
      network = diagnostics['link_state'] == 'OK' ||
          diagnostics['link_state'] == 'CONNECTED';
      _lastTelemetryAt = DateTime.now();
      obstacle = data['obstacle'] ?? false;
      charger = diagnostics['is_charging'] ?? false;
      shuntingCompleted = data['completed'] ?? false;
    });
    if (shuntingCompleted && screen == TabletScreen.telemetry) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => screen = TabletScreen.shuntingCompleted);
      });
    }
    if (obstacle && screen == TabletScreen.telemetry) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => screen = TabletScreen.obstacleWarning);
      });
    }
    if (charger && screen == TabletScreen.telemetry) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => screen = TabletScreen.charger);
      });
    }
  }

  Future<void> connectDevice(ShuntingDevice device) async {
    if (!device.online) return;
    setState(() => screen = TabletScreen.telemetry);
  }

  Future<void> finishShunting() async {
    if (mounted) setState(() {
      current?.inUse = false;
      current = null;
      distance = 0;
      screen = TabletScreen.devices;
    });
  }

  Future<void> triggerObstacle() async {
    setState(() => obstacle = true);
  }

  Future<void> clearObstacle() async {
    setState(() => obstacle = false);
  }

  Future<void> toggleCharger() async {
    setState(() => charger = !charger);
    if (charger) setState(() => screen = TabletScreen.charger);
  }

  Future<void> changeDeviceTo(ShuntingDevice device) async {
    if (device.online) setState(() {
      current = device;
      screen = TabletScreen.telemetry;
    });
  }

  Widget _buildScreen() {
    final volumeDown = () {
      setState(() => volume = (volume - 1).clamp(0, 10));
      _playVolumeSound('sounds/volume_down.wav');
    };
    final volumeUp = () {
      setState(() => volume = (volume + 1).clamp(0, 10));
      _playVolumeSound('sounds/volume_up.wav');
    };
    switch (screen) {
      case TabletScreen.splash:
        return const SplashScreen();
      case TabletScreen.pairingP1:
        return ReferenceScreen(
          asset: 'assets/images/01_Pairing_P1.png',
          onPrimary: () => setState(() => screen = TabletScreen.pairingP2),
          onPageNext: () => setState(() => screen = TabletScreen.pairingP2),
          overlay: _buildReferenceDevices(),
          onVolumeDown: volumeDown,
          onVolumeUp: volumeUp,
        );
      case TabletScreen.pairingP2:
        return ReferenceScreen(
          asset: 'assets/images/05_Pairing_P2.png',
          onBack: () => setState(() => screen = TabletScreen.pairingP1),
          onPrimary: () => setState(() => screen = TabletScreen.pairingP3),
          onPagePrevious: () => setState(() => screen = TabletScreen.pairingP1),
          onPageNext: () => setState(() => screen = TabletScreen.pairingP3),
          overlay: _buildReferenceDevices(),
          onVolumeDown: volumeDown,
          onVolumeUp: volumeUp,
        );
      case TabletScreen.pairingP3:
        return ReferenceScreen(
          asset: 'assets/images/06_Pairing_P3.png',
          onBack: () => setState(() => screen = TabletScreen.pairingP2),
          onPrimary: () => setState(() => screen = TabletScreen.pairingP4),
          onPagePrevious: () => setState(() => screen = TabletScreen.pairingP2),
          onPageNext: () => setState(() => screen = TabletScreen.pairingP4),
          overlay: _buildReferenceDevices(),
          onVolumeDown: volumeDown,
          onVolumeUp: volumeUp,
        );
      case TabletScreen.pairingP4:
        return ReferenceScreen(
          asset: 'assets/images/07_Pairing_P4.png',
          onBack: () => setState(() => screen = TabletScreen.pairingP3),
          onPrimary: () => setState(() => screen = TabletScreen.pairingP5),
          onPagePrevious: () => setState(() => screen = TabletScreen.pairingP3),
          onPageNext: () => setState(() => screen = TabletScreen.pairingP5),
          overlay: _buildReferenceDevices(),
          onVolumeDown: volumeDown,
          onVolumeUp: volumeUp,
        );
      case TabletScreen.pairingP5:
        return ReferenceScreen(
          asset: 'assets/images/08_Pairing_P5.png',
          onBack: () => setState(() => screen = TabletScreen.pairingP4),
          onPrimary: () => setState(() => screen = current == null
              ? TabletScreen.error
              : TabletScreen.telemetry),
          onPagePrevious: () => setState(() => screen = TabletScreen.pairingP4),
          overlay: _buildReferenceDevices(),
          onVolumeDown: volumeDown,
          onVolumeUp: volumeUp,
        );
      case TabletScreen.connecting:
        return ReferenceScreen(
          asset: 'assets/images/02_Connecting.png',
          onVolumeDown: volumeDown,
          onVolumeUp: volumeUp,
        );
      case TabletScreen.telemetry:
        return ReferenceScreen(
          asset: 'assets/images/04_Telemetry.png',
          onPrimary: () => setState(() => screen = TabletScreen.endShunting),
          overlay: Positioned(
            left: 0,
            right: 0,
            top: 235,
            child: Center(
              child: Text(
                '${distance.toStringAsFixed(0)} cm',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          onVolumeDown: volumeDown,
          onVolumeUp: volumeUp,
        );
      case TabletScreen.error:
        return ReferenceScreen(
          asset: 'assets/images/03_Error.png',
          onPrimary: _pollTelemetry,
          onVolumeDown: volumeDown,
          onVolumeUp: volumeUp,
        );
      case TabletScreen.changeDevice:
        return ReferenceScreen(
          asset: 'assets/images/09_Change_Device.png',
          onBack: () => setState(() => screen = TabletScreen.telemetry),
          onPrimary: () => setState(() => screen = TabletScreen.confirmSelection),
          onVolumeDown: volumeDown,
          onVolumeUp: volumeUp,
        );
      case TabletScreen.confirmSelection:
        return ReferenceScreen(
          asset: 'assets/images/10_Confirm_Selection.png',
          onPrimary: () => setState(() => screen = TabletScreen.telemetry),
          onBack: () => setState(() => screen = TabletScreen.changeDevice),
          onVolumeDown: volumeDown,
          onVolumeUp: volumeUp,
        );
      case TabletScreen.endShunting:
        return ReferenceScreen(
          asset: 'assets/images/11_End_Shunting.png',
          onPrimary: finishShunting,
          onBack: () => setState(() => screen = TabletScreen.telemetry),
          onVolumeDown: volumeDown,
          onVolumeUp: volumeUp,
        );
      case TabletScreen.shuntingCompleted:
        return ReferenceScreen(
          asset: 'assets/images/12_Shunting_Completed.png',
          onPrimary: () => setState(() => screen = TabletScreen.devices),
          onVolumeDown: volumeDown,
          onVolumeUp: volumeUp,
        );
      case TabletScreen.charger:
        return ReferenceScreen(
          asset: 'assets/images/13_Charger_Plugged.png',
          onPrimary: toggleCharger,
          onBack: () => setState(() => screen = TabletScreen.telemetry),
          onVolumeDown: volumeDown,
          onVolumeUp: volumeUp,
        );
      case TabletScreen.obstacleWarning:
        return ReferenceScreen(
          asset: 'assets/images/14_Obstacle_Warning.png',
          onPrimary: () async {
            await clearObstacle();
            if (mounted) setState(() => screen = TabletScreen.telemetry);
          },
          onVolumeDown: volumeDown,
          onVolumeUp: volumeUp,
        );
      case TabletScreen.devices:
        return _devices();
    }
  }

  Widget _devices() {
    final assets = [
      'assets/images/05_Pairing_P2.png',
      'assets/images/06_Pairing_P3.png',
      'assets/images/07_Pairing_P4.png',
      'assets/images/08_Pairing_P5.png',
    ];
    final visible = devices.skip(page * 9).take(9).toList();
    return ReferenceScreen(
      asset: assets[page.clamp(0, assets.length - 1)],
      hidePageNumber: true,
      onBack: () => setState(() => screen = TabletScreen.pairingP1),
      onPagePrevious: page > 0
          ? () => setState(() => page--)
          : null,
      onPageNext: page < assets.length - 1
          ? () => setState(() => page++)
          : null,
      onRefresh: _pollTelemetry,
      overlay: IgnorePointer(
        child: visible.isEmpty
            ? Positioned(
                left: 395,
                top: 315,
                width: 235,
                height: 72,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xdd02060c),
                    border: Border.all(
                      color: const Color(0xff38d6ff),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'NO LIVE\nTRANSMITTERS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            : Stack(
                children: [
                  for (var index = 0; index < visible.length; index++)
                    Positioned(
                      left: 110 + (index % 3) * 285,
                      top: 207 + (index ~/ 3) * 110,
                      width: 235,
                      child: Text(
                        '${visible[index].name}  ${visible[index].battery}%\nONLINE',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  bool get _telemetryIsFresh {
    final lastTelemetry = _lastTelemetryAt;
    return lastTelemetry != null &&
        DateTime.now().difference(lastTelemetry) <=
            const Duration(seconds: 3);
  }

  String get _signalLabel {
    if (!_telemetryIsFresh || !tabletNetwork || !network || gsmRssi == 0) {
      return 'NO SIGNAL';
    }
    if (gsmRssi >= -75) return 'STRONG';
    if (gsmRssi >= -95) return 'FAIR';
    if (gsmRssi >= -110) return 'WEAK';
    return 'NO SIGNAL';
  }

  Widget _buildReferenceStatus() {
    final deviceStatus =
        current != null && _telemetryIsFresh ? 'DEVICE OK' : 'DEVICE ERR';
    final networkStatus = _telemetryIsFresh && tabletNetwork && network
        ? 'CONNECTED'
        : 'OFFLINE';
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 34,
            left: 85,
            width: 170,
            child: _statusText('$tabletBattery%'),
          ),
          Positioned(
            top: 34,
            left: 285,
            width: 170,
            child: _statusText(_signalLabel),
          ),
          Positioned(
            top: 34,
            left: 485,
            width: 170,
            child: _statusText(deviceStatus),
          ),
          Positioned(
            top: 34,
            left: 685,
            width: 170,
            child: _statusText(networkStatus),
          ),
        ],
      ),
    );
  }

  Widget _statusText(String value) => Text(
        value,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );

  void _handleSystemBack() {
    switch (screen) {
      case TabletScreen.pairingP2:
        setState(() => screen = TabletScreen.pairingP1);
        return;
      case TabletScreen.pairingP3:
        setState(() => screen = TabletScreen.pairingP2);
        return;
      case TabletScreen.pairingP4:
        setState(() => screen = TabletScreen.pairingP3);
        return;
      case TabletScreen.pairingP5:
        setState(() => screen = TabletScreen.pairingP4);
        return;
      case TabletScreen.telemetry:
      case TabletScreen.error:
      case TabletScreen.changeDevice:
      case TabletScreen.endShunting:
      case TabletScreen.charger:
      case TabletScreen.obstacleWarning:
        setState(() => screen = TabletScreen.devices);
        return;
      case TabletScreen.devices:
      case TabletScreen.splash:
      case TabletScreen.pairingP1:
      case TabletScreen.connecting:
      case TabletScreen.confirmSelection:
      case TabletScreen.shuntingCompleted:
        return;
    }
  }

  Widget _buildReferenceDevices() {
    return IgnorePointer(
      child: Stack(
        children: [
          for (var index = 0;
              index < devices.length && index < 9;
              index++)
            Positioned(
              left: 110 + (index % 3) * 285,
              top: 207 + (index ~/ 3) * 110,
              width: 235,
              child: Text(
                '${devices[index].name}  ${devices[index].battery}%\n'
                '${devices[index].online ? 'ONLINE' : 'OFFLINE'}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Indian Railways – Shunting Tablet',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xff02060c),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff1e90ff),
          brightness: Brightness.dark,
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
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0xff07101c), Color(0xff02060c)],
                        radius: 0.9,
                      ),
                    ),
                    child: Stack(
                      children: [
                        _buildScreen(),
                        if (screen != TabletScreen.splash)
                          _buildReferenceStatus(),
                      ],
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
    _volumePlayer.dispose();
    _telemetryTimer?.cancel();
    _connectivitySubscription?.cancel();
    api.dispose();
    super.dispose();
  }
}
