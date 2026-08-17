# AGENT PROMPT 5 — Python SVM Trainer (`training/`)

**Read `PROJECT_CONTEXT.md` first (schema §5, model §6, feature order in Prompt 3 / `features.h`, conventions §11).**

## Your task
Write a **Python** pipeline that turns the collected CSV(s) into a trained SVM and **exports `model.h` + `scaler.h`** for the deployment firmware, with an honest evaluation. Deliver both a **script** (`train.py`) and a **Jupyter notebook** (`train.ipynb`) that share a `utils.py`.

## Data
- Input: one or more CSVs matching schema §5 (columns: `timestamp_iso, milk_type, adulterant, level_pct, source, temp_c, ph_raw_mv, tds_raw_mv, turbidity_raw_mv, density_g, color_r, color_g, color_b, color_clear`). Support globbing a `data/` folder and concatenating.
- **Label = `adulterant`** (4 classes: pure, water, detergent, starch).
- **Features (exact order, must match `features.h`):** `[ph, tds, turbidity, density, temperature, color_r, color_g, color_b, color_clear]`.
  - Map raw → feature: apply the same calibration the firmware uses where relevant, OR train on raw values but document it; **temperature-correct the density** (specific gravity referenced to a standard temp) and keep `temperature` as its own feature.
  - Provide a single, documented `raw_to_features(df)` so firmware and trainer agree.

## Pipeline
1. Load + concat + clean (drop NaNs, obvious sensor faults). Print class counts and **warn on imbalance** across `adulterant` AND across `milk_type`/`source` (so the user knows if the model may overfit a source).
2. `StandardScaler` on features (save means/scales).
3. **Model selection:** `GridSearchCV` over SVM **linear vs RBF**, `C`, `gamma`, with **stratified k-fold (k=5)**; scoring **macro-F1**; `probability=True` (for the uncertain threshold).
4. **Honest evaluation** (print + save to `training/report/`): accuracy, macro-F1, per-class precision/recall/F1, **full confusion matrix** (also as a PNG), and a **binary pure-vs-adulterated** summary. Explicitly note starch is typically the hardest class. Show a held-out test split result, not just CV.
5. **Uncertain threshold analysis:** sweep the probability threshold (0.4–0.9), plot accuracy vs coverage, recommend a default (~0.60) and print how many test samples fall to "Uncertain" at that level.
6. Optional: quick **feature-importance** view (permutation importance) so the user can see which sensors matter.
7. **Export:**
   - `model.h` via **`micromlgen.port(clf)`** (SVM → C++), namespaced so it drops into `03_deployment`.
   - `scaler.h`: `const float FEAT_MEAN[9] = {...}; const float FEAT_SCALE[9] = {...};` in the exact feature order, plus the chosen `CONF_THRESHOLD` default.
   - Print a one-line "copy these two files into `03_deployment/`" instruction.
8. Save the fitted pipeline (`joblib`) and a `metrics.json`.

## Quality bar
- Deterministic (`random_state`), reproducible; `requirements.txt` pinned (`scikit-learn, pandas, numpy, matplotlib, micromlgen, joblib`).
- Do NOT overstate results — the report must be usable in the user's viva/thesis as an honest evaluation. Include a short "limitations" note (dataset size, source diversity, drift).
- Guard against tiny datasets (clear message if too few samples per class).

## Deliverables
`training/train.py`, `training/train.ipynb`, `training/utils.py`, `training/requirements.txt`, `training/data/.gitkeep`, `training/report/` (populated on run), and `training/README.md` (how to run, where CSVs go, how to move `model.h`/`scaler.h` into `03_deployment`). Include 2–3 rows of **synthetic sample data** so the pipeline runs end-to-end before real data exists (clearly marked synthetic).
