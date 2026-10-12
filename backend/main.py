from pathlib import Path
from datetime import datetime, timezone
import json
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
    version="1.0.0",
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
# Load trained ML model
# ---------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent

MODEL_PATH = BASE_DIR / "models" / "flood_risk_model.pkl"
METADATA_PATH = BASE_DIR / "models" / "model_metadata.json"

model = joblib.load(MODEL_PATH)


# Exact feature order used during ML training
FEATURES = [
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


# ---------------------------------------------------------
# Input schema
# ---------------------------------------------------------

class FloodPredictionRequest(BaseModel):
    temp: float
    humidity: float
    cloud_cover: float
    annual: float
    jan_feb: float
    mar_may: float
    jun_sep: float
    oct_dec: float
    avgjune: float
    sub: float


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
        "model": "XGBoost",
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
        "model": "XGBoost",
        "number_of_features": len(FEATURES),
    }


# ---------------------------------------------------------
# Model information endpoint
# ---------------------------------------------------------

@app.get("/model-info")
def model_info():
    return {
        "model": "XGBoost",
        "target": "flood",
        "classes": [0, 1],
        "features": FEATURES,
        "feature_count": len(FEATURES),
        "risk_levels": {
            "Low": "0.00 - 0.24",
            "Moderate": "0.25 - 0.49",
            "High": "0.50 - 0.74",
            "Critical": "0.75 - 1.00",
        },
        "note": (
            "Risk levels are application-defined probability bands. "
            "The original dataset target is binary: 0 = No Flood, 1 = Flood."
        ),
    }


# ---------------------------------------------------------
# Flood prediction endpoint
# ---------------------------------------------------------

@app.post("/predict")
def predict_flood(request: FloodPredictionRequest):

    try:
        # Create DataFrame using the exact feature names
        # and exact order used during model training.
        input_data = pd.DataFrame(
            [
                {
                    "Temp": request.temp,
                    "Humidity": request.humidity,
                    "Cloud Cover": request.cloud_cover,
                    "ANNUAL": request.annual,
                    "Jan-Feb": request.jan_feb,
                    "Mar-May": request.mar_may,
                    "Jun-Sep": request.jun_sep,
                    "Oct-Dec": request.oct_dec,
                    "avgjune": request.avgjune,
                    "sub": request.sub,
                }
            ],
            columns=FEATURES,
        )

        # Prediction: 0 = No Flood, 1 = Flood
        prediction = int(model.predict(input_data)[0])

        # Get probability for class 1 (Flood)
        probabilities = model.predict_proba(input_data)[0]

        class_list = list(model.classes_)

        if 1 not in class_list:
            raise ValueError("Model does not contain flood class 1.")

        flood_class_index = class_list.index(1)
        flood_probability = float(probabilities[flood_class_index])

        # Convert probability into application risk band
        risk_level = get_risk_level(flood_probability)

        return {
            "flood_occurred": prediction,
            "flood_label": "Flood" if prediction == 1 else "No Flood",
            "flood_probability": round(flood_probability, 4),
            "flood_probability_percent": round(flood_probability * 100, 2),
            "risk_level": risk_level,
            "model": "XGBoost",
            "disclaimer": (
                "This prediction is an AI/ML decision-support estimate "
                "and should not be treated as an official flood warning."
            ),
        }

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Prediction failed: {str(exc)}",
        )



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
    return {"count": len(rows), "resources": rows}

@app.post("/resources", status_code=201)
def create_resource(resource: ResourceCreate):
    if not resource.organization_name.strip() or not resource.name.strip() or not resource.location.strip():
        raise HTTPException(status_code=400, detail="Organization, resource name, and location are required.")
    if resource.quantity < 0:
        raise HTTPException(status_code=400, detail="Quantity cannot be negative.")
    row = {
        "resource_id": f"RES-{uuid.uuid4().hex[:8].upper()}",
        "organization_name": resource.organization_name.strip(),
        "name": resource.name.strip(),
        "resource_type": resource.resource_type.strip(),
        "quantity": resource.quantity,
        "location": resource.location.strip(),
        "contact": resource.contact.strip(),
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
