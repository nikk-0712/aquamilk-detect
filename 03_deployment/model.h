// model.h — trained SVM, exported by training/train.py.
//
// TODO: replace with the trained model. Until you do, MODEL_IS_PLACEHOLDER is 1 and
// every test reports "Uncertain — model not trained", which is the honest answer for
// a device with no model in it.
//
// FORMAT (what train.py writes, what svm_infer.h reads) — this is sklearn's own
// one-vs-one SVC layout, so on-device probabilities match predict_proba instead of
// being a made-up "confidence":
//   SVM_KERNEL_RBF     1 for rbf, 0 for linear
//   SVM_GAMMA          rbf gamma (ignored when linear)
//   SVM_N_SV           support vectors per class, in CLASS_NAMES order
//   SVM_SV             [n_sv_total][FEATURE_COUNT] support vectors, already scaled
//   SVM_DUAL           [CLASS_COUNT-1][n_sv_total] dual_coef_
//   SVM_INTERCEPT      [n_pairs] intercept_, pair order (0,1)(0,2)(0,3)(1,2)(1,3)(2,3)
//   SVM_PROB_A/B       [n_pairs] Platt probA_/probB_ for the pairwise sigmoids
//   CLASS_NAMES        class labels in sklearn's sorted order
#pragma once

#include <features.h>

#define MODEL_IS_PLACEHOLDER 1

// sklearn sorts labels alphabetically; this is the order train.py will emit.
static const char* const CLASS_NAMES[CLASS_COUNT] = { "detergent", "pure", "starch", "water" };

#define SVM_KERNEL_RBF 1
static const float SVM_GAMMA = 0.1f;

#define SVM_N_SV_TOTAL 4
#define SVM_N_PAIRS    6      // CLASS_COUNT * (CLASS_COUNT - 1) / 2

static const uint16_t SVM_N_SV[CLASS_COUNT] = { 1, 1, 1, 1 };

// One dummy support vector per class at the origin of the scaled space.
static const float SVM_SV[SVM_N_SV_TOTAL][FEATURE_COUNT] = {
  { 0, 0, 0, 0, 0, 0, 0, 0, 0 },
  { 0, 0, 0, 0, 0, 0, 0, 0, 0 },
  { 0, 0, 0, 0, 0, 0, 0, 0, 0 },
  { 0, 0, 0, 0, 0, 0, 0, 0, 0 }
};

// All-zero duals + zero intercepts => every pairwise decision is a tie, every
// pairwise probability is 0.5, so the top class probability lands at 0.25 and the
// verdict is always "Uncertain" until a real model is dropped in.
static const float SVM_DUAL[CLASS_COUNT - 1][SVM_N_SV_TOTAL] = {
  { 0, 0, 0, 0 },
  { 0, 0, 0, 0 },
  { 0, 0, 0, 0 }
};

static const float SVM_INTERCEPT[SVM_N_PAIRS] = { 0, 0, 0, 0, 0, 0 };
static const float SVM_PROB_A[SVM_N_PAIRS]    = { 0, 0, 0, 0, 0, 0 };
static const float SVM_PROB_B[SVM_N_PAIRS]    = { 0, 0, 0, 0, 0, 0 };
