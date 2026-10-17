"""Validate and summarise the flood dataset (works for the bundled simulated data or a real archive export)."""
from pathlib import Path
import sys
import pandas as pd

REQUIRED = [
    "Date", "Latitude", "Longitude", "Rainfall (mm)", "Rainfall 3-Day (mm)", "Temperature (°C)",
    "Humidity (%)", "River Discharge (m³/s)", "Water Level (m)", "Elevation (m)", "Land Cover",
    "Soil Type", "Population Density", "Infrastructure", "Historical Floods", "Flood Occurred",
]
OPTIONAL = ["Station", "State", "River"]

path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / "flood_risk_dataset_india.csv"
df = pd.read_csv(path)
print("Dataset:", path.name)
print("Records:", f"{len(df):,}", "(need >= 10,000)" if len(df) < 10_000 else "(OK, >= 10,000)")
missing = [c for c in REQUIRED if c not in df.columns]
print("Missing required columns:", missing or "none")
print("Optional columns present:", [c for c in OPTIONAL if c in df.columns])
if "Date" in df.columns:
    dates = pd.to_datetime(df["Date"], errors="coerce")
    print("Date range:", dates.min().date(), "->", dates.max().date(), "| unparseable dates:", int(dates.isna().sum()))
print("\nMissing values per column:")
nulls = df.isna().sum()
print(nulls[nulls > 0].to_string() if (nulls > 0).any() else "none")
if "Flood Occurred" in df.columns:
    print("\nTarget distribution (0 = no flood, 1 = flood):")
    print(df["Flood Occurred"].value_counts().sort_index().to_string())
print("\nNote: the bundled file is simulated historical-style data, not official observed flood records.")
