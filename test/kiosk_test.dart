import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shunting_tablet/app.dart';
import 'package:shunting_tablet/services/api_service.dart';
import 'package:shunting_tablet/services/beeper.dart';
import 'package:shunting_tablet/services/kiosk.dart';
import 'package:shunting_tablet/services/pin_store.dart';
import 'package:shunting_tablet/widgets/reference_screen.dart';

class _SilentBeeper implements Beeper {
  @override
  void update({
    required int intervalMs,
    required bool continuous,
    required int volume,
  }) {}

  @override
  void dispose() {}
}

class FakeKiosk implements KioskController {
  KioskStatus current;
  final calls = <String>[];
  VoidCallback? onChanged;

  FakeKiosk({this.current = const KioskStatus()});

  @override
  Future<KioskStatus> status() async => current;

  @override
  Future<KioskStatus> enterMaintenance() async {
    calls.add('enterMaintenance');
    current = KioskStatus(
        deviceOwner: current.deviceOwner, maintenance: true, locked: false);
    return current;
  }

  @override
  Future<KioskStatus> lockNow() async {
    calls.add('lockNow');
    current = KioskStatus(
        deviceOwner: current.deviceOwner,
        maintenance: false,
        locked: current.deviceOwner);
    return current;
  }

  @override
  Future<bool> openSettings() async {
    calls.add('openSettings');
    return true;
  }

  @override
  Future<bool> openWifiSettings() async {
    calls.add('openWifiSettings');
    return true;
  }

  @override
  Future<KioskStatus> decommission() async {
    calls.add('decommission');
    current = const KioskStatus();
    return current;
  }

  @override
  void setOnChanged(VoidCallback? callback) => onChanged = callback;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/battery'),
      (call) async => call.method == 'getBatteryLevel' ? 80 : null,
    );
  });

  late FakeKiosk kiosk;
  const livePayload = {
    'deviceId': 'TX-01',
    'readings': {'distance_cm': 250},
    'diagnostics': {
      'status': 'ONLINE',
      'link_state': 'OK',
      'battery_pct': 77,
    },
    'ageMs': 0,
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    kiosk = FakeKiosk();
  });

  Future<void> boot(WidgetTester t) async {
    t.view.physicalSize = const Size(1024, 600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(ShuntingApp(
      apiService: ApiService(
        client: MockClient(
            (_) async => http.Response(jsonEncode(livePayload), 200)),
      ),
      beeper: _SilentBeeper(),
      kiosk: kiosk,
      pinStore: PinStore(),
    ));
    await t.pump();
    await t.pump(const Duration(seconds: 5));
    await t.pump(const Duration(seconds: 1));
    await t.pump();
  }

  String screenName(WidgetTester t) {
    final finder = find.byType(ReferenceScreen);
    if (finder.evaluate().isEmpty) return 'splash';
    return (t.widget(finder) as ReferenceScreen)
        .asset
        .split('/')
        .last
        .replaceAll('.png', '');
  }

  Future<void> holdGate(WidgetTester t, {int seconds = 5}) async {
    final gesture = await t.startGesture(const Offset(30, 30));
    await t.pump(Duration(seconds: seconds));
    await gesture.up();
    await t.pump();
  }

  Future<void> typePin(WidgetTester t, String pin) async {
    for (final d in pin.split('')) {
      await t.tap(find.byKey(Key('pin-$d')));
      await t.pump();
    }
    await t.tap(find.byKey(const Key('pin-ok')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }

  String pinError(WidgetTester t) =>
      t.widget<Text>(find.byKey(const Key('pin-error'))).data ?? '';

  Future<void> unlock(WidgetTester t, [String pin = '2580']) async {
    await holdGate(t);
    await typePin(t, pin);
  }

  testWidgets('the hidden corner needs a full 5 s hold', (t) async {
    await boot(t);
    expect(find.byKey(const Key('pin-dots')), findsNothing);

    await holdGate(t, seconds: 3); // released too early
    expect(find.byKey(const Key('pin-dots')), findsNothing);

    await holdGate(t);
    expect(find.byKey(const Key('pin-dots')), findsOneWidget);
    expect(find.text('ENTER PIN'), findsOneWidget);
    // The corner itself is not reachable while a panel is up.
    expect(find.byKey(const Key('kiosk-gate')), findsNothing);
  });

  testWidgets('cancel closes the PIN pad without unlocking', (t) async {
    await boot(t);
    await holdGate(t);
    await t.tap(find.byKey(const Key('pin-cancel')));
    await t.pump();
    expect(find.byKey(const Key('pin-dots')), findsNothing);
    expect(kiosk.calls, isEmpty);
  });

  testWidgets('a wrong PIN is rejected and nothing is unlocked', (t) async {
    await boot(t);
    await holdGate(t);
    await typePin(t, '1111');
    expect(pinError(t), 'WRONG PIN');
    expect(kiosk.calls, isEmpty);
    expect(find.byKey(const Key('maintenance-banner')), findsNothing);
  });

  testWidgets('a PIN shorter than 4 digits is not submitted', (t) async {
    await boot(t);
    await holdGate(t);
    await typePin(t, '12');
    expect(pinError(t), startsWith('AT LEAST'));
    expect(kiosk.calls, isEmpty);
  });

  testWidgets('five wrong PINs lock entry for 30 s, then it works again',
      (t) async {
    await boot(t);
    await holdGate(t);
    for (var i = 0; i < 4; i++) {
      await typePin(t, '1111');
      expect(pinError(t), 'WRONG PIN');
    }
    await typePin(t, '1111');
    expect(pinError(t), startsWith('TOO MANY TRIES'));

    // Even the right PIN is refused while locked out.
    await typePin(t, '2580');
    expect(pinError(t), startsWith('TOO MANY TRIES'));
    expect(kiosk.calls, isEmpty);

    await t.pump(const Duration(seconds: 31));
    await typePin(t, '2580');
    expect(kiosk.calls, ['enterMaintenance']);
    expect(find.text('MAINTENANCE MODE'), findsOneWidget);
  });

  testWidgets('correct PIN enters maintenance: menu and banner appear',
      (t) async {
    await boot(t);
    await unlock(t);
    expect(kiosk.calls, ['enterMaintenance']);
    expect(find.text('MAINTENANCE MODE'), findsOneWidget);
    expect(find.byKey(const Key('menu-not-provisioned')), findsOneWidget);
    expect(find.byKey(const Key('maintenance-banner')), findsOneWidget);
  });

  testWidgets('closing the menu keeps the tablet unlocked, with no timer',
      (t) async {
    await boot(t);
    await unlock(t);
    await t.tap(find.byKey(const Key('menu-close')));
    await t.pump();
    expect(find.text('MAINTENANCE MODE'), findsNothing);
    expect(find.byKey(const Key('maintenance-banner')), findsOneWidget);

    // Hours pass: nothing re-locks by itself.
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(minutes: 30));
    }
    expect(find.byKey(const Key('maintenance-banner')), findsOneWidget);
    expect(kiosk.calls, ['enterMaintenance']);
  });

  testWidgets('LOCK TABLET NOW in the menu locks again without a PIN',
      (t) async {
    await boot(t);
    await unlock(t);
    await t.tap(find.byKey(const Key('menu-lock')));
    await t.pump();
    expect(kiosk.calls, ['enterMaintenance', 'lockNow']);
    expect(find.byKey(const Key('maintenance-banner')), findsNothing);
    expect(find.text('MAINTENANCE MODE'), findsNothing);
    // Unlocking again needs the PIN again.
    await holdGate(t);
    expect(find.text('ENTER PIN'), findsOneWidget);
  });

  testWidgets('LOCK NOW on the banner locks again', (t) async {
    await boot(t);
    await unlock(t);
    await t.tap(find.byKey(const Key('menu-close')));
    await t.pump();
    await t.tap(find.byKey(const Key('banner-lock')));
    await t.pump();
    expect(kiosk.calls.last, 'lockNow');
    expect(find.byKey(const Key('maintenance-banner')), findsNothing);
  });

  testWidgets('a tablet that restarted while unlocked is still unlocked',
      (t) async {
    kiosk = FakeKiosk(current: const KioskStatus(maintenance: true));
    await boot(t);
    expect(find.byKey(const Key('maintenance-banner')), findsOneWidget);
  });

  testWidgets('the notification action (LOCK NOW) updates the screen',
      (t) async {
    await boot(t);
    await unlock(t);
    await t.tap(find.byKey(const Key('menu-close')));
    await t.pump();
    expect(find.byKey(const Key('maintenance-banner')), findsOneWidget);

    // Android locked the tablet and tells the app.
    kiosk.current = const KioskStatus(deviceOwner: true, locked: true);
    kiosk.onChanged!();
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('maintenance-banner')), findsNothing);
  });

  testWidgets('Wi-Fi and Android settings are reachable from the menu',
      (t) async {
    await boot(t);
    await unlock(t);
    await t.tap(find.byKey(const Key('menu-wifi')));
    await t.tap(find.byKey(const Key('menu-settings')));
    await t.pump();
    expect(
        kiosk.calls, ['enterMaintenance', 'openWifiSettings', 'openSettings']);
  });

  testWidgets('a provisioned tablet does not show the not-set-up warning',
      (t) async {
    kiosk =
        FakeKiosk(current: const KioskStatus(deviceOwner: true, locked: true));
    await boot(t);
    await unlock(t);
    expect(find.byKey(const Key('menu-not-provisioned')), findsNothing);
  });

  testWidgets('change PIN: confirmation must match, old PIN stops working',
      (t) async {
    await boot(t);
    await unlock(t);
    await t.tap(find.byKey(const Key('menu-change-pin')));
    await t.pump();
    expect(find.text('NEW PIN'), findsOneWidget);
    await typePin(t, '4321');
    expect(find.text('CONFIRM NEW PIN'), findsOneWidget);

    await typePin(t, '9999'); // mismatch
    expect(pinError(t), 'PINS DO NOT MATCH');
    await typePin(t, '4321');
    expect(find.byKey(const Key('menu-message')), findsOneWidget);
    expect(find.text('PIN CHANGED'), findsOneWidget);

    // Lock, then the old PIN is refused and the new one accepted.
    await t.tap(find.byKey(const Key('menu-lock')));
    await t.pump();
    await holdGate(t);
    await typePin(t, '2580');
    expect(pinError(t), 'WRONG PIN');
    await typePin(t, '4321');
    expect(find.text('MAINTENANCE MODE'), findsOneWidget);
  });

  testWidgets('the PIN is stored hashed, never in clear', (t) async {
    await boot(t);
    await unlock(t);
    await t.tap(find.byKey(const Key('menu-change-pin')));
    await t.pump();
    await typePin(t, '4321');
    await typePin(t, '4321');
    final prefs = await SharedPreferences.getInstance();
    final all = prefs.getKeys().map((k) => '${prefs.get(k)}').join('|');
    expect(all.contains('4321'), false);
    expect(prefs.getString('kiosk_pin_hash'), hasLength(64));
  });

  testWidgets('decommission needs confirmation', (t) async {
    await boot(t);
    await unlock(t);
    await t.tap(find.byKey(const Key('menu-decommission')));
    await t.pump();
    expect(find.text('REMOVE KIOSK?'), findsOneWidget);

    await t.tap(find.byKey(const Key('confirm-no')));
    await t.pump();
    expect(kiosk.calls, ['enterMaintenance']);
    expect(find.text('MAINTENANCE MODE'), findsOneWidget);

    await t.tap(find.byKey(const Key('menu-decommission')));
    await t.pump();
    await t.tap(find.byKey(const Key('confirm-yes')));
    await t.pump();
    await t.pump();
    expect(kiosk.calls.last, 'decommission');
    expect(find.text('KIOSK REMOVED'), findsOneWidget);
  });

  testWidgets('touches cannot reach the screen underneath a panel', (t) async {
    await boot(t);
    expect(screenName(t), '01_Pairing_P1');
    await holdGate(t);
    // The live device card is under the barrier, outside the pad.
    await t.tapAt(const Offset(230, 225));
    await t.pump();
    expect(screenName(t), '01_Pairing_P1'); // not the confirm screen
    await t.tap(find.byKey(const Key('pin-cancel')));
    await t.pump();
    await t.tapAt(const Offset(230, 225));
    await t.pump();
    expect(screenName(t), '10_Confirm_Selection'); // works again afterwards
  });
}
