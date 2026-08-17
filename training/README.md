# training/ — SVM trainer

Turns the CSVs you collected into `model.h` + `scaler.h` for the deployment firmware,
plus an evaluation report you can defend in a viva.

## Run it

```bash
python -m pip install -r training/requirements.txt
```

Put the CSVs exported from the web app's **Collect** page into `training/data/`, then:

```bash
python train.py
```

Smoke-test the whole pipeline before you own any real data:

```bash
python train.py --synthetic
```

Check the maths itself (feature transform + the probability path the firmware runs):

```bash
python utils.py
```

Useful flags: `--chamber-ml` (must match the value stored on the device — the Calibrate
page shows it), `--test-size`, `--seed`, `--min-per-class`, `--no-export`.

## What comes out

| File | What it is |
|---|---|
| `model.h` | The trained SVM: support vectors, dual coefficients, intercepts, Platt `probA_`/`probB_` |
| `scaler.h` | `FEAT_MEAN[9]`, `FEAT_SCALE[9]`, and the recommended `CONF_THRESHOLD` |
| `report/report.txt` | The whole run as text: CV score, held-out metrics, confusion matrix, threshold sweep, limitations |
| `report/confusion.png` | Confusion matrix |
| `report/threshold.png` | Accuracy vs coverage as the Uncertain cut-off moves |
| `report/metrics.json` | Every number, machine-readable |
| `pipeline.joblib` | Fitted scaler + model, if you want to keep exploring in Python |

Copy the two headers into the firmware and reflash:

```bash
cp training/model.h training/scaler.h 03_deployment/
```

Pushing those changed headers re-triggers the firmware build in CI, so the `.bin` the
web app offers gets your model automatically.

## Features

Exact order, matching `libs/AquaMilkSensors/src/features.h`:

```
[ph, tds, turbidity, density, temperature, color_r, color_g, color_b, color_clear]
```

`raw_to_features()` in `utils.py` is the single definition of that mapping. It does
exactly one transform: `density_g` in a fixed-volume chamber becomes a
temperature-corrected **specific gravity**, with the same constants `sensors.cpp` uses.
Everything else is fed as the raw millivolts and raw colour counts the CSV already holds.

That is a deliberate choice. The CSV only stores raws, so training on raws means the
firmware and the trainer cannot disagree about what a feature *is*, and re-calibrating
the pH probe does not silently invalidate a trained model. `StandardScaler` makes the
units irrelevant to the SVM anyway. Calibrated pH / ppm / NTU still exist on the device —
for humans to read, not for the model to consume.

## Why not micromlgen

The spec suggested `micromlgen.port()`. Its SVM port emits `predict()` only, and this
product needs a **probability**, because anything below the confidence threshold has to
come out as "Uncertain". A model that can only say "starch" with no confidence attached
cannot implement that rule.

So the exporter writes scikit-learn's own `SVC` internals, and
`03_deployment/svm_infer.h` runs libsvm's actual procedure: one-vs-one decision values →
Platt sigmoids → Chu & Lin pairwise coupling. Before writing `model.h`,
`verify_probabilities()` re-implements that same path in numpy and asserts it reproduces
`clf.predict_proba` (typically within ~2e-3, the coupling loop's own tolerance). If it
ever disagrees, the run fails and nothing is exported — a wrong confidence would be
worse than no model, since the whole Uncertain mechanism rests on it.

## Reading the report honestly

- **Report the confusion matrix, not the accuracy.** With a few dozen rows per class,
  accuracy moves several points just from reshuffling the split.
- **Starch is the hard class.** It pushes turbidity the same direction fat does, so it
  gets confused with pure milk more than water or detergent do. If starch recall is much
  worse than the rest, that is the expected failure, not a bug.
- **Balance matters more than volume.** The trainer warns when one class is more than
  3× another, and when every row shares a single `source` or `milk_type` — a model
  trained on one dairy mostly learns that dairy.
- **The binary headline** (pure vs adulterated) is always reported alongside the
  4-class numbers, because it is the number a user actually acts on.
- `--synthetic` runs are labelled as synthetic in both the console output and
  `metrics.json`. Those numbers describe a random generator, not milk.

## data/

`SYNTHETIC_sample.csv` is generated, clearly marked, and exists so `python train.py`
works on a fresh clone. Delete it once you have real data — otherwise it will be
concatenated into your dataset and quietly train on invented numbers.
