import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'models/device.dart';
import 'services/api_service.dart';
import 'widgets/device_card.dart';
import 'widgets/hud.dart';
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
  Timer? _telemetryTimer;
  List<ShuntingDevice> devices = [];
  ShuntingDevice? current;
  int page = 0;
  int volume = 5;
  int battery = 0;
  bool network = false;
  double distance = 0;
  bool obstacle = false;
  bool charger = false;
  bool shuntingCompleted = false;
  bool _devicesLoaded = false;
  bool _backendAvailable = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _pollTelemetry();
    _telemetryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollTelemetry(),
    );
    if (mounted) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => screen = TabletScreen.pairingP1);
      });
    }
  }

  Future<void> _pollTelemetry() async {
    try {
      final data = await api.fetchTelemetry();
      if (mounted) {
        _onTelemetryUpdate(data);
        setState(() {
          _devicesLoaded = true;
          _backendAvailable = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _devicesLoaded = true;
        _backendAvailable = false;
      });
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
    final device = ShuntingDevice(
      number: 1,
      name: deviceName.toString(),
      online: diagnostics['status'] == 'ONLINE',
      inUse: true,
      battery: (diagnostics['battery_pct'] as num?)?.toInt() ?? 0,
    );
    setState(() {
      devices = [device];
      current = device;
      distance = ((readings['distance_cm'] as num?)?.toDouble() ?? 0) / 100;
      battery = (diagnostics['battery_pct'] as num?)?.toInt() ?? 0;
      network = diagnostics['link_state'] == 'OK' ||
          diagnostics['link_state'] == 'CONNECTED';
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
    switch (screen) {
      case TabletScreen.splash:
        return const SplashScreen();
      case TabletScreen.pairingP1:
        return ReferenceScreen(
          asset: 'assets/images/01_Pairing_P1.png',
          onPrimary: () => setState(() => screen = TabletScreen.pairingP2),
        );
      case TabletScreen.pairingP2:
        return ReferenceScreen(
          asset: 'assets/images/05_Pairing_P2.png',
          onBack: () => setState(() => screen = TabletScreen.pairingP1),
          onPrimary: () => setState(() => screen = TabletScreen.pairingP3),
        );
      case TabletScreen.pairingP3:
        return ReferenceScreen(
          asset: 'assets/images/06_Pairing_P3.png',
          onBack: () => setState(() => screen = TabletScreen.pairingP2),
          onPrimary: () => setState(() => screen = TabletScreen.pairingP4),
        );
      case TabletScreen.pairingP4:
        return ReferenceScreen(
          asset: 'assets/images/07_Pairing_P4.png',
          onBack: () => setState(() => screen = TabletScreen.pairingP3),
          onPrimary: () => setState(() => screen = TabletScreen.pairingP5),
        );
      case TabletScreen.pairingP5:
        return ReferenceScreen(
          asset: 'assets/images/08_Pairing_P5.png',
          onBack: () => setState(() => screen = TabletScreen.pairingP4),
          onPrimary: () => setState(() => screen = current == null
              ? TabletScreen.error
              : TabletScreen.telemetry),
        );
      case TabletScreen.connecting:
        return const ReferenceScreen(asset: 'assets/images/02_Connecting.png');
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
        );
      case TabletScreen.error:
        return ReferenceScreen(
          asset: 'assets/images/03_Error.png',
          onPrimary: _pollTelemetry,
        );
      case TabletScreen.changeDevice:
        return ReferenceScreen(
          asset: 'assets/images/09_Change_Device.png',
          onBack: () => setState(() => screen = TabletScreen.telemetry),
          onPrimary: () => setState(() => screen = TabletScreen.confirmSelection),
        );
      case TabletScreen.confirmSelection:
        return ReferenceScreen(
          asset: 'assets/images/10_Confirm_Selection.png',
          onPrimary: () => setState(() => screen = TabletScreen.telemetry),
          onBack: () => setState(() => screen = TabletScreen.changeDevice),
        );
      case TabletScreen.endShunting:
        return ReferenceScreen(
          asset: 'assets/images/11_End_Shunting.png',
          onPrimary: finishShunting,
          onBack: () => setState(() => screen = TabletScreen.telemetry),
        );
      case TabletScreen.shuntingCompleted:
        return ReferenceScreen(
          asset: 'assets/images/12_Shunting_Completed.png',
          onPrimary: () => setState(() => screen = TabletScreen.devices),
        );
      case TabletScreen.charger:
        return ReferenceScreen(
          asset: 'assets/images/13_Charger_Plugged.png',
          onPrimary: toggleCharger,
          onBack: () => setState(() => screen = TabletScreen.telemetry),
        );
      case TabletScreen.obstacleWarning:
        return ReferenceScreen(
          asset: 'assets/images/14_Obstacle_Warning.png',
          onPrimary: () async {
            await clearObstacle();
            if (mounted) setState(() => screen = TabletScreen.telemetry);
          },
        );
      case TabletScreen.devices:
        return _devices();
    }
  }

  Widget _devices() {
    final start = page * 9;
    final visible = devices.skip(start).take(9).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(70, 80, 70, 65),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 630,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xff1e90ff)),
                    ),
                    child: const Text(
                      'AVAILABLE DEAD-ENDS',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 7,
                  child: SizedBox(
                    width: 130,
                    height: 38,
                    child: TextButton.icon(
                      onPressed: _pollTelemetry,
                      icon: const Icon(Icons.refresh, color: Color(0xff38d6ff)),
                      label: const Text(
                        'REFRESH',
                        style: TextStyle(color: Color(0xff38d6ff)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _devicesLoaded
                ? GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visible.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 14,
                      childAspectRatio: 2.8,
                    ),
                    itemBuilder: (context, index) {
                      final d = visible[index];
                      return DeviceCard(
                        device: d,
                        onTap: d.online && !d.inUse
                            ? () => connectDevice(d)
                            : null,
                      );
                    },
                  )
                : const Center(child: CircularProgressIndicator(color: Color(0xff1e90ff))),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: page > 0 ? () => setState(() => page--) : null,
                icon: const Icon(Icons.chevron_left, color: Color(0xff38d6ff)),
              ),
              Text("PAGE-${(page + 1).toString().padLeft(2, '0')}",
                  style: const TextStyle(fontSize: 18, color: Colors.white)),
              IconButton(
                onPressed: start + 9 < devices.length
                    ? () => setState(() => page++)
                    : null,
                icon: const Icon(Icons.chevron_right, color: Color(0xff38d6ff)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHud() => Positioned(
        top: 14,
        left: 60,
        right: 60,
        child: HUD(
          battery: battery,
          network: network,
          deviceOk: current != null,
          volume: volume,
          onVolumeDown: () {
            setState(() => volume = (volume - 1).clamp(0, 10));
            _volumePlayer.play(AssetSource('sounds/volume_down.wav'));
          },
          onVolumeUp: () {
            setState(() => volume = (volume + 1).clamp(0, 10));
            _volumePlayer.play(AssetSource('sounds/volume_up.wav'));
          },
        ),
      );

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
      home: Scaffold(
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
                      if (_backendAvailable &&
                          screen != TabletScreen.splash &&
                          screen != TabletScreen.charger &&
                          screen != TabletScreen.obstacleWarning &&
                          screen != TabletScreen.error &&
                          screen != TabletScreen.shuntingCompleted &&
                          screen != TabletScreen.pairingP1 &&
                          screen != TabletScreen.pairingP2 &&
                          screen != TabletScreen.pairingP3 &&
                          screen != TabletScreen.pairingP4 &&
                          screen != TabletScreen.pairingP5 &&
                          screen != TabletScreen.connecting)
                        _buildHud(),
                    ],
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
    api.dispose();
    super.dispose();
  }
}
