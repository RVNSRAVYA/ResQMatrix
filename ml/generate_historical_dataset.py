"""Generate a dated, station-wise HISTORICAL-STYLE flood record dataset (2000-2025).

IMPORTANT - READ THIS
---------------------
This file creates *simulated* historical records. It was produced without access
to government archives (IMD / India-WRIS / CWC / NDMA), so the rows are NOT
observed measurements. The structure mimics what a real archive looks like:

  * a fixed set of monitoring stations (cities / river basins across India),
  * one dated observation per station per sampled day between 2000 and 2025,
  * monsoon-season (Jun-Sep) concentration of heavy rain and floods,
  * station-level traits (elevation, soil, land cover, flood history),
  * rolling features (previous-3-day rainfall, station flood count in the
    previous year) computed in chronological order,
  * noisy labels, so a model cannot reach 100% accuracy.

To use REAL data, replace `flood_risk_dataset_india.csv` with a file that has the
same column names (see COLUMNS in train_model.py) and re-run train_model.py.

Run:  python ml/generate_historical_dataset.py
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "flood_risk_dataset_india.csv"
SEED = 20261017
N_TARGET = 12_000                      # >= 10,000 records
START, END = "2000-01-01", "2025-12-31"
rng = np.random.default_rng(SEED)

# (station, state, lat, lon, elevation_m, river, annual-rain factor, soil, land cover, pop density)
STATIONS = [
    ("Guwahati", "Assam", 26.14, 91.74, 55, "Brahmaputra", 1.45, "Clay", "Urban", 5200),
    ("Dibrugarh", "Assam", 27.48, 94.91, 105, "Brahmaputra", 1.50, "Silt", "Agricultural", 1100),
    ("Patna", "Bihar", 25.59, 85.14, 53, "Ganga", 1.10, "Silt", "Urban", 1800),
    ("Darbhanga", "Bihar", 26.15, 85.90, 52, "Kamla Balan", 1.15, "Silt", "Agricultural", 1500),
    ("Kolkata", "West Bengal", 22.57, 88.36, 9, "Hooghly", 1.25, "Clay", "Urban", 24000),
    ("Bhubaneswar", "Odisha", 20.30, 85.82, 45, "Mahanadi", 1.10, "Loam", "Urban", 2000),
    ("Cuttack", "Odisha", 20.46, 85.88, 36, "Mahanadi", 1.15, "Silt", "Urban", 1900),
    ("Visakhapatnam", "Andhra Pradesh", 17.69, 83.22, 5, "Godavari", 1.00, "Sandy", "Urban", 3000),
    ("Vijayawada", "Andhra Pradesh", 16.51, 80.65, 11, "Krishna", 1.00, "Clay", "Urban", 3900),
    ("Rajahmundry", "Andhra Pradesh", 17.00, 81.80, 14, "Godavari", 1.05, "Clay", "Agricultural", 1300),
    ("Hyderabad", "Telangana", 17.39, 78.49, 505, "Musi", 0.75, "Loam", "Urban", 18000),
    ("Chennai", "Tamil Nadu", 13.08, 80.27, 6, "Adyar", 0.95, "Sandy", "Urban", 26000),
    ("Kochi", "Kerala", 9.93, 76.27, 3, "Periyar", 1.55, "Peat", "Urban", 6300),
    ("Alappuzha", "Kerala", 9.49, 76.33, 1, "Pamba", 1.55, "Peat", "Water Body", 1500),
    ("Mangaluru", "Karnataka", 12.91, 74.86, 22, "Netravati", 1.60, "Sandy", "Urban", 2300),
    ("Mumbai", "Maharashtra", 19.08, 72.88, 14, "Mithi", 1.35, "Sandy", "Urban", 21000),
    ("Pune", "Maharashtra", 18.52, 73.86, 560, "Mula-Mutha", 0.85, "Loam", "Urban", 6000),
    ("Surat", "Gujarat", 21.17, 72.83, 13, "Tapi", 1.05, "Silt", "Urban", 13000),
    ("Ahmedabad", "Gujarat", 23.02, 72.57, 53, "Sabarmati", 0.70, "Loam", "Urban", 12000),
    ("Lucknow", "Uttar Pradesh", 26.85, 80.95, 123, "Gomti", 0.90, "Loam", "Urban", 1800),
    ("Varanasi", "Uttar Pradesh", 25.32, 82.97, 80, "Ganga", 0.95, "Silt", "Urban", 2400),
    ("Gorakhpur", "Uttar Pradesh", 26.76, 83.37, 77, "Rapti", 1.05, "Silt", "Agricultural", 1500),
    ("Delhi", "Delhi", 28.61, 77.21, 216, "Yamuna", 0.70, "Loam", "Urban", 11000),
    ("Dehradun", "Uttarakhand", 30.32, 78.03, 640, "Rispana", 1.20, "Loam", "Forest", 550),
    ("Srinagar", "Jammu & Kashmir", 34.08, 74.80, 1585, "Jhelum", 0.65, "Loam", "Urban", 400),
    ("Shimla", "Himachal Pradesh", 31.10, 77.17, 2200, "Sutlej", 0.90, "Loam", "Forest", 250),
    ("Jaipur", "Rajasthan", 26.91, 75.79, 431, "Dhund", 0.45, "Sandy", "Urban", 600),
    ("Bhopal", "Madhya Pradesh", 23.26, 77.41, 527, "Betwa", 0.80, "Loam", "Urban", 855),
    ("Raipur", "Chhattisgarh", 21.25, 81.63, 298, "Mahanadi", 0.90, "Loam", "Agricultural", 1000),
    ("Ranchi", "Jharkhand", 23.34, 85.31, 651, "Subarnarekha", 0.95, "Loam", "Grassland", 450),
]
N_ST = len(STATIONS)
SOIL_RISK = {"Clay": 0.90, "Silt": 0.80, "Peat": 0.75, "Loam": 0.50, "Sandy": 0.25}
LAND_RISK = {"Water Body": 1.0, "Urban": 0.75, "Agricultural": 0.60, "Grassland": 0.40, "Forest": 0.25}

# Monthly rainfall seasonality (India: strong Jun-Sep monsoon, Oct-Nov NE monsoon in the south-east).
MONTH_RAIN = np.array([0.05, 0.05, 0.07, 0.10, 0.18, 0.55, 1.10, 1.05, 0.80, 0.30, 0.15, 0.07])

# Sample dates, with heavier sampling in monsoon months (as archives usually emphasise flood season).
all_days = pd.date_range(START, END, freq="D")
month_w = np.array([0.6, 0.6, 0.6, 0.7, 0.9, 1.5, 2.2, 2.2, 1.8, 1.1, 0.8, 0.6])
day_w = month_w[all_days.month - 1]
day_w = day_w / day_w.sum()
dates = all_days[rng.choice(len(all_days), N_TARGET, p=day_w)]
station_idx = rng.integers(0, N_ST, N_TARGET)

df = pd.DataFrame({"Date": dates, "sid": station_idx}).sort_values(["Date", "sid"]).reset_index(drop=True)
df = df.drop_duplicates(["Date", "sid"]).reset_index(drop=True)
n = len(df)

st = pd.DataFrame(STATIONS, columns=["Station", "State", "lat", "lon", "elev", "River", "rf", "Soil", "Land", "pop"])
s = st.loc[df["sid"].to_numpy()].reset_index(drop=True)
month = df["Date"].dt.month.to_numpy()
year = df["Date"].dt.year.to_numpy()

# ---------------------------------------------------------------- weather / hydrology
season = MONTH_RAIN[month - 1]
rain = rng.gamma(shape=0.9 + 1.3 * season, scale=(14 + 32 * s["rf"].to_numpy()) * (0.6 + season), size=n)
rain = np.clip(rain, 0, 420)
# slow climate trend + year-to-year variability
year_eff = rng.normal(0, 0.12, size=int(year.max()) + 1)[year] if False else 0
rain *= 1 + 0.004 * (year - 2000)

# previous-3-day cumulative rainfall (correlated with today's rain)
rain_3d = np.clip(rain * rng.uniform(0.9, 2.6, n) * (0.6 + 0.5 * season), 0, 900)

temperature = np.clip(
    30 + 6 * np.sin((month - 3) / 12 * 2 * np.pi) - 5.5 * season - (s["elev"].to_numpy() / 280)
    + rng.normal(0, 2.4, n), 2, 46)
humidity = np.clip(52 + 34 * season + 0.10 * np.sqrt(rain) * 8 + rng.normal(0, 7, n), 18, 100)

base_discharge = 180 + 480 * s["rf"].to_numpy()
river_discharge = np.clip(
    base_discharge * (0.35 + 2.2 * season) + 7.5 * rain_3d + rng.normal(0, 260, n), 5, 6500)
water_level = np.clip(
    1.2 + 0.0011 * river_discharge + 0.006 * rain_3d - 0.0009 * s["elev"].to_numpy()
    + rng.normal(0, 0.75, n), 0.1, 13.0)
elevation = np.clip(s["elev"].to_numpy() + rng.normal(0, 3, n), 0.5, 2300)

pop = np.clip(s["pop"].to_numpy() * rng.uniform(0.85, 1.2, n), 50, 30000)
infra = (rng.random(n) < (0.30 + 0.45 * (pop > 2500))).astype(int)  # 1 = drainage / embankment present

# ---------------------------------------------------------------- chronological features
df["rain"] = rain
df["sid"] = df["sid"].to_numpy()
prev_year_floods = np.zeros(n, dtype=int)

# Latent flood propensity (hidden physical process). Flood = threshold crossing + noise.
rain_n = np.clip(rain / 250, 0, 1.4)
rain3_n = np.clip(rain_3d / 500, 0, 1.4)
dis_n = np.clip(river_discharge / 5000, 0, 1.3)
wl_n = np.clip(water_level / 10, 0, 1.3)
low_n = np.clip(1 - elevation / 700, 0, 1)
soil_r = s["Soil"].map(SOIL_RISK).to_numpy()
land_r = s["Land"].map(LAND_RISK).to_numpy()

latent = (
    1.35 * rain_n + 0.95 * rain3_n + 1.20 * dis_n + 1.10 * wl_n + 0.80 * low_n
    + 0.35 * soil_r + 0.30 * land_r - 0.25 * infra + 0.10 * np.clip(pop / 20000, 0, 1)
    + 0.30 * rain_n * dis_n
)
# Unobserved factors (dam releases, tide, local drainage blockage, data errors) -> irreducible noise.
latent += rng.normal(0, 1.1, n)
threshold = np.quantile(latent, 0.62)          # ~38% of records are flood events
flood = (latent > threshold).astype(int)

# station-level flood history feature: number of flood events at station in the PREVIOUS calendar year
df["flood"] = flood
yearly = df.groupby(["sid", df["Date"].dt.year])["flood"].sum().rename("n").reset_index()
yearly["Date"] = yearly["Date"] + 1
merged = df.assign(Y=df["Date"].dt.year).merge(
    yearly.rename(columns={"Date": "Y"}), on=["sid", "Y"], how="left")
prev_year_floods = merged["n"].fillna(0).to_numpy()
hist_flag = (prev_year_floods >= 3).astype(int)

out = pd.DataFrame({
    "Date": df["Date"].dt.strftime("%Y-%m-%d"),
    "Station": s["Station"],
    "State": s["State"],
    "River": s["River"],
    "Latitude": s["lat"].to_numpy() + rng.normal(0, 0.01, n),
    "Longitude": s["lon"].to_numpy() + rng.normal(0, 0.01, n),
    "Rainfall (mm)": rain,
    "Rainfall 3-Day (mm)": rain_3d,
    "Temperature (°C)": temperature,
    "Humidity (%)": humidity,
    "River Discharge (m³/s)": river_discharge,
    "Water Level (m)": water_level,
    "Elevation (m)": elevation,
    "Land Cover": s["Land"],
    "Soil Type": s["Soil"],
    "Population Density": pop,
    "Infrastructure": infra,
    "Historical Floods": hist_flag,
    "Flood Occurred": flood,
})
out.to_csv(OUT, index=False, float_format="%.4f")
print(f"Saved {len(out):,} historical-style records ({out['Date'].min()} -> {out['Date'].max()}) to {OUT}")
print("Stations:", out["Station"].nunique(), "| Flood rate:", round(out['Flood Occurred'].mean(), 3))
print("NOTE: simulated historical-style data; replace with real archive data for real-world claims.")
