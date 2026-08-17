# AGENT PROMPT 1 — Calibration & Test Firmware (`01_calibration/`)

**Read `PROJECT_CONTEXT.md` first and obey it (pin map §3, ADC rules §3, power/pump §4, protocol §8, conventions §11). Use any skills that help (e.g. the skill-creator/docs skills for the README).**

## Your task
Write an **Arduino (ESP32, arduino-esp32 core)** sketch named `01_calibration.ino` that lets the user **read and calibrate every sensor individually and all at once**, driven from the web app over **USB Web Serial** using the JSON protocol in §8. Store calibration constants in NVS (`Preferences`, namespace `"amd_cal"`). This firmware never uses Wi-Fi.

## Sensors to support (pins from §3)
pH (GPIO36), TDS (GPIO39), turbidity (GPIO34) — all ADC1, use `analogReadMilliVolts`, `ADC_11db`, oversample (e.g. 64 reads, discard outliers, average). TCS34725 (I²C 21/22, Adafruit_TCS34725). DS18B20 (OneWire GPIO4, DallasTemperature). HX711 (DOUT16/SCK17, HX711 lib). TFT ST7735 (SPI, Adafruit_ST7735 or TFT_eSPI — pick one and pin it in a comment) for a local status readout.

## Behaviour
1. **Boot:** init all sensors, load saved calibration from NVS (defaults if none). Show "Calibration mode" + connection hint on the TFT.
2. **Stream readings** at ~5 Hz as `{"t":"reading",...}` (all raw + calibrated values). Also mirror a compact live view on the TFT.
3. **Handle commands** (ack every one with `{"t":"ack",...}`):
   - `{"cmd":"calibrate","sensor":"ph","point":7.0}` and `...,"point":4.0}` → **2-point pH cal**: capture current mV at each point, compute slope+offset (mV→pH), save. Support a **"raw/skip" mode** (`{"cmd":"set","key":"ph_mode","val":"raw"}`) that bypasses cal and reports raw mV — because the user may skip buffers.
   - `{"cmd":"calibrate","sensor":"tds"}` → run `GravityTDS` calibration against a known solution if provided, else keep library default; expose K factor.
   - `{"cmd":"calibrate","sensor":"turbidity","point":"clear"}` → set clear-water zero reference.
   - `{"cmd":"calibrate","sensor":"color","point":"white"}` → capture white reference for normalization.
   - `{"cmd":"tare"}` → zero the load cell (empty chamber).
   - `{"cmd":"calibrate","sensor":"density","known_g":100.0}` → set span with a known weight → compute scale factor.
   - `{"cmd":"set","key":"...","val":...}` → adjustable params (oversample count, adc divider ratios per analog channel, flush ms).
   - `{"cmd":"flush","ms":5000}` → pulse the pump (respect `PUMP_ACTIVE_LOW` from §4) to test the flush path.
   - `{"cmd":"selftest"}` → run an **all-sensors-at-once** health check: confirm each sensor responds, values in plausible range; return `{"t":"selftest",...ok flags...}`.
4. **Persistence:** every successful calibration writes to NVS immediately and returns the stored constants so the UI can display them. A `{"cmd":"factory_reset"}` clears NVS.

## Requirements / quality bar
- Non-blocking loop (no `delay` in the stream path); robust JSON parsing (ArduinoJson) that ignores malformed lines.
- Each analog channel has a **configurable divider ratio** constant (see §3 ADC note) applied before reporting mV→sensor units.
- Clear serial banner on boot with firmware name + version + build date.
- A shared `sensors.h/.cpp` module (read + calibrate + apply) so `02_collection` and `03_deployment` can reuse the exact same code — **factor sensor code into reusable files**.
- Comment the chosen TFT library + wiring; keep pins matching §3.
- Provide a short in-sketch header comment listing the JSON commands.
- Include `library requirements` (names + versions) as a comment block for CI to install: `ArduinoJson, Adafruit_TCS34725, OneWire, DallasTemperature, HX711, Adafruit_ST7735 (+Adafruit_GFX) or TFT_eSPI, DFRobot GravityTDS`.

## Deliverables
`01_calibration/01_calibration.ino`, `01_calibration/sensors.h`, `01_calibration/sensors.cpp`, and a short `01_calibration/README.md` (what it does, how to flash, the command list, calibration walkthrough). Verify it compiles under arduino-cli for `esp32:esp32:esp32`.
