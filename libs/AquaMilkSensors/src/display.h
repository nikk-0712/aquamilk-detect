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

Adafruit_ST7735& dispTft();                            // escape hatch for custom screens
