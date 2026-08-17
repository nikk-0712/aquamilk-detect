// sensors.h — shared sensor stack for Aqua Milk Detect (all three firmwares).
//
// Everything here is non-blocking-ish: sensorsUpdate() must be called often from
// loop(); each channel refreshes at its own cadence (DS18B20 needs 750 ms per
// conversion, HX711 delivers ~10 samples/s, the colour chip needs its integration
// time) and the newest value of every channel is cached in a Reading.
//
// Pin map: pins.h (PROJECT_CONTEXT.md §3). Calibration lives in NVS namespace
// "amd_cal". Feature order: features.h.
#pragma once

#include <Arduino.h>
#include "pins.h"
#include "features.h"

// ---------------------------------------------------------------- pump wiring
// PROJECT_CONTEXT.md §4: the IRF520 module is not logic-level, so the documented
// wiring drives its gate through a 2N2222 (GPIO25 -> 1k -> base, collector -> SIG
// with 10k pull-up to +5V). That transistor INVERTS the signal: GPIO HIGH = pump OFF.
// Set this false only if you swap in a logic-level MOSFET (e.g. IRLZ44N) driven directly.
#ifndef PUMP_ACTIVE_LOW
#define PUMP_ACTIVE_LOW true
#endif

// ------------------------------------------------------------------- readings
// One snapshot. *_mv values are already divider-corrected (i.e. the voltage the
// sensor board actually put out, not the voltage the ESP32 pin saw).
struct Reading {
  float    temp_c        = NAN;
  float    ph_mv         = NAN;
  float    tds_mv        = NAN;
  float    turb_mv       = NAN;
  float    density_g     = NAN;   // grams in the chamber, tare-corrected
  uint16_t r = 0, g = 0, b = 0, c = 0;
  uint32_t ts_ms         = 0;
  // liveness flags, refreshed by sensorsUpdate()
  bool ok_temp = false, ok_color = false, ok_scale = false;
};

// Per-channel mean + standard deviation from a trimmed average (Stage 2 reports these).
struct AveragedSample {
  float mean[FEATURE_COUNT];
  float sd[FEATURE_COUNT];
  float temp_c = NAN, ph_mv = NAN, tds_mv = NAN, turb_mv = NAN, density_g = NAN;
  float temp_sd = 0, ph_sd = 0, tds_sd = 0, turb_sd = 0, density_sd = 0;
  uint16_t r = 0, g = 0, b = 0, c = 0;
  uint16_t n = 0;          // reads that survived trimming
  bool ok = false;
};

// ---------------------------------------------------------------- calibration
struct Calibration {
  // pH: two-point fit, pH = ph_slope * mv + ph_offset (slope is negative on most boards)
  float ph_mv7  = NAN;          // mV captured in pH 7.0 buffer
  float ph_mv4  = NAN;          // mV captured in pH 4.0 buffer
  float ph_slope  = -0.0169f;   // -1/59.16: the ideal Nernst 59.16 mV per pH unit at 25 C
  float ph_offset = 7.0f;
  bool  ph_raw_mode = true;     // default true: the user may skip buffers entirely

  float tds_k = 1.0f;           // TDS K factor (1.0 = stock probe response)
  float turb_clear_mv = 3300.0f;// clear-water reference, set by calibration

  float col_wr = 0, col_wg = 0, col_wb = 0, col_wc = 0;  // white reference (0 = unset)

  long  hx_offset = 0;          // load cell tare, raw counts
  float hx_scale  = 420.0f;     // raw counts per gram — MUST be calibrated per cell

  // ADC divider ratios: sensor_mv = pin_mv * div. 2.0 means a 2:1 divider (§3).
  float div_ph = 2.0f, div_tds = 1.0f, div_turb = 2.0f;

  uint16_t oversample = 64;     // ADC reads averaged per channel per update
  uint16_t avg_ms     = 3000;   // averaging window for one sample/test (§11)
  uint16_t flush_ms   = 5000;   // auto-flush duration (§11)
  float    conf_threshold = 0.60f;  // "Uncertain" below this (§6)
  float    chamber_ml = 100.0f; // fixed chamber volume used for specific gravity
};

extern Calibration cal;

// ------------------------------------------------------------------------ API
bool sensorsBegin();          // init buses + sensors, load calibration from NVS
void sensorsUpdate();         // call every loop(); refreshes whatever is due
const Reading& sensorsLatest();

void calLoad();
void calSave();
void calFactoryReset();       // wipe NVS, restore defaults

// Calibration actions (return false if the captured value was implausible)
bool calPhPoint(float ph_point);        // capture current mV as the 7.0 or 4.0 point
bool calTdsWithKnown(float known_ppm);  // solve K from a known solution (<=0 = keep default)
void calTurbidityClear();               // current mV becomes the clear-water zero
void calColorWhite();                   // current RGBC becomes the white reference
void calTare();                         // zero the load cell
bool calDensitySpan(float known_g);     // set counts-per-gram from a known weight

// Derived / display-only conversions (NOT model features — see features.h)
float phFromMv(float mv);
float tdsPpm(float mv, float temp_c);
float turbidityNtu(float mv);
float specificGravity(float grams, float temp_c);   // temp-corrected to 20 C

// Build the model feature vector from a reading (order per features.h)
void featuresFrom(const Reading& r, float out[FEATURE_COUNT]);

// Trimmed averaging: avgStart(), then keep calling sensorsUpdate() + avgFeed()
// until !avgBusy(), then avgFinish(). Drops the top/bottom 10% per channel.
void avgStart(uint16_t window_ms);
bool avgBusy();
void avgFeed();                       // cheap; ignores repeat timestamps
AveragedSample avgFinish();

// Pump / flush (§4). Non-blocking: call pumpUpdate() from loop().
void pumpBegin();
void pumpStart(uint32_t ms);
void pumpStop();
bool pumpBusy();
void pumpUpdate();

// All-sensors health check. Fills ok_* flags, writes a reason into `why` on failure.
bool sensorsSelftest(Reading& out, char* why, size_t why_len);
