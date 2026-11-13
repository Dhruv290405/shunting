import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shunting_tablet/app.dart';
import 'package:shunting_tablet/services/api_service.dart';
import 'package:shunting_tablet/services/beeper.dart';
import 'package:shunting_tablet/widgets/reference_screen.dart';

// Button centres in the 1024x600 reference space.
const _back = Offset(100, 540);
const _volDown = Offset(365, 540);
const _volUp = Offset(650, 540);
const _centre = Offset(510, 535);
const _primary = Offset(900, 540); // red END SHUNTING button
const _prevPage = Offset(40, 295);
const _nextPage = Offset(985, 295);
const _refresh = Offset(740, 132);
const _card0 = Offset(230, 225);
const _yesA = Offset(380, 395); // change-device YES
const _noA = Offset(645, 395);
const _yesB = Offset(380, 405); // confirm / end-shunting YES
const _noB = Offset(640, 405);

/// Records what the app asks the speaker to do (no audio in tests).
class FakeBeeper implements Beeper {
  int intervalMs = 0;
  bool continuous = false;
  int volume = -1;

  @override
  void update({
    required int intervalMs,
    required bool continuous,
    required int volume,
  }) {
    this.intervalMs = intervalMs;
    this.continuous = continuous;
    this.volume = volume;
  }

  @override
  void dispose() {}
}

int _readingId = 0;

/// Readings as the server returns them in `recent`, oldest first. Ids always
/// increase, like the database ids.
List<Map<String, dynamic>> _recent(List<int> cms) => [
      for (final cm in cms) {'id': ++_readingId, 'cm': cm, 'ageMs': 100},
    ];

Map<String, dynamic> _live({
  bool obstacle = false,
  bool charging = false,
  bool completed = false,
  String id = 'TX-01',
  int distanceCm = 250,
  int ageMs = 0,
  List<Map<String, dynamic>>? recent,
}) =>
    {
      'deviceId': id,
      'readings': {'distance_cm': distanceCm},
      'diagnostics': {
        'status': 'ONLINE',
        'link_state': 'OK',
        'battery_pct': 77,
        'gsm_rssi': -70,
        'is_charging': charging,
      },
      'obstacle': obstacle,
      'completed': completed,
      'ageSeconds': ageMs ~/ 1000,
      'ageMs': ageMs,
      if (recent != null) 'recent': recent,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/battery'),
      (call) async => call.method == 'getBatteryLevel' ? 80 : null,
    );
  });

  late Map<String, dynamic>? payload; // null => HTTP failure
  late FakeBeeper beeper;

  setUp(() {
    beeper = FakeBeeper();
    payload = _live();
  });

  ApiService fakeApi() => ApiService(
        client: MockClient((request) async {
          final body = payload;
          if (body == null) return http.Response('boom', 500);
          return http.Response(jsonEncode(body), 200);
        }),
      );

  String screenName(WidgetTester t) {
    final finder = find.byType(ReferenceScreen);
    if (finder.evaluate().isEmpty) return 'splash';
    return (t.widget(finder) as ReferenceScreen)
        .asset
        .split('/')
        .last
        .replaceAll('.png', '');
  }

  Future<void> tick(WidgetTester t, [int seconds = 1]) async {
    await t.pump(Duration(seconds: seconds));
    await t.pump();
  }

  Future<void> tapAt(WidgetTester t, Offset o) async {
    await t.tapAt(o);
    await t.pump();
  }

  Future<void> boot(WidgetTester t) async {
    t.view.physicalSize = const Size(1024, 600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(ShuntingApp(apiService: fakeApi(), beeper: beeper));
    await t.pump();
    expect(screenName(t), 'splash');
    await tick(t, 4); // splash timer + first polls
    await tick(t);
  }

  /// Select the live device, confirm, and wait for the connection. The
  /// receiver waits at least 3 s on the Connecting screen.
  Future<void> connect(WidgetTester t) async {
    await tapAt(t, _card0);
    expect(screenName(t), '10_Confirm_Selection');
    await tapAt(t, _yesB);
    expect(screenName(t), '02_Connecting');
    await tick(t, 2);
    expect(screenName(t), '02_Connecting');
    await tick(t, 2);
    expect(screenName(t), '04_Telemetry');
  }

  /// The number written in the centre pill.
  String volumeShown(WidgetTester t) =>
      t.widget<Text>(find.byKey(const Key('volume-readout'))).data!;

  // ---------------------------------------------------------------------
  // Pairing list and connecting
  // ---------------------------------------------------------------------

  testWidgets('splash leaves to the device list even when offline', (t) async {
    payload = null;
    await boot(t);
    expect(screenName(t), '01_Pairing_P1');
    // Refresh, page arrows and back are inert/harmless with no devices.
    await tapAt(t, _refresh);
    await tapAt(t, _nextPage);
    await tapAt(t, _prevPage);
    await tapAt(t, _back);
    await tapAt(t, _card0);
    expect(screenName(t), '01_Pairing_P1');
  });

  testWidgets('live device is listed, selected, confirmed and connected',
      (t) async {
    await boot(t);
    expect(screenName(t), '01_Pairing_P1');
    expect(find.textContaining('TX-01'), findsOneWidget);

    await tapAt(t, _card0);
    expect(screenName(t), '10_Confirm_Selection');
    expect(find.text('TX-01'), findsOneWidget);

    // NO returns to the list.
    await tapAt(t, _noB);
    expect(screenName(t), '01_Pairing_P1');

    await connect(t);
    expect(find.text('3'), findsOneWidget); // 250 cm -> whole metres
  });

  testWidgets(
      'connecting times out after 20 s, shows the error 3 s, then the list',
      (t) async {
    await boot(t);
    await tapAt(t, _card0);
    await tapAt(t, _yesB);
    // The selected transmitter stops being the one that reports.
    payload = _live(id: 'TX-02');
    await tick(t, 19);
    expect(screenName(t), '02_Connecting');
    await tick(t, 2);
    expect(screenName(t), '03_Error');
    await tick(t, 4); // error hold is 3 s
    expect(screenName(t), '01_Pairing_P1');
    expect(find.text('--'), findsNWidgets(3)); // nothing connected
  });

  testWidgets('a slow connection still recovers while the error is shown',
      (t) async {
    await boot(t);
    await tapAt(t, _card0);
    await tapAt(t, _yesB);
    payload = _live(id: 'TX-02');
    await tick(t, 21);
    expect(screenName(t), '03_Error');

    payload = _live(); // the selected transmitter is heard after all
    await tick(t, 1);
    await t.pump(const Duration(milliseconds: 300));
    await t.pump();
    expect(screenName(t), '04_Telemetry');
    expect(find.text('TX-01'), findsOneWidget);
  });

  testWidgets('back on connecting returns to the list', (t) async {
    await boot(t);
    await tapAt(t, _card0);
    await tapAt(t, _yesB);
    await tapAt(t, _back);
    expect(screenName(t), '01_Pairing_P1');
  });

  // ---------------------------------------------------------------------
  // Telemetry controls
  // ---------------------------------------------------------------------

  testWidgets('change device: Back arrow opens it, YES disconnects, NO stays',
      (t) async {
    await boot(t);
    await connect(t);

    await tapAt(t, _centre); // the centre pill is not a button
    expect(screenName(t), '04_Telemetry');

    await tapAt(t, _back);
    expect(screenName(t), '09_Change_Device');
    // The status bar and the dialog both name the device.
    expect(find.text('TX-01'), findsNWidgets(2));
    await tapAt(t, _noA);
    expect(screenName(t), '04_Telemetry');

    await tapAt(t, _back);
    await tapAt(t, _back); // Back in the dialog also returns
    expect(screenName(t), '04_Telemetry');

    await tapAt(t, _back);
    await tapAt(t, _yesA);
    expect(screenName(t), '01_Pairing_P1');
    // The connection was closed right away (receiver: GSM_Disconnect, "--").
    expect(find.text('--'), findsNWidgets(3));
    await tick(t, 1);
    expect(beeper.intervalMs, 0);
  });

  testWidgets(
      'end shunting: red button, NO returns, YES completes then restarts',
      (t) async {
    await boot(t);
    await connect(t);

    await tapAt(t, _primary);
    expect(screenName(t), '11_End_Shunting');
    await tapAt(t, _noB);
    expect(screenName(t), '04_Telemetry');

    await tapAt(t, _primary);
    await tapAt(t, _yesB);
    expect(screenName(t), '12_Shunting_Completed');
    expect(find.text('--'), findsNWidgets(3)); // disconnected

    await tick(t, 1);
    expect(screenName(t), '12_Shunting_Completed'); // held for 2 s
    await tick(t, 2);
    expect(screenName(t), 'splash'); // back to the start-up screen
    await tick(t, 3);
    expect(screenName(t), '01_Pairing_P1');
  });

  testWidgets('back on the completed screen goes straight to the list',
      (t) async {
    await boot(t);
    await connect(t);
    await tapAt(t, _primary);
    await tapAt(t, _yesB);
    await tapAt(t, _back);
    expect(screenName(t), '01_Pairing_P1');
  });

  testWidgets('system back button follows the receiver screen flow', (t) async {
    await boot(t);
    await connect(t);
    Future<void> systemBack() async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
        (_) {},
      );
      await t.pump();
    }

    await systemBack();
    expect(screenName(t), '09_Change_Device');
    await systemBack();
    expect(screenName(t), '04_Telemetry');
  });

  // ---------------------------------------------------------------------
  // Volume
  // ---------------------------------------------------------------------

  testWidgets('volume is a percentage in 10% steps shown in the centre pill',
      (t) async {
    await boot(t);
    expect(volumeShown(t), '50'); // receiver default

    await tapAt(t, _volDown);
    expect(volumeShown(t), '40');
    await tapAt(t, _volUp);
    await tapAt(t, _volUp);
    expect(volumeShown(t), '60');
    for (var i = 0; i < 12; i++) {
      await tapAt(t, _volUp);
    }
    expect(volumeShown(t), '100');
    for (var i = 0; i < 12; i++) {
      await tapAt(t, _volDown);
    }
    expect(volumeShown(t), '0');

    await connect(t);
    expect(volumeShown(t), '0'); // also on telemetry
    expect(find.byKey(const Key('volume-osd')), findsNothing); // no popup
  });

  test('speaker gain curve: mute at 0, full at 100, monotonic, quiet low steps',
      () {
    expect(Beeper.gainForVolume(0), 0);
    expect(Beeper.gainForVolume(100), 1);
    expect(Beeper.gainForVolume(50), closeTo(0.25, 1e-9));
    var last = -1.0;
    for (var v = 0; v <= 100; v += 10) {
      final g = Beeper.gainForVolume(v);
      expect(g, greaterThan(last));
      last = g;
    }
    expect(Beeper.gainForVolume(500), 1); // clamped
  });

  // ---------------------------------------------------------------------
  // Status bar, distance
  // ---------------------------------------------------------------------

  testWidgets(
      'status bar follows the receiver: device, health, GSM, tablet battery',
      (t) async {
    await boot(t);
    // Nothing connected yet: device, health and link type are not claimed.
    expect(find.text('--'), findsNWidgets(3));
    expect(find.text('80%'), findsOneWidget); // tablet battery, not the device's

    await connect(t);
    expect(find.text('TX-01'), findsOneWidget); // which device we are connected to
    expect(find.text('BEST'), findsOneWidget);
    expect(find.text('GSM'), findsOneWidget);
    expect(find.text('--'), findsNothing);
    expect(find.text('80%'), findsOneWidget);
  });

  testWidgets('health: BEST within 2 s, GOOD up to the 15 s stale limit',
      (t) async {
    await boot(t);
    await connect(t);

    payload = _live(ageMs: 3000);
    await tick(t);
    expect(find.text('GOOD'), findsOneWidget);

    payload = _live(ageMs: 14000);
    await tick(t);
    expect(find.text('GOOD'), findsOneWidget);

    payload = _live(ageMs: 500);
    await tick(t);
    expect(find.text('BEST'), findsOneWidget);
  });

  testWidgets('distance text: whole metres, OR beyond range, per-device range',
      (t) async {
    payload = _live(id: 'TX-12', distanceCm: 18000);
    await boot(t);
    await connect(t);
    expect(find.text('OR'), findsOneWidget); // 180 m > TX-12's 44 m limit

    payload = _live(id: 'TX-12', distanceCm: 4400);
    await tick(t);
    expect(find.text('44'), findsOneWidget);

    payload = _live(id: 'TX-12', distanceCm: 1234);
    await tick(t);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('TX-09 has the 180 m LiDAR range like the receiver', (t) async {
    payload = _live(id: 'TX-09', distanceCm: 17000);
    await boot(t);
    await connect(t);
    expect(find.text('170'), findsOneWidget);
    payload = _live(id: 'TX-09', distanceCm: 18000);
    await tick(t);
    expect(find.text('OR'), findsOneWidget);
  });

  // ---------------------------------------------------------------------
  // Link loss: stay on telemetry, DC + alarm (receiver BothLinksDown)
  // ---------------------------------------------------------------------

  testWidgets('a short outage changes nothing', (t) async {
    await boot(t);
    await connect(t);

    payload = null;
    await tick(t, 8);
    expect(screenName(t), '04_Telemetry');
    expect(find.text('DC'), findsNothing);
    expect(find.text('BEST'), findsNothing); // aging, but still linked
    expect(beeper.continuous, false);

    payload = _live();
    await tick(t, 3);
    expect(screenName(t), '04_Telemetry');
    expect(find.text('BEST'), findsOneWidget);
  });

  testWidgets(
      'link loss shows the Error page with a steady alarm and recovers by itself',
      (t) async {
    await boot(t);
    await connect(t);
    await tick(t, 2);
    expect(beeper.intervalMs, 150);

    payload = null;
    await tick(t, 17); // > 15 s without a transmitter message
    expect(screenName(t), '03_Error'); // "check if device is turned on"
    expect(find.text('--'), findsNWidgets(2)); // health and link type
    expect(find.text('TX-01'), findsOneWidget); // still the connected device
    expect(beeper.continuous, true);

    // Unlike a failed connection attempt, it does not time out to the list.
    await tick(t, 30);
    expect(screenName(t), '03_Error');
    expect(beeper.continuous, true);

    // The transmitter comes back: straight back to live telemetry.
    payload = _live();
    await tick(t, 3);
    expect(screenName(t), '04_Telemetry');
    expect(find.text('3'), findsOneWidget);
    expect(find.text('BEST'), findsOneWidget);
    expect(beeper.continuous, false);
    expect(beeper.intervalMs, 150);
  });

  testWidgets('link loss during the obstacle warning also shows the Error page',
      (t) async {
    await boot(t);
    await connect(t);
    payload = _live(obstacle: true);
    await tick(t);
    expect(screenName(t), '14_Obstacle_Warning');

    payload = null;
    await tick(t, 17);
    expect(screenName(t), '03_Error');
    expect(beeper.continuous, true);
  });

  testWidgets('Back on the link-lost Error page disconnects and goes to the list',
      (t) async {
    await boot(t);
    await connect(t);
    payload = null;
    await tick(t, 17);
    expect(screenName(t), '03_Error');

    await tapAt(t, _back);
    expect(screenName(t), '01_Pairing_P1');
    expect(find.text('--'), findsNWidgets(3)); // disconnected
    await tick(t, 2);
    expect(beeper.continuous, false);
    expect(beeper.intervalMs, 0);
  });

  testWidgets('out of range (OR) is only a label: no Error page', (t) async {
    payload = _live(id: 'TX-12', distanceCm: 18000);
    await boot(t);
    await connect(t);
    await tick(t, 20);
    expect(screenName(t), '04_Telemetry');
    expect(find.text('OR'), findsOneWidget);
    expect(beeper.intervalMs, 0);
    expect(beeper.continuous, false);
  });

  testWidgets('the transmitter reported offline is dropped from the list',
      (t) async {
    await boot(t);
    expect(find.textContaining('TX-01'), findsOneWidget);
    payload = {
      ..._live(),
      'diagnostics': {
        'status': 'OFFLINE',
        'link_state': 'LOST',
        'battery_pct': 0,
      },
    };
    await tick(t, 2);
    expect(find.textContaining('TX-01'), findsNothing);
    expect(find.text('NO LIVE\nTRANSMITTERS'), findsOneWidget);
  });

  // ---------------------------------------------------------------------
  // Obstacle (receiver TickObstacleOverlay), from the distance stream
  // ---------------------------------------------------------------------

  testWidgets(
      'obstacle warning: sudden drop to 5 m or less, hysteresis, clears above 6 m',
      (t) async {
    payload = _live(distanceCm: 3000, recent: _recent([3000]));
    await boot(t);
    await connect(t);
    await tick(t); // baseline reading

    // A normal approach (small steps) never triggers it.
    for (final cm in [2600, 2200, 1500, 1100, 700, 400]) {
      payload = _live(distanceCm: cm, recent: _recent([cm]));
      await tick(t);
      expect(screenName(t), '04_Telemetry', reason: 'approach at $cm cm');
    }

    // Two readings arrive within one poll. Only the full sequence shows the
    // sudden 27 m drop: the newest reading alone (300) is just 1 m below the
    // previous poll (400).
    payload = _live(distanceCm: 300, recent: _recent([3000, 300]));
    await tick(t);
    expect(screenName(t), '14_Obstacle_Warning');
    expect(beeper.intervalMs, 150); // the buzzer keeps going under the overlay

    // Still at 5-6 m: the warning holds (hysteresis).
    payload = _live(distanceCm: 550, recent: _recent([550]));
    await tick(t);
    expect(screenName(t), '14_Obstacle_Warning');

    // Clears above 6 m.
    payload = _live(distanceCm: 700, recent: _recent([700]));
    await tick(t);
    expect(screenName(t), '04_Telemetry');
  });

  testWidgets('obstacle also works against a server without the recent list',
      (t) async {
    payload = _live(distanceCm: 3000);
    await boot(t);
    await connect(t);
    await tick(t);
    payload = _live(distanceCm: 300);
    await tick(t);
    expect(screenName(t), '14_Obstacle_Warning');
  });

  testWidgets('a repeated recent list is not processed twice', (t) async {
    final list = _recent([3000]);
    payload = _live(distanceCm: 3000, recent: list);
    await boot(t);
    await connect(t);
    await tick(t, 3); // the same reading is served on every poll
    expect(screenName(t), '04_Telemetry');
  });

  testWidgets(
      'obstacle screen: Back opens change device, red button ends shunting',
      (t) async {
    await boot(t);
    await connect(t);
    // The first reading of a session is only a baseline (receiver rule).
    payload = _live(distanceCm: 3000, recent: _recent([3000]));
    await tick(t, 2);
    payload = _live(distanceCm: 300, recent: _recent([300]));
    await tick(t);
    expect(screenName(t), '14_Obstacle_Warning');

    await tapAt(t, _primary);
    expect(screenName(t), '11_End_Shunting');
    await tapAt(t, _noB);
    expect(screenName(t), '04_Telemetry'); // overlay only covers telemetry

    payload = _live(distanceCm: 3000, recent: _recent([3000]));
    await tick(t, 2);
    payload = _live(distanceCm: 300, recent: _recent([300]));
    await tick(t);
    expect(screenName(t), '14_Obstacle_Warning');
    await tapAt(t, _back);
    expect(screenName(t), '09_Change_Device');
  });

  testWidgets('a device-reported obstacle flag still raises the warning',
      (t) async {
    await boot(t);
    await connect(t);
    payload = _live(obstacle: true);
    await tick(t);
    expect(screenName(t), '14_Obstacle_Warning');
    payload = _live();
    await tick(t);
    expect(screenName(t), '04_Telemetry');
  });

  // ---------------------------------------------------------------------
  // Charger / device-reported completion
  // ---------------------------------------------------------------------

  testWidgets('charger screen shows battery and clears when unplugged',
      (t) async {
    await boot(t);
    await connect(t);

    payload = _live(charging: true);
    await tick(t);
    expect(screenName(t), '13_Charger_Plugged');
    expect(find.text('77'), findsOneWidget);

    payload = _live();
    await tick(t);
    expect(screenName(t), '04_Telemetry');
  });

  testWidgets('device-reported completion shows completed once (edge)',
      (t) async {
    await boot(t);
    await connect(t);

    payload = _live(completed: true);
    await tick(t);
    expect(screenName(t), '12_Shunting_Completed');
    await tapAt(t, _back);
    expect(screenName(t), '01_Pairing_P1');

    // The stale "completed" flag must not bounce a new session.
    await connect(t);
    await tick(t, 3);
    expect(screenName(t), '04_Telemetry');
  });

  // ---------------------------------------------------------------------
  // Beeper (receiver TickBuzzer)
  // ---------------------------------------------------------------------

  testWidgets('beeper cadence follows distance like the receiver buzzer',
      (t) async {
    await boot(t);
    // Not connected: nothing sounds, even when the operator touches buttons.
    await tapAt(t, _volUp);
    await tapAt(t, _card0);
    await tapAt(t, _noB);
    await tick(t, 2);
    expect(beeper.intervalMs, 0);
    expect(beeper.continuous, false);

    await connect(t);
    // distance (cm) -> beep interval (ms)
    for (final entry in {
      250: 150, // < 5 m
      700: 200, // < 10 m
      1500: 250, // < 20 m
      3000: 400, // 20 m .. range limit
      4400: 400,
      4500: 0, // out of range: silent
    }.entries) {
      payload = _live(distanceCm: entry.key);
      await tick(t, 2);
      expect(beeper.intervalMs, entry.value, reason: '${entry.key} cm');
      expect(beeper.continuous, false);
    }
  });

  testWidgets('beeper follows the volume, and is silent on dialogs', (t) async {
    await boot(t);
    await connect(t);
    await tick(t, 2);
    expect(beeper.intervalMs, 150);
    expect(beeper.volume, 50);

    // The volume buttons only change the loudness of the beeps.
    await tapAt(t, _volUp);
    await tapAt(t, _volUp);
    await tick(t, 1);
    expect(beeper.volume, 70);
    expect(beeper.intervalMs, 150);
    for (var i = 0; i < 8; i++) {
      await tapAt(t, _volDown);
    }
    await tick(t, 1);
    expect(beeper.volume, 0);

    // Silent while a dialog (not live telemetry) is showing.
    await tapAt(t, _primary);
    expect(screenName(t), '11_End_Shunting');
    await tick(t, 1);
    expect(beeper.intervalMs, 0);
    await tapAt(t, _noB);
    await tick(t, 1);
    expect(beeper.intervalMs, 150);
  });

  // ---------------------------------------------------------------------
  // Api service
  // ---------------------------------------------------------------------

  test('ApiService unwraps Lambda-style {"body": "<json>"} responses', () async {
    final api = ApiService(
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'statusCode': 200,
              'body': jsonEncode({'deviceId': 'X'}),
            }),
            200,
          )),
    );
    expect((await api.fetchTelemetry())['deviceId'], 'X');
  });

  test('ApiService sends the deviceId the Lambda requires', () async {
    Uri? seen;
    final api = ApiService(
      deviceId: 'TX-07',
      client: MockClient((request) async {
        seen = request.url;
        return http.Response(jsonEncode({'deviceId': 'TX-07'}), 200);
      }),
    );
    await api.fetchTelemetry();
    expect(seen!.queryParameters[ApiService.deviceIdParam], 'TX-07');
  });

  test('ApiService throws on HTTP errors and non-object bodies', () async {
    final bad = ApiService(
        client: MockClient((_) async => http.Response('nope', 400)));
    expect(bad.fetchTelemetry(), throwsException);
    final list =
        ApiService(client: MockClient((_) async => http.Response('[]', 200)));
    expect(list.fetchTelemetry(), throwsException);
  });
}
