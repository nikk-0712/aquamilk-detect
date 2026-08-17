# Stage 2 — Data collection firmware

Captures labelled training samples and streams them to the **Collect** page of the web
app, which builds the CSV in the browser. No Wi-Fi, no SD card. Sensor code and
calibration are inherited from Stage 1 — same `libs/AquaMilkSensors`, same NVS
namespace, so **calibrate before you collect**.

## Flash it

Web app: **Flash → Collection firmware** (Chrome asks which device; no port to configure).
Or, with your own port from `arduino-cli board list` in place of the example `COM5`:

```bash
arduino-cli compile --fqbn esp32:esp32:esp32 --libraries libs 02_collection
```

```bash
arduino-cli upload -p COM5 --fqbn esp32:esp32:esp32 02_collection
```

## Capture workflow

1. Open **Collect**, connect the device.
2. Fill in the labels: milk type (cow / buffalo / toned), adulterant (pure / water /
   detergent / starch), level %, and the free-text **source** (which dairy, shop or
   person the milk came from). The labels live in the browser — the device never sees
   them, it only measures.
3. Pour the sample into the chamber. Watch the live values settle.
4. Hit **Capture**. The device averages for `avg_ms` (default 3 s), emits one
   `{"t":"sample",…}` record, then auto-flushes for `flush_ms` (default 5 s) and sends
   `{"t":"flush_done"}`. One capture = one CSV row; there is no auto-batching.
5. Repeat. The browser keeps the running table, per-class counts, and the CSV export.

Capture is refused with `{"t":"ack","ok":false,"msg":"busy"}` while an average or a
flush is still running, so you cannot accidentally sample into a flushing chamber.

**Aim for balance.** The per-class counts in the web app exist because an SVM trained
on 90 pure and 6 starch samples will simply learn to say "pure". Collect across more
than one source too — a model trained on one dairy's milk mostly learns that dairy.

## Sample record fields

Names match the CSV schema (`PROJECT_CONTEXT.md` §5) exactly, so the browser maps them
straight into a row:

| Field | Meaning |
|---|---|
| `temp_c` | DS18B20 °C |
| `ph_raw_mv` | pH board output, millivolts, divider-corrected |
| `tds_raw_mv` | TDS board output, millivolts |
| `turbidity_raw_mv` | Turbidity board output, millivolts |
| `density_g` | Grams in the fixed-volume chamber, tare-corrected |
| `color_r`, `color_g`, `color_b`, `color_clear` | TCS34725 raw channels |
| `ph_sd`, `tds_sd`, `turbidity_sd`, `density_sd`, `temp_sd` | Standard deviation across the averaging window |
| `sg` | Derived temperature-corrected specific gravity (this is model feature 3) |
| `n` | Reads that survived outlier trimming (top/bottom 10 % dropped) |
| `ts`, `count` | Device millis, session sample counter |

The `*_sd` columns are the honest-sample check: if `density_sd` is large someone
knocked the bench, if `turbidity_sd` is large there were bubbles. Retake that sample
rather than training on it.

## Commands

| Command | Effect |
|---|---|
| `{"cmd":"capture"}` | Average, emit one sample, auto-flush |
| `{"cmd":"flush","ms":5000}` | Flush now |
| `{"cmd":"tare"}` | Re-zero the empty chamber |
| `{"cmd":"set","key":"avg_ms","val":3000}` | Averaging window (200–20000 ms) |
| `{"cmd":"set","key":"flush_ms","val":5000}` | Flush duration (0–60000 ms) |
| `{"cmd":"reset_counter"}` | Clear the on-device session counter |
