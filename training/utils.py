"""utils.py — shared helpers for the Aqua Milk Detect trainer.

Used by both train.py and train.ipynb so the script and the notebook cannot drift.

Two contracts matter here:

1. FEATURES is the feature order from libs/AquaMilkSensors/src/features.h. Change one,
   change both, retrain, reflash.
2. The exported model.h / scaler.h layout is what 03_deployment/svm_infer.h reads.

Why not micromlgen: micromlgen's SVM port emits predict() only, and the product spec
needs a probability so it can answer "Uncertain" below a threshold. So we export the
same numbers scikit-learn itself uses (support vectors, dual coefficients, intercepts,
Platt probA_/probB_) and the firmware runs libsvm's own pairwise-coupling maths.
verify_probabilities() proves the exported path matches predict_proba before export.
"""
from __future__ import annotations

import glob as globmod
import json
import pathlib
from datetime import datetime, timezone

import numpy as np
import pandas as pd

# ---------------------------------------------------------------------- contracts
FEATURES = ["ph", "tds", "turbidity", "density", "temperature",
            "color_r", "color_g", "color_b", "color_clear"]
LABEL = "adulterant"
CLASSES = ["detergent", "pure", "starch", "water"]        # sklearn sorts labels
RAW_COLUMNS = ["timestamp_iso", "milk_type", "adulterant", "level_pct", "source",
               "temp_c", "ph_raw_mv", "tds_raw_mv", "turbidity_raw_mv", "density_g",
               "color_r", "color_g", "color_b", "color_clear"]

# Must match sensors.cpp::specificGravity()
WATER_RHO_20C = 0.998203
THERMAL_EXPANSION = 2.1e-4


# ------------------------------------------------------------------------- loading
def load_csvs(pattern: str = "data/*.csv") -> pd.DataFrame:
    """Concatenate every CSV matching the pattern. Raises if none are found."""
    paths = sorted(globmod.glob(pattern))
    if not paths:
        raise FileNotFoundError(
            f"no CSVs matched {pattern!r}. Export one from the web app's Collect page "
            "into training/data/ first."
        )
    frames = []
    for p in paths:
        df = pd.read_csv(p)
        missing = [c for c in RAW_COLUMNS if c not in df.columns]
        if missing:
            raise ValueError(f"{p} is missing columns {missing}; expected the schema in "
                             "PROJECT_CONTEXT.md §5")
        df["_file"] = pathlib.Path(p).name
        frames.append(df)
    out = pd.concat(frames, ignore_index=True)
    print(f"loaded {len(out)} rows from {len(paths)} file(s): "
          f"{', '.join(pathlib.Path(p).name for p in paths)}")
    return out


def clean(df: pd.DataFrame) -> pd.DataFrame:
    """Drop rows the sensors clearly failed on, and report what went."""
    n0 = len(df)
    df = df.dropna(subset=[c for c in RAW_COLUMNS if c != "source"])
    # A DS18B20 that is not answering reports -127; a dead analog channel reads 0 mV.
    df = df[(df.temp_c > -40) & (df.temp_c < 85)]
    df = df[(df.ph_raw_mv > 0) & (df.tds_raw_mv >= 0) & (df.turbidity_raw_mv > 0)]
    df = df[df[LABEL].isin(CLASSES)]
    dropped = n0 - len(df)
    if dropped:
        print(f"dropped {dropped} row(s) with missing values or out-of-range sensors")
    return df.reset_index(drop=True)


# ------------------------------------------------------------------------ features
def raw_to_features(df: pd.DataFrame, chamber_ml: float = 100.0) -> pd.DataFrame:
    """Turn raw CSV columns into the model's feature matrix, in FEATURES order.

    Only one transform happens here: grams in a fixed-volume chamber become a
    temperature-corrected specific gravity, exactly as sensors.cpp does it on device.
    Everything else is fed as the raw millivolts / raw colour counts the CSV holds,
    which is why firmware and trainer cannot disagree (see features.h).

    chamber_ml MUST be the same value the device has stored (Calibrate page shows it).
    """
    rho = df.density_g / chamber_ml
    rho20 = rho * (1.0 + THERMAL_EXPANSION * (df.temp_c - 20.0))
    out = pd.DataFrame({
        "ph": df.ph_raw_mv,
        "tds": df.tds_raw_mv,
        "turbidity": df.turbidity_raw_mv,
        "density": rho20 / WATER_RHO_20C,
        "temperature": df.temp_c,
        "color_r": df.color_r,
        "color_g": df.color_g,
        "color_b": df.color_b,
        "color_clear": df.color_clear,
    })
    return out[FEATURES].astype(float)


# ------------------------------------------------------------------------- balance
def check_balance(df: pd.DataFrame, min_per_class: int = 10) -> list[str]:
    """Print class counts and return human-readable warnings (never raises)."""
    warnings: list[str] = []
    counts = df[LABEL].value_counts()
    print("\nclass counts (adulterant):")
    for c in CLASSES:
        n = int(counts.get(c, 0))
        print(f"  {c:<10} {n}")
        if n == 0:
            warnings.append(f"no samples at all for '{c}' — the model cannot ever predict it")
        elif n < min_per_class:
            warnings.append(f"only {n} samples for '{c}' (want >= {min_per_class}); "
                            "its precision/recall numbers will be noise")

    if len(counts) > 1 and counts.max() > 3 * counts.min():
        warnings.append(f"class imbalance {counts.max()}:{counts.min()} — the SVM will lean "
                        "toward the majority class regardless of what the accuracy says")

    for col in ("milk_type", "source"):
        vc = df[col].astype(str).value_counts()
        print(f"\n{col} spread:")
        for k, v in vc.items():
            print(f"  {k:<24} {v}")
        if len(vc) == 1:
            warnings.append(f"every row has the same {col} ({vc.index[0]!r}) — the model may be "
                            f"learning that {col}, not adulteration. Collect from more sources.")

    return warnings


# ------------------------------------------------------------- probability check
def _dec_values(clf, X_scaled: np.ndarray) -> np.ndarray:
    """Re-implement libsvm's one-vs-one decision values from the fitted attributes.

    This is the same arithmetic svm_infer.h runs on the ESP32 — computing it here in
    numpy is how we prove the firmware path is right before shipping it.
    """
    sv = clf.support_vectors_
    dual = clf.dual_coef_
    n_sv = clf.n_support_
    starts = np.concatenate([[0], np.cumsum(n_sv)])
    k = len(n_sv)

    if clf.kernel == "rbf":
        gamma = _gamma_of(clf, X_scaled)
        d2 = ((X_scaled[:, None, :] - sv[None, :, :]) ** 2).sum(axis=2)
        kern = np.exp(-gamma * d2)
    else:
        kern = X_scaled @ sv.T

    dec = []
    for i in range(k):
        for j in range(i + 1, k):
            si, ei = starts[i], starts[i + 1]
            sj, ej = starts[j], starts[j + 1]
            val = kern[:, si:ei] @ dual[j - 1, si:ei] + kern[:, sj:ej] @ dual[i, sj:ej]
            dec.append(val + clf.intercept_[len(dec)])
    return np.column_stack(dec)


def _gamma_of(clf, X_scaled: np.ndarray) -> float:
    gamma = getattr(clf, "_gamma", None)
    if gamma is not None:
        return float(gamma)
    if isinstance(clf.gamma, (int, float)):
        return float(clf.gamma)
    if clf.gamma == "scale":
        return 1.0 / (X_scaled.shape[1] * float(X_scaled.var()))
    return 1.0 / X_scaled.shape[1]                       # "auto"


def _sigmoid(dec, A, B):
    t = dec * A + B
    return np.where(t >= 0, np.exp(-t) / (1.0 + np.exp(-t)), 1.0 / (1.0 + np.exp(t)))


def _couple(pairwise: np.ndarray, k: int) -> np.ndarray:
    """Chu & Lin pairwise coupling — sklearn's multiclass_probability, in numpy."""
    n = pairwise.shape[0]
    out = np.full((n, k), 1.0 / k)
    for row in range(n):
        p = out[row]
        Q = np.zeros((k, k))
        r = pairwise[row]
        for t in range(k):
            Q[t, t] = sum(r[j, t] ** 2 for j in range(k) if j != t)
            for j in range(k):
                if j != t:
                    Q[t, j] = -r[j, t] * r[t, j]
        for _ in range(100):
            Qp = Q @ p
            pQp = float(p @ Qp)
            if np.max(np.abs(Qp - pQp)) < 5e-4:
                break
            for t in range(k):
                if Q[t, t] == 0:
                    continue
                diff = (-Qp[t] + pQp) / Q[t, t]
                p[t] += diff
                pQp = (pQp + diff * (diff * Q[t, t] + 2 * Qp[t])) / (1 + diff) ** 2
                Qp = (Qp + diff * Q[t]) / (1 + diff)
                p /= (1 + diff)
        out[row] = p / p.sum()
    return out


def verify_probabilities(clf, X_scaled: np.ndarray, tol: float = 2e-3) -> float:
    """Assert our exported maths reproduces clf.predict_proba. Returns the max error."""
    k = len(clf.classes_)
    dec = _dec_values(clf, X_scaled)
    pair = np.zeros((X_scaled.shape[0], k, k))
    eps = 1e-7
    idx = 0
    for i in range(k):
        for j in range(i + 1, k):
            pij = np.clip(_sigmoid(dec[:, idx], clf.probA_[idx], clf.probB_[idx]), eps, 1 - eps)
            pair[:, i, j] = pij
            pair[:, j, i] = 1 - pij
            idx += 1
    mine = _couple(pair, k)
    theirs = clf.predict_proba(X_scaled)
    err = float(np.max(np.abs(mine - theirs)))
    print(f"\nfirmware probability path vs sklearn predict_proba: max abs error {err:.2e}")
    assert err < tol, (
        f"exported probability maths disagrees with sklearn by {err:.3e} (> {tol}). "
        "Do not ship this model — svm_infer.h would report different confidences."
    )
    return err


# --------------------------------------------------------------------- header export
def _cfloat(v) -> str:
    """Format a float as a valid C++ literal.

    "%.6g" % 0.0 is "0", and `0f` is not a floating literal in C++ — the compiler needs a
    decimal point or an exponent. Missing this makes every exported model.h containing a
    zero coefficient (i.e. all of them) fail to compile.
    """
    s = f"{float(v):.6g}"
    if not any(ch in s for ch in ".eE"):
        s += ".0"
    return s + "f"


def _fmt_arr(values, per_line=6):
    out, line = [], []
    for v in values:
        line.append(_cfloat(v))
        if len(line) == per_line:
            out.append("  " + ", ".join(line) + ",")
            line = []
    if line:
        out.append("  " + ", ".join(line))
    return "\n".join(out).rstrip(",")


def export_scaler_h(path: pathlib.Path, mean, scale, threshold: float) -> None:
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    body = f"""// scaler.h — GENERATED by training/train.py on {stamp}. Do not edit by hand.
// StandardScaler constants in features.h order:
//   {', '.join(FEATURES)}
#pragma once

#include <features.h>

static const float FEAT_MEAN[FEATURE_COUNT] = {{
{_fmt_arr(mean)}
}};

static const float FEAT_SCALE[FEATURE_COUNT] = {{
{_fmt_arr(scale)}
}};

// Recommended "Uncertain" cut-off from the threshold sweep. Adjustable in Settings.
static const float CONF_THRESHOLD = {threshold:.2f}f;
"""
    path.write_text(body, encoding="utf-8")
    print(f"wrote {path}")


def export_model_h(path: pathlib.Path, clf, X_scaled: np.ndarray) -> None:
    classes = [str(c) for c in clf.classes_]
    n_sv = clf.n_support_
    sv = clf.support_vectors_
    dual = clf.dual_coef_
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    gamma = _gamma_of(clf, X_scaled)

    sv_rows = ",\n".join("  { " + ", ".join(_cfloat(v) for v in row) + " }" for row in sv)
    dual_rows = ",\n".join("  { " + ", ".join(_cfloat(v) for v in row) + " }" for row in dual)

    body = f"""// model.h — GENERATED by training/train.py on {stamp}. Do not edit by hand.
// SVM: kernel={clf.kernel}, C={clf.C}, {len(sv)} support vectors, classes {classes}.
// Layout is scikit-learn's own one-vs-one SVC, read by 03_deployment/svm_infer.h.
#pragma once

#include <features.h>

#define MODEL_IS_PLACEHOLDER 0

static const char* const CLASS_NAMES[CLASS_COUNT] = {{ {', '.join(f'"{c}"' for c in classes)} }};

#define SVM_KERNEL_RBF {1 if clf.kernel == "rbf" else 0}
static const float SVM_GAMMA = {_cfloat(gamma)};

#define SVM_N_SV_TOTAL {len(sv)}
#define SVM_N_PAIRS    {len(clf.intercept_)}

static const uint16_t SVM_N_SV[CLASS_COUNT] = {{ {', '.join(str(int(n)) for n in n_sv)} }};

static const float SVM_SV[SVM_N_SV_TOTAL][FEATURE_COUNT] = {{
{sv_rows}
}};

static const float SVM_DUAL[CLASS_COUNT - 1][SVM_N_SV_TOTAL] = {{
{dual_rows}
}};

static const float SVM_INTERCEPT[SVM_N_PAIRS] = {{
{_fmt_arr(clf.intercept_)}
}};

static const float SVM_PROB_A[SVM_N_PAIRS] = {{
{_fmt_arr(clf.probA_)}
}};

static const float SVM_PROB_B[SVM_N_PAIRS] = {{
{_fmt_arr(clf.probB_)}
}};
"""
    path.write_text(body, encoding="utf-8")
    print(f"wrote {path}  ({len(sv)} support vectors, "
          f"~{len(sv) * len(FEATURES) * 4 / 1024:.1f} KB of flash)")


def save_json(path: pathlib.Path, obj) -> None:
    path.write_text(json.dumps(obj, indent=2, default=float), encoding="utf-8")
    print(f"wrote {path}")


# ------------------------------------------------------------------- synthetic data
def synthetic_frame(n_per_class: int = 12, seed: int = 7) -> pd.DataFrame:
    """SYNTHETIC data so the pipeline runs end to end before any real milk exists.

    These numbers are invented to be separable, not measured. Any accuracy you see on
    them says something about this generator and nothing about milk.
    """
    rng = np.random.default_rng(seed)
    # per class: pH mV, TDS mV, turbidity mV, grams in a 100 mL chamber, R, G, B, clear
    centres = {
        "pure":      (1580, 640, 1180, 103.2, 900, 880, 790, 2600),
        "water":     (1610, 480, 1500, 101.4, 780, 770, 700, 2950),
        "detergent": (1350, 900, 1260, 102.6, 860, 850, 800, 2700),
        "starch":    (1560, 690,  920, 103.6, 940, 900, 780, 2200),
    }
    rows = []
    for cls, (ph, tds, turb, g, r, gr, b, c) in centres.items():
        for i in range(n_per_class):
            def jit(v, s):
                return float(v * (1 + rng.normal(0, s)))
            temp = float(rng.uniform(22, 30))
            rows.append({
                "timestamp_iso": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "milk_type": ["cow", "buffalo", "toned"][i % 3],
                "adulterant": cls,
                "level_pct": 0 if cls == "pure" else [5, 10, 20][i % 3],
                "source": "SYNTHETIC",
                "temp_c": round(temp, 1),
                "ph_raw_mv": round(jit(ph, 0.012), 1),
                "tds_raw_mv": round(jit(tds, 0.02), 1),
                "turbidity_raw_mv": round(jit(turb, 0.018), 1),
                "density_g": round(jit(g, 0.0035), 2),
                "color_r": int(jit(r, 0.03)),
                "color_g": int(jit(gr, 0.03)),
                "color_b": int(jit(b, 0.03)),
                "color_clear": int(jit(c, 0.03)),
            })
    return pd.DataFrame(rows)[RAW_COLUMNS]


if __name__ == "__main__":
    # Self-check: the feature transform and the probability maths are the two places a
    # silent mistake would poison every model, so both are exercised here.
    #   python utils.py
    from sklearn.preprocessing import StandardScaler
    from sklearn.svm import SVC

    df = clean(synthetic_frame(20))
    X = raw_to_features(df)
    assert list(X.columns) == FEATURES, "feature order drifted from features.h"

    # specific gravity must match the firmware formula for a known case
    probe = pd.DataFrame({"density_g": [100.0], "temp_c": [20.0], "ph_raw_mv": [1.0],
                          "tds_raw_mv": [1.0], "turbidity_raw_mv": [1.0], "color_r": [1],
                          "color_g": [1], "color_b": [1], "color_clear": [1]})
    sg = raw_to_features(probe).density.iloc[0]
    assert abs(sg - 1.0 / WATER_RHO_20C) < 1e-6, f"specific gravity maths changed: {sg}"

    scaler = StandardScaler().fit(X)
    Xs = scaler.transform(X)
    y = df[LABEL].to_numpy()
    for kernel in ("rbf", "linear"):
        clf = SVC(kernel=kernel, C=10, probability=True, random_state=0).fit(Xs, y)
        verify_probabilities(clf, Xs)
    print("\nutils self-check passed")
