# Shunting tablet: install, kiosk setup and recovery

## 1. Build the APK

```
flutter build apk --release --dart-define=DEVICE_ID=TX-12
```

Optional build settings (all `--dart-define=`):

| Setting | Default | Meaning |
|---|---|---|
| `DEVICE_ID` | `TX-12` | Transmitter this tablet reads. |
| `LAMBDA_URL` | the IoT handler Function URL | Where telemetry is read from. |
| `LAMBDA_API_KEY` | none | Sent as `x-api-key` if the Lambda has `API_KEY` set. |
| `KIOSK_PIN` | `2580` | Factory maintenance PIN. **Change it** (or use CHANGE PIN in the menu). |

APK: `build/app/outputs/flutter-apk/app-release.apk`

## 2. Try the app first (no kiosk, no risk)

```
adb install -r app-release.apk
adb shell am start -n com.example.shunting_tablet/.MainActivity
```

Until step 3 is done the app never locks the tablet. Android may ask which Home
app to use the first time you press Home: choose "Just once" while testing.

## 3. Turn on kiosk lock (once per tablet)

Needs a tablet with **no Google/other accounts**, or a freshly factory-reset one
(Android refuses device-owner setup otherwise).

```
adb shell dpm set-device-owner com.example.shunting_tablet/.KioskAdminReceiver
```

Then open the app (or restart the tablet). From now on:

* power on / restart -> the tablet opens the shunting app directly;
* no status bar, Home, Recents, notifications, Settings or lock screen;
* the screen never sleeps, and the system volume is kept at maximum (the
  volume number in the centre pill scales the beeps); hardware volume keys do
  nothing;
* the power button still turns the screen off and on.

If `set-device-owner` says "already several users / accounts": remove the
accounts (Settings > Accounts), or factory-reset the tablet, and run it again.

## 4. Maintenance (unlock) - always manual

1. **Press and hold the top-left corner of the screen for 5 seconds.**
   (There is nothing visible there.)
2. Enter the **PIN** (factory PIN `2580`, change it with CHANGE PIN).
   Five wrong PINs block PIN entry for 30 seconds.
3. The maintenance menu opens and the tablet is **unlocked**:
   * an amber banner "MAINTENANCE MODE - TABLET NOT LOCKED" with a **LOCK NOW**
     button stays at the top of every screen, and a notification with a
     LOCK NOW action stays in the notification shade;
   * `WI-FI SETTINGS` / `ANDROID SETTINGS` open the Android screens;
   * the Home and Back buttons work normally and leave the shunting app;
     opening the app again does not lock it automatically.
4. **There is no automatic re-lock.** The tablet stays unlocked - even after a
   restart - until someone presses **LOCK TABLET NOW** (menu), **LOCK NOW**
   (banner) or the notification action. Locking needs no PIN; unlocking again
   always does.

## 5. Remove the kiosk completely

Menu > `REMOVE KIOSK (DECOMMISSION)` > confirm. The app stops being device owner
and Home app; the tablet behaves like a normal tablet. No factory reset needed.

## 6. If something goes wrong (recovery)

* Forgot the PIN: `adb shell dpm remove-active-admin com.example.shunting_tablet/.KioskAdminReceiver`
  (works because the app is a debuggable-by-adb device owner only while USB
  debugging is on), or uninstall: `adb uninstall com.example.shunting_tablet`
  after decommissioning. Last resort: factory reset.
* Keep **USB debugging enabled** on test tablets until you are confident.
* A normal APK update keeps the kiosk: `adb install -r app-release.apk`.

## 7. Test checklist (per tablet)

- [ ] App opens, device list shows the live transmitter (TX-12).
- [ ] Connect -> Telemetry, distance, beeps, volume number changes.
- [ ] Kiosk on: Home / Back / Recents / swipe-down do nothing.
- [ ] Restart the tablet: opens straight into the app.
- [ ] Power button: screen off/on, app still there.
- [ ] 5 s corner hold + PIN opens the menu; wrong PIN rejected.
- [ ] While unlocked, Home and Back leave the app; reopening it stays unlocked.
- [ ] Unlocked for > 15 minutes: stays unlocked, banner + notification visible.
- [ ] LOCK NOW (menu, banner, notification) locks again.
- [ ] Restart while unlocked: still unlocked.
- [ ] Switch Wi-Fi off and on from the menu: data resumes.
