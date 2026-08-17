# AGENT PROMPT 2 — Data Collection Firmware (`02_collection/`)

**Read `PROJECT_CONTEXT.md` first (pin map §3, schema §5, protocol §8, conventions §11). Reuse `sensors.h/.cpp` from `01_calibration/` verbatim — do not re-implement sensor code.**

## Your task
Write an **Arduino (ESP32)** sketch `02_collection.ino` that captures **labelled training samples** and streams them to the web app over **USB Web Serial**, where the browser writes the CSV. No Wi-Fi, no SD card.

## Behaviour
1. **Boot:** init sensors via shared module, load calibration from NVS, show "Collection mode" + sample counter on the TFT.
2. **Live stream** `{"t":"reading",...}` at ~5 Hz so the UI shows live values while the user prepares a sample.
3. **On `{"cmd":"capture"}`** (labels are attached by the browser, not the device):
   - Show "Capturing…" on TFT. Take a **~3 s averaged reading** (per §11): collect all sensor channels continuously, then report a single consolidated record `{"t":"sample","temp_c":..,"ph_raw_mv":..,"tds_raw_mv":..,"turbidity_raw_mv":..,"density_g":..,"color_r":..,"color_g":..,"color_b":..,"color_clear":..,"n":<reads averaged>,"ts":<ms>}`.
   - Then **auto-flush** (pump per §4, default 5 s) and report `{"t":"flush_done"}`. Increment + show the on-device counter.
   - The browser is responsible for prepending the labels (`milk_type, adulterant, level_pct, source`) and `timestamp_iso`, and appending the row to the in-memory CSV (per schema §5).
4. **Commands:** `{"cmd":"flush","ms":..}`, `{"cmd":"tare"}`, `{"cmd":"set","key":"avg_ms","val":3000}`, `{"cmd":"set","key":"flush_ms","val":5000}`, `{"cmd":"reset_counter"}`.
5. **Capture policy:** one `capture` = one averaged row (per user's decision). Do NOT auto-batch. Guard against captures while a flush is in progress (return `{"t":"ack","ok":false,"msg":"busy"}`).

## Requirements / quality bar
- Report **raw** values exactly as schema §5 names them so the CSV columns line up 1:1.
- Averaging must discard obvious outliers (e.g. trim top/bottom 10%) before mean; report the sample std-dev per channel too (`*_sd`) — useful for spotting a bad reading. (Extra fields are fine; the browser maps the known columns.)
- Non-blocking; robust JSON (ArduinoJson); ignore malformed input.
- Same TFT library + pins as `01_calibration`.
- Header comment lists commands + the exact `sample` field names.

## Deliverables
`02_collection/02_collection.ino` (reusing `sensors.h/.cpp`), and `02_collection/README.md` (how to flash, the capture workflow, field list). Verify it compiles under arduino-cli for `esp32:esp32:esp32`.
