// features.h — THE FEATURE-ORDER CONTRACT between firmware and trainer.
//
// This order is fixed. training/utils.py::raw_to_features() builds columns in
// exactly this order, scaler.h stores means/scales in exactly this order, and
// model.h was trained on exactly this order. Change one, change all four.
//
//   index  name          unit / definition
//   0      ph            ph_raw_mv        averaged millivolts at the pH board output (divider-corrected)
//   1      tds           tds_raw_mv       averaged millivolts at the TDS board output
//   2      turbidity     turbidity_raw_mv averaged millivolts at the turbidity board output
//   3      density       specific gravity, temperature-corrected to 20 C (dimensionless, ~1.02-1.04 for milk)
//   4      temperature   temp_c           DS18B20 degrees Celsius
//   5      color_r       TCS34725 raw red channel count
//   6      color_g       TCS34725 raw green channel count
//   7      color_b       TCS34725 raw blue channel count
//   8      color_clear   TCS34725 raw clear channel count
//
// WHY RAW MILLIVOLTS AND NOT CALIBRATED pH/ppm/NTU:
// The CSV (PROJECT_CONTEXT.md §5) stores raw millivolts, so the trainer can only
// see raws. Feeding the SVM the same raws the CSV holds makes firmware and trainer
// agree by construction -- no calibration constants have to be mirrored into Python,
// and a re-calibration never silently invalidates a trained model. StandardScaler
// makes the units irrelevant to the SVM anyway. Calibrated pH / ppm / NTU are still
// computed for the human (TFT + dashboard readouts), they just are not model inputs.
#pragma once

#define FEATURE_COUNT 9

// Indices, for readable code at the few places that touch one feature by name.
enum FeatureIndex {
  F_PH = 0,
  F_TDS,
  F_TURBIDITY,
  F_DENSITY,
  F_TEMPERATURE,
  F_COLOR_R,
  F_COLOR_G,
  F_COLOR_B,
  F_COLOR_CLEAR
};

// Human labels, same order. Used for the "which sensors drove this" readout.
static const char* const FEATURE_NAMES[FEATURE_COUNT] = {
  "pH", "TDS", "Turbidity", "Density", "Temp",
  "Red", "Green", "Blue", "Clear"
};

// Number of classes: pure, water, detergent, starch (§6).
// The concrete order is whatever the trainer emitted -- model.h ships CLASS_NAMES[]
// so the label order always comes from the same file as the model.
#define CLASS_COUNT 4
