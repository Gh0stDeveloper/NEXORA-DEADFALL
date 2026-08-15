# Android Phase 1.1 validation

Phase 1.1 validates the player vertical slice on Android at two levels: automated Android runtime checks and physical-device ergonomics.

## Automated runtime gate

`.github/workflows/android-runtime.yml` exports the `Android Emulator` preset for x86_64, boots an Android 15 / API 35 Pixel 7 emulator, installs the APK, launches the game, injects real Android touch events and inspects logcat.

The gate requires:

- application process remains alive after startup;
- Godot client bootstrap marker is emitted;
- Android diagnostics report landscape orientation;
- Android diagnostics report a valid display safe area;
- RUN, JUMP, CROUCH, PRONE and CAM buttons reach `PlayerInput`;
- the virtual joystick reaches `PlayerInput`;
- the touch-look area reaches `PlayerInput`;
- no GDScript parse/runtime error, Android fatal exception or ANR marker is present.

The normal `Android Debug` preset remains ARM64-only for physical phones. The separate emulator preset prevents CI requirements from changing the shipping architecture strategy.

## Runtime markers

Debug Android builds emit one-time markers that can be inspected with:

```bash
adb logcat | grep -E 'DEADFALL_|NEXORA: DEADFALL'
```

Important markers:

- `DEADFALL_ANDROID_READY`: screen, viewport, safe-area, cutout and DPI data.
- `DEADFALL_TOUCH_ACTION <action>`: first successful press for each touch action.
- `DEADFALL_TOUCH_JOYSTICK active`: joystick generated a meaningful movement vector.
- `DEADFALL_TOUCH_LOOK active`: the look region generated an aiming delta.

These markers are emitted only in Android debug builds and are not intended for production release logging.

## Physical-device acceptance checklist

Automation cannot determine whether controls feel good in a human hand. Before Issue #2 is closed, test the ARM64 APK on at least one real Android phone in landscape and record:

1. Joystick: reachable, stable center, no accidental release, comfortable dead zone.
2. Look: comfortable sensitivity for a 180-degree turn and fine aiming.
3. RUN/JUMP/CROUCH/PRONE/CAM: reachable without hand repositioning and without accidental neighboring presses.
4. Camera cycle: FPS -> TPS rear -> TPS front -> FPS with no visual discontinuity severe enough to affect play.
5. Stances: crouch/prone transitions feel responsive; standing is rejected under the low tunnel ceiling.
6. Safe area: no interactive control is hidden by a notch, camera cutout, rounded corner or system gesture inset.
7. Performance sanity: no obvious sustained stutter during continuous movement/camera input in TestRange.

Record device model, Android version, display resolution/DPI and any control that feels too small, too close or too sensitive. Those observations become tuning changes, not architectural rewrites.
