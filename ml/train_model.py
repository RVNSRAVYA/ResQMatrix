import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd

from sklearn.model_selection import (
    RepeatedStratifiedKFold,
    StratifiedKFold,
    cross_validate,
    train_test_split,
)
from sklearn.tree import DecisionTreeClassifier
from sklearn.ensemble import RandomForestClassifier
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import (
    accuracy_score,
    precision_score,
    recall_score,
    f1_score,
    confusion_matrix,
    classification_report,
)

from xgboost import XGBClassifier


# ---------------------------------------------------------
# Paths
# ---------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent
DATA_FILE = BASE_DIR / "flood dataset.xlsx"
MODEL_DIR = BASE_DIR / "models"

MODEL_DIR.mkdir(exist_ok=True)

MODEL_FILE = MODEL_DIR / "flood_risk_model.pkl"
METADATA_FILE = MODEL_DIR / "model_metadata.json"


# ---------------------------------------------------------
# Load dataset
# ---------------------------------------------------------

print("=" * 70)
print("ResQMatrix - Machine Learning Training")
print("=" * 70)

print("\nLoading dataset...")

df = pd.read_excel(DATA_FILE, sheet_name="Sheet5")

print(f"Dataset shape: {df.shape}")

# Remove accidental spaces from column names
df.columns = df.columns.astype(str).str.strip()

print("\nColumns:")
print(df.columns.tolist())


# ---------------------------------------------------------
# Validate required columns
# ---------------------------------------------------------

required_columns = [
    "Temp",
    "Humidity",
    "Cloud Cover",
    "ANNUAL",
    "Jan-Feb",
    "Mar-May",
    "Jun-Sep",
    "Oct-Dec",
    "avgjune",
    "sub",
    "flood",
]

missing_columns = [
    column for column in required_columns
    if column not in df.columns
]

if missing_columns:
    raise ValueError(
        f"Missing required columns: {missing_columns}"
    )


# ---------------------------------------------------------
# Clean data
# ---------------------------------------------------------

df = df[required_columns].copy()

print("\nMissing values before cleaning:")
print(df.isnull().sum())

df = df.dropna().reset_index(drop=True)

print(f"\nRows after cleaning: {len(df)}")


# ---------------------------------------------------------
# Features and target
# ---------------------------------------------------------

feature_columns = [
    "Temp",
    "Humidity",
    "Cloud Cover",
    "ANNUAL",
    "Jan-Feb",
    "Mar-May",
    "Jun-Sep",
    "Oct-Dec",
    "avgjune",
    "sub",
]

target_column = "flood"

X = df[feature_columns]
y = df[target_column].astype(int)


# ---------------------------------------------------------
# Target distribution
# ---------------------------------------------------------

print("\nTarget distribution:")
print(y.value_counts())

print("\nTarget percentages:")
print(
    (y.value_counts(normalize=True) * 100)
    .round(2)
    .sort_index()
)


# ---------------------------------------------------------
# Class imbalance
# ---------------------------------------------------------

negative_count = int((y == 0).sum())
positive_count = int((y == 1).sum())

scale_pos_weight = negative_count / positive_count

print(
    f"\nXGBoost scale_pos_weight: "
    f"{scale_pos_weight:.4f}"
)


# ---------------------------------------------------------
# Models
# ---------------------------------------------------------

models = {
    "Decision Tree": DecisionTreeClassifier(
        max_depth=5,
        min_samples_leaf=3,
        class_weight="balanced",
        random_state=42,
    ),

    "Random Forest": RandomForestClassifier(
        n_estimators=300,
        max_depth=8,
        min_samples_leaf=2,
        class_weight="balanced",
        random_state=42,
        n_jobs=-1,
    ),

    "KNN": Pipeline(
        steps=[
            ("scaler", StandardScaler()),
            (
                "knn",
                KNeighborsClassifier(
                    n_neighbors=5,
                    weights="distance",
                ),
            ),
        ]
    ),

    "XGBoost": XGBClassifier(
        n_estimators=200,
        max_depth=3,
        learning_rate=0.03,
        min_child_weight=2,
        subsample=0.9,
        colsample_bytree=0.9,
        reg_alpha=0.1,
        reg_lambda=1.0,
        scale_pos_weight=scale_pos_weight,
        random_state=42,
        eval_metric="logloss",
        n_jobs=1,
    ),
}


# ---------------------------------------------------------
# Cross-validation comparison
# ---------------------------------------------------------

print("\n" + "=" * 70)
print("MODEL COMPARISON")
print("=" * 70)

cv = RepeatedStratifiedKFold(
    n_splits=4,
    n_repeats=3,
    random_state=42,
)

scoring = {
    "accuracy": "accuracy",
    "precision": "precision",
    "recall": "recall",
    "f1": "f1",
}

results = []

for name, model in models.items():

    print(f"\nTraining/evaluating: {name}")

    scores = cross_validate(
        model,
        X,
        y,
        cv=cv,
        scoring=scoring,
        n_jobs=1,
        error_score="raise",
    )

    accuracy_mean = scores["test_accuracy"].mean()
    precision_mean = scores["test_precision"].mean()
    recall_mean = scores["test_recall"].mean()
    f1_mean = scores["test_f1"].mean()

    accuracy_std = scores["test_accuracy"].std()
    precision_std = scores["test_precision"].std()
    recall_std = scores["test_recall"].std()
    f1_std = scores["test_f1"].std()

    print(
        f"Accuracy : {accuracy_mean:.4f} +/- {accuracy_std:.4f}"
    )
    print(
        f"Precision: {precision_mean:.4f} +/- {precision_std:.4f}"
    )
    print(
        f"Recall   : {recall_mean:.4f} +/- {recall_std:.4f}"
    )
    print(
        f"F1       : {f1_mean:.4f} +/- {f1_std:.4f}"
    )

    results.append(
        {
            "model": name,
            "accuracy": accuracy_mean,
            "precision": precision_mean,
            "recall": recall_mean,
            "f1": f1_mean,
        }
    )


# ---------------------------------------------------------
# Results table
# ---------------------------------------------------------

results_df = pd.DataFrame(results)

results_df = results_df.sort_values(
    by=["f1", "recall"],
    ascending=False,
).reset_index(drop=True)

print("\n" + "=" * 70)
print("FINAL MODEL COMPARISON")
print("=" * 70)

print(
    results_df.to_string(
        index=False,
        formatters={
            "accuracy": "{:.4f}".format,
            "precision": "{:.4f}".format,
            "recall": "{:.4f}".format,
            "f1": "{:.4f}".format,
        },
    )
)


# ---------------------------------------------------------
# Select best model
# ---------------------------------------------------------

best_model_name = results_df.iloc[0]["model"]

print(
    f"\nSelected model: {best_model_name}"
)

best_model = models[best_model_name]


# ---------------------------------------------------------
# Holdout evaluation for selected model
# ---------------------------------------------------------

X_train, X_test, y_train, y_test = train_test_split(
    X,
    y,
    test_size=0.20,
    stratify=y,
    random_state=42,
)

best_model.fit(X_train, y_train)

y_pred = best_model.predict(X_test)

holdout_accuracy = accuracy_score(y_test, y_pred)
holdout_precision = precision_score(
    y_test,
    y_pred,
    zero_division=0,
)
holdout_recall = recall_score(
    y_test,
    y_pred,
    zero_division=0,
)
holdout_f1 = f1_score(
    y_test,
    y_pred,
    zero_division=0,
)

cm = confusion_matrix(y_test, y_pred)

print("\n" + "=" * 70)
print("HOLDOUT TEST RESULTS")
print("=" * 70)

print(f"Accuracy : {holdout_accuracy:.4f}")
print(f"Precision: {holdout_precision:.4f}")
print(f"Recall   : {holdout_recall:.4f}")
print(f"F1-score : {holdout_f1:.4f}")

print("\nConfusion Matrix:")
print(cm)

print("\nClassification Report:")
print(
    classification_report(
        y_test,
        y_pred,
        target_names=["No Flood", "Flood"],
        zero_division=0,
    )
)


# ---------------------------------------------------------
# Train final model on complete dataset
# ---------------------------------------------------------

print("\nTraining final model using all available data...")

best_model.fit(X, y)


# ---------------------------------------------------------
# Save model
# ---------------------------------------------------------

joblib.dump(best_model, MODEL_FILE)

print(f"\nModel saved to:")
print(MODEL_FILE)


# ---------------------------------------------------------
# Risk thresholds
# ---------------------------------------------------------

risk_thresholds = {
    "Low": [0.00, 0.25],
    "Moderate": [0.25, 0.50],
    "High": [0.50, 0.75],
    "Critical": [0.75, 1.00],
}


# ---------------------------------------------------------
# Metadata
# ---------------------------------------------------------

metadata = {
    "dataset_file": DATA_FILE.name,
    "dataset_rows": int(len(df)),
    "dataset_columns": int(len(df.columns)),
    "target_column": target_column,
    "target_distribution": {
        "0": negative_count,
        "1": positive_count,
    },
    "features": feature_columns,
    "selected_model": best_model_name,
    "selection_metric": "F1-score, with Recall as tie-breaker",

    "cross_validation": {
        "method": "RepeatedStratifiedKFold",
        "n_splits": 4,
        "n_repeats": 3,
        "random_state": 42,
    },

    "model_comparison": results_df.to_dict(
        orient="records"
    ),

    "holdout_metrics": {
        "accuracy": holdout_accuracy,
        "precision": holdout_precision,
        "recall": holdout_recall,
        "f1": holdout_f1,
        "confusion_matrix": cm.tolist(),
    },

    "risk_thresholds": risk_thresholds,

    "prediction_note": (
        "The target dataset is binary: 0 = No Flood, "
        "1 = Flood. The four risk levels are "
        "application-defined probability bands and "
        "are not four ground-truth classes."
    ),

    "disclaimer": (
        "This prediction is an AI/ML decision-support "
        "estimate and should not be treated as an "
        "official flood warning."
    ),
}

with open(
    METADATA_FILE,
    "w",
    encoding="utf-8",
) as f:
    json.dump(
        metadata,
        f,
        indent=4,
    )

print("\nMetadata saved to:")
print(METADATA_FILE)

print("\n" + "=" * 70)
print("TRAINING COMPLETED")
print("=" * 70)

