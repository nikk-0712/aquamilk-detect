// sensors.cpp — see sensors.h. One implementation, three firmwares.
#include "sensors.h"

#include <Preferences.h>
#include <Wire.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <Adafruit_TCS34725.h>
#include <HX711.h>

// ------------------------------------------------------------------ internals
Calibration cal;

static Preferences prefs;
static Reading g_r;

static OneWire           oneWire(PIN_ONEWIRE);
static DallasTemperature ds18b20(&oneWire);
static Adafruit_TCS34725  tcs(TCS34725_INTEGRATIONTIME_24MS, TCS34725_GAIN_1X);
static HX711             scale;

static bool     tcs_present = false;
static uint32_t t_analog = 0, t_color = 0, t_temp_req = 0;
static bool     temp_pending = false;

// Pump state
static bool     pump_on = false;
static uint32_t pump_until = 0;

// Averaging state. Channels 0..8 are the feature vector (features.h); channel 9
// is density in grams, which the CSV wants next to the derived specific gravity.
#define AVG_CH      (FEATURE_COUNT + 1)
#define AVG_DENS_G  FEATURE_COUNT
#define AVG_MAX     96
static float    avg_buf[AVG_CH][AVG_MAX];
static uint16_t avg_n = 0;
static uint32_t avg_until = 0, avg_last_ts = 0;
static bool     avg_running = false;

// ------------------------------------------------------------- small utilities
static float readMv(uint8_t pin, float divider, uint16_t reads) {
  // ADC1 only (§3). analogReadMilliVolts() applies the per-chip calibration curve,
  // which is far better than scaling a raw count ourselves.
  uint32_t sum = 0;
  for (uint16_t i = 0; i < reads; i++) sum += analogReadMilliVolts(pin);
  return (float)sum / reads * divider;
}

static float mean_of(const float* v, uint16_t n) {
  if (!n) return NAN;
  float s = 0;
  for (uint16_t i = 0; i < n; i++) s += v[i];
  return s / n;
}

static void sort_copy(const float* src, float* dst, uint16_t n) {
  memcpy(dst, src, n * sizeof(float));
  for (uint16_t i = 1; i < n; i++) {            // insertion sort, n <= 96
    float k = dst[i];
    int16_t j = i - 1;
    while (j >= 0 && dst[j] > k) { dst[j + 1] = dst[j]; j--; }
    dst[j + 1] = k;
  }
}

// Trimmed mean + sd: drop the lowest and highest 10% before averaging, so one
// bubble on the turbidity window or one bump of the bench cannot move a sample.
static void trimmed_stats(const float* src, uint16_t n, float& mean, float& sd) {
  if (n == 0) { mean = NAN; sd = 0; return; }
  static float tmp[AVG_MAX];
  sort_copy(src, tmp, n);
  uint16_t cut = n / 10;
  uint16_t lo = cut, hi = n - cut;              // [lo, hi)
  if (hi <= lo) { lo = 0; hi = n; }
  uint16_t m = hi - lo;
  mean = mean_of(tmp + lo, m);
  float acc = 0;
  for (uint16_t i = lo; i < hi; i++) acc += (tmp[i] - mean) * (tmp[i] - mean);
  sd = (m > 1) ? sqrtf(acc / (m - 1)) : 0.0f;
}

// --------------------------------------------------------------- calibration IO
void calLoad() {
  Calibration d;                                // defaults
  prefs.begin("amd_cal", true);
  cal.ph_mv7      = prefs.getFloat ("ph_mv7",   d.ph_mv7);
  cal.ph_mv4      = prefs.getFloat ("ph_mv4",   d.ph_mv4);
  cal.ph_slope    = prefs.getFloat ("ph_slope", d.ph_slope);
  cal.ph_offset   = prefs.getFloat ("ph_off",   d.ph_offset);
  cal.ph_raw_mode = prefs.getBool  ("ph_raw",   d.ph_raw_mode);
  cal.tds_k       = prefs.getFloat ("tds_k",    d.tds_k);
  cal.turb_clear_mv = prefs.getFloat("turb0",   d.turb_clear_mv);
  cal.col_wr      = prefs.getFloat ("col_wr",   d.col_wr);
  cal.col_wg      = prefs.getFloat ("col_wg",   d.col_wg);
  cal.col_wb      = prefs.getFloat ("col_wb",   d.col_wb);
  cal.col_wc      = prefs.getFloat ("col_wc",   d.col_wc);
  cal.hx_offset   = prefs.getLong  ("hx_off",   d.hx_offset);
  cal.hx_scale    = prefs.getFloat ("hx_scale", d.hx_scale);
  cal.div_ph      = prefs.getFloat ("div_ph",   d.div_ph);
  cal.div_tds     = prefs.getFloat ("div_tds",  d.div_tds);
  cal.div_turb    = prefs.getFloat ("div_turb", d.div_turb);
  cal.oversample  = prefs.getUShort("oversamp", d.oversample);
  cal.avg_ms      = prefs.getUShort("avg_ms",   d.avg_ms);
  cal.flush_ms    = prefs.getUShort("flush_ms", d.flush_ms);
  cal.conf_threshold = prefs.getFloat("conf_thr", d.conf_threshold);
  cal.chamber_ml  = prefs.getFloat ("chamber",  d.chamber_ml);
  prefs.end();
  if (cal.oversample < 1)   cal.oversample = 1;
  if (cal.oversample > 256) cal.oversample = 256;
  scale.set_offset(cal.hx_offset);
  scale.set_scale(cal.hx_scale != 0 ? cal.hx_scale : 1.0f);
}

void calSave() {
  prefs.begin("amd_cal", false);
  prefs.putFloat ("ph_mv7",   cal.ph_mv7);
  prefs.putFloat ("ph_mv4",   cal.ph_mv4);
  prefs.putFloat ("ph_slope", cal.ph_slope);
  prefs.putFloat ("ph_off",   cal.ph_offset);
  prefs.putBool  ("ph_raw",   cal.ph_raw_mode);
  prefs.putFloat ("tds_k",    cal.tds_k);
  prefs.putFloat ("turb0",    cal.turb_clear_mv);
  prefs.putFloat ("col_wr",   cal.col_wr);
  prefs.putFloat ("col_wg",   cal.col_wg);
  prefs.putFloat ("col_wb",   cal.col_wb);
  prefs.putFloat ("col_wc",   cal.col_wc);
  prefs.putLong  ("hx_off",   cal.hx_offset);
  prefs.putFloat ("hx_scale", cal.hx_scale);
  prefs.putFloat ("div_ph",   cal.div_ph);
  prefs.putFloat ("div_tds",  cal.div_tds);
  prefs.putFloat ("div_turb", cal.div_turb);
  prefs.putUShort("oversamp", cal.oversample);
  prefs.putUShort("avg_ms",   cal.avg_ms);
  prefs.putUShort("flush_ms", cal.flush_ms);
  prefs.putFloat ("conf_thr", cal.conf_threshold);
  prefs.putFloat ("chamber",  cal.chamber_ml);
  prefs.end();
}

void calFactoryReset() {
  prefs.begin("amd_cal", false);
  prefs.clear();
  prefs.end();
  cal = Calibration();
  scale.set_offset(cal.hx_offset);
  scale.set_scale(cal.hx_scale);
}

// ------------------------------------------------------------------- lifecycle
bool sensorsBegin() {
  analogReadResolution(12);
  analogSetPinAttenuation(PIN_PH,        ADC_11db);   // widest range, 0..~3.1 V
  analogSetPinAttenuation(PIN_TDS,       ADC_11db);
  analogSetPinAttenuation(PIN_TURBIDITY, ADC_11db);

  Wire.begin(PIN_SDA, PIN_SCL);
  tcs_present = tcs.begin();

  ds18b20.begin();
  ds18b20.setWaitForConversion(false);   // async: request now, collect ~750 ms later
  ds18b20.setResolution(12);

  scale.begin(PIN_HX711_DOUT, PIN_HX711_SCK);

  calLoad();                             // also pushes offset/scale into the HX711
  pumpBegin();

  g_r.ts_ms = millis();
  return tcs_present;                    // the colour chip is the one we can probe on I2C
}

void sensorsUpdate() {
  const uint32_t now = millis();

  // --- analog trio, every 50 ms ---
  if (now - t_analog >= 50) {
    t_analog = now;
    g_r.ph_mv   = readMv(PIN_PH,        cal.div_ph,   cal.oversample);
    g_r.tds_mv  = readMv(PIN_TDS,       cal.div_tds,  cal.oversample);
    g_r.turb_mv = readMv(PIN_TURBIDITY, cal.div_turb, cal.oversample);
    g_r.ts_ms   = now;
  }

  // --- DS18B20: fire a conversion, pick it up 800 ms later ---
  if (!temp_pending && now - t_temp_req >= 1000) {
    ds18b20.requestTemperatures();
    t_temp_req = now;
    temp_pending = true;
  } else if (temp_pending && now - t_temp_req >= 800) {
    float t = ds18b20.getTempCByIndex(0);
    temp_pending = false;
    // DEVICE_DISCONNECTED_C is -127; anything outside a sane bench range is a fault
    if (t > -40.0f && t < 85.0f) { g_r.temp_c = t; g_r.ok_temp = true; }
    else                         { g_r.ok_temp = false; }
  }

  // --- colour, every 150 ms (getRawData blocks for the 24 ms integration) ---
  if (tcs_present && now - t_color >= 150) {
    t_color = now;
    uint16_t r, g, b, c;
    tcs.getRawData(&r, &g, &b, &c);
    g_r.r = r; g_r.g = g; g_r.b = b; g_r.c = c;
    g_r.ok_color = (c > 0);
  }

  // --- HX711: read whenever a conversion is sitting there (~10/s) ---
  if (scale.is_ready()) {
    long raw = scale.read();
    float grams = (raw - (float)cal.hx_offset) / (cal.hx_scale != 0 ? cal.hx_scale : 1.0f);
    // light smoothing: the cell is noisy at 10 SPS and the chamber is not moving
    g_r.density_g = isnan(g_r.density_g) ? grams : (0.7f * g_r.density_g + 0.3f * grams);
    g_r.ok_scale = true;
  }

  pumpUpdate();
  if (avg_running) avgFeed();
}

const Reading& sensorsLatest() { return g_r; }

// ------------------------------------------------------ derived (display only)
float phFromMv(float mv) {
  if (cal.ph_raw_mode || isnan(mv)) return NAN;      // caller shows raw mV instead
  return cal.ph_slope * mv + cal.ph_offset;
}

float tdsPpm(float mv, float temp_c) {
  if (isnan(mv)) return NAN;
  float t = isnan(temp_c) ? 25.0f : temp_c;
  float v = mv / 1000.0f;                            // Gravity TDS curve wants volts
  float comp_v = v / (1.0f + 0.02f * (t - 25.0f));   // temperature compensation
  float ppm = (133.42f * comp_v * comp_v * comp_v
             - 255.86f * comp_v * comp_v
             + 857.39f * comp_v) * 0.5f * cal.tds_k;
  return ppm < 0 ? 0 : ppm;
}

float turbidityNtu(float mv) {
  if (isnan(mv)) return NAN;
  // Datasheet quadratic for the common 0-4.5 V turbidity module, referenced to the
  // clear-water zero captured during calibration so a dirty window does not read as milk.
  float v = mv / 1000.0f;
  float v_clear = cal.turb_clear_mv / 1000.0f;
  float v_adj = v + (4.2f - v_clear);                // shift so clear water lands at 4.2 V
  float ntu = -1120.4f * v_adj * v_adj + 5742.3f * v_adj - 4352.9f;
  if (ntu < 0)    ntu = 0;
  if (ntu > 3000) ntu = 3000;                        // sensor saturates; milk is well past this
  return ntu;
}

float specificGravity(float grams, float temp_c) {
  if (isnan(grams) || cal.chamber_ml <= 0) return NAN;
  float t = isnan(temp_c) ? 25.0f : temp_c;
  float rho = grams / cal.chamber_ml;                        // g/mL as measured
  // Correct to 20 C. 2.1e-4 /K is the volumetric expansion of milk/water near room
  // temperature; tune it here if you characterise your own chamber.
  float rho20 = rho * (1.0f + 2.1e-4f * (t - 20.0f));
  return rho20 / 0.998203f;                                  // vs water at 20 C
}

void featuresFrom(const Reading& r, float out[FEATURE_COUNT]) {
  out[F_PH]          = r.ph_mv;
  out[F_TDS]         = r.tds_mv;
  out[F_TURBIDITY]   = r.turb_mv;
  out[F_DENSITY]     = specificGravity(r.density_g, r.temp_c);
  out[F_TEMPERATURE] = isnan(r.temp_c) ? 25.0f : r.temp_c;
  out[F_COLOR_R]     = r.r;
  out[F_COLOR_G]     = r.g;
  out[F_COLOR_B]     = r.b;
  out[F_COLOR_CLEAR] = r.c;
}

// ------------------------------------------------------------ calibration acts
bool calPhPoint(float ph_point) {
  float mv = g_r.ph_mv;
  if (isnan(mv) || mv <= 0) return false;
  if (fabsf(ph_point - 7.0f) < 0.5f)      cal.ph_mv7 = mv;
  else if (fabsf(ph_point - 4.0f) < 0.5f) cal.ph_mv4 = mv;
  else return false;                                   // only the 7.0 and 4.0 buffers

  if (!isnan(cal.ph_mv7) && !isnan(cal.ph_mv4) &&
      fabsf(cal.ph_mv4 - cal.ph_mv7) > 20.0f) {        // need a real span, not noise
    cal.ph_slope  = (4.0f - 7.0f) / (cal.ph_mv4 - cal.ph_mv7);
    cal.ph_offset = 7.0f - cal.ph_slope * cal.ph_mv7;
    cal.ph_raw_mode = false;                           // two good points: report pH
  }
  calSave();
  return true;
}

bool calTdsWithKnown(float known_ppm) {
  if (known_ppm <= 0) { calSave(); return true; }       // keep the stock response
  float uncal = tdsPpm(g_r.tds_mv, g_r.temp_c) / (cal.tds_k != 0 ? cal.tds_k : 1.0f);
  if (uncal < 1.0f) return false;                       // probe in air / not wet
  cal.tds_k = known_ppm / uncal;
  calSave();
  return true;
}

void calTurbidityClear() {
  if (!isnan(g_r.turb_mv)) cal.turb_clear_mv = g_r.turb_mv;
  calSave();
}

void calColorWhite() {
  cal.col_wr = g_r.r; cal.col_wg = g_r.g; cal.col_wb = g_r.b; cal.col_wc = g_r.c;
  calSave();
}

void calTare() {
  scale.set_offset(scale.read_average(16));
  cal.hx_offset = scale.get_offset();
  g_r.density_g = NAN;                                  // drop the smoothing history
  calSave();
}

bool calDensitySpan(float known_g) {
  if (known_g <= 0) return false;
  long raw = scale.read_average(16);
  float counts = (float)(raw - cal.hx_offset);
  if (fabsf(counts) < 100.0f) return false;             // nothing on the cell
  cal.hx_scale = counts / known_g;
  scale.set_scale(cal.hx_scale);
  calSave();
  return true;
}

// ------------------------------------------------------------------ averaging
void avgStart(uint16_t window_ms) {
  avg_n = 0;
  avg_last_ts = 0;
  avg_until = millis() + (window_ms ? window_ms : cal.avg_ms);
  avg_running = true;
}

bool avgBusy() {
  if (!avg_running) return false;
  if ((int32_t)(millis() - avg_until) >= 0) avg_running = false;
  return avg_running;
}

void avgFeed() {
  if (!avg_running || avg_n >= AVG_MAX) return;
  if (g_r.ts_ms == avg_last_ts) return;                 // no fresh analog frame yet
  avg_last_ts = g_r.ts_ms;
  float f[FEATURE_COUNT];
  featuresFrom(g_r, f);
  for (uint8_t i = 0; i < FEATURE_COUNT; i++) avg_buf[i][avg_n] = f[i];
  avg_buf[AVG_DENS_G][avg_n] = g_r.density_g;
  avg_n++;
}

AveragedSample avgFinish() {
  avg_running = false;
  AveragedSample s;
  if (avg_n == 0) return s;                             // ok stays false

  for (uint8_t i = 0; i < FEATURE_COUNT; i++) trimmed_stats(avg_buf[i], avg_n, s.mean[i], s.sd[i]);
  float dens_mean, dens_sd;
  trimmed_stats(avg_buf[AVG_DENS_G], avg_n, dens_mean, dens_sd);

  s.ph_mv     = s.mean[F_PH];          s.ph_sd      = s.sd[F_PH];
  s.tds_mv    = s.mean[F_TDS];         s.tds_sd     = s.sd[F_TDS];
  s.turb_mv   = s.mean[F_TURBIDITY];   s.turb_sd    = s.sd[F_TURBIDITY];
  s.temp_c    = s.mean[F_TEMPERATURE]; s.temp_sd    = s.sd[F_TEMPERATURE];
  s.density_g = dens_mean;             s.density_sd = dens_sd;
  s.r = (uint16_t)lroundf(s.mean[F_COLOR_R]);
  s.g = (uint16_t)lroundf(s.mean[F_COLOR_G]);
  s.b = (uint16_t)lroundf(s.mean[F_COLOR_B]);
  s.c = (uint16_t)lroundf(s.mean[F_COLOR_CLEAR]);
  s.n = avg_n;
  s.ok = true;
  avg_n = 0;
  return s;
}

// ----------------------------------------------------------------------- pump
static inline void pumpWrite(bool on) {
  // LEDC on GPIO25 (§4). Full-on/full-off duty: PWM exists so a future build can
  // dial the flow rate down without touching call sites.
  bool level = PUMP_ACTIVE_LOW ? !on : on;
  ledcWrite(PIN_PUMP, level ? 255 : 0);
}

void pumpBegin() {
  ledcAttach(PIN_PUMP, 1000, 8);      // 1 kHz, 8-bit — arduino-esp32 3.x API
  pump_on = false;
  pumpWrite(false);
}

void pumpStart(uint32_t ms) {
  if (ms == 0) ms = cal.flush_ms;
  pump_until = millis() + ms;
  pump_on = true;
  pumpWrite(true);
}

void pumpStop() {
  pump_on = false;
  pumpWrite(false);
}

bool pumpBusy() { return pump_on; }

void pumpUpdate() {
  if (pump_on && (int32_t)(millis() - pump_until) >= 0) pumpStop();
}

// ------------------------------------------------------------------- selftest
bool sensorsSelftest(Reading& out, char* why, size_t why_len) {
  // Give every channel a chance to refresh at least once (DS18B20 is the slow one).
  uint32_t t0 = millis();
  while (millis() - t0 < 1200) { sensorsUpdate(); delay(5); }
  out = g_r;

  bool analog_ok = !isnan(g_r.ph_mv) && !isnan(g_r.tds_mv) && !isnan(g_r.turb_mv);
  bool ok = analog_ok && g_r.ok_temp && g_r.ok_color && g_r.ok_scale;
  if (why && why_len) {
    if (ok) snprintf(why, why_len, "all ok");
    else    snprintf(why, why_len, "no response: %s%s%s%s",
                     analog_ok    ? "" : "analog ",
                     g_r.ok_temp  ? "" : "ds18b20 ",
                     g_r.ok_color ? "" : "tcs34725 ",
                     g_r.ok_scale ? "" : "hx711");
  }
  return ok;
}
