"""Train and evaluate the ResQMatrix flood-risk classifier on historical-style records.

Evaluation is CHRONOLOGICAL: the model trains on records up to 2019 and is tested on
2020-2025, which is stricter than a random split because the test years are "the future".
A stratified random split and 5-fold CV on the training years are reported as well.

The shipped dataset is simulated historical-style data (see generate_historical_dataset.py).
Metrics therefore describe this dataset only, not real-world flood-forecast skill.
"""
from pathlib import Path
import json
import shutil
import warnings
import joblib
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, confusion_matrix, f1_score, precision_score, recall_score, roc_auc_score
from sklearn.model_selection import StratifiedKFold, cross_validate, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

warnings.filterwarnings("ignore")
ROOT = Path(__file__).resolve().parent
DATA = ROOT / "flood_risk_dataset_india.csv"
MODEL_DIR = ROOT / "models"
MODEL_DIR.mkdir(exist_ok=True)
MODEL_PATH = MODEL_DIR / "flood_risk_model.pkl"
META_PATH = MODEL_DIR / "model_metadata.json"

FEATURES = [
    "Latitude", "Longitude", "Rainfall (mm)", "Rainfall 3-Day (mm)", "Temperature (°C)",
    "Humidity (%)", "River Discharge (m³/s)", "Water Level (m)", "Elevation (m)",
    "Land Cover", "Soil Type", "Population Density", "Infrastructure", "Historical Floods",
]
TARGET = "Flood Occurred"
CATEGORICAL = ["Land Cover", "Soil Type"]
NUMERIC = [c for c in FEATURES if c not in CATEGORICAL]
TEST_FROM_YEAR = 2020


def build_model() -> Pipeline:
    pre = ColumnTransformer([
        ("num", Pipeline([("imputer", SimpleImputer(strategy="median")), ("scale", StandardScaler())]), NUMERIC),
        ("cat", Pipeline([("imputer", SimpleImputer(strategy="most_frequent")),
                          ("onehot", OneHotEncoder(handle_unknown="ignore"))]), CATEGORICAL),
    ])
    return Pipeline([("preprocess", pre), ("classifier", LogisticRegression(max_iter=3000, C=1.0, random_state=42))])


def scores(y_true, pred, proba):
    return {
        "accuracy": float(accuracy_score(y_true, pred)),
        "precision": float(precision_score(y_true, pred, zero_division=0)),
        "recall": float(recall_score(y_true, pred, zero_division=0)),
        "f1": float(f1_score(y_true, pred, zero_division=0)),
        "roc_auc": float(roc_auc_score(y_true, proba)),
        "confusion_matrix": confusion_matrix(y_true, pred).tolist(),
    }


def main():
    if not DATA.exists():
        raise FileNotFoundError(f"Dataset not found: {DATA}. Run generate_historical_dataset.py first.")
    df = pd.read_csv(DATA)
    df.columns = df.columns.astype(str).str.strip()
    missing = [c for c in FEATURES + [TARGET, "Date"] if c not in df.columns]
    if missing:
        raise ValueError(f"Missing columns: {missing}")
    df["Date"] = pd.to_datetime(df["Date"])
    df = df.dropna(subset=FEATURES + [TARGET]).copy()
    df[TARGET] = df[TARGET].astype(int)
    if len(df) < 10_000:
        raise ValueError(f"Need at least 10,000 records, found {len(df)}.")

    # 1) Chronological hold-out (primary metric)
    train = df[df["Date"].dt.year < TEST_FROM_YEAR]
    test = df[df["Date"].dt.year >= TEST_FROM_YEAR]
    m = build_model().fit(train[FEATURES], train[TARGET])
    chrono = scores(test[TARGET], m.predict(test[FEATURES]), m.predict_proba(test[FEATURES])[:, 1])

    # 2) Stratified random 80/20 split (secondary)
    Xtr, Xte, ytr, yte = train_test_split(df[FEATURES], df[TARGET], test_size=0.2, random_state=42, stratify=df[TARGET])
    m2 = build_model().fit(Xtr, ytr)
    strat = scores(yte, m2.predict(Xte), m2.predict_proba(Xte)[:, 1])

    # 3) 5-fold CV on the training years only
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    res = cross_validate(build_model(), train[FEATURES], train[TARGET], cv=cv,
                         scoring=["accuracy", "precision", "recall", "f1"], n_jobs=1)
    cv_metrics = {k.removeprefix("test_"): {"mean": float(np.mean(v)), "std": float(np.std(v))}
                  for k, v in res.items() if k.startswith("test_")}

    # Final artifact: refit on every record after evaluation.
    final = build_model().fit(df[FEATURES], df[TARGET])
    joblib.dump(final, MODEL_PATH)

    import sklearn
    metadata = {
        "dataset_file": DATA.name,
        "dataset_rows": int(len(df)),
        "dataset_columns": int(df.shape[1]),
        "date_range": [df["Date"].min().strftime("%Y-%m-%d"), df["Date"].max().strftime("%Y-%m-%d")],
        "stations": int(df["Station"].nunique()) if "Station" in df.columns else None,
        "dataset_type": "Historical-style flood records (2000-2025), simulated; replace with archive data for real-world claims.",
        "target_column": TARGET,
        "target_distribution": {str(int(k)): int(v) for k, v in df[TARGET].value_counts().sort_index().items()},
        "features": FEATURES,
        "categorical_features": CATEGORICAL,
        "selected_model": "Logistic Regression with preprocessing pipeline",
        "sklearn_version": sklearn.__version__,
        "evaluation": {
            "primary_split": f"Chronological: train < {TEST_FROM_YEAR}, test {TEST_FROM_YEAR}-2025",
            "train_rows": int(len(train)),
            "test_rows": int(len(test)),
            "holdout_metrics": chrono,
            "stratified_random_split_metrics": strat,
            "training_years_5fold_cv": cv_metrics,
        },
        "risk_thresholds": {"Low": [0.0, 0.25], "Moderate": [0.25, 0.5], "High": [0.5, 0.75], "Critical": [0.75, 1.0]},
        "note": "Metrics describe this simulated historical-style dataset only. They are not evidence of real-world flood-forecast accuracy.",
    }
    META_PATH.write_text(json.dumps(metadata, indent=2), encoding="utf-8")

    backend = ROOT.parent / "backend"
    (backend / "models").mkdir(parents=True, exist_ok=True)
    (backend / "data").mkdir(parents=True, exist_ok=True)
    shutil.copy2(MODEL_PATH, backend / "models" / MODEL_PATH.name)
    bmeta = dict(metadata)
    bmeta["dataset_file"] = f"data/{DATA.name}"
    (backend / "models" / META_PATH.name).write_text(json.dumps(bmeta, indent=2), encoding="utf-8")
    shutil.copy2(DATA, backend / "data" / DATA.name)

    print(f"RECORDS: {len(df):,}  ({metadata['date_range'][0]} -> {metadata['date_range'][1]})  train={len(train):,} test={len(test):,}")
    print(f"CHRONOLOGICAL HOLDOUT ({TEST_FROM_YEAR}-2025) ACCURACY: {chrono['accuracy']*100:.2f}%  "
          f"precision {chrono['precision']*100:.2f}%  recall {chrono['recall']*100:.2f}%  F1 {chrono['f1']*100:.2f}%  AUC {chrono['roc_auc']:.3f}")
    print(f"STRATIFIED 80/20 ACCURACY:  {strat['accuracy']*100:.2f}%")
    print(f"5-FOLD CV (training years): {cv_metrics['accuracy']['mean']*100:.2f}% +/- {cv_metrics['accuracy']['std']*100:.2f}")
    print("MODEL SAVED:", MODEL_PATH)


if __name__ == "__main__":
    main()
