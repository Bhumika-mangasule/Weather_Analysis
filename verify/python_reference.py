r"""
python_reference.py  -  INDEPENDENT CHECK of the R analysis
=============================================================
This script repeats the same analysis as R/main_analysis.R using Python
(pandas + numpy). It has two jobs:

1. Cross-check: run it with  --out verify/python_output  and compare the files
   with the ones R created in results/.  If the numbers match, the R code is
   correct (two different tools -> same answer).
2. Fallback: run it with  --out results  to create the JSON files without R.
   (The JSON will say "generated_by": "Python reference script".)

Usage (from the project folder):
    python verify\python_reference.py --out verify\python_output
"""
import argparse, json, math, os, datetime
import numpy as np
import pandas as pd

parser = argparse.ArgumentParser()
parser.add_argument("--data", default="weather_data/weather.csv")
parser.add_argument("--out", default="verify/python_output")
args = parser.parse_args()
os.makedirs(args.out, exist_ok=True)

# ---------- 1. LOAD ----------
raw = pd.read_csv(args.data, encoding="utf-8-sig")
rows_raw = len(raw)
missing_raw = raw.isna().sum()
duplicates = int(raw.duplicated().sum())

# ---------- 2. CLEAN ----------
df = raw.drop_duplicates().copy()
df["Formatted Date"] = pd.to_datetime(df["Formatted Date"].str[:19])  # local clock time
df = df.sort_values("Formatted Date").reset_index(drop=True)
df["Year"] = df["Formatted Date"].dt.year
df["Month"] = df["Formatted Date"].dt.month

zero_humidity = int((df["Humidity"] == 0).sum())
zero_pressure = int((df["Pressure (millibars)"] == 0).sum())
df.loc[df["Humidity"] == 0, "Humidity"] = np.nan
df.loc[df["Pressure (millibars)"] == 0, "Pressure (millibars)"] = np.nan
precip_filled = int(df["Precip Type"].isna().sum())
df["Precip Type"] = df["Precip Type"].fillna("unknown")

out = df.copy()
out["Formatted Date"] = out["Formatted Date"].dt.strftime("%Y-%m-%d %H:%M:%S")
out.to_csv(os.path.join(args.out, "weather_cleaned.csv"), index=False)

# ---------- 3. STATISTICS ----------
stat_vars = {  # column : digits used when finding the mode
    "Temperature (C)": 1, "Apparent Temperature (C)": 1, "Humidity": 2,
    "Wind Speed (km/h)": 1, "Wind Bearing (degrees)": 0,
    "Visibility (km)": 1, "Pressure (millibars)": 1,
}

def get_mode(x, digits):
    x = x.dropna().round(digits)
    counts = {}
    for v in x:                       # first-appearance order, like R's unique()
        counts[v] = counts.get(v, 0) + 1
    best = max(counts.values())
    for v, c in counts.items():
        if c == best:
            return float(v)

r = lambda v, d=4: None if (v is None or (isinstance(v, float) and math.isnan(v))) else round(float(v), d)

statistics = []
for col, dg in stat_vars.items():
    x = df[col]
    statistics.append({
        "variable": col, "n": int(x.notna().sum()),
        "mean": r(x.mean()), "median": r(x.median()), "mode": r(get_mode(x, dg)),
        "sd": r(x.std()), "variance": r(x.var()), "min": r(x.min()), "max": r(x.max()),
    })

corr = df[list(stat_vars)].corr(min_periods=1)
corr_out = {"variables": list(stat_vars),
            "matrix": [[r(v, 3) for v in row] for row in corr.values]}

# ---------- 4. CHART DATA ----------
temp = df["Temperature (C)"]
lo, hi = math.floor(temp.min() / 2) * 2, math.ceil(temp.max() / 2) * 2
breaks = np.arange(lo, hi + 2, 2)
counts, _ = np.histogram(temp, bins=breaks)      # [a,b) and last bin closed
hist_labels = [f"{int(breaks[i])} to {int(breaks[i+1])}" for i in range(len(counts))]

df["YearMonth"] = df["Formatted Date"].dt.strftime("%Y-%m")
monthly = df.groupby("YearMonth")["Temperature (C)"].mean()

month_names = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
seasonal = df.groupby("Month").agg(t=("Temperature (C)", "mean"), h=("Humidity", "mean"))

cond = (df.groupby("Summary").agg(n=("Summary", "size"), t=("Temperature (C)", "mean"),
                                  h=("Humidity", "mean"))
          .sort_values("n", ascending=False, kind="stable").head(10))
prec = (df.groupby("Precip Type").agg(n=("Precip Type", "size"), t=("Temperature (C)", "mean"),
                                      h=("Humidity", "mean"), w=("Wind Speed (km/h)", "mean"))
          .sort_values("n", ascending=False, kind="stable"))

samp = df.iloc[::60]
samp = samp[samp["Humidity"].notna()]

chart_data = {
    "generated_by": "Python reference script (pandas)",
    "temperature_histogram": {"labels": hist_labels, "counts": [int(c) for c in counts]},
    "monthly_temperature": {"labels": list(monthly.index), "values": [r(v) for v in monthly.values]},
    "seasonal_pattern": {"labels": month_names,
                         "avg_temperature": [r(v) for v in seasonal["t"]],
                         "avg_humidity": [r(v) for v in seasonal["h"]]},
    "weather_conditions": {"labels": list(cond.index), "counts": [int(v) for v in cond["n"]],
                           "avg_temperature": [r(v) for v in cond["t"]],
                           "avg_humidity": [r(v) for v in cond["h"]]},
    "precipitation_types": {"labels": list(prec.index), "counts": [int(v) for v in prec["n"]],
                            "avg_temperature": [r(v) for v in prec["t"]],
                            "avg_humidity": [r(v) for v in prec["h"]],
                            "avg_wind_speed": [r(v) for v in prec["w"]]},
    "temp_vs_humidity": {"note": "Every 60th hourly record (about 1,600 points) so the chart stays fast.",
                         "temperature": [r(v, 2) for v in samp["Temperature (C)"]],
                         "humidity": [r(v, 2) for v in samp["Humidity"]]},
    "rainfall_available": False,
}

# ---------- 5. FINDINGS (text built from the real numbers) ----------
st = {s["variable"]: s for s in statistics}
T, H, W = st["Temperature (C)"], st["Humidity"], st["Wind Speed (km/h)"]
first_date, last_date = df["Formatted Date"].min(), df["Formatted Date"].max()
hot_i, cold_i = seasonal["t"].idxmax(), seasonal["t"].idxmin()
yearly = df.groupby("Year")["Temperature (C)"].mean()

pairs = []
vs = list(stat_vars)
for i in range(len(vs)):
    for j in range(i + 1, len(vs)):
        if {vs[i], vs[j]} == {"Temperature (C)", "Apparent Temperature (C)"}:
            continue  # these two are almost the same thing, not an interesting finding
        pairs.append((vs[i], vs[j], corr.iloc[i, j]))
pairs.sort(key=lambda p: -abs(p[2]))
tc = corr.loc["Temperature (C)", "Humidity"]
top_cond = cond.index[0]
share = 100 * cond["n"].iloc[0] / len(df)
rain_n = int(prec.loc["rain", "n"]); snow_n = int(prec.loc["snow", "n"])

def strength(c):
    a = abs(c)
    return "strong" if a >= 0.7 else "moderate" if a >= 0.4 else "weak"

findings = [
    f"The cleaned dataset has {len(df):,} hourly records from {first_date:%d %b %Y} to {last_date:%d %b %Y}.",
    f"Temperature averages {T['mean']:.2f} C (median {T['median']:.2f} C) and ranges from {T['min']:.1f} C to {T['max']:.1f} C. "
    f"The standard deviation is {T['sd']:.2f} C, so temperatures vary a lot through the year.",
    f"{month_names[hot_i-1]} is the hottest month on average ({seasonal['t'][hot_i]:.1f} C) and "
    f"{month_names[cold_i-1]} is the coldest ({seasonal['t'][cold_i]:.1f} C).",
    f"Temperature and humidity have a {strength(tc)} {'negative' if tc < 0 else 'positive'} correlation (r = {tc:.2f}): "
    f"{'warmer hours tend to be drier' if tc < 0 else 'warmer hours tend to be more humid'}.",
    f"The strongest relationship (ignoring Temperature vs Apparent Temperature) is {pairs[0][0]} vs {pairs[0][1]} (r = {pairs[0][2]:.2f}).",
    f"'{top_cond}' is the most common weather condition ({share:.1f}% of all records).",
    f"Rain is recorded in {rain_n:,} hours and snow in {snow_n:,} hours. Average temperature is "
    f"{prec.loc['rain','t']:.1f} C during rain and {prec.loc['snow','t']:.1f} C during snow.",
    f"The warmest year on average was {int(yearly.idxmax())} ({yearly.max():.2f} C) and the coolest was {int(yearly.idxmin())} ({yearly.min():.2f} C).",
    f"Data quality: {zero_pressure:,} pressure readings and {zero_humidity:,} humidity readings were exactly 0, which is physically "
    f"impossible, so they were treated as sensor errors and set to missing before calculating statistics.",
    "The dataset has no rainfall-amount column, so total rainfall cannot be calculated. "
    "Only the precipitation type (rain / snow) is available.",
]

# ---------- 6. SUMMARY JSON ----------
def miss_row(col, zeros, note):
    return {"column": col, "missing_in_raw_file": int(missing_raw[col]), "invalid_zeros_found": zeros,
            "missing_after_cleaning": int(df[col].isna().sum()), "treatment": note}

missing_rows = []
for col in raw.columns:
    if col == "Humidity":
        missing_rows.append(miss_row(col, zero_humidity, "Zeros are impossible humidity values -> set to missing (NA)"))
    elif col == "Pressure (millibars)":
        missing_rows.append(miss_row(col, zero_pressure, "Zeros are impossible pressure values -> set to missing (NA)"))
    elif col == "Precip Type":
        missing_rows.append({"column": col, "missing_in_raw_file": int(missing_raw[col]), "invalid_zeros_found": 0,
                             "missing_after_cleaning": 0, "treatment": "Missing precipitation type -> filled with 'unknown'"})
    elif col == "Loud Cover":
        missing_rows.append(miss_row(col, 0, "Every value is 0 (no information) -> kept in file, excluded from statistics"))
    else:
        missing_rows.append(miss_row(col, 0, "No problem found"))

summary = {
    "generated_by": "Python reference script (pandas)",
    "generated_at": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "dataset": {"file": "weather_data/weather.csv", "rows_raw": rows_raw, "rows_clean": len(df),
                "duplicates_removed": duplicates, "columns": raw.shape[1], "column_names": list(raw.columns),
                "date_start": f"{first_date:%Y-%m-%d}", "date_end": f"{last_date:%Y-%m-%d}",
                "rainfall_available": False},
    "cards": {"avg_temperature": T["mean"], "max_temperature": T["max"], "min_temperature": T["min"],
              "avg_humidity": H["mean"], "avg_wind_speed": W["mean"], "total_rainfall": None,
              "total_records": len(df)},
    "missing_values": missing_rows,
    "statistics": statistics,
    "correlations": corr_out,
    "findings": findings,
}

preview = out.drop(columns=["Year", "Month"]).head(200).round(2)
preview_rows = json.loads(preview.to_json(orient="records"))

for name, obj in [("summary.json", summary), ("chart_data.json", chart_data),
                  ("preview.json", {"columns": list(preview.columns), "rows": preview_rows})]:
    with open(os.path.join(args.out, name), "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=2, ensure_ascii=False)
print("Done. Files written to", args.out)
