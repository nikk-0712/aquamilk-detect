// display.cpp — see display.h.
#include "display.h"
#include "pins.h"
#include <Preferences.h>

static Adafruit_ST7735 tft(PIN_TFT_CS, PIN_TFT_DC, PIN_TFT_RST);

#define HEADER_H 18          // aqua title strip; body text starts below it

static uint8_t s_rot = AMD_TFT_ROTATION;

// Apply the panel's fine offset then the rotation. Order matters: setRotation()
// derives the address-window start from the col/row start, so the nudge is set
// first. setColRowStart(0,0) is a no-op, so this is safe when no nudge is needed.
static void applyRotation() {
#if (AMD_TFT_COLSTART != 0) || (AMD_TFT_ROWSTART != 0)
  tft.setColRowStart(AMD_TFT_COLSTART, AMD_TFT_ROWSTART);   // only pulled in when nudged
#endif
  tft.setRotation(s_rot & 3);
}

static void rotLoad() {
  Preferences p;
  p.begin("amd_cal", true);
  s_rot = p.getUChar("tft_rot", AMD_TFT_ROTATION) & 3;
  p.end();
}

static void rotSave() {
  Preferences p;
  p.begin("amd_cal", false);
  p.putUChar("tft_rot", s_rot & 3);
  p.end();
}

void dispBegin(const char* title) {
  rotLoad();
  tft.initR(AMD_TFT_INITR);           // panel variant (fixes edge-offset glitch)
  applyRotation();
  tft.fillScreen(AMD_BG);
  tft.setTextWrap(false);
  dispTitle(title);
}

void dispSetRotation(uint8_t r) {
  s_rot = r & 3;
  rotSave();
  applyRotation();
  tft.fillScreen(AMD_BG);             // orientation changed; caller repaints
}

uint8_t dispRotation() { return s_rot; }

// Header: title in aqua with a crisp 2px accent rule under it, so it reads as
// intentional app chrome rather than a floating line.
void dispTitle(const char* title) {
  tft.fillRect(0, 0, tft.width(), HEADER_H, AMD_BG);
  tft.setTextColor(AMD_ACCENT);
  tft.setTextSize(1);
  tft.setCursor(4, 5);
  tft.print(title);
  tft.drawFastHLine(0, HEADER_H - 2, tft.width(), AMD_ACCENT);
  tft.drawFastHLine(0, HEADER_H - 1, tft.width(), AMD_ACCENT);
}

void dispLines(const char* const* lines, uint8_t n) {
  tft.fillRect(0, HEADER_H, tft.width(), tft.height() - HEADER_H, AMD_BG);
  tft.setTextSize(1);
  tft.setTextColor(AMD_TEXT);
  int16_t y = HEADER_H + 4;
  for (uint8_t i = 0; i < n && y < tft.height() - 8; i++) {
    tft.setCursor(4, y);
    tft.print(lines[i]);
    y += 11;
  }
}

void dispBig(const char* word, uint16_t color, const char* sub) {
  const int16_t top = HEADER_H + 2;
  const int16_t h   = tft.height() - top - 3;
  tft.fillRect(0, HEADER_H, tft.width(), tft.height() - HEADER_H, AMD_BG);
  // Verdict panel, outlined in the result colour so the whole screen reads at a glance.
  tft.drawRoundRect(3, top, tft.width() - 6, h, 7, color);

  const bool have_sub = sub && *sub;
  // Vertically centre the word (+ sub) as a block, so it fills whatever the
  // current rotation gives us instead of sitting at a fixed portrait offset.
  const int16_t wordH = 16;                     // size-2 glyph height
  const int16_t subGap = have_sub ? 10 : 0;
  const int16_t subH   = have_sub ? 8  : 0;
  const int16_t blockH = wordH + subGap + subH;
  int16_t y = top + (h - blockH) / 2;
  if (y < top + 4) y = top + 4;

  tft.setTextSize(2);
  tft.setTextColor(color);
  int16_t w = (int16_t)strlen(word) * 12;       // size-2 glyphs are 12 px wide
  int16_t x = (tft.width() - w) / 2;
  if (x < 2) x = 2;
  tft.setCursor(x, y);
  tft.print(word);

  if (have_sub) {
    tft.setTextSize(1);
    tft.setTextColor(AMD_MUTED);
    int16_t sw = (int16_t)strlen(sub) * 6;
    int16_t sx = (tft.width() - sw) / 2;
    if (sx < 2) sx = 2;
    tft.setCursor(sx, y + wordH + subGap);
    tft.print(sub);
  }
}

// The 128x160 panel has no alpha and a 6x8 font, so "premium" here is hierarchy, not
// material: a rounded panel outline, muted labels, values right-aligned in a column.
#define PANEL_X 3
#define PANEL_R 7

void dispKV(const char* status, const char* const* keys, const char* const* vals, uint8_t n) {
  const int16_t top = HEADER_H + 2;
  const int16_t h   = tft.height() - top - 3;
  tft.fillRect(0, HEADER_H, tft.width(), tft.height() - HEADER_H, AMD_BG);
  tft.drawRoundRect(PANEL_X, top, tft.width() - PANEL_X * 2, h, PANEL_R, AMD_MUTED);
  tft.setTextSize(1);

  const int16_t xl = PANEL_X + 6;                       // label column
  const int16_t xr = tft.width() - PANEL_X - 6;         // value column, right edge
  int16_t y = top + 7;

  if (status && *status) {
    tft.setTextColor(AMD_ACCENT);
    tft.setCursor(xl, y);
    tft.print(status);
    y += 13;
    tft.drawFastHLine(xl, y - 4, xr - xl, AMD_MUTED);
  }

  for (uint8_t i = 0; i < n && y < tft.height() - 10; i++) {
    tft.setTextColor(AMD_MUTED);
    tft.setCursor(xl, y);
    tft.print(keys[i]);
    // right-align the value: size-1 glyphs are 6 px wide
    int16_t x = xr - (int16_t)strlen(vals[i]) * 6;
    if (x < xl) x = xl;
    tft.setTextColor(AMD_TEXT);
    tft.setCursor(x, y);
    tft.print(vals[i]);
    y += 12;
  }
}

void dispBar(uint8_t pct, uint16_t color, int16_t y) {
  if (pct > 100) pct = 100;
  const int16_t x = 12, w = tft.width() - 24, h = 6;
  tft.fillRect(x, y, w, h, AMD_MUTED);
  tft.fillRect(x, y, (int16_t)((uint32_t)w * pct / 100), h, color);
}

Adafruit_ST7735& dispTft() { return tft; }
