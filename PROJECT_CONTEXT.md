# Aqua Milk Detect — PROJECT CONTEXT (single source of truth)

> Every agent building any part of this project MUST read this file first and treat it as authoritative. If a prompt and this file disagree, this file wins. Keep the same names, pins, colors, and schema everywhere.

**Tagline:** *Milk purity in seconds.*
**One line:** A low-cost, portable IoT + edge-ML device that classifies a milk sample as **Pure / Water-adulterated / Detergent-adulterated / Starch-adulterated** (or **Uncertain**) in seconds, using multi-sensor data and an on-device SVM, with a self-cleaning flush and an elegant web + on-device UI.

SDGs: 3 (Good Health), 9 (Industry/Innovation), 12 (Responsible Consumption).

---

## 1. System overview (three stages, one repo)

The system is delivered as **three separate Arduino firmwares** plus **one web app**, **one Python trainer**, and **CI to build + host**:

| Stage | Folder | Runs on | Talks to browser via | Purpose |
|---|---|---|---|---|
| 1. Calibration & test | `01_calibration/` | ESP32 | **USB Web Serial** | Read + calibrate each sensor and all-at-once |
| 2. Data collection | `02_collection/` | ESP32 | **USB Web Serial** | Capture labelled samples → CSV in browser |
| 3. Deployment | `03_deployment/` | ESP32 | **Wi-Fi (SoftAP / STA)** + TFT | Run the trained SVM, show verdict, self-flush |
| Web app | `web/` | GitHub Pages | — | Flash firmware + Calibrate + Collect UIs |
| Trainer | `training/` | User PC (Python) | — | Train SVM from CSV → export `model.h` |
| CI | `.github/workflows/` | GitHub Actions | — | Build `.bin`s + deploy `web/` to Pages |

**Data/ML loop:** Stage 2 collects labelled CSV → Python trainer makes `model.h` → drop into Stage 3 → deploy.

---

## 2. Hardware (FINAL bill of materials)

**MCU:** ESP32 DevKit V1, 38-pin, ESP32-WROOM-32 (user owns). Framework: **Arduino (arduino-esp32 core)**. NOT ESP-IDF.

**Sensors & modules:**
| Function | Part | Interface | Notes |
|---|---|---|---|
| pH | Analog pH sensor kit (Industrial Grade Analog pH, BNC probe) | Analog → ADC1 | Detergent (alkaline) flag; output may reach ~3–5 V → **see ADC note** |
| TDS / conductivity | DFRobot Gravity Analog TDS (genuine) | Analog → ADC1 | Water/detergent dilution; library `GravityTDS` |
| Turbidity | Turbidity Sensor With Module | Analog → ADC1 | Starch/suspended solids; output 0–4.5 V → **needs divider** |
| Colour | TCS34725 RGB+Clear | I²C | R,G,B,Clear channels as features |
| Temperature | DS18B20 waterproof (genuine chip, 1 m) | OneWire | Temp compensation for pH/TDS/density |
| Density | HX711 + 3 kg load cell | HX711 2-wire | Weigh fixed-volume chamber → specific gravity |
| Display | 1.8" TFT ST7735, 128×160 | SPI | On-device verdict + status |
| Pump | 6 V peristaltic dosing pump | via MOSFET | Auto-flush chamber with distilled water |
| Pump switch | **IRF520 MOSFET module** (user owns) | GPIO (PWM) | ⚠️ **not logic-level — see §4** |
| Flyback | 1N4007 diode (user owns) | across pump | Protects MOSFET/ESP32 |
| Power step-down | LM2596 buck | — | 12 V → 6 V (pump) and 5 V/3.3 V (logic) |
| Power source | 12 V 1.5 A adapter (user owns) | — | 18 W, ample |
| Input | **1 × TTP223 capacitive touch pad** (user owns) | GPIO (RTC pin) | Gesture-driven; **NO LEDs** |
| Fluidics | Silicone tube 1 m + user's reservoir & waste cup | — | Flush plumbing |

**User-owned / not purchased:** ESP32, IRF520 module, 12 V 1.5 A adapter, 1N4007 diode, TTP223 pad(s), 2N2222 transistors, jumper wires, breadboard.
**User to source separately:** enclosure + test chamber, distilled water, (optional, cheap) pH 4/7 buffer sachets.

**Purchase split (both free-shipping > ₹999, ₹0 shipping):**
- **Robu.in:** pH kit (₹1,975) + DS18B20 genuine-chip (₹89).
- **Robocraze:** DFRobot TDS, turbidity, 6 V pump, TCS34725, 1.8" TFT, 3 kg load cell + HX711, LM2596, silicone tube.
- Total to buy ≈ **₹4,969** (under ₹5,000 budget). Owned parts saved ≈ ₹600.

---

## 3. Pin map (ESP32-WROOM-32, 38-pin) — FINAL

Use these exact pins in all firmwares.

| Signal | GPIO | Notes |
|---|---|---|
| pH analog in | **36** (VP, ADC1_CH0) | input-only, ADC1 |
| TDS analog in | **39** (VN, ADC1_CH3) | input-only, ADC1 |
| Turbidity analog in | **34** (ADC1_CH6) | input-only, ADC1 |
| TCS34725 SDA | **21** | I²C |
| TCS34725 SCL | **22** | I²C |
| DS18B20 data | **4** | OneWire + 4.7 kΩ pull-up to 3V3 |
| HX711 DOUT | **16** | |
| HX711 SCK | **17** | |
| TFT SCLK | **18** | VSPI |
| TFT MOSI | **23** | VSPI |
| TFT CS | **5** | strapping pin — fine as output |
| TFT DC | **2** | strapping pin — fine as output |
| TFT RST | **15** | strapping pin — fine as output |
| TFT BL (backlight) | tie to 3V3 (or **32** for dim) | |
| Pump (IRF520 SIG/gate) | **25** | LEDC PWM channel |
| TTP223 OUT | **27** | RTC-capable → deep-sleep touch wake (ext0) |

**ADC rules (critical):**
- All three analog sensors are on **ADC1** because **ADC2 is unusable while Wi-Fi is on**.
- ESP32 ADC is 12-bit, 0–3.3 V. **Any sensor board that can output > 3.3 V (turbidity 0–4.5 V; pH board can approach 5 V) MUST go through a resistor voltage divider** (e.g. 2:1) or the board must be run at 3.3 V. Document the divider in the wiring README. Calibration maps raw ADC → sensor value, so exact divider ratio is captured during calibration.
- Use `analogReadMilliVolts()` / attenuation `ADC_11db` for the widest linear range; average many samples.

Free/unused pins for future use: 13, 14, 26, 33, 35 (35 input-only). Avoid GPIO12 (strapping, boot).

---

## 4. Power & pump switching (the IRF520 caveat — do not skip)

Power: 12 V adapter → LM2596 #1 set to **6 V** for the pump; logic runs from **5 V/USB or a second LM2596 at 5 V**. ESP32 from 5 V pin or USB.

Pump switching uses the user's **IRF520 module**. **IRF520 is NOT a logic-level MOSFET** — its gate wants ~10 V; at the ESP32's 3.3 V it barely turns on (weak, hot, unreliable). Firmware must therefore:
- Drive the pump on a **PWM-capable GPIO (25)** via LEDC, and expose pump on/off + duty as config.
- **Wiring recommendation baked into README:** because IRF520 is marginal at 3.3 V, drive its `SIG` through a **2N2222 level-shifter** so the gate swings to ~5 V: `GPIO25 → 1 kΩ → 2N2222 base; emitter → GND; collector → IRF520 SIG with a 10 kΩ pull-up to +5 V`. **This inverts logic (GPIO HIGH = pump OFF)** — firmware MUST have a `PUMP_ACTIVE_LOW` compile-time flag (default `true` for this wiring) so on/off is correct. If the user instead swaps to a logic-level MOSFET (IRLZ44N), set the flag `false`.
- Always place the **1N4007 flyback diode across the pump** (band/cathode to +6 V).

---

## 5. Data schema (CSV) — FINAL

One captured sample = one CSV row. Store **raw** sensor values (so features can be re-derived) plus labels & metadata.

```
timestamp_iso, milk_type, adulterant, level_pct, source,
temp_c, ph_raw_mv, tds_raw_mv, turbidity_raw_mv,
density_g, color_r, color_g, color_b, color_clear
```

- `milk_type` ∈ {cow, buffalo, toned}
- `adulterant` ∈ {pure, water, detergent, starch}
- `level_pct` ∈ {0, 5, 10, 20, 30, …} (0 for pure)
- `source` = free text (dairy / shop / person / place) — **user's tagging field**
- `*_raw_mv` = averaged ADC millivolts; `density_g` = temp-corrected grams for the fixed volume; color_* = TCS34725 channels.
- CSV is created and saved **in the browser** (no server, no SD card).

**Feature vector for the model (≈10):** `ph, tds, turbidity, density(temp-corrected specific gravity), temperature, color_r, color_g, color_b, color_clear` (+ optionally derived ratios). Fit a `StandardScaler`; export scaler constants alongside the model.

---

## 6. Model & inference

- **Algorithm:** SVM (scikit-learn). Compare **linear vs RBF** via `GridSearchCV` + stratified k-fold; pick best by macro-F1.
- **Classes:** `pure, water, detergent, starch`. Also compute a **binary headline** (pure vs adulterated).
- **Uncertain / reject:** use `predict_proba` (Platt) — if top-class probability `< threshold` (default **0.60**, tunable in the deployment Settings), output **Uncertain**. Optionally a one-class outlier guard on "pure".
- **Export:** `micromlgen` → `model.h` (C++), plus a `scaler.h` (means/scales) → included by `03_deployment`. Inference on-device is microseconds.
- **Honesty:** trainer must print accuracy, macro-F1, full **confusion matrix**, per-class precision/recall, and note that starch is the hardest class. Report both multiclass and binary numbers.

---

## 7. Interaction — single TTP223 gestures (deployment)

**No LEDs.** All feedback is on the **TFT** and the **web dashboard**. One touch pad, gesture vocabulary (keep timing generous; show a gesture cheat-sheet in the menu):

| Gesture | Action |
|---|---|
| **Single tap** | Start a test |
| **Double tap** | Flush now |
| **Long-press (~1.5 s)** | Open on-screen menu → navigate with taps (Wi-Fi info · Tare · Re-check calibration · Settings) |
| **Tap-tap-hold** | **Soft power**: enter deep sleep (screen/Wi-Fi off, µA). A touch **wakes** it (ext0 on GPIO27). No true hardware off (a touch pad can't power a dead board); a physical switch on the adapter gives hard-off if desired. |

Test flow: sample in → single tap → TFT shows "Reading…" (average ~3 s) → verdict + confidence → **auto-flush ~5 s** → ready. Uncertain → amber "Uncertain — retest", auto-suggest flush + retry.

---

## 8. Connectivity & protocol

- **USB Web Serial (Stages 1 & 2):** newline-delimited **JSON**. Baud 115200.
  - Device→browser: `{"t":"reading","ph":..,"tds":..,"turb":..,"temp":..,"dens":..,"r":..,"g":..,"b":..,"c":..,"ts":..}`
  - Browser→device: `{"cmd":"capture"}` · `{"cmd":"calibrate","sensor":"ph","point":7.0}` · `{"cmd":"tare"}` · `{"cmd":"flush","ms":5000}` · `{"cmd":"set","key":"..","val":..}`
  - Device acks: `{"t":"ack","cmd":"..","ok":true,"msg":".."}`
- **Wi-Fi (Stage 3):** default **SoftAP** SSID `AquaMilk-XXXX` (XXXX = last 2 bytes of MAC), password shown on TFT; device serves its own dashboard at `http://192.168.4.1` with a **WebSocket** for live data. Optional **STA** (join lab Wi-Fi, creds set in Settings) reachable at **`aquamilk.local`** via mDNS. HTTP only on-device (that's why Run is device-served — an HTTPS page can't call an HTTP device: mixed content).

---

## 9. Design language (Apple-grade) — shared by web app AND device dashboard

**Use the installed Apple design skill for all UI work.** Both the GitHub-hosted app and the ESP32-served Run page share this system.

- **Type:** `-apple-system, "SF Pro Text", "SF Pro Display", system-ui, sans-serif`. Big rounded titles, strong hierarchy, tight tracking on large text.
- **Theme:** **light + dark, auto (`prefers-color-scheme`), default light.**
- **Palette:**
  - Accent (aqua-teal): `#0FB5C9` (darker `#0A8FA3`)
  - Backgrounds: light `#F5F5F7`, dark `#000000` — Apple's own neutrals; they read warmer
    and calmer than the blue-tinted `#F5F7FA` / `#0B0F14` this started with
  - Text: light `#1D1D1F`, dark `#F5F5F7`; secondary `#86868B` / `#A1A1A6`
  - Cards/surfaces: light `#FFFFFF`, dark `#1D1D1F`, with subtle translucency/blur (frosted) where tasteful
  - **Result semantics:** Pure = green `#34C759` · Adulterated = red `#FF3B30` · Uncertain = amber `#FF9F0A` (Apple system colors)
- **Shape & motion:** 16–20 px corner radius, soft layered shadows, 8-pt spacing grid, 200–300 ms ease transitions, gentle spring on the result reveal, circular **confidence ring** (SVG). SF-style segmented controls, toggles, large tap targets.
- **Tone:** calm, spacious, confident. No clutter, no debug vibes. Production-grade.
- **Branding:** title **"Aqua Milk Detect"**, tagline **"Milk purity in seconds"**, a **minimal logo mark** (agent designs it — think a clean drop/wave in aqua-teal). Provide as inline SVG.
- **Device dashboard constraint:** must be lean enough to live in ESP32 flash (single gzipped HTML/CSS/JS in PROGMEM or LittleFS) yet visually identical in spirit.

---

## 10. Repo layout (created by CI prompt)

```
aquamilk-detect/
├── PROJECT_CONTEXT.md          ← this file (source of truth)
├── README.md                   ← wiring, setup, usage, wiring diagram
├── 01_calibration/             ← Arduino sketch
├── 02_collection/              ← Arduino sketch
├── 03_deployment/              ← Arduino sketch (+ model.h, scaler.h, web assets)
├── web/                        ← the GitHub-Pages SPA (Flash/Calibrate/Collect/Run)
│   └── firmware/               ← .bin + ESP Web Tools manifests (built by CI)
├── training/                   ← Python trainer (notebook + script) → model.h
├── docs/                       ← diagrams, images
└── .github/workflows/          ← build + deploy
```

## 11. Global conventions
- License **MIT**.
- Each sample/test **averages ~3 s** of readings. Auto-flush default **5 s** (adjustable in Settings).
- Confidence threshold default **0.60** (Settings).
- Store calibration constants + settings + rolling log in **NVS (`Preferences`)**; larger logs/assets in **LittleFS**.
- Persistent rolling test log kept on device flash (last ~200 results), plus full session history in the browser (exportable CSV).
- Prompts assume a capable coding agent (files + shell + arduino-cli/PlatformIO + Git/GitHub + skills). Target boards/libs pinned by CI.
- Web Serial + ESP Web Tools work in **desktop Chrome/Edge only** (state this in the app UI).
