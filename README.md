# Weather Data Analysis and Visualization System Using R and Web Technologies

R cleans and analyses an hourly weather dataset (2006–2016) and exports the results as JSON.
A simple HTML/CSS/JavaScript dashboard (with Chart.js) reads those JSON files and shows cards, tables and charts.

## 1. Project structure

```
Weather_Analysis_Project/
├── weather_data/
│   ├── weather.csv            <- the dataset used by all scripts
│   └── weather.csv.csv        <- same data re-saved with different number formatting (unchanged, not used)
├── R/
│   ├── main_analysis.R        <- RUN THIS (load, clean, analyse, export)
│   ├── data_cleaning.R        <- loading + cleaning functions
│   ├── visualization.R        <- ggplot2 plots -> plots/
│   └── weather_analysis.R     <- your ORIGINAL script (3 small fixes, see section 7)
├── frontend/
│   ├── index.html  style.css  script.js
├── results/
│   ├── summary.json           <- cards, statistics, missing values, correlations, findings
│   ├── chart_data.json        <- data for the 6 charts
│   ├── preview.json           <- first 200 rows for the table
│   ├── weather_cleaned.csv    <- cleaned dataset
│   └── weather_dataset.csv, weather_statistics.csv   <- outputs of your original script
├── plots/                     <- PNG plots
├── verify/
│   ├── python_reference.py    <- independent Python check of the R results
│   └── compare_results.py     <- compares R output with the Python check
├── docs/                      <- flowchart.png, screenshots, VIVA.md
├── run_analysis.bat           <- double-click: runs the R analysis
└── start_dashboard.bat        <- double-click: starts the dashboard
```

## 2. What your project had, and what was added

| Item | Before | Now |
|---|---|---|
| Load, head, dim, names, str, missing values, duplicates | done | kept (`main_analysis.R` prints them) |
| Mean, median, variance, SD, correlations, 6 base-R plots | done | extended: **mode, min, max** for 7 variables |
| Cleaning | not done | duplicates, date conversion, impossible zeros, missing precipitation type |
| Date conversion | partly (only inside a plot) | proper date-time column + sorting |
| JSON export | missing | `summary.json`, `chart_data.json`, `preview.json` |
| Frontend | missing | dashboard, analysis tables, 6 Chart.js charts, About |
| Bug in `weather_analysis.R` | a stray `)` near the end stopped the script from running | fixed |

## 3. Important facts about the dataset

* **No rainfall amount column.** There is only `Precip Type` (rain/snow). So the *Total Rainfall* card says "Not available" and chart 5 compares precipitation **types**. No rainfall number is invented.
* **1,288 pressure values and 22 humidity values are exactly 0.** That is impossible, so they are set to missing (NA) before calculating statistics. This is why the pressure standard deviation in your old `weather_statistics.csv` (116.97) was wrong; after cleaning it is about 7.78.
* 24 duplicate rows were removed; 517 missing `Precip Type` values were filled with `"unknown"`.
* `Loud Cover` is 0 in every row, so it is left out of the statistics.
* The CSV is not in date order, so the cleaning step sorts it.

## 4. Installation (Windows)

1. Install **R** (https://cran.r-project.org) and add it to PATH, e.g. `C:\Program Files\R\R-4.4.1\bin`.
   Check in Command Prompt: `Rscript --version`
2. Install **Python 3** (only used to start a tiny local web server, and for the optional check).
3. Packages install automatically the first time you run the analysis (readr, dplyr, lubridate, ggplot2, jsonlite). Internet is needed once.

## 5. Run everything

Open **Command Prompt** and replace the path with where you unzipped the project:

```bat
cd /d C:\Users\YourName\Desktop\Weather_Analysis_Project

:: Step 1 - run the R analysis (creates results\*.json, results\weather_cleaned.csv, plots\*.png)
Rscript R\main_analysis.R

:: Step 2 - start the dashboard
python -m http.server 8000
```

Then open **http://localhost:8000/frontend/index.html** in Chrome or Edge.
(Shortcut: double-click `run_analysis.bat`, then `start_dashboard.bat`.)

**Why a server?** Browsers block JavaScript from reading files when a page is opened by double-clicking it (`file://`). `python -m http.server` is the simplest fix. Flask is **not** needed: the frontend only reads static JSON files, so no backend logic is required.

**RStudio users:** open `R/main_analysis.R`, run `setwd("C:/path/to/Weather_Analysis_Project")` in the console, then click Source.

**Chart.js offline:** the page loads Chart.js from the internet (jsDelivr). For offline use, download https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js and save it as `frontend\lib\chart.umd.min.js`. The page uses it automatically if the internet copy fails.

## 6. How R is connected to the frontend

```
weather.csv -> R (clean, analyse) -> results/*.json -> script.js (fetch) -> cards, tables, Chart.js
```
Every number on the page comes from the JSON files. If a file is missing, the page shows an error message telling you what to do.

## 7. Changes to your original `R/weather_analysis.R`

Only three things were changed: (1) removed the stray `)` and the loose code after the completion message, which made the file impossible to run; (2) it now reads `weather_data/weather.csv` automatically and only opens `file.choose()` if that file is not found; (3) `View()` only runs in interactive sessions so `Rscript` does not fail. The rest is untouched. `main_analysis.R` is the new, complete version.

## 8. Testing status (please read)

Done in my environment:
* The Python check script ran on the real dataset and produced `results/*.json` (so the dashboard has real values).
* The dashboard was opened in headless Chromium at desktop (1366 px) and mobile (390 px) widths: cards match `summary.json`, tables/search/column filter work, no horizontal scrolling, no JavaScript errors, and the error message appears when files cannot be loaded.
* The data passed to each of the 6 charts was checked against the JSON files (using a stand-in for Chart.js).

**NOT done (could not be done where I worked):**
* **The R scripts were not executed** — R was not available. They are written carefully but are untested; if R prints an error, send me the message and I will fix it.
* **Chart.js drawing was not seen** — there was no internet, so I could not view the rendered charts, and the screenshots in `docs/screenshots/` show the page without charts.
* **The `results/*.json` currently in the folder came from the Python script** (the dashboard footer says "Python reference script"). Run `Rscript R\main_analysis.R` and the footer will change to your R version, proving the dashboard now shows R's output.

To confirm R and Python agree:
```bat
python verify\python_reference.py --out verify\python_output
python verify\compare_results.py
```
It prints `OK` or lists the differences.

## 9. Plots

`main_analysis.R` writes (ggplot2): `histogram.png`, `line_graph.png`, `scatter_plot.png`, `box_plot.png`, `bar_chart.png` (now top-10 weather conditions), `seasonal_pattern.png`, `correlation_heatmap.png`. These replace your earlier base-R versions of the same names; `pie_chart.png` is your old one and is left as is.

## 10. Troubleshooting

| Problem | Fix |
|---|---|
| `'Rscript' is not recognized` | Add R's `bin` folder to PATH, or run with the full path: `"C:\Program Files\R\R-4.4.1\bin\Rscript.exe" R\main_analysis.R` |
| Page says "Could not load the analysis results" | Run the R step first and open the page through `http://localhost:8000`, not by double-clicking |
| Charts area says Chart.js could not be loaded | Connect to the internet, or add `frontend\lib\chart.umd.min.js` (section 5) |
| Port 8000 busy | Use `python -m http.server 8080` and open `localhost:8080` |
