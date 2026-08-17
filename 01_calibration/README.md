# Stage 1 — Calibration & test firmware

Reads every sensor, calibrates each one, and stores the constants in the ESP32's NVS
so Stages 2 and 3 inherit them. Driven from the **Calibrate** page of the web app over
USB Web Serial. No Wi-Fi in this firmware.

## Flash it

From the web app (easiest): **Flash → Calibration firmware** in desktop Chrome/Edge.

From the command line:

```bash
arduino-cli compile --fqbn esp32:esp32:esp32 --libraries libs 01_calibration
```

```bash
arduino-cli upload -p COM5 --fqbn esp32:esp32:esp32 01_calibration
```

`--libraries libs` is what makes `#include <sensors.h>` resolve — the shared sensor
code lives in [libs/AquaMilkSensors](../libs/AquaMilkSensors) so all three firmwares
compile the *same* file instead of three drifting copies. Using the Arduino IDE
instead? Copy `libs/AquaMilkSensors` into your `Arduino/libraries/` folder once.

## Command list

| Command | What it does |
|---|---|
| `{"cmd":"get_cal"}` | Return the stored constants as `{"t":"cal",…}` |
| `{"cmd":"calibrate","sensor":"ph","point":7.0}` | Capture the current mV as the pH 7.0 point |
| `{"cmd":"calibrate","sensor":"ph","point":4.0}` | Capture pH 4.0; with both points it fits slope + offset and leaves raw mode |
| `{"cmd":"set","key":"ph_mode","val":"raw"}` | Skip pH calibration entirely, report raw mV |
| `{"cmd":"calibrate","sensor":"tds","known_ppm":707}` | Solve the K factor against a known solution (omit for the stock curve) |
| `{"cmd":"calibrate","sensor":"turbidity","point":"clear"}` | Current reading becomes the clear-water zero |
| `{"cmd":"calibrate","sensor":"color","point":"white"}` | Capture the white reference |
| `{"cmd":"tare"}` | Zero the load cell with the chamber empty |
| `{"cmd":"calibrate","sensor":"density","known_g":100.0}` | Set counts-per-gram from a known weight |
| `{"cmd":"flush","ms":5000}` | Run the pump to test the flush path |
| `{"cmd":"selftest"}` | All sensors at once → `{"t":"selftest",…}` with a flag per sensor |
| `{"cmd":"set","key":…,"val":…}` | `oversample`, `div_ph`, `div_tds`, `div_turb`, `avg_ms`, `flush_ms`, `chamber_ml`, `conf_thr` |
| `{"cmd":"factory_reset"}` | Wipe NVS back to defaults |

Every command is acked with `{"t":"ack","cmd":…,"ok":…,"msg":…}`, and anything that
changes calibration is followed by a fresh `{"t":"cal",…}` snapshot. Readings stream
at ~5 Hz as `{"t":"reading",…}`: `ph`/`tds`/`turb` are **millivolts at the sensor
board** (divider already applied), and `calc.{ph,ppm,ntu,sg}` are the human-readable
conversions.

## Calibration walkthrough

Do these in order, with the web app's Calibrate page open.

1. **Dividers first.** Any sensor board that can swing above 3.3 V needs a resistor
   divider (§3): turbidity 0–4.5 V and the pH board both do. Measure your actual
   divider with a multimeter and set the ratio (`div_ph`, `div_turb`, `div_tds`) —
   2.0 means "the pin sees half of what the board puts out". Everything downstream
   assumes this is right.
2. **Selftest.** Hit *Test all sensors*. Every flag should be true. A false flag is a
   wiring problem, not a calibration problem — fix it before continuing.
3. **Tare + density span.** Empty, dry chamber → *Tare*. Then put a known weight
   (a 100 g calibration weight, or anything you can weigh on a kitchen scale) on the
   cell → *set span with known weight*. Also set `chamber_ml` to your chamber's real
   fixed volume; specific gravity is grams ÷ this number.
4. **Turbidity zero.** Fill the chamber with distilled water → *set clear-water zero*.
5. **Colour white reference.** Same clear water (or a white card against the sensor)
   → *set white reference*.
6. **pH, if you have buffers.** Rinse the probe, sit it in pH 7.0 → capture 7.0;
   rinse, sit in pH 4.0 → capture 4.0. Two good points switch the firmware out of raw
   mode. **No buffers? Leave raw mode on** — the model trains on raw millivolts either
   way (see `features.h`), so skipping this costs you the human-readable pH number,
   not accuracy.
7. **Flush test.** Hit *Flush test*. If the pump does nothing, re-read §4 of
   `PROJECT_CONTEXT.md`: the IRF520 is not logic-level, and the documented 2N2222
   level-shifter **inverts** the signal, which is why `PUMP_ACTIVE_LOW` defaults to
   `true` in `sensors.h`. If the pump instead runs constantly and stops when you
   command a flush, your wiring is non-inverting — flip that flag and rebuild.

Constants are written to NVS (namespace `amd_cal`) the moment each step succeeds, so
you can power-cycle mid-way through without losing work.
