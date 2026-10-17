"""Smoke-test the ResQMatrix API locally. Run: python test_backend.py"""
from pathlib import Path
import json
from fastapi.testclient import TestClient
import main

BASE = Path(__file__).resolve().parent
STATE_FILES = ["emergency_requests.json", "resources.json", "donations.json", "allocations.json"]
original = {name: (BASE / name).read_bytes() if (BASE / name).exists() else None for name in STATE_FILES}
checks = []

def check(name, response, expected=200):
    ok = response.status_code == expected
    checks.append((name, ok, response.status_code, response.text[:200]))
    if not ok:
        raise AssertionError(f"{name}: expected HTTP {expected}, got {response.status_code}: {response.text[:500]}")

try:
    with TestClient(main.app) as client:
        check("root", client.get("/"))
        check("health", client.get("/health"))
        check("model-info", client.get("/model-info"))
        check("risk-areas", client.get("/risk-areas?limit=5"))
        check("emergency-requests list", client.get("/emergency-requests"))
        check("resources list", client.get("/resources"))
        check("donations list", client.get("/donations"))
        check("allocations list", client.get("/allocations"))
        check("triage", client.get("/triage"))
        payload = {
            "latitude": 16.5062, "longitude": 80.6480, "rainfall": 100, "rainfall_3day": 180,
            "temperature": 28, "humidity": 85, "river_discharge": 500, "water_level": 4,
            "elevation": 20, "land_cover": "Urban", "soil_type": "Alluvial",
            "population_density": 3000, "infrastructure": 2, "historical_floods": 1
        }
        prediction = client.post("/predict", json=payload)
        check("flood prediction", prediction)
        assert "risk_level" in prediction.json() and "flood_probability_percent" in prediction.json()
        created = client.post("/emergency-requests", json={
            "emergency_type": "Medical", "urgency": "High", "people_count": 2,
            "description": "Automated smoke test", "latitude": 16.5062, "longitude": 80.6480
        }, follow_redirects=True)
        check("create emergency request", created, 201)
    print("\nBackend smoke tests passed:")
    for name, ok, code, _ in checks:
        print(f"  PASS  {name} (HTTP {code})")
except Exception as exc:
    print(f"\nBACKEND TEST FAILED: {exc}")
    raise
finally:
    for name, content in original.items():
        path = BASE / name
        if content is None:
            path.unlink(missing_ok=True)
        else:
            path.write_bytes(content)
