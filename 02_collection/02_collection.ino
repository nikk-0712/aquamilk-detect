/*
  02_collection.ino — Aqua Milk Detect, Stage 2: capture labelled training samples.
  ESP32 DevKit V1 (arduino-esp32 core). NO Wi-Fi, NO SD card — the browser writes the CSV.

  USB Web Serial, newline JSON, 115200 (PROJECT_CONTEXT.md §8). Sensor code and
  calibration come from libs/AquaMilkSensors, identical to 01_calibration.

  ---------------------------------------------------------------- device -> host
    {"t":"reading", ph, tds, turb, temp, dens, r, g, b, c, ts, count}   ~5 Hz live view
    {"t":"sample",  temp_c, ph_raw_mv, tds_raw_mv, turbidity_raw_mv, density_g,
                    color_r, color_g, color_b, color_clear,
                    ph_sd, tds_sd, turbidity_sd, density_sd, temp_sd,
                    sg, n, ts, count}
        One capture = one averaged row. Field names match the CSV schema (§5) 1:1;
        the browser prepends timestamp_iso, milk_type, adulterant, level_pct, source.
        *_sd are the per-channel standard deviations of that average — a large sd
        means something moved while you were capturing, so retake the sample.
        sg is the derived temperature-corrected specific gravity (model feature 3).
    {"t":"ack", cmd, ok, msg}
    {"t":"flush_done", count}

  ---------------------------------------------------------------- host -> device
    {"cmd":"capture"}                      average for avg_ms, then auto-flush
    {"cmd":"flush","ms":5000}
    {"cmd":"tare"}
    {"cmd":"set","key":"avg_ms","val":3000}
    {"cmd":"set","key":"flush_ms","val":5000}
    {"cmd":"reset_counter"}

  Captures are refused with {"t":"ack","ok":false,"msg":"busy"} while a capture or
  flush is already running. The counter is a session counter (RAM), reset by
  {"cmd":"reset_counter"} or a power cycle — the browser owns the real dataset.

  Libraries: same pinned set as 01_calibration (see that header + CI workflow).
*/

#include <ArduinoJson.h>
#include <sensors.h>
#include <serialio.h>
#include <display.h>

#define FW_NAME "02_collection"
#define FW_VER  "1.0.0"

enum State { IDLE, AVERAGING, FLUSHING };
static State    state = IDLE;
static uint16_t sample_count = 0;
static uint32_t t_stream = 0, t_tft = 0;

// ---------------------------------------------------------------------- output
static void sendReading() {
  JsonDocument d;
  readingJson(d);
  d["count"] = sample_count;          // the UI shows the on-device capture tally
  serializeJson(d, Serial);
  Serial.println();
}

// Emit the consolidated record. Names are the CSV column names from §5 so the
// browser can map them straight into a row.
static void sendSample(const AveragedSample& s) {
  JsonDocument d;
  d["t"] = "sample";
  d["temp_c"]           = s.temp_c;
  d["ph_raw_mv"]        = s.ph_mv;
  d["tds_raw_mv"]       = s.tds_mv;
  d["turbidity_raw_mv"] = s.turb_mv;
  d["density_g"]        = s.density_g;
  d["color_r"]          = s.r;
  d["color_g"]          = s.g;
  d["color_b"]          = s.b;
  d["color_clear"]      = s.c;
  d["ph_sd"]            = s.ph_sd;
  d["tds_sd"]           = s.tds_sd;
  d["turbidity_sd"]     = s.turb_sd;
  d["density_sd"]       = s.density_sd;
  d["temp_sd"]          = s.temp_sd;
  d["sg"]               = s.mean[F_DENSITY];
  d["n"]                = s.n;
  d["ts"]               = millis();
  d["count"]            = sample_count;
  serializeJson(d, Serial);
  Serial.println();
}

// ------------------------------------------------------------------- commands
static void handleLine(char* line) {
  JsonDocument in;
  if (deserializeJson(in, line)) return;                 // malformed: ignore
  const char* cmd = in["cmd"] | "";
  if (!*cmd) return;

  if (!strcmp(cmd, "capture")) {
    if (state != IDLE) { sendAck("capture", false, "busy"); return; }
    avgStart(cal.avg_ms);
    state = AVERAGING;
    sendAck("capture", true, "averaging");
  }
  else if (!strcmp(cmd, "flush")) {
    if (state != IDLE) { sendAck("flush", false, "busy"); return; }
    pumpStart(in["ms"] | cal.flush_ms);
    state = FLUSHING;
    sendAck("flush", true, "pump on");
  }
  else if (!strcmp(cmd, "tare")) {
    if (state != IDLE) { sendAck("tare", false, "busy"); return; }
    calTare();
    sendAck("tare", true, "chamber zeroed");
  }
  else if (!strcmp(cmd, "set")) {
    const char* key = in["key"] | "";
    if (!strcmp(key, "avg_ms")) {
      cal.avg_ms = constrain((int)(in["val"] | 3000), 200, 20000);
      calSave(); sendAck("set", true, "avg_ms set");
    } else if (!strcmp(key, "flush_ms")) {
      cal.flush_ms = constrain((int)(in["val"] | 5000), 0, 60000);
      calSave(); sendAck("set", true, "flush_ms set");
    } else {
      sendAck("set", false, "unknown key (use avg_ms / flush_ms)");
    }
  }
  else if (!strcmp(cmd, "reset_counter")) {
    sample_count = 0;
    sendAck("reset_counter", true, "counter cleared");
  }
  else sendAck(cmd, false, "unknown cmd");
}

// ------------------------------------------------------------------------ TFT
static void updateTft() {
  const Reading& r = sensorsLatest();
  static char v_cnt[10], v_ph[12], v_tds[12], v_turb[12], v_t[12], v_sg[12];
  snprintf(v_cnt,  sizeof v_cnt,  "%u", sample_count);
  snprintf(v_ph,   sizeof v_ph,   "%.0f mV", r.ph_mv);
  snprintf(v_tds,  sizeof v_tds,  "%.0f mV", r.tds_mv);
  snprintf(v_turb, sizeof v_turb, "%.0f mV", r.turb_mv);
  snprintf(v_t,    sizeof v_t,    "%.1f C", r.temp_c);
  snprintf(v_sg,   sizeof v_sg,   "%.3f", specificGravity(r.density_g, r.temp_c));

  const char* status = state == AVERAGING ? "Capturing..."
                     : state == FLUSHING  ? "Flushing..."
                                          : "Ready - hit Capture";
  const char* keys[] = { "Samples", "pH", "TDS", "Turbidity", "Temp", "Density" };
  const char* vals[] = { v_cnt, v_ph, v_tds, v_turb, v_t, v_sg };
  dispKV(status, keys, vals, sizeof(keys) / sizeof(keys[0]));
}

// ---------------------------------------------------------------------- setup
void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println();
  Serial.printf("# Aqua Milk Detect %s v%s (%s %s)\n", FW_NAME, FW_VER, __DATE__, __TIME__);
  Serial.println("# USB Web Serial, newline JSON, 115200. Send {\"cmd\":\"capture\"} to sample.");

  dispBegin("Aqua Milk Detect");
  sensorsBegin();
  const char* boot[] = { "Collection mode", "", "Connect USB in the", "web app, label the",
                         "sample, hit Capture." };
  dispLines(boot, 5);
}

void loop() {
  sensorsUpdate();          // also feeds the averager and runs the pump timer
  serialPoll(handleLine);

  switch (state) {
    case AVERAGING:
      if (!avgBusy()) {
        AveragedSample s = avgFinish();
        if (s.ok) {
          sample_count++;
          sendSample(s);
        } else {
          sendAck("capture", false, "no reads collected");
        }
        pumpStart(cal.flush_ms);       // auto-flush right after every capture (§11)
        state = FLUSHING;
      }
      break;

    case FLUSHING:
      if (!pumpBusy()) {
        JsonDocument d;
        d["t"] = "flush_done";
        d["count"] = sample_count;
        serializeJson(d, Serial);
        Serial.println();
        state = IDLE;
      }
      break;

    case IDLE:
    default:
      break;
  }

  uint32_t now = millis();
  if (now - t_stream >= 200) { t_stream = now; sendReading(); }   // ~5 Hz
  if (now - t_tft    >= 500) { t_tft = now;    updateTft(); }
}
