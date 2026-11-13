import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Proximity beeper, modelled on the shunting receiver's buzzer
/// (Receiver firmware: buzzer.c + screen_sm.c TickBuzzer()).
///
/// The beep cadence speeds up as the dead-end gets closer. Nothing is played
/// when the operator touches the screen: the volume buttons only set how loud
/// these distance-driven sounds are.
abstract class Beeper {
  /// [intervalMs] is the receiver's toggle interval (beep ON for this long,
  /// OFF for this long); 0 means silent. [continuous] sounds a steady alarm
  /// tone (link lost) and overrides [intervalMs]. [volume] is 0..100 in steps
  /// of 10, like the receiver's volume_pct.
  void update({
    required int intervalMs,
    required bool continuous,
    required int volume,
  });

  void dispose();

  /// Receiver cadence bands (screen_sm.c TickBuzzer): the closer, the faster.
  static int intervalForDistanceCm(int cm) {
    if (cm < 500) return 150; // < 5 m: dead-end warning
    if (cm < 1000) return 200; // < 10 m
    if (cm < 2000) return 250; // < 20 m
    return 400; // 20 m up to the unit's range limit
  }

  /// Speaker gain for a volume percentage. The receiver drives a 12 V piezo
  /// with a hand-tuned PWM duty table that does not transfer to a tablet
  /// speaker, so this is our own perceptual curve: 0 is mute, low steps are
  /// quiet but audible, 100 is full volume.
  static double gainForVolume(int volumePct) {
    final x = (volumePct.clamp(0, 100)) / 100.0;
    return x * x;
  }
}

/// Plays the bundled sounds through the speaker. The sounds are 960 Hz square
/// waves, the receiver buzzer's frequency (TIM2: 96 MHz / 10 / 10000). Each
/// cadence file already contains one ON phase followed by one OFF phase of the
/// receiver's interval and is looped gaplessly, so timing needs no timers.
class AudioBeeper implements Beeper {
  final AudioPlayer _beepPlayer = AudioPlayer();
  final AudioPlayer _alarmPlayer = AudioPlayer();
  int _intervalMs = 0;
  bool _alarmOn = false;

  AudioBeeper() {
    final context = AudioContextConfig(
      route: AudioContextConfigRoute.speaker,
      focus: AudioContextConfigFocus.mixWithOthers,
      respectSilence: false,
    ).build();
    _beepPlayer.setAudioContext(context);
    _alarmPlayer.setAudioContext(context);
    _beepPlayer.setReleaseMode(ReleaseMode.loop);
    _alarmPlayer.setReleaseMode(ReleaseMode.loop);
  }

  void _stopBeep() {
    if (_intervalMs != 0) {
      _intervalMs = 0;
      _beepPlayer.stop();
    }
  }

  void _stopAlarm() {
    if (_alarmOn) {
      _alarmOn = false;
      _alarmPlayer.stop();
    }
  }

  @override
  void update({
    required int intervalMs,
    required bool continuous,
    required int volume,
  }) {
    final gain = Beeper.gainForVolume(volume);
    if (gain <= 0) {
      _stopBeep();
      _stopAlarm();
      return;
    }

    if (continuous) {
      _stopBeep();
      if (!_alarmOn) {
        _alarmOn = true;
        _alarmPlayer
            .play(AssetSource('sounds/alarm.wav'), volume: gain)
            .catchError((Object e) => debugPrint('Unable to play alarm: $e'));
      } else {
        _alarmPlayer.setVolume(gain);
      }
      return;
    }
    _stopAlarm();

    if (intervalMs <= 0) {
      _stopBeep();
      return;
    }
    if (intervalMs != _intervalMs) {
      _intervalMs = intervalMs;
      _beepPlayer
          .play(AssetSource('sounds/beep_$intervalMs.wav'), volume: gain)
          .catchError((Object e) => debugPrint('Unable to play beep: $e'));
    } else {
      _beepPlayer.setVolume(gain);
    }
  }

  @override
  void dispose() {
    _beepPlayer.dispose();
    _alarmPlayer.dispose();
  }
}
