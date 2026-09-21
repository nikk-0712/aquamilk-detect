// display.h — minimal ST7735 helpers shared by the three firmwares.
//
// TFT library: Adafruit_ST7735 + Adafruit_GFX. Chosen over TFT_eSPI because the
// pins are passed in the constructor, so nothing has to patch a User_Setup.h in
// CI or on your machine. Wiring is pins.h / PROJECT_CONTEXT.md §3:
//   SCLK 18, MOSI 23, CS 5, DC 2, RST 15, BL -> 3V3.
// Panel is the 1.8" 128x160 "black tab" variant.
#pragma once

#include <Arduino.h>
#include <Adafruit_ST7735.h>

// ---------------------------------------------------------------- panel config
// The 1.8" 128x160 modules ship as several "tab" variants that differ only in
// their pixel offset. If a band of stray/skipped pixels shows along ONE edge
// (the classic "not using the whole screen" glitch), the wrong variant is
// selected: change AMD_TFT_INITR to INITR_GREENTAB (the most common alternative),
// then INITR_REDTAB. Define it in the sketch before including display.h to override.
#ifndef AMD_TFT_INITR
#define AMD_TFT_INITR INITR_BLACKTAB
#endif
// Fine offset nudge, in pixels, for a panel a tab type gets close but not exact.
// Usually 0. Applied on top of the tab's own offset.
#ifndef AMD_TFT_COLSTART
#define AMD_TFT_COLSTART 0
#endif
#ifndef AMD_TFT_ROWSTART
#define AMD_TFT_ROWSTART 0
#endif
// Default rotation when NVS has none. 0/2 = portrait (128x160), 1/3 = landscape
// (160x128). The live value is stored in NVS ("amd_cal"/"tft_rot") and set at
// runtime with dispSetRotation() — no need to physically turn the panel.
#ifndef AMD_TFT_ROTATION
#define AMD_TFT_ROTATION 1   // this build's panel is mounted a quarter-turn; 1 puts the
#endif                       // header at the top. (Flip to 3 if it comes out upside-down.)

// Aqua Milk Detect palette (§9) in RGB565.
#define AMD_BG      0x0000   // near-black, matches the dark theme background
#define AMD_TEXT    0xFFFF
#define AMD_MUTED   0x8410
#define AMD_ACCENT  0x0DFB   // aqua-teal #0FB5C9
#define AMD_GREEN   0x360C   // #34C759 pure
#define AMD_RED     0xF9A6   // #FF3B30 adulterated
#define AMD_AMBER   0xFCE0   // #FF9F0A uncertain

void dispBegin(const char* title);
void dispTitle(const char* title);                     // small aqua header line
void dispLines(const char* const* lines, uint8_t n);   // body text, one row each
void dispBig(const char* word, uint16_t color, const char* sub);

// Label/value grid: labels muted on the left, values right-aligned in white, so the
// numbers line up in a column instead of being padded by hand at every call site.
// status is an optional line above the grid (nullptr to skip).
void dispKV(const char* status, const char* const* keys, const char* const* vals, uint8_t n);

// Horizontal fill bar, 0-100, drawn at row y. Used for the verdict's confidence.
void dispBar(uint8_t pct, uint16_t color, int16_t y);

// Rotate the panel in software (0..3; odd = landscape). Persists to NVS and
// clears the screen — the caller repaints its current view afterwards.
void    dispSetRotation(uint8_t r);
uint8_t dispRotation();

Adafruit_ST7735& dispTft();                            // escape hatch for custom screens
