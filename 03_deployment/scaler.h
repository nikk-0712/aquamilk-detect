// scaler.h — StandardScaler constants, in features.h order.
//
// TODO: replace with the trained scaler. training/train.py overwrites this file;
// copy it (and model.h) into 03_deployment/ after training.
//
// PLACEHOLDER: mean 0 / scale 1 is the identity transform, so the untrained build
// still compiles and runs — it just cannot classify anything (see model.h).
#pragma once

#include <features.h>

// Order: ph, tds, turbidity, density, temperature, color_r, color_g, color_b, color_clear
static const float FEAT_MEAN[FEATURE_COUNT] = {
  0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f
};

static const float FEAT_SCALE[FEATURE_COUNT] = {
  1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f
};

// Default "Uncertain" cut-off (§6). Adjustable at runtime in Settings; this is only
// the factory default the trainer recommends.
static const float CONF_THRESHOLD = 0.60f;
