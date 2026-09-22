/*
  02_collection.ino — Aqua Milk Detect, Stage 2: capture labelled training samples.
  ESP32 DevKit (arduino-esp32 core).

  WIRELESS collection. This unit's USB-serial path is dead, so the device runs a
  Wi-Fi SoftAP and serves its own collect page. Join the AP, label the sample, hit
  Capture: the averaged row is stored on the device in /samples.csv (LittleFS) and
  downloaded over Wi-Fi. No USB needed — the board runs from its 12 V supply.

  Sensor code + calibration: libs/AquaMilkSensors (same as 01_calibration).

  CSV columns (match the trainer, web/app.js COLUMNS):
    timestamp_iso, milk_type, adulterant, level_pct, source, temp_c, ph_raw_mv,
    tds_raw_mv, turbidity_raw_mv, color_r, color_g, color_b, color_clear
  (timestamp_iso is device ms since boot — the device has no clock; the trainer
   uses the sensor columns, not the timestamp.)

  Libraries: pinned set from 01_calibration + ESP Async WebServer + Async TCP.
*/

#include <WiFi.h>
#include <DNSServer.h>
#include <LittleFS.h>
#include <ArduinoJson.h>
#include <ESPAsyncWebServer.h>

#include <sensors.h>
#include <serialio.h>          // readingJson() builds the live-view JSON
#include <display.h>

#define FW_NAME "02_collection"
#define FW_VER  "2.0.0"
#define CSV_PATH "/samples.csv"

static const char* CSV_HEADER =
  "timestamp_iso,milk_type,adulterant,level_pct,source,temp_c,ph_raw_mv,"
  "tds_raw_mv,turbidity_raw_mv,color_r,color_g,color_b,color_clear\n";

static AsyncWebServer server(80);
static DNSServer      dns;
static String         ap_ssid, ap_pass, ip_str;

enum State { IDLE, AVERAGING, FLUSHING };
static State    state = IDLE;
static uint32_t sample_count = 0;
static uint32_t t_tft = 0;

// Label stashed when a capture is requested, written when the average completes.
static char p_milk[16] = "cow", p_adu[16] = "pure", p_src[64] = "";
static int  p_lvl = 0;

// -------------------------------------------------------------------- CSV (fs)
static void csvEnsureHeader() {
  if (LittleFS.exists(CSV_PATH)) return;
  File f = LittleFS.open(CSV_PATH, FILE_WRITE);
  if (f) { f.print(CSV_HEADER); f.close(); }
}

static uint32_t csvCountRows() {
  File f = LittleFS.open(CSV_PATH, FILE_READ);
  if (!f) return 0;
  uint32_t n = 0; bool first = true;
  while (f.available()) {
    String line = f.readStringUntil('\n');
    if (!line.length()) continue;
    if (first) { first = false; continue; }      // skip header
    n++;
  }
  f.close();
  return n;
}

static void csvAppend(const AveragedSample& s) {
  File f = LittleFS.open(CSV_PATH, FILE_APPEND);
  if (!f) return;
  f.printf("%lu,%s,%s,%d,%s,%.2f,%.1f,%.1f,%.1f,%u,%u,%u,%u\n",
           (unsigned long)millis(), p_milk, p_adu, p_lvl, p_src,
           s.temp_c, s.ph_mv, s.tds_mv, s.turb_mv,
           s.r, s.g, s.b, s.c);
  f.close();
}

// Strip commas/newlines from a label so it can't break the CSV; cap the length.
static void clean(char* dst, size_t n, const String& src) {
  size_t j = 0;
  for (size_t i = 0; i < src.length() && j < n - 1; i++) {
    char c = src[i];
    if (c == ',' || c == '\n' || c == '\r') c = ' ';
    dst[j++] = c;
  }
  dst[j] = 0;
}

// ------------------------------------------------------------------------ TFT
static void updateTft() {
  const Reading& r = sensorsLatest();
  static char v_cnt[10], v_ph[12], v_tds[12], v_turb[12], v_t[12], v_col[16];
  snprintf(v_cnt,  sizeof v_cnt,  "%lu", (unsigned long)sample_count);
  snprintf(v_ph,   sizeof v_ph,   "%.0f mV", r.ph_mv);
  snprintf(v_tds,  sizeof v_tds,  "%.0f mV", r.tds_mv);
  snprintf(v_turb, sizeof v_turb, "%.0f mV", r.turb_mv);
  snprintf(v_t,    sizeof v_t,    "%.1f C", r.temp_c);
  snprintf(v_col,  sizeof v_col,  "%u/%u/%u", r.r, r.g, r.b);
  const char* status = state == AVERAGING ? "Capturing..."
                     : state == FLUSHING  ? "Flushing..." : "Wi-Fi collect page";
  const char* keys[] = { "Samples", "pH", "TDS", "Turbidity", "Temp", "Colour" };
  const char* vals[] = { v_cnt, v_ph, v_tds, v_turb, v_t, v_col };
  dispKV(status, keys, vals, 6);
}

// ------------------------------------------------------------- Wi-Fi / captive
static void netStart() {
  uint8_t mac[6]; WiFi.macAddress(mac);
  char id[5]; snprintf(id, sizeof id, "%02X%02X", mac[4], mac[5]);
  ap_ssid = String("AquaMilk-") + id;
  ap_pass = String("aqua-") + id;              // 9 chars (AP needs >= 8)
  WiFi.mode(WIFI_AP);
  WiFi.softAP(ap_ssid.c_str(), ap_pass.c_str());
  ip_str = WiFi.softAPIP().toString();         // 192.168.4.1
  dns.setErrorReplyCode(DNSReplyCode::NoError);
  dns.start(53, "*", WiFi.softAPIP());          // captive portal -> auto-open the page
}

static String argS(AsyncWebServerRequest* q, const char* k) {
  if (q->hasParam(k, true))  return q->getParam(k, true)->value();
  if (q->hasParam(k, false)) return q->getParam(k, false)->value();
  return String();
}

// --------------------------------------------------------------- served page
static const char PAGE[] PROGMEM = R"HTML(<!doctype html><html><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>Aqua Milk - Collect</title>
<style>
body{font-family:system-ui,sans-serif;margin:0;background:#0b1416;color:#e8eef0}
header{padding:14px 16px;font-weight:700;color:#0FB5C9;font-size:18px}
.card{background:#14201f;margin:12px;padding:14px;border-radius:14px}
label{display:block;font-size:12px;color:#8aa;margin:10px 0 4px}
select,input{width:100%;padding:10px;border-radius:8px;border:1px solid #2a3a3a;background:#0e1a1a;color:#e8eef0;font-size:16px;box-sizing:border-box}
.row{display:flex;gap:8px;flex-wrap:wrap;margin-top:10px}
button{flex:1;min-width:90px;padding:14px;border:0;border-radius:10px;background:#0FB5C9;color:#012;font-weight:700;font-size:16px}
button.sec{background:#223333;color:#cfe}
button:disabled{opacity:.5}
a.dl{display:block;text-align:center;padding:14px;border-radius:10px;background:#223333;color:#cfe;text-decoration:none;font-weight:700;margin-top:10px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:8px}
.m{background:#0e1a1a;border-radius:10px;padding:10px}
.m b{display:block;font-size:20px}.m span{font-size:11px;color:#8aa}
.big{grid-column:1/3;text-align:center}.big b{font-size:34px;color:#0FB5C9}
#st{font-size:13px;color:#8aa;margin-top:8px;min-height:16px}
</style></head><body>
<header>Aqua Milk - Collect (Wi-Fi)</header>
<div class=card>
<label>Milk type</label>
<select id=milk><option>cow</option><option>buffalo</option><option>toned</option></select>
<label>Adulterant</label>
<select id=adu><option>pure</option><option>water</option><option>detergent</option><option>starch</option></select>
<label>Level % (0 for pure)</label><input id=lvl type=number value=0>
<label>Source</label><input id=src placeholder="dairy / shop / lab prep">
</div>
<div class=card>
<div class=grid>
<div class=m><b id=ph>-</b><span>pH (mV)</span></div>
<div class=m><b id=tds>-</b><span>TDS (mV)</span></div>
<div class=m><b id=turb>-</b><span>Turbidity (mV)</span></div>
<div class=m><b id=temp>-</b><span>Temp (C)</span></div>
<div class=m><b id=col>-</b><span>Colour R/G/B</span></div>
<div class=m><b id=cnt>0</b><span>Saved samples</span></div>
</div>
<div class=row>
<button id=cap>Capture</button>
<button class=sec id=flush>Flush</button>
</div>
<div id=st></div>
<a class=dl href="/api/csv" download="samples.csv">Download CSV</a>
<div class=row><button class=sec id=clr>Clear all samples</button></div>
</div>
<script>
var $=function(i){return document.getElementById(i)};
var busy=false;
function poll(){fetch('/api/reading').then(function(r){return r.json()}).then(function(d){
 $('ph').textContent=Math.round(d.ph);$('tds').textContent=Math.round(d.tds);
 $('turb').textContent=Math.round(d.turb);$('temp').textContent=(d.temp==null?0:d.temp).toFixed(1);
 $('col').textContent=d.r+'/'+d.g+'/'+d.b;$('cnt').textContent=d.count;
 var wb=busy;busy=(d.state!=='idle');$('cap').disabled=busy;
 if(!busy&&wb)$('st').textContent='saved - '+d.count+' samples';
}).catch(function(){$('st').textContent='link lost - move closer / rejoin';})}
setInterval(poll,600);poll();
$('cap').onclick=function(){
 var p='milk='+encodeURIComponent($('milk').value)+'&adu='+encodeURIComponent($('adu').value)+'&lvl='+encodeURIComponent($('lvl').value||0)+'&src='+encodeURIComponent($('src').value);
 $('st').textContent='capturing...';
 fetch('/api/capture',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:p});
};
$('flush').onclick=function(){fetch('/api/flush',{method:'POST'})};
$('clr').onclick=function(){if(confirm('Erase all saved samples on the device?'))fetch('/api/clear',{method:'POST'}).then(function(){$('st').textContent='cleared'})};
</script></body></html>)HTML";

static void routes() {
  server.on("/", HTTP_GET, [](AsyncWebServerRequest* q) {
    q->send_P(200, "text/html", PAGE);
  });

  server.on("/api/reading", HTTP_GET, [](AsyncWebServerRequest* q) {
    JsonDocument d;
    readingJson(d);
    d["count"] = sample_count;
    d["state"] = state == AVERAGING ? "capturing" : state == FLUSHING ? "flushing" : "idle";
    String s; serializeJson(d, s);
    q->send(200, "application/json", s);
  });

  server.on("/api/capture", HTTP_POST, [](AsyncWebServerRequest* q) {
    if (state != IDLE) { q->send(200, "application/json", "{\"ok\":false,\"msg\":\"busy\"}"); return; }
    clean(p_milk, sizeof p_milk, argS(q, "milk"));
    clean(p_adu,  sizeof p_adu,  argS(q, "adu"));
    clean(p_src,  sizeof p_src,  argS(q, "src"));
    p_lvl = argS(q, "lvl").toInt();
    if (!p_milk[0]) strcpy(p_milk, "cow");
    if (!p_adu[0])  strcpy(p_adu, "pure");
    avgStart(cal.avg_ms);
    state = AVERAGING;
    q->send(200, "application/json", "{\"ok\":true}");
  });

  server.on("/api/flush", HTTP_POST, [](AsyncWebServerRequest* q) {
    if (state == IDLE) { pumpStart(cal.flush_ms); state = FLUSHING; }
    q->send(200, "application/json", "{\"ok\":true}");
  });

  server.on("/api/csv", HTTP_GET, [](AsyncWebServerRequest* q) {
    if (LittleFS.exists(CSV_PATH)) q->send(LittleFS, CSV_PATH, "text/csv");
    else                           q->send(200, "text/csv", CSV_HEADER);
  });

  server.on("/api/clear", HTTP_POST, [](AsyncWebServerRequest* q) {
    LittleFS.remove(CSV_PATH);
    csvEnsureHeader();
    sample_count = 0;
    q->send(200, "application/json", "{\"ok\":true}");
  });

  server.onNotFound([](AsyncWebServerRequest* q) {
    q->redirect(String("http://") + ip_str + "/");   // captive portal
  });
}

// ---------------------------------------------------------------------- setup
void setup() {
  Serial.begin(115200);
  delay(150);
  Serial.printf("# Aqua Milk Detect %s v%s (%s %s)\n", FW_NAME, FW_VER, __DATE__, __TIME__);

  dispBegin("Aqua Milk Detect");
  sensorsBegin();

  if (!LittleFS.begin(true)) Serial.println("# LittleFS mount failed");
  csvEnsureHeader();
  sample_count = csvCountRows();

  netStart();
  Serial.printf("# AP %s  pass %s  http://%s\n", ap_ssid.c_str(), ap_pass.c_str(), ip_str.c_str());

  routes();
  server.begin();

  static char l_ssid[26], l_pass[26], l_ip[26];
  snprintf(l_ssid, sizeof l_ssid, "SSID: %s", ap_ssid.c_str());
  snprintf(l_pass, sizeof l_pass, "Pass: %s", ap_pass.c_str());
  snprintf(l_ip,   sizeof l_ip,   "%s", ip_str.c_str());
  const char* boot[] = { "Collection (Wi-Fi)", "", "Join this network:", l_ssid, l_pass,
                         "then open 192.168.4.1", l_ip };
  dispLines(boot, 7);
}

void loop() {
  dns.processNextRequest();
  sensorsUpdate();                         // also feeds the averager + pump timer

  if (state == AVERAGING && !avgBusy()) {
    AveragedSample s = avgFinish();
    if (s.ok) { csvAppend(s); sample_count++; }
    pumpStart(cal.flush_ms);               // auto-flush after every capture
    state = FLUSHING;
  }
  if (state == FLUSHING && !pumpBusy()) state = IDLE;

  uint32_t now = millis();
  if (now - t_tft >= 500) { t_tft = now; updateTft(); }
}
