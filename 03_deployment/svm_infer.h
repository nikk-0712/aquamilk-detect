// svm_infer.h — evaluate the exported SVM (model.h) on device, with probabilities.
//
// This is sklearn's own algorithm, not an approximation:
//   1. one-vs-one decision values from the dual coefficients (libsvm layout),
//   2. Platt sigmoids per class pair using probA_/probB_,
//   3. Chu & Lin pairwise coupling to turn the 6 pairwise probabilities into 4
//      class probabilities — the same iterative procedure sklearn's
//      multiclass_probability() runs.
// training/train.py re-implements steps 2-3 in numpy and asserts its output matches
// predict_proba, so what runs here is verified against scikit-learn before export.
//
// Inference cost: SVM_N_SV_TOTAL * FEATURE_COUNT multiply-adds. Microseconds.
#pragma once

#include <math.h>
#include <string.h>
#include <features.h>
#include "model.h"
#include "scaler.h"

struct Verdict {
  uint8_t cls        = 0;                 // index into CLASS_NAMES
  float   conf       = 0.0f;              // probability of that class
  float   prob[CLASS_COUNT] = { 0 };
  bool    uncertain  = true;
  bool    adulterated = false;            // binary headline: anything but "pure"
  uint8_t top_feat[2] = { 0, 1 };         // most unusual features (|z| ranked)
  float   z[FEATURE_COUNT] = { 0 };       // standardized features, for the dashboard
};

// --- kernel between a scaled sample and support vector i -------------------
static inline float svm_kernel(const float* x, uint16_t i) {
  const float* sv = SVM_SV[i];
#if SVM_KERNEL_RBF
  float d2 = 0;
  for (uint8_t f = 0; f < FEATURE_COUNT; f++) {
    float d = x[f] - sv[f];
    d2 += d * d;
  }
  return expf(-SVM_GAMMA * d2);
#else
  float dot = 0;
  for (uint8_t f = 0; f < FEATURE_COUNT; f++) dot += x[f] * sv[f];
  return dot;
#endif
}

// --- Platt sigmoid, guarded the way libsvm guards it -----------------------
static inline float svm_sigmoid(float dec, float A, float B) {
  float t = dec * A + B;
  // 1/(1+exp(t)), written to avoid overflow for large |t|
  if (t >= 0) { float e = expf(-t); return e / (1.0f + e); }
  return 1.0f / (1.0f + expf(t));
}

// --- one-vs-one decision values (libsvm dual layout) ----------------------
static void svm_decision(const float* x, float* dec /*[SVM_N_PAIRS]*/) {
  static float k[SVM_N_SV_TOTAL];
  for (uint16_t i = 0; i < SVM_N_SV_TOTAL; i++) k[i] = svm_kernel(x, i);

  uint16_t start[CLASS_COUNT];
  uint16_t acc = 0;
  for (uint8_t c = 0; c < CLASS_COUNT; c++) { start[c] = acc; acc += SVM_N_SV[c]; }

  uint8_t p = 0;
  for (uint8_t i = 0; i < CLASS_COUNT; i++) {
    for (uint8_t j = i + 1; j < CLASS_COUNT; j++, p++) {
      float sum = 0;
      for (uint16_t s = 0; s < SVM_N_SV[i]; s++) sum += SVM_DUAL[j - 1][start[i] + s] * k[start[i] + s];
      for (uint16_t s = 0; s < SVM_N_SV[j]; s++) sum += SVM_DUAL[i][start[j] + s]     * k[start[j] + s];
      dec[p] = sum + SVM_INTERCEPT[p];
    }
  }
}

// --- Chu & Lin pairwise coupling (sklearn's multiclass_probability) --------
static void svm_couple(const float pairwise[CLASS_COUNT][CLASS_COUNT], float* prob) {
  const uint8_t k = CLASS_COUNT;
  float Q[CLASS_COUNT][CLASS_COUNT];
  float Qp[CLASS_COUNT];
  for (uint8_t t = 0; t < k; t++) prob[t] = 1.0f / k;

  for (uint8_t t = 0; t < k; t++) {
    Q[t][t] = 0;
    for (uint8_t j = 0; j < k; j++) {
      if (j == t) continue;
      Q[t][t] += pairwise[j][t] * pairwise[j][t];
      Q[t][j]  = -pairwise[j][t] * pairwise[t][j];
    }
  }

  for (uint8_t iter = 0; iter < 100; iter++) {
    float pQp = 0;
    for (uint8_t t = 0; t < k; t++) {
      Qp[t] = 0;
      for (uint8_t j = 0; j < k; j++) Qp[t] += Q[t][j] * prob[j];
      pQp += prob[t] * Qp[t];
    }
    float max_err = 0;
    for (uint8_t t = 0; t < k; t++) {
      float err = fabsf(Qp[t] - pQp);
      if (err > max_err) max_err = err;
    }
    if (max_err < 5e-4f) break;                 // sklearn's tolerance

    for (uint8_t t = 0; t < k; t++) {
      if (Q[t][t] == 0) continue;
      float diff = (-Qp[t] + pQp) / Q[t][t];
      prob[t] += diff;
      pQp = (pQp + diff * (diff * Q[t][t] + 2 * Qp[t])) / (1 + diff) / (1 + diff);
      for (uint8_t j = 0; j < k; j++) {
        Qp[j] = (Qp[j] + diff * Q[t][j]) / (1 + diff);
        prob[j] /= (1 + diff);
      }
    }
  }

  float sum = 0;
  for (uint8_t t = 0; t < k; t++) sum += prob[t];
  if (sum > 0) for (uint8_t t = 0; t < k; t++) prob[t] /= sum;
}

// --- public entry point ----------------------------------------------------
// features: raw feature vector in features.h order. threshold: current setting.
static Verdict svmClassify(const float* features, float threshold) {
  Verdict v;

  // standardize with the exported scaler
  static float x[FEATURE_COUNT];
  for (uint8_t f = 0; f < FEATURE_COUNT; f++) {
    float s = FEAT_SCALE[f] != 0 ? FEAT_SCALE[f] : 1.0f;
    float raw = isnan(features[f]) ? FEAT_MEAN[f] : features[f];   // missing -> neutral
    x[f] = (raw - FEAT_MEAN[f]) / s;
    v.z[f] = x[f];
  }

  // the two most unusual channels: a plain-English "why" for the verdict
  uint8_t a = 0, b = 1;
  for (uint8_t f = 0; f < FEATURE_COUNT; f++) {
    if (fabsf(v.z[f]) > fabsf(v.z[a]))      { b = a; a = f; }
    else if (f != a && fabsf(v.z[f]) > fabsf(v.z[b])) { b = f; }
  }
  v.top_feat[0] = a;
  v.top_feat[1] = b;

#if MODEL_IS_PLACEHOLDER
  // No trained model on board: say so instead of inventing a class.
  for (uint8_t c = 0; c < CLASS_COUNT; c++) v.prob[c] = 1.0f / CLASS_COUNT;
  v.cls = 0;
  v.conf = 1.0f / CLASS_COUNT;
  v.uncertain = true;
  v.adulterated = false;
  return v;
#else
  static float dec[SVM_N_PAIRS];
  svm_decision(x, dec);

  float pairwise[CLASS_COUNT][CLASS_COUNT];
  const float eps = 1e-7f;
  uint8_t p = 0;
  for (uint8_t i = 0; i < CLASS_COUNT; i++) {
    for (uint8_t j = i + 1; j < CLASS_COUNT; j++, p++) {
      float pij = svm_sigmoid(dec[p], SVM_PROB_A[p], SVM_PROB_B[p]);
      if (pij < eps)     pij = eps;
      if (pij > 1 - eps) pij = 1 - eps;
      pairwise[i][j] = pij;          // P(class i | i or j)
      pairwise[j][i] = 1.0f - pij;
    }
  }
  svm_couple(pairwise, v.prob);

  uint8_t best = 0;
  for (uint8_t c = 1; c < CLASS_COUNT; c++) if (v.prob[c] > v.prob[best]) best = c;
  v.cls  = best;
  v.conf = v.prob[best];
  v.uncertain = v.conf < threshold;
  v.adulterated = strcmp(CLASS_NAMES[best], "pure") != 0;
  return v;
#endif
}

// Binary headline probability: everything that is not "pure".
static inline float probAdulterated(const Verdict& v) {
  float p = 0;
  for (uint8_t c = 0; c < CLASS_COUNT; c++)
    if (strcmp(CLASS_NAMES[c], "pure") != 0) p += v.prob[c];
  return p;
}
