from pathlib import Path
from datetime import datetime, timezone
import json
import math
import uuid

import joblib
import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel


# ---------------------------------------------------------
# App configuration
# ---------------------------------------------------------

app = FastAPI(
    title="ResQMatrix API",
    description="Intelligent emergency prioritization and resource allocation framework API",
    version="2.0.0",
)


# Allow Flutter Web / local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------
# Load trained ML model (auto-retrains if the saved model is unusable)
# ---------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent

MODEL_PATH = BASE_DIR / "models" / "flood_risk_model.pkl"
METADATA_PATH = BASE_DIR / "models" / "model_metadata.json"
DATASET_PATH = BASE_DIR / "data" / "flood_risk_dataset_india.csv"

# Exact feature order used by the historical dataset and trained pipeline.
FEATURES = [
    "Latitude", "Longitude", "Rainfall (mm)", "Rainfall 3-Day (mm)", "Temperature (°C)",
    "Humidity (%)", "River Discharge (m³/s)", "Water Level (m)", "Elevation (m)",
    "Land Cover", "Soil Type", "Population Density", "Infrastructure", "Historical Floods",
]
CATEGORICAL = ["Land Cover", "Soil Type"]
NUMERIC = [c for c in FEATURES if c not in CATEGORICAL]
TARGET = "Flood Occurred"


def _read_metadata() -> dict:
    try:
        return json.loads(METADATA_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def _retrain_from_csv():
    """Fit the same pipeline as ml/train_model.py directly from the bundled CSV."""
    import sklearn
    from sklearn.compose import ColumnTransformer
    from sklearn.impute import SimpleImputer
    from sklearn.linear_model import LogisticRegression
    from sklearn.pipeline import Pipeline
    from sklearn.preprocessing import OneHotEncoder, StandardScaler

    data = pd.read_csv(DATASET_PATH).dropna(subset=FEATURES + [TARGET])
    pre = ColumnTransformer([
        ("num", Pipeline([("imputer", SimpleImputer(strategy="median")), ("scale", StandardScaler())]), NUMERIC),
        ("cat", Pipeline([("imputer", SimpleImputer(strategy="most_frequent")),
                          ("onehot", OneHotEncoder(handle_unknown="ignore"))]), CATEGORICAL),
    ])
    fresh = Pipeline([("preprocess", pre), ("classifier", LogisticRegression(max_iter=3000, random_state=42))])
    fresh.fit(data[FEATURES], data[TARGET].astype(int))
    try:
        joblib.dump(fresh, MODEL_PATH)
        meta = _read_metadata()
        meta["sklearn_version"] = sklearn.__version__
        METADATA_PATH.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    except OSError:
        pass
    print("[ResQMatrix] Model retrained from bundled dataset for this environment.")
    return fresh


def _load_model():
    import sklearn
    meta = _read_metadata()
    saved_version = meta.get("sklearn_version")
    if MODEL_PATH.exists() and saved_version in (None, sklearn.__version__):
        try:
            loaded = joblib.load(MODEL_PATH)
            loaded.predict_proba(pd.read_csv(DATASET_PATH, nrows=3)[FEATURES])  # smoke test
            return loaded
        except Exception as exc:  # noqa: BLE001 - any failure -> retrain
            print(f"[ResQMatrix] Saved model could not be used ({exc}); retraining.")
    return _retrain_from_csv()


model = _load_model()
MODEL_METADATA = _read_metadata()
MODEL_NAME = MODEL_METADATA.get("selected_model", "Logistic Regression with preprocessing pipeline")
HOLDOUT_METRICS = MODEL_METADATA.get("evaluation", {}).get("holdout_metrics", {})
DATASET_TYPE = "Historical-style flood records (2000-2025), simulated"


# ---------------------------------------------------------
# Input schema matching the historical dataset
# ---------------------------------------------------------

class FloodPredictionRequest(BaseModel):
    latitude: float
    longitude: float
    rainfall: float
    rainfall_3day: float | None = None
    temperature: float
    humidity: float
    river_discharge: float
    water_level: float
    elevation: float
    land_cover: str
    soil_type: str
    population_density: float
    infrastructure: int
    historical_floods: int


# ---------------------------------------------------------
# Risk level calculation
# ---------------------------------------------------------

def get_risk_level(probability: float) -> str:
    """
    Application-defined risk bands based on predicted
    flood probability.

    These are NOT ground-truth classes from the dataset.
    """

    if probability < 0.25:
        return "Low"
    elif probability < 0.50:
        return "Moderate"
    elif probability < 0.75:
        return "High"
    else:
        return "Critical"


# ---------------------------------------------------------
# Root endpoint
# ---------------------------------------------------------

@app.get("/")
def root():
    return {
        "project": "ResQMatrix",
        "message": "ResQMatrix backend is running",
        "model": MODEL_NAME,
        "features": FEATURES,
    }


# ---------------------------------------------------------
# Health endpoint
# ---------------------------------------------------------

@app.get("/health")
def health():
    return {
        "status": "healthy",
        "model_loaded": True,
        "model": MODEL_NAME,
        "number_of_features": len(FEATURES),
    }


# ---------------------------------------------------------
# Model information endpoint
# ---------------------------------------------------------

@app.get("/model-info")
def model_info():
    evaluation = MODEL_METADATA.get("evaluation", {})
    return {
        "model": MODEL_NAME,
        "target": TARGET,
        "classes": [0, 1],
        "dataset_rows": int(MODEL_METADATA.get("dataset_rows", 0)),
        "dataset_file": "data/flood_risk_dataset_india.csv",
        "dataset_type": DATASET_TYPE,
        "date_range": MODEL_METADATA.get("date_range"),
        "stations": MODEL_METADATA.get("stations"),
        "features": FEATURES,
        "feature_count": len(FEATURES),
        "accuracy_percent": round(float(HOLDOUT_METRICS.get("accuracy", 0)) * 100, 2),
        "evaluation": HOLDOUT_METRICS,
        "evaluation_split": evaluation.get("primary_split"),
        "stratified_random_split_metrics": evaluation.get("stratified_random_split_metrics"),
        "cross_validation": evaluation.get("training_years_5fold_cv"),
        "risk_levels": {
            "Low": "0.00 - 0.24",
            "Moderate": "0.25 - 0.49",
            "High": "0.50 - 0.74",
            "Critical": "0.75 - 1.00",
        },
        "note": (
            "Accuracy is measured on a chronological hold-out (2020-2025 records, never used for training). "
            "The bundled records are simulated historical-style data, not official observations, so the score "
            "does not establish real-world flood-forecast accuracy. Risk levels are application-defined "
            "probability bands; the target is binary: 0 = No Flood, 1 = Flood."
        ),
    }

# ---------------------------------------------------------
# Flood prediction endpoint
# ---------------------------------------------------------

@app.post("/predict")
def predict_flood(request: FloodPredictionRequest):
    try:
        input_data = pd.DataFrame([{
            "Latitude": request.latitude,
            "Longitude": request.longitude,
            "Rainfall (mm)": request.rainfall,
            "Rainfall 3-Day (mm)": request.rainfall_3day if request.rainfall_3day is not None else request.rainfall * 1.6,
            "Temperature (°C)": request.temperature,
            "Humidity (%)": request.humidity,
            "River Discharge (m³/s)": request.river_discharge,
            "Water Level (m)": request.water_level,
            "Elevation (m)": request.elevation,
            "Land Cover": request.land_cover,
            "Soil Type": request.soil_type,
            "Population Density": request.population_density,
            "Infrastructure": request.infrastructure,
            "Historical Floods": request.historical_floods,
        }], columns=FEATURES)
        prediction = int(model.predict(input_data)[0])
        probabilities = model.predict_proba(input_data)[0]
        class_list = list(model.classes_)
        if 1 not in class_list:
            raise ValueError("Model does not contain flood class 1.")
        flood_probability = float(probabilities[class_list.index(1)])
        risk_level = get_risk_level(flood_probability)
        return {
            "flood_occurred": prediction,
            "flood_label": "Flood" if prediction == 1 else "No Flood",
            "flood_probability": round(flood_probability, 4),
            "flood_probability_percent": round(flood_probability * 100, 2),
            "risk_level": risk_level,
            "model": MODEL_NAME,
            "dataset_rows": int(MODEL_METADATA.get("dataset_rows", 0)),
            "dataset_note": "Trained on simulated historical-style records; holdout accuracy does not establish real-world flood forecast accuracy.",
            "disclaimer": "This estimate is based on simulated historical-style records and is not an official flood warning or validated real-world forecast.",
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(exc)}")


@app.get("/risk-areas")
def get_risk_areas(limit: int = 60):
    """Return model-estimated flood risk per monitoring station for the map.

    Each station's risk is the mean model probability across its records from the most recent
    year in the historical dataset, plus the station's long-run historical flood rate.
    """
    if not DATASET_PATH.exists():
        raise HTTPException(status_code=503, detail="Flood map dataset is missing.")
    try:
        limit = max(1, min(limit, 200))
        data = pd.read_csv(DATASET_PATH)
        data["probability"] = model.predict_proba(data[FEATURES])[:, list(model.classes_).index(1)]
        data["year"] = pd.to_datetime(data["Date"]).dt.year
        latest_year = int(data["year"].max())
        recent = data[data["year"] >= latest_year - 1]
        grouped = recent.groupby("Station").agg(
            latitude=("Latitude", "mean"), longitude=("Longitude", "mean"),
            state=("State", "first"), river=("River", "first"),
            probability=("probability", "mean"), records=("probability", "size"),
        )
        history = data.groupby("Station").agg(
            total_records=("probability", "size"),
            flood_events=(TARGET, "sum"),
        )
        grouped = grouped.join(history).sort_values("probability", ascending=False).head(limit)
        points = []
        for station, row in grouped.iterrows():
            probability = float(row["probability"])
            points.append({
                "id": station,
                "station": station,
                "state": row["state"],
                "river": row["river"],
                "latitude": round(float(row["latitude"]), 5),
                "longitude": round(float(row["longitude"]), 5),
                "probability": round(probability, 4),
                "probability_percent": round(probability * 100, 1),
                "risk_level": get_risk_level(probability),
                "historical_flood_events": int(row["flood_events"]),
                "historical_records": int(row["total_records"]),
                "historical_flood_rate_percent": round(100 * row["flood_events"] / row["total_records"], 1),
            })
        return {
            "count": len(points),
            "dataset_rows": int(len(data)),
            "dataset_type": DATASET_TYPE,
            "date_range": [str(data["Date"].min()), str(data["Date"].max())],
            "areas": points,
            "disclaimer": "Station risk is model-estimated from simulated historical-style records. It is not an official flood boundary, live sensor reading, or government alert.",
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not prepare risk map: {str(exc)}")


 # ---------------------------------------------------------
# Emergency request system
# ---------------------------------------------------------

EMERGENCY_FILE = BASE_DIR / "emergency_requests.json"


class EmergencyRequestCreate(BaseModel):
    emergency_type: str
    urgency: str
    people_count: int
    description: str
    latitude: float
    longitude: float


def load_emergency_requests():
    if not EMERGENCY_FILE.exists():
        return []

    try:
        with open(EMERGENCY_FILE, "r", encoding="utf-8") as file:
            return json.load(file)
    except (json.JSONDecodeError, OSError):
        return []


def save_emergency_requests(requests):
    with open(EMERGENCY_FILE, "w", encoding="utf-8") as file:
        json.dump(requests, file, indent=2)


@app.post("/emergency-requests", status_code=201)
def create_emergency_request(request: EmergencyRequestCreate):
    if request.people_count <= 0:
        raise HTTPException(
            status_code=400,
            detail="Number of people must be greater than 0.",
        )

    if not -90 <= request.latitude <= 90:
        raise HTTPException(
            status_code=400,
            detail="Invalid latitude.",
        )

    if not -180 <= request.longitude <= 180:
        raise HTTPException(
            status_code=400,
            detail="Invalid longitude.",
        )

    emergency = {
        "request_id": f"FR-{uuid.uuid4().hex[:8].upper()}",
        "emergency_type": request.emergency_type,
        "urgency": request.urgency,
        "people_count": request.people_count,
        "description": request.description,
        "latitude": request.latitude,
        "longitude": request.longitude,
        "status": "Submitted",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    requests = load_emergency_requests()
    requests.append(emergency)
    save_emergency_requests(requests)

    return {
        "message": "Emergency request submitted successfully.",
        "request": emergency,
    }


@app.get("/emergency-requests")
def get_emergency_requests():
    requests = load_emergency_requests()

    return {
        "count": len(requests),
        "requests": requests,
    }


@app.get("/emergency-requests/{request_id}")
def get_emergency_request(request_id: str):
    requests = load_emergency_requests()

    for request in requests:
        if request["request_id"] == request_id:
            return request

    raise HTTPException(
        status_code=404,
        detail="Emergency request not found.",
    )       

# ---------------------------------------------------------
# ResQMatrix organization resource and donation management
# Demo persistence uses JSON files. Use PostgreSQL + authentication
# before any real/public emergency deployment.
# ---------------------------------------------------------

RESOURCE_FILE = BASE_DIR / "resources.json"
DONATION_FILE = BASE_DIR / "donations.json"

class ResourceCreate(BaseModel):
    organization_name: str
    name: str
    resource_type: str
    quantity: int
    location: str
    contact: str = ""
    latitude: float | None = None
    longitude: float | None = None

class DonationCreate(BaseModel):
    organization_name: str
    donor_name: str
    donation_type: str
    quantity_or_amount: str
    notes: str = ""

class EmergencyStatusUpdate(BaseModel):
    status: str

class ResourceVerificationUpdate(BaseModel):
    status: str

RESOURCE_STATUSES = {"Pending", "Verified", "Rejected", "Unavailable"}
EMERGENCY_STATUSES = {"Submitted", "Under Review", "Assigned", "Accepted", "In Progress", "Resolved", "Cancelled"}

def _load_json_list(path: Path):
    if not path.exists():
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, list) else []
    except (json.JSONDecodeError, OSError):
        return []

def _save_json_list(path: Path, rows):
    path.write_text(json.dumps(rows, indent=2), encoding="utf-8")

@app.get("/resources")
def list_resources():
    rows = _load_json_list(RESOURCE_FILE)
    # Backwards-compatible defaults for resource records created before
    # allocation tracking was added.
    for row in rows:
        row.setdefault("available_quantity", int(row.get("quantity", 0) or 0))
        row.setdefault("allocated_quantity", 0)
    return {"count": len(rows), "resources": rows}

@app.post("/resources", status_code=201)
def create_resource(resource: ResourceCreate):
    if not resource.organization_name.strip() or not resource.name.strip() or not resource.location.strip():
        raise HTTPException(status_code=400, detail="Organization, resource name, and location are required.")
    if resource.quantity < 0:
        raise HTTPException(status_code=400, detail="Quantity cannot be negative.")
    if (resource.latitude is None) != (resource.longitude is None):
        raise HTTPException(status_code=400, detail="Enter both latitude and longitude, or leave both blank.")
    if resource.latitude is not None and not -90 <= resource.latitude <= 90:
        raise HTTPException(status_code=400, detail="Latitude must be between -90 and 90.")
    if resource.longitude is not None and not -180 <= resource.longitude <= 180:
        raise HTTPException(status_code=400, detail="Longitude must be between -180 and 180.")
    row = {
        "resource_id": f"RES-{uuid.uuid4().hex[:8].upper()}",
        "organization_name": resource.organization_name.strip(),
        "name": resource.name.strip(),
        "resource_type": resource.resource_type.strip(),
        "quantity": resource.quantity,
        "available_quantity": resource.quantity,
        "allocated_quantity": 0,
        "location": resource.location.strip(),
        "contact": resource.contact.strip(),
        "latitude": resource.latitude,
        "longitude": resource.longitude,
        "status": "Pending",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    rows = _load_json_list(RESOURCE_FILE)
    rows.append(row)
    _save_json_list(RESOURCE_FILE, rows)
    return {"message": "Resource submitted for administrator verification.", "resource": row}

@app.patch("/resources/{resource_id}/verification")
def verify_resource(resource_id: str, update: ResourceVerificationUpdate):
    if update.status not in RESOURCE_STATUSES:
        raise HTTPException(status_code=400, detail=f"Status must be one of: {', '.join(sorted(RESOURCE_STATUSES))}")
    rows = _load_json_list(RESOURCE_FILE)
    for row in rows:
        if row["resource_id"] == resource_id:
            row["status"] = update.status
            row["verified_at"] = datetime.now(timezone.utc).isoformat() if update.status == "Verified" else None
            _save_json_list(RESOURCE_FILE, rows)
            return {"message": "Resource status updated.", "resource": row}
    raise HTTPException(status_code=404, detail="Resource not found.")

@app.get("/donations")
def list_donations():
    rows = _load_json_list(DONATION_FILE)
    return {"count": len(rows), "donations": rows}

@app.post("/donations", status_code=201)
def create_donation(donation: DonationCreate):
    if not donation.organization_name.strip() or not donation.donor_name.strip() or not donation.donation_type.strip() or not donation.quantity_or_amount.strip():
        raise HTTPException(status_code=400, detail="Organization, donor, donation type, and quantity/amount are required.")
    row = {
        "donation_id": f"DON-{uuid.uuid4().hex[:8].upper()}",
        "organization_name": donation.organization_name.strip(),
        "donor_name": donation.donor_name.strip(),
        "donation_type": donation.donation_type.strip(),
        "quantity_or_amount": donation.quantity_or_amount.strip(),
        "notes": donation.notes.strip(),
        "status": "Received",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    rows = _load_json_list(DONATION_FILE)
    rows.append(row)
    _save_json_list(DONATION_FILE, rows)
    return {"message": "Donation recorded successfully.", "donation": row}

@app.patch("/emergency-requests/{request_id}/status")
def update_emergency_status(request_id: str, update: EmergencyStatusUpdate):
    if update.status not in EMERGENCY_STATUSES:
        raise HTTPException(status_code=400, detail=f"Status must be one of: {', '.join(sorted(EMERGENCY_STATUSES))}")
    rows = load_emergency_requests()
    for row in rows:
        if row["request_id"] == request_id:
            row["status"] = update.status
            row["updated_at"] = datetime.now(timezone.utc).isoformat()
            save_emergency_requests(rows)
            return {"message": "Emergency status updated.", "request": row}
    raise HTTPException(status_code=404, detail="Emergency request not found.")

# ---------------------------------------------------------
# ResQMatrix feature 1: transparent priority triage
# ---------------------------------------------------------

TRIAGE_EXCLUDED_STATUSES = {"Resolved", "Cancelled"}


def _parse_timestamp(value):
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    except (TypeError, ValueError):
        return None


def _priority_assessment(emergency):
    """Transparent rule-based queue score; not a medical/official assessment."""
    urgency = str(emergency.get("urgency", "Medium")).strip().casefold()
    urgency_points = {"critical": 45, "high": 32, "medium": 20, "low": 8}.get(urgency, 15)

    people = max(1, int(emergency.get("people_count", 1) or 1))
    if people >= 26:
        people_points = 25
        people_reason = f"{people} people reported (highest impact bracket)"
    elif people >= 11:
        people_points = 18
        people_reason = f"{people} people reported"
    elif people >= 6:
        people_points = 13
        people_reason = f"{people} people reported"
    elif people >= 3:
        people_points = 8
        people_reason = f"{people} people reported"
    else:
        people_points = 3
        people_reason = f"{people} people reported"

    emergency_type = str(emergency.get("emergency_type", "Other")).strip().casefold()
    type_points = 20 if emergency_type in {"medical", "ambulance", "rescue"} else 14 if emergency_type == "shelter" else 10 if emergency_type in {"food", "water", "medicines", "food & water"} else 5
    type_reason = "Life-safety request" if type_points == 20 else "Essential shelter/relief need" if type_points >= 10 else "General assistance request"

    created = _parse_timestamp(emergency.get("created_at"))
    age_minutes = max(0, int((datetime.now(timezone.utc) - created).total_seconds() // 60)) if created else 0
    aging_points = min(10, age_minutes // 30)
    if age_minutes >= 180:
        age_reason = f"Waiting {age_minutes // 60}h {age_minutes % 60}m"
    elif age_minutes >= 30:
        age_reason = f"Waiting {age_minutes} minutes"
    else:
        age_reason = "Recently submitted"

    status = str(emergency.get("status", "Submitted"))
    queue_points = 5 if status == "Submitted" else 3 if status == "Under Review" else 0
    score = min(100, urgency_points + people_points + type_points + aging_points + queue_points)
    band = "Critical" if score >= 75 else "High" if score >= 55 else "Moderate" if score >= 35 else "Low"
    action = "Immediate dispatch review" if band == "Critical" else "Prioritize resource assignment" if band == "High" else "Review in the active response queue" if band == "Moderate" else "Monitor and review"
    return {
        "priority_score": score,
        "priority_band": band,
        "recommended_action": action,
        "reasons": [
            f"Urgency: {emergency.get('urgency', 'Medium')} (+{urgency_points})",
            f"{people_reason} (+{people_points})",
            f"{type_reason} (+{type_points})",
            f"{age_reason} (+{aging_points})",
            f"Queue status: {status} (+{queue_points})",
        ],
        "score_method": "Rule-based demonstration score: urgency, people affected, request category, waiting time and workflow status.",
    }


@app.get("/triage")
def get_priority_triage():
    """List active emergencies ranked by a clear, rule-based triage score."""
    items = []
    for emergency in load_emergency_requests():
        if str(emergency.get("status", "Submitted")) in TRIAGE_EXCLUDED_STATUSES:
            continue
        items.append({**emergency, **_priority_assessment(emergency)})
    items.sort(key=lambda row: (row["priority_score"], str(row.get("created_at", ""))), reverse=True)
    return {
        "count": len(items),
        "requests": items,
        "method_note": "Operational decision support only. Scores are transparent rule-based heuristics, not a substitute for a trained dispatcher or official emergency guidance.",
    }


# ---------------------------------------------------------
# ResQMatrix feature 2: resource recommendation and allocation
# ---------------------------------------------------------

ALLOCATION_FILE = BASE_DIR / "allocations.json"


class AllocationCreate(BaseModel):
    request_id: str
    resource_id: str
    quantity: int = 1


def _resource_type_matches(emergency_type, resource_type):
    emergency = str(emergency_type or "Other").strip().casefold()
    resource = str(resource_type or "Other").strip().casefold()
    aliases = {
        "rescue": {"rescue team", "rescue", "water rescue"},
        "medical": {"medical", "medicines", "ambulance"},
        "ambulance": {"ambulance", "medical"},
        "food": {"food & water", "food", "water"},
        "water": {"food & water", "water", "food"},
        "food & water": {"food & water", "food", "water"},
        "medicines": {"medicines", "medical"},
        "shelter": {"shelter"},
        "other": {"other"},
    }
    desired = aliases.get(emergency, {emergency})
    return resource in desired


def _get_emergency_or_404(request_id):
    for row in load_emergency_requests():
        if row.get("request_id") == request_id:
            return row
    raise HTTPException(status_code=404, detail="Emergency request not found.")


def _resource_available_quantity(resource):
    return max(0, int(resource.get("available_quantity", resource.get("quantity", 0)) or 0))


def _distance_km(lat1, lon1, lat2, lon2):
    """Return great-circle straight-line distance in km, or None if incomplete."""
    if any(value is None for value in (lat1, lon1, lat2, lon2)):
        return None
    try:
        lat1, lon1, lat2, lon2 = map(float, (lat1, lon1, lat2, lon2))
    except (TypeError, ValueError):
        return None
    if not (-90 <= lat1 <= 90 and -90 <= lat2 <= 90 and -180 <= lon1 <= 180 and -180 <= lon2 <= 180):
        return None
    earth_radius_km = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    a = math.sin(delta_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    return earth_radius_km * 2 * math.atan2(math.sqrt(a), math.sqrt(max(0.0, 1 - a)))


def _distance_points(distance_km):
    if distance_km is None:
        return 0
    if distance_km <= 5:
        return 20
    if distance_km <= 10:
        return 17
    if distance_km <= 25:
        return 13
    if distance_km <= 50:
        return 8
    return 2


@app.get("/allocations")
def list_allocations():
    rows = _load_json_list(ALLOCATION_FILE)
    return {"count": len(rows), "allocations": sorted(rows, key=lambda row: row.get("created_at", ""), reverse=True)}


@app.get("/allocations/recommendations/{request_id}")
def get_allocation_recommendations(request_id: str):
    emergency = _get_emergency_or_404(request_id)
    assessment = _priority_assessment(emergency)
    candidates = []
    for resource in _load_json_list(RESOURCE_FILE):
        available = _resource_available_quantity(resource)
        if resource.get("status") != "Verified" or available < 1:
            continue
        type_match = _resource_type_matches(emergency.get("emergency_type"), resource.get("resource_type"))
        # Only suggest verified, available resources with a compatible category.
        # Proximity is scored only when both sides have validated GPS coordinates.
        if not type_match:
            continue
        capacity_points = min(20, available)
        priority_points = int(assessment["priority_score"] * 0.2)
        distance_km = _distance_km(
            emergency.get("latitude"), emergency.get("longitude"),
            resource.get("latitude"), resource.get("longitude"),
        )
        proximity_points = _distance_points(distance_km)
        # 40 base points for being verified + category-compatible, then up to
        # 20 each for inventory availability, request priority and proximity.
        score = min(100, 40 + capacity_points + priority_points + proximity_points)
        reasons = [
            f"Verified resource with compatible category: {resource.get('resource_type', 'Other')}",
            f"{available} unit(s) currently available (+{capacity_points} inventory points)",
            f"Request priority: {assessment['priority_band']} ({assessment['priority_score']}/100; +{priority_points} points)",
        ]
        if distance_km is None:
            reasons.append("Distance not scored: add resource GPS coordinates to enable proximity ranking.")
        else:
            reasons.append(f"Approx. {distance_km:.1f} km straight-line distance (+{proximity_points} proximity points; not a road-route estimate)")
        candidates.append({
            **resource,
            "available_quantity": available,
            "distance_km": round(distance_km, 2) if distance_km is not None else None,
            "proximity_points": proximity_points,
            "recommendation_score": score,
            "reasons": reasons,
        })
    candidates.sort(key=lambda row: (
        row["recommendation_score"],
        row["available_quantity"],
        -(row["distance_km"] if row["distance_km"] is not None else 1e9),
    ), reverse=True)
    return {
        "request": emergency,
        "priority": assessment,
        "count": len(candidates),
        "recommendations": candidates,
        "method_note": "Only verified, available resources in a compatible category are recommended. Ranking considers available inventory, request priority and straight-line proximity when both request and resource GPS coordinates exist. This is not road-route distance; human coordinators must verify suitability.",
    }


@app.post("/allocations", status_code=201)
def allocate_resource(allocation: AllocationCreate):
    if allocation.quantity <= 0:
        raise HTTPException(status_code=400, detail="Allocation quantity must be greater than zero.")
    emergency = _get_emergency_or_404(allocation.request_id)
    if emergency.get("status") in TRIAGE_EXCLUDED_STATUSES:
        raise HTTPException(status_code=400, detail="Resources cannot be allocated to a resolved or cancelled request.")

    resources = _load_json_list(RESOURCE_FILE)
    selected = next((row for row in resources if row.get("resource_id") == allocation.resource_id), None)
    if selected is None:
        raise HTTPException(status_code=404, detail="Resource not found.")
    if selected.get("status") != "Verified":
        raise HTTPException(status_code=400, detail="Only administrator-verified resources can be allocated.")
    if not _resource_type_matches(emergency.get("emergency_type"), selected.get("resource_type")):
        raise HTTPException(status_code=400, detail="This resource category does not match the emergency request.")

    available = _resource_available_quantity(selected)
    if allocation.quantity > available:
        raise HTTPException(status_code=400, detail=f"Only {available} unit(s) are available for this resource.")

    selected["available_quantity"] = available - allocation.quantity
    selected["allocated_quantity"] = int(selected.get("allocated_quantity", 0) or 0) + allocation.quantity
    _save_json_list(RESOURCE_FILE, resources)

    allocations = _load_json_list(ALLOCATION_FILE)
    row = {
        "allocation_id": f"ALL-{uuid.uuid4().hex[:8].upper()}",
        "request_id": allocation.request_id,
        "resource_id": allocation.resource_id,
        "resource_name": selected.get("name", "Resource"),
        "organization_name": selected.get("organization_name", "Organization"),
        "resource_type": selected.get("resource_type", "Other"),
        "quantity": allocation.quantity,
        "status": "Allocated",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    allocations.append(row)
    _save_json_list(ALLOCATION_FILE, allocations)

    emergency_rows = load_emergency_requests()
    for item in emergency_rows:
        if item.get("request_id") == allocation.request_id:
            if item.get("status") in {"Submitted", "Under Review"}:
                item["status"] = "Assigned"
            item["allocated_resource_ids"] = list(dict.fromkeys(item.get("allocated_resource_ids", []) + [allocation.resource_id]))
            item["updated_at"] = datetime.now(timezone.utc).isoformat()
            break
    save_emergency_requests(emergency_rows)

    return {"message": "Resource allocated successfully.", "allocation": row, "available_quantity": selected["available_quantity"]}
