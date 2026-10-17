# ResQMatrix – What's new

## Interface redesign
- Shared design system (theme + reusable widgets) applied app-wide.
- Dashboard rebuilt as a command center: sidebar on desktop, model-accuracy hero, KPI cards, workspace cards with hover effects, model-insights panel.
- Flood Risk Intelligence: quick scenarios, grouped inputs, probability gauge and risk scale.
- Flood Risk Atlas: station markers, risk filters, ranked station list, per-station history sheet.

## Historical dataset + model
- Synthetic random dataset replaced by 11,665 dated station records (2000–2025, 30 stations) with rolling-rainfall and prior-year flood-history features.
- Chronological evaluation (train ≤2019, test 2020–2025): **85.77% accuracy**; stratified split 85.73%; 5-fold CV 85.13%.
- Backend: new `rainfall_3day` input, station-level `/risk-areas`, richer `/model-info`, automatic retrain if the saved model is incompatible.
- Records are simulated historical-style data; swap in real archive data using the steps in README.md.

## Convenience
- `run_all.bat` / `run_all.sh` one-click start; `train_model.*` to regenerate data and retrain.
