/*
  01_calibration.ino — Aqua Milk Detect, Stage 1: read + calibrate every sensor.
  ESP32 DevKit V1 (arduino-esp32 core). NO Wi-Fi in this firmware.

  Talks to the web app over USB Web Serial, newline-delimited JSON, 115200 baud
  (PROJECT_CONTEXT.md §8). Calibration constants live in NVS namespace "amd_cal".

  ---------------------------------------------------------------- device -> host
    {"t":"reading", ph, tds, turb, temp, dens, r, g, b, c, ts,
                    calc:{ph, ppm, ntu, sg}, ok:{temp,color,scale}}
                                                  ~5 Hz. ph/tds/turb are millivolts
                                                  at the sensor board (divider applied);
                                                  calc.* are the calibrated human values
                                                  (calc.ph is null while pH raw mode is on).
    {"t":"ack",   cmd, ok, msg}                   every command is acked
    {"t":"cal",   ...}                            full calibration snapshot (see sendCal)
    {"t":"selftest", ok, why, analog, ds18b20, tcs34725, hx711, ...}
    {"t":"flush_done"}

  ---------------------------------------------------------------- host -> device
    {"cmd":"calibrate","sensor":"ph","point":7.0}        capture the pH 7.0 point
    {"cmd":"calibrate","sensor":"ph","point":4.0}        capture the pH 4.0 point (fits slope)
    {"cmd":"calibrate","sensor":"tds","known_ppm":707}   solve K (omit/0 = keep stock curve)
    {"cmd":"calibrate","sensor":"turbidity","point":"clear"}
    {"cmd":"calibrate","sensor":"color","point":"white"}
    {"cmd":"calibrate","sensor":"density","known_g":100.0}
    {"cmd":"tare"}                                       zero the empty chamber
    {"cmd":"flush","ms":5000}                            test the pump path
    {"cmd":"selftest"}                                   all sensors at once
    {"cmd":"get_cal"}                                    ask for the {"t":"cal"} snapshot
    {"cmd":"factory_reset"}                              wipe NVS
    {"cmd":"set","key":"<k>","val":<v>}  keys:
        ph_mode ("raw"|"cal"), oversample, div_ph, div_tds, div_turb,
        avg_ms, flush_ms, chamber_ml, conf_thr

  Libraries (pinned in .github/workflows/build-firmware.yml):
    ArduinoJson 7.4.3, Adafruit TCS34725 1.4.4, Adafruit GFX 1.12.6,
    Adafruit ST7735 and ST7789 1.10.4, Adafruit BusIO 1.17.4, OneWire 2.3.8,
    DallasTemperature 3.9.0, HX711 Arduino Library 0.7.5.
    Core: esp32:esp32 3.3.10. Shared code: libs/AquaMilkSensors.
    Build FQBN: esp32:esp32:esp32:PartitionScheme=huge_app
    TFT is Adafruit_ST7735 (pins passed in the constructor, see display.h).
*/

#include <ArduinoJson.h>
#include <sensors.h>
#include <display.h>

#define FW_NAME "01_calibration"
#define FW_VER  "1.0.0"

static char     rx[256];
static uint16_t rx_len   = 0;
static uint32_t t_stream = 0, t_tft = 0;

// ---------------------------------------------------------------------- output
static void sendAck(const char* cmd, bool ok, const char* msg) {
  JsonDocument d;
  d["t"] = "ack";
  d["cmd"] = cmd;
  d["ok"] = ok;
  d["msg"] = msg;
  serializeJson(d, Serial);
  Serial.println();
}

static void sendCal() {
  JsonDocument d;
  d["t"] = "cal";
  if (isnan(cal.ph_mv7)) d["ph_mv7"] = nullptr; else d["ph_mv7"] = cal.ph_mv7;
  if (isnan(cal.ph_mv4)) d["ph_mv4"] = nullptr; else d["ph_mv4"] = cal.ph_mv4;
  d["ph_slope"]    = cal.ph_slope;
  d["ph_offset"]   = cal.ph_offset;
  d["ph_raw_mode"] = cal.ph_raw_mode;
  d["tds_k"]       = cal.tds_k;
  d["turb_clear_mv"] = cal.turb_clear_mv;
  JsonArray w = d["col_w"].to<JsonArray>();
  w.add(cal.col_wr); w.add(cal.col_wg); w.add(cal.col_wb); w.add(cal.col_wc);
  d["hx_offset"]  = cal.hx_offset;
  d["hx_scale"]   = cal.hx_scale;
  d["div_ph"]     = cal.div_ph;
  d["div_tds"]    = cal.div_tds;
  d["div_turb"]   = cal.div_turb;
  d["oversample"] = cal.oversample;
  d["avg_ms"]     = cal.avg_ms;
  d["flush_ms"]   = cal.flush_ms;
  d["chamber_ml"] = cal.chamber_ml;
  d["conf_thr"]   = cal.conf_threshold;
  serializeJson(d, Serial);
  Serial.println();
}

static void sendReading() {
  const Reading& r = sensorsLatest();
  JsonDocument d;
  d["t"]    = "reading";
  d["ph"]   = r.ph_mv;
  d["tds"]  = r.tds_mv;
  d["turb"] = r.turb_mv;
  d["temp"] = r.temp_c;
  d["dens"] = r.density_g;
  d["r"] = r.r; d["g"] = r.g; d["b"] = r.b; d["c"] = r.c;
  d["ts"] = r.ts_ms;
  JsonObject calc = d["calc"].to<JsonObject>();
  float ph = phFromMv(r.ph_mv);
  if (isnan(ph)) calc["ph"] = nullptr; else calc["ph"] = ph;
  calc["ppm"] = tdsPpm(r.tds_mv, r.temp_c);
  calc["ntu"] = turbidityNtu(r.turb_mv);
  calc["sg"]  = specificGravity(r.density_g, r.temp_c);
  JsonObject ok = d["ok"].to<JsonObject>();
  ok["temp"]  = r.ok_temp;
  ok["color"] = r.ok_color;
  ok["scale"] = r.ok_scale;
  serializeJson(d, Serial);
  Serial.println();
}

// ------------------------------------------------------------------- commands
static void doSet(JsonDocument& in) {
  const char* key = in["key"] | "";
  JsonVariant val = in["val"];
  char msg[64];

  if      (!strcmp(key, "ph_mode"))    cal.ph_raw_mode = !strcmp(val | "cal", "raw");
  else if (!strcmp(key, "oversample")) cal.oversample = constrain((int)(val | 64), 1, 256);
  else if (!strcmp(key, "div_ph"))     cal.div_ph   = val | 1.0f;
  else if (!strcmp(key, "div_tds"))    cal.div_tds  = val | 1.0f;
  else if (!strcmp(key, "div_turb"))   cal.div_turb = val | 1.0f;
  else if (!strcmp(key, "avg_ms"))     cal.avg_ms   = constrain((int)(val | 3000), 200, 20000);
  else if (!strcmp(key, "flush_ms"))   cal.flush_ms = constrain((int)(val | 5000), 0, 60000);
  else if (!strcmp(key, "chamber_ml")) cal.chamber_ml = val | 100.0f;
  else if (!strcmp(key, "conf_thr"))   cal.conf_threshold = constrain((float)(val | 0.60f), 0.0f, 0.99f);
  else { snprintf(msg, sizeof msg, "unknown key %s", key); sendAck("set", false, msg); return; }

  calSave();
  snprintf(msg, sizeof msg, "%s set", key);
  sendAck("set", true, msg);
  sendCal();
}

static void doCalibrate(JsonDocument& in) {
  const char* s = in["sensor"] | "";
  if (!strcmp(s, "ph")) {
    float p = in["point"] | NAN;
    bool ok = calPhPoint(p);
    sendAck("calibrate", ok, ok ? "ph point stored" : "need point 7.0 or 4.0 with a live probe");
  } else if (!strcmp(s, "tds")) {
    float known = in["known_ppm"] | 0.0f;
    bool ok = calTdsWithKnown(known);
    sendAck("calibrate", ok, ok ? "tds k stored" : "probe reads ~0, is it submerged?");
  } else if (!strcmp(s, "turbidity")) {
    calTurbidityClear();
    sendAck("calibrate", true, "clear-water zero stored");
  } else if (!strcmp(s, "color")) {
    calColorWhite();
    sendAck("calibrate", true, "white reference stored");
  } else if (!strcmp(s, "density")) {
    float g = in["known_g"] | 0.0f;
    bool ok = calDensitySpan(g);
    sendAck("calibrate", ok, ok ? "density span stored" : "put the known weight on first");
  } else {
    sendAck("calibrate", false, "unknown sensor");
    return;
  }
  sendCal();
}

static void doSelftest() {
  Reading r;
  char why[80];
  bool ok = sensorsSelftest(r, why, sizeof why);
  JsonDocument d;
  d["t"]  = "selftest";
  d["ok"] = ok;
  d["why"] = why;
  d["analog"]   = !isnan(r.ph_mv) && !isnan(r.tds_mv) && !isnan(r.turb_mv);
  d["ds18b20"]  = r.ok_temp;
  d["tcs34725"] = r.ok_color;
  d["hx711"]    = r.ok_scale;
  d["ph"] = r.ph_mv; d["tds"] = r.tds_mv; d["turb"] = r.turb_mv;
  d["temp"] = r.temp_c; d["dens"] = r.density_g;
  d["r"] = r.r; d["g"] = r.g; d["b"] = r.b; d["c"] = r.c;
  serializeJson(d, Serial);
  Serial.println();
}

static void handleLine(char* line) {
  JsonDocument in;
  if (deserializeJson(in, line)) return;        // malformed: ignore silently
  const char* cmd = in["cmd"] | "";
  if (!*cmd) return;

  if (!strcmp(cmd, "calibrate"))          doCalibrate(in);
  else if (!strcmp(cmd, "set"))           doSet(in);
  else if (!strcmp(cmd, "tare"))        { calTare(); sendAck("tare", true, "chamber zeroed"); sendCal(); }
  else if (!strcmp(cmd, "flush")) {
    if (pumpBusy()) { sendAck("flush", false, "busy"); return; }
    uint32_t ms = in["ms"] | cal.flush_ms;
    pumpStart(ms);
    sendAck("flush", true, "pump on");
  }
  else if (!strcmp(cmd, "selftest"))      { sendAck("selftest", true, "running"); doSelftest(); }
  else if (!strcmp(cmd, "get_cal"))       { sendAck("get_cal", true, "ok"); sendCal(); }
  else if (!strcmp(cmd, "factory_reset")) { calFactoryReset(); sendAck("factory_reset", true, "nvs cleared"); sendCal(); }
  else                                      sendAck(cmd, false, "unknown cmd");
}

static void pollSerial() {
  while (Serial.available()) {
    char ch = (char)Serial.read();
    if (ch == '\n' || ch == '\r') {
      if (rx_len) { rx[rx_len] = 0; handleLine(rx); rx_len = 0; }
    } else if (rx_len < sizeof(rx) - 1) {
      rx[rx_len++] = ch;
    } else {
      rx_len = 0;                              // overlong line: drop it
    }
  }
}

// ------------------------------------------------------------------------ TFT
static void updateTft() {
  const Reading& r = sensorsLatest();
  static char l0[24], l1[24], l2[24], l3[24], l4[24], l5[24];
  float ph = phFromMv(r.ph_mv);
  snprintf(l0, sizeof l0, "pH  %6.0f mV", r.ph_mv);
  if (isnan(ph)) snprintf(l1, sizeof l1, "    raw mode");
  else           snprintf(l1, sizeof l1, "    pH %.2f", ph);
  snprintf(l2, sizeof l2, "TDS %6.0f ppm", tdsPpm(r.tds_mv, r.temp_c));
  snprintf(l3, sizeof l3, "Tur %6.0f NTU", turbidityNtu(r.turb_mv));
  snprintf(l4, sizeof l4, "T   %6.1f C", r.temp_c);
  snprintf(l5, sizeof l5, "SG  %6.3f", specificGravity(r.density_g, r.temp_c));
  const char* lines[] = { "Calibration mode", "USB: connect in web app", "", l0, l1, l2, l3, l4, l5,
                          pumpBusy() ? "flushing..." : "" };
  dispLines(lines, sizeof(lines) / sizeof(lines[0]));
}

// ---------------------------------------------------------------------- setup
void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println();
  Serial.printf("# Aqua Milk Detect %s v%s (%s %s)\n", FW_NAME, FW_VER, __DATE__, __TIME__);
  Serial.println("# USB Web Serial, newline JSON, 115200. Send {\"cmd\":\"get_cal\"} to start.");

  dispBegin("Aqua Milk Detect");
  bool colour_ok = sensorsBegin();
  const char* boot[] = { "Calibration mode", "", colour_ok ? "sensors: I2C ok" : "sensors: TCS34725?",
                         "Connect USB in the", "web app to calibrate." };
  dispLines(boot, 5);

  sendCal();                                   // so the UI shows stored constants immediately
}

void loop() {
  sensorsUpdate();                             // non-blocking; drives every channel
  pollSerial();

  uint32_t now = millis();
  if (now - t_stream >= 200) { t_stream = now; sendReading(); }        // ~5 Hz
  if (now - t_tft    >= 500) { t_tft = now;    updateTft(); }

  static bool was_pumping = false;
  if (was_pumping && !pumpBusy()) Serial.println("{\"t\":\"flush_done\"}");
  was_pumping = pumpBusy();
}
