#!/usr/bin/env python3
"""train.py — Aqua Milk Detect SVM trainer.

    python train.py                          # trains on data/*.csv
    python train.py --data "data/*.csv" --chamber-ml 100 --seed 42
    python train.py --synthetic               # runs on generated data, for a smoke test

Outputs (into training/):
    model.h, scaler.h        drop both into 03_deployment/, then reflash
    report/report.txt        the honest evaluation, safe to paste into a thesis
    report/confusion.png     confusion matrix
    report/threshold.png     accuracy vs coverage as the Uncertain cut-off moves
    report/metrics.json      every number, machine-readable
    pipeline.joblib          fitted scaler + model, for reuse in Python

Read PROJECT_CONTEXT.md §5 (schema) and §6 (model) first. Feature order lives in
libs/AquaMilkSensors/src/features.h and is mirrored by utils.FEATURES.
"""
from __future__ import annotations

import argparse
import pathlib
import sys

import joblib
import matplotlib
import numpy as np

matplotlib.use("Agg")                     # no display on CI
import matplotlib.pyplot as plt           # noqa: E402
from sklearn.inspection import permutation_importance                      # noqa: E402
from sklearn.metrics import (accuracy_score, classification_report,        # noqa: E402
                            confusion_matrix, f1_score)
from sklearn.model_selection import (GridSearchCV, StratifiedKFold,        # noqa: E402
                                    train_test_split)
from sklearn.preprocessing import StandardScaler                           # noqa: E402
from sklearn.svm import SVC                                                # noqa: E402

import utils                                                              # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
REPORT = HERE / "report"


def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                               formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--data", default="data/*.csv", help="glob for the collected CSVs")
    p.add_argument("--synthetic", action="store_true", help="use generated data instead of files")
    p.add_argument("--chamber-ml", type=float, default=100.0,
                   help="chamber volume the DEVICE has stored (Calibrate page shows it)")
    p.add_argument("--test-size", type=float, default=0.25, help="held-out fraction")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--min-per-class", type=int, default=10)
    p.add_argument("--no-export", action="store_true", help="evaluate only, write no headers")
    return p.parse_args()


def main() -> int:
    a = parse_args()
    REPORT.mkdir(exist_ok=True)
    lines: list[str] = []                 # collected into report/report.txt

    def say(s=""):
        print(s)
        lines.append(str(s))

    # ------------------------------------------------------------------- 1. data
    if a.synthetic:
        say("USING SYNTHETIC DATA — these numbers describe a random generator, not milk.")
        df = utils.synthetic_frame(seed=a.seed)
    else:
        df = utils.load_csvs(a.data)
    df = utils.clean(df)

    warnings = utils.check_balance(df, a.min_per_class)
    counts = df[utils.LABEL].value_counts()

    if len(df) < 20 or counts.min() < 3 or len(counts) < 2:
        say("\nNot enough data to train anything meaningful.")
        say(f"  rows: {len(df)}, classes present: {len(counts)}, smallest class: "
            f"{int(counts.min()) if len(counts) else 0}")
        say("  Collect at least ~10 samples per class (30+ is better) and run again.")
        return 2

    X = utils.raw_to_features(df, a.chamber_ml)
    y = df[utils.LABEL].to_numpy()
    say(f"\nfeatures ({len(utils.FEATURES)}): {', '.join(utils.FEATURES)}")
    say(f"chamber volume used for specific gravity: {a.chamber_ml} mL "
        "(must match the device's stored value)")

    strat = y if counts.min() >= 2 else None
    X_tr, X_te, y_tr, y_te = train_test_split(
        X, y, test_size=a.test_size, random_state=a.seed, stratify=strat)

    scaler = StandardScaler().fit(X_tr)
    Xs_tr, Xs_te = scaler.transform(X_tr), scaler.transform(X_te)

    # --------------------------------------------------- 2. model selection (§6)
    _, inv = np.unique(y_tr, return_inverse=True)
    folds = int(min(5, np.bincount(inv).min()))
    if folds < 2:
        say("\nA class has a single training row — cannot cross-validate. Collect more.")
        return 2
    if folds < 5:
        warnings.append(f"only {folds}-fold CV was possible (smallest class is tiny)")

    grid = [
        {"kernel": ["linear"], "C": [0.1, 1, 10, 100]},
        {"kernel": ["rbf"], "C": [1, 10, 100, 1000], "gamma": ["scale", 0.01, 0.1, 1]},
    ]
    search = GridSearchCV(
        SVC(probability=True, random_state=a.seed),
        grid, scoring="f1_macro",
        cv=StratifiedKFold(n_splits=folds, shuffle=True, random_state=a.seed),
        n_jobs=-1, refit=True,
    )
    search.fit(Xs_tr, y_tr)
    clf: SVC = search.best_estimator_
    say(f"\nbest params: {search.best_params_}")
    say(f"cross-validated macro-F1 (train folds): {search.best_score_:.3f} over {folds} folds")

    # ------------------------------------------------------- 3. honest evaluation
    y_hat = clf.predict(Xs_te)
    acc = accuracy_score(y_te, y_hat)
    f1m = f1_score(y_te, y_hat, average="macro")
    say(f"\nheld-out test set ({len(y_te)} rows)")
    say(f"  accuracy   {acc:.3f}")
    say(f"  macro-F1   {f1m:.3f}")
    say("\nper-class (held-out):")
    say(classification_report(y_te, y_hat, zero_division=0))

    labels = list(clf.classes_)
    cm = confusion_matrix(y_te, y_hat, labels=labels)
    say("confusion matrix (rows = truth, cols = predicted)")
    say("            " + "".join(f"{c[:9]:>10}" for c in labels))
    for i, c in enumerate(labels):
        say(f"{c:<12}" + "".join(f"{v:>10}" for v in cm[i]))

    # binary headline: pure vs anything else
    bin_true = np.where(y_te == "pure", "pure", "adulterated")
    bin_pred = np.where(y_hat == "pure", "pure", "adulterated")
    bin_acc = accuracy_score(bin_true, bin_pred)
    say(f"\nbinary pure-vs-adulterated accuracy: {bin_acc:.3f}")
    say(classification_report(bin_true, bin_pred, zero_division=0))

    if "starch" in labels:
        i = labels.index("starch")
        support = int(cm[i].sum())
        recall = cm[i, i] / support if support else float("nan")
        say(f"starch recall: {recall:.3f} on {support} test row(s) — starch is normally the "
            "hardest class, because it moves turbidity in the same direction as fat does.")

    fig, ax = plt.subplots(figsize=(4.6, 4.2), dpi=160)
    ax.imshow(cm, cmap="Blues")
    ax.set_xticks(range(len(labels)), labels, rotation=45, ha="right")
    ax.set_yticks(range(len(labels)), labels)
    for i in range(len(labels)):
        for j in range(len(labels)):
            ax.text(j, i, cm[i, j], ha="center", va="center",
                    color="white" if cm[i, j] > cm.max() / 2 else "black")
    ax.set_xlabel("predicted")
    ax.set_ylabel("truth")
    ax.set_title(f"Confusion matrix (acc {acc:.2f}, macro-F1 {f1m:.2f})", fontsize=10)
    fig.tight_layout()
    fig.savefig(REPORT / "confusion.png")
    plt.close(fig)

    # -------------------------------------- 4. Uncertain threshold sweep (§6, §11)
    proba = clf.predict_proba(Xs_te)
    top = proba.max(axis=1)
    pred = clf.classes_[proba.argmax(axis=1)]
    sweep = []
    say("\nUncertain threshold sweep (held-out):")
    say("  thr   coverage   accuracy-when-answered")
    for thr in np.arange(0.40, 0.91, 0.05):
        keep = top >= thr
        cov = float(keep.mean())
        if keep.any():
            sacc = float(accuracy_score(y_te[keep], pred[keep]))
            say(f"  {thr:.2f}   {cov:6.2f}     {sacc:.3f}")
        else:
            sacc = None
            say(f"  {thr:.2f}   {cov:6.2f}     (nothing answered)")
        sweep.append({"threshold": round(float(thr), 2), "coverage": cov, "accuracy": sacc})

    # Recommend the lowest threshold that keeps accuracy high without gutting coverage.
    ok = [s for s in sweep if s["accuracy"] is not None and s["coverage"] >= 0.7]
    recommended = max(ok, key=lambda s: (s["accuracy"], s["coverage"]))["threshold"] if ok else 0.60
    n_unc = int((top < recommended).sum())
    say(f"\nrecommended threshold {recommended:.2f} → {n_unc} of {len(y_te)} test rows "
        f"({n_unc / len(y_te):.0%}) would be reported as Uncertain")
    say("Default in PROJECT_CONTEXT.md is 0.60; the device Settings page can change it "
        "without retraining.")

    fig, ax = plt.subplots(figsize=(5, 3.4), dpi=160)
    ax.plot([s["threshold"] for s in sweep], [s["coverage"] for s in sweep], "-o",
            label="coverage (answered)")
    ax.plot([s["threshold"] for s in sweep],
            [s["accuracy"] if s["accuracy"] is not None else np.nan for s in sweep], "-s",
            label="accuracy when answered")
    ax.axvline(recommended, ls="--", c="#0FB5C9", label=f"recommended {recommended:.2f}")
    ax.set_xlabel("confidence threshold")
    ax.set_ylim(0, 1.05)
    ax.legend(fontsize=8)
    ax.grid(alpha=.3)
    fig.tight_layout()
    fig.savefig(REPORT / "threshold.png")
    plt.close(fig)

    # ------------------------------------------------- 5. which sensors mattered
    say("\npermutation importance (drop in macro-F1 when a channel is shuffled):")
    imp = permutation_importance(clf, Xs_te, y_te, scoring="f1_macro",
                                 n_repeats=10, random_state=a.seed)
    order = np.argsort(imp.importances_mean)[::-1]
    importance = {}
    for i in order:
        importance[utils.FEATURES[i]] = float(imp.importances_mean[i])
        say(f"  {utils.FEATURES[i]:<12} {imp.importances_mean[i]:+.3f} "
            f"± {imp.importances_std[i]:.3f}")

    # --------------------------------------------------------- 6. export + verify
    utils.verify_probabilities(clf, scaler.transform(X))   # asserts firmware maths matches

    if not a.no_export:
        utils.export_scaler_h(HERE / "scaler.h", scaler.mean_, scaler.scale_, recommended)
        utils.export_model_h(HERE / "model.h", clf, Xs_tr)
        joblib.dump({"scaler": scaler, "clf": clf, "features": utils.FEATURES,
                     "chamber_ml": a.chamber_ml}, HERE / "pipeline.joblib")

    utils.save_json(REPORT / "metrics.json", {
        "rows": int(len(df)),
        "class_counts": {k: int(v) for k, v in counts.items()},
        "best_params": search.best_params_,
        "cv_macro_f1": float(search.best_score_),
        "test_accuracy": float(acc),
        "test_macro_f1": float(f1m),
        "binary_accuracy": float(bin_acc),
        "confusion_matrix": {"labels": labels, "matrix": cm.tolist()},
        "threshold_sweep": sweep,
        "recommended_threshold": float(recommended),
        "permutation_importance": importance,
        "support_vectors": int(len(clf.support_vectors_)),
        "synthetic": bool(a.synthetic),
        "chamber_ml": a.chamber_ml,
        "seed": a.seed,
    })

    # ------------------------------------------------------------ 7. limitations
    say("\n--- limitations, read before quoting any number above ---")
    say(f"* {len(df)} rows total, {len(y_te)} held out. Numbers from a set this size move by "
        "several points when you reshuffle; report the confusion matrix, not just accuracy.")
    say("* One device, one set of calibration constants. Recalibrating, swapping a probe or "
        "moving to another board shifts the raw millivolts, and the model does not know that.")
    say("* Adulterant levels in the dataset are the ones you prepared. A 2 % dilution is not "
        "in scope if you only collected 5 % and up.")
    say("* Starch is the hardest class: it changes turbidity the way fat does. Expect its "
        "recall to lag the others.")
    say("* Drift: probes age, the chamber films over. Re-run selftest and re-calibrate "
        "periodically, and re-collect if verdicts start disagreeing with reality.")
    if a.synthetic:
        say("* THIS RUN USED SYNTHETIC DATA. It proves the pipeline works, nothing else.")
    for w in warnings:
        say(f"* WARNING: {w}")

    (REPORT / "report.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"\nwrote {REPORT / 'report.txt'}")
    if not a.no_export:
        print("\nNext: copy these two files into 03_deployment/ and reflash:")
        print(f"  {HERE / 'model.h'}")
        print(f"  {HERE / 'scaler.h'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
