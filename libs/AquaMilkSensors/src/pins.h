// pins.h — Aqua Milk Detect pin map (PROJECT_CONTEXT.md §3, FINAL).
// Do not change these without updating PROJECT_CONTEXT.md §3 and the README wiring table.
#pragma once

// --- Analog sensors: all on ADC1, because ADC2 is unusable while Wi-Fi is on (§3) ---
#define PIN_PH        36   // VP / ADC1_CH0, input-only
#define PIN_TDS       39   // VN / ADC1_CH3, input-only
#define PIN_TURBIDITY 34   // ADC1_CH6,     input-only

// --- I2C (TCS34725 colour) ---
#define PIN_SDA 21
#define PIN_SCL 22

// --- OneWire (DS18B20), needs 4.7k pull-up to 3V3 ---
#define PIN_ONEWIRE 4

// --- HX711 load cell amp ---
#define PIN_HX711_DOUT 16
#define PIN_HX711_SCK  17

// --- TFT ST7735 128x160 on VSPI ---
#define PIN_TFT_SCLK 18
#define PIN_TFT_MOSI 23
#define PIN_TFT_CS    5
#define PIN_TFT_DC   13   // moved off GPIO2 — GPIO2 is a boot-strapping pin and the
#define PIN_TFT_RST  14   // TFT on it (and RST on GPIO15) blocks USB flashing at reset
// Backlight: tie to 3V3. GPIO32 is left free if you want PWM dimming later.

// --- Pump via 3.3 V relay module, IN pin on GPIO25 (§4) ---
#define PIN_PUMP 25

// --- TTP223 capacitive pad. RTC-capable so ext0 deep-sleep wake works (§7) ---
#define PIN_TOUCH 27

// Free for future use: 26, 32, 33, 35 (35 input-only). Avoid GPIO12 (strapping/boot),
// and GPIO2/GPIO15 — keep those clear of anything driven at reset or USB flashing breaks.
