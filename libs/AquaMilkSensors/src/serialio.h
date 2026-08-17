// serialio.h — the JSON-over-USB plumbing all three firmwares share (§8).
//
// 01_calibration and 02_collection each had their own copy of the line reader, the ack
// helper and the reading serialiser; 03_deployment had a third copy of the serialiser
// for its WebSocket. One copy here instead.
#pragma once

#include <Arduino.h>
#include <ArduinoJson.h>

// Called once per complete newline-terminated line received. The buffer is reusable
// scratch — copy anything you need to keep.
using LineHandler = void (*)(char* line);

// Drain the serial input, calling fn for each line. Overlong lines are dropped rather
// than truncated, so a garbled line can never be half-parsed as a command.
void serialPoll(LineHandler fn);

// {"t":"ack","cmd":..,"ok":..,"msg":..}
void sendAck(const char* cmd, bool ok, const char* msg);

// Fill d with the live reading: raw millivolts/grams/colour plus the calibrated
// human values under "calc". Callers add their own extra fields before serialising.
void readingJson(JsonDocument& d);
