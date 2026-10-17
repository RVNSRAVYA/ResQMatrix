# ResQMatrix: Intelligent Emergency Prioritization and Resource Allocation Framework

ResQMatrix is a Flutter + FastAPI project that helps response coordinators review emergencies, rank them by urgency, find verified resources, allocate them, and estimate flood risk with a machine-learning model trained on **11,665 dated historical-style records (2000–2025) from 30 monitoring stations**.

## Quick start

**Windows (one click):** extract to a folder such as `C:\Projects\ResQMatrix`, then double-click `run_all.bat`.
It creates the Python environment on first run, starts the API in its own window and launches the app in Chrome.

**macOS / Linux:** `./run_all.sh`

**Manual steps**
1. `setup_backend.bat` (or `./setup_backend.sh`) – first run only, installs Python packages.
2. `run_backend.bat` (or `./run_backend.sh`) – API at http://127.0.0.1:8000 (docs at `/docs`, status at `/health`).
3. In a second terminal: `cd mobile`, `flutter pub get`, `flutter run -d chrome`.

Android emulator uses `http://10.0.2.2:8000` automatically. For a physical phone on the same Wi-Fi:
`flutter run --dart-define=API_BASE_URL=http://<your-pc-ip>:8000` (or `run_flutter_phone.bat <ip>`).

Requirements: Python 3.11+, Flutter SDK, Chrome (web) / Android Studio (Android). The API retrains its model automatically at startup if the saved model file cannot be loaded (for example after a scikit-learn version change).

## What's new in this version

### Redesigned interface
- New shared design system (`mobile/lib/theme`, `mobile/lib/widgets`): consistent navy/teal palette, rounded cards, soft shadows, refined inputs, buttons, chips and page transitions across **every** screen.
- **Command-center dashboard**: dark sidebar navigation on desktop (grouped Operations / Intelligence / Network), responsive card layout on phones, live KPI cards, hero banner with a model-accuracy ring, hover effects, and a model-insights panel (records, coverage, stations, precision, recall, F1).
- **Flood Risk Intelligence**: one-tap quick scenarios, grouped inputs, side-by-side result panel with probability gauge and a Low → Critical risk scale.
- **Flood Risk Atlas**: station markers sized by risk, risk-band filter chips, ranked station list, and a detail sheet with the station's historical flood rate and event counts.

### Historical dataset and model
- `ml/flood_risk_dataset_india.csv` now holds **11,665 dated records** (2000-01-01 → 2025-12-31) for 30 stations (city, state, river basin) with 14 model inputs, including a 3-day cumulative rainfall feature and a "frequent recent floods" flag computed from the previous year's station history. Monsoon (Jun–Sep) concentrates heavy rain and flood events.
- Model: Logistic Regression with imputation, scaling and one-hot encoding.
- **Evaluation is chronological**: trained on 2000–2019, tested on 2020–2025 (records the model never saw).

| Evaluation | Accuracy |
|---|---|
| Chronological hold-out (2020–2025, 2,713 records) | **85.77%** (precision 86.9%, recall 75.7%, F1 80.9%, ROC-AUC 0.926) |
| Stratified random 80/20 split | 85.73% |
| 5-fold CV on training years | 85.13% ± 1.40 |

Reproduce: `python ml/generate_historical_dataset.py` then `python ml/train_model.py` (or `train_model.bat` / `./train_model.sh`). The seed is fixed, so results are repeatable.

## Important: about the dataset and the accuracy figure
The bundled records are **simulated historical-style data, not official observations**. They were generated without access to IMD / India-WRIS / CWC / NDMA archives, using realistic station traits, monsoon seasonality, rolling features and deliberate label noise (unobserved factors such as dam releases and local drainage). The ~85% figure therefore describes how well the model learns *this* dataset and must not be quoted as real-world flood-forecast accuracy.

**To use real historical data:** export or assemble a CSV with the same columns (see `ml/inspect_dataset.py` for the required list: Date, Latitude, Longitude, Rainfall (mm), Rainfall 3-Day (mm), Temperature (°C), Humidity (%), River Discharge (m³/s), Water Level (m), Elevation (m), Land Cover, Soil Type, Population Density, Infrastructure, Historical Floods, Flood Occurred; optional Station, State, River). Save it as `ml/flood_risk_dataset_india.csv`, run `python ml/inspect_dataset.py`, then `python ml/train_model.py`. Whatever accuracy you then obtain is your real, honest result.

## Feature overview
- **Priority triage** – explainable 0–100 score from urgency, people affected, category, waiting time and status; Critical/High/Moderate/Low queue with reasons.
- **Resource allocation** – only verified, in-stock, category-compatible resources; ranked by compatibility, stock, priority and optional straight-line distance; validated allocation updates inventory and request status.
- **Emergency requests** with GPS coordinates; **Weather monitor** (Open-Meteo); **Resource directory**; **Organization portal** (resources and donations, new items start *Pending*); **Administrator console** (status updates and resource verification).

## API routes
`GET /health`, `GET /model-info`, `GET /risk-areas`, `POST /predict` (`rainfall_3day` optional; defaults to 1.6 × rainfall), `GET/POST /emergency-requests`, `PATCH /emergency-requests/{id}/status`, `GET /triage`, `GET/POST /resources`, `PATCH /resources/{id}/verification`, `GET/POST /donations`, `GET /allocations`, `GET /allocations/recommendations/{request_id}`, `POST /allocations`. Interactive reference: `/docs`.

## Limitations
- Triage scores are an explainable heuristic for human review, not a validated triage model.
- Distance is straight-line, not road routing.
- Organization/Admin screens have no login; API endpoints are unprotected. Add authentication before any real deployment.
- Requests, resources, donations and allocations are stored in local JSON files (demo only; use a database for deployment).
- Flood predictions and map risk levels are demonstrations, not official warnings.

## Project structure
- `mobile/` – Flutter app (`lib/theme`, `lib/widgets`, `lib/screens`, `lib/services`)
- `backend/` – FastAPI app, model, dataset copy, JSON demo data
- `ml/` – dataset generator, training script, dataset inspector, model artifacts
- `run_all.*`, `setup_backend.*`, `run_backend.*`, `train_model.*`, `run_flutter_*.bat` – helper scripts


## Quick validation (Windows)

1. Run `setup_backend.bat` once.
2. Run `test_backend.bat` to smoke-test the API endpoints and prediction route. The test restores the JSON demo stores after it runs.
3. Run `run_backend.bat` to start the API at `http://127.0.0.1:8000`; open `/docs` to inspect the endpoints.
4. In a second terminal, run `cd mobile`, `flutter pub get`, and `flutter run -d chrome`.

If Windows reports that plugins require symlink support, open Developer settings with `start ms-settings:developers` and enable Developer Mode. This is a Windows setup requirement, not a Dart source-code error.

### Accuracy and dataset disclosure

The bundled `flood_risk_dataset_india.csv` is **simulated historical-style data**, not verified official flood observations. Its reported test accuracy must not be presented as real-world flood prediction accuracy. Real-world performance requires a validated dataset of actual observations and reliable event labels.
