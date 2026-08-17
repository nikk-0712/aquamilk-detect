// serialio.cpp — see serialio.h.
#include "serialio.h"
#include "sensors.h"

void serialPoll(LineHandler fn) {
  static char     rx[256];
  static uint16_t len = 0;

  while (Serial.available()) {
    char ch = (char)Serial.read();
    if (ch == '\n' || ch == '\r') {
      if (len) { rx[len] = 0; fn(rx); len = 0; }
    } else if (len < sizeof(rx) - 1) {
      rx[len++] = ch;
    } else {
      len = 0;                     // overlong line: drop it whole
    }
  }
}

void sendAck(const char* cmd, bool ok, const char* msg) {
  JsonDocument d;
  d["t"] = "ack";
  d["cmd"] = cmd;
  d["ok"] = ok;
  d["msg"] = msg;
  serializeJson(d, Serial);
  Serial.println();
}

void readingJson(JsonDocument& d) {
  const Reading& r = sensorsLatest();
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
}
