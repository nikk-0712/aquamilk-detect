// display.cpp — see display.h.
#include "display.h"
#include "pins.h"

static Adafruit_ST7735 tft(PIN_TFT_CS, PIN_TFT_DC, PIN_TFT_RST);

#define HEADER_H 18          // aqua title strip; body text starts below it

void dispBegin(const char* title) {
  tft.initR(INITR_BLACKTAB);          // 1.8" 128x160 black-tab panel
  tft.setRotation(0);                 // portrait 128 x 160
  tft.fillScreen(AMD_BG);
  tft.setTextWrap(false);
  dispTitle(title);
}

void dispTitle(const char* title) {
  tft.fillRect(0, 0, tft.width(), HEADER_H, AMD_BG);
  tft.setTextColor(AMD_ACCENT);
  tft.setTextSize(1);
  tft.setCursor(4, 5);
  tft.print(title);
  tft.drawFastHLine(0, HEADER_H - 2, tft.width(), AMD_ACCENT);
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
  tft.fillRect(0, HEADER_H, tft.width(), tft.height() - HEADER_H, AMD_BG);
  tft.setTextSize(2);
  tft.setTextColor(color);
  // centre the word: size-2 glyphs are 12 px wide
  int16_t w = (int16_t)strlen(word) * 12;
  int16_t x = (tft.width() - w) / 2;
  if (x < 2) x = 2;
  tft.setCursor(x, 60);
  tft.print(word);
  if (sub && *sub) {
    tft.setTextSize(1);
    tft.setTextColor(AMD_MUTED);
    int16_t sw = (int16_t)strlen(sub) * 6;
    int16_t sx = (tft.width() - sw) / 2;
    if (sx < 2) sx = 2;
    tft.setCursor(sx, 90);
    tft.print(sub);
  }
}

Adafruit_ST7735& dispTft() { return tft; }
