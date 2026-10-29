# Project Explanation for Presentation and Viva

## 30-second summary
"I analysed about 96,000 hourly weather records from 2006 to 2016 using R. I cleaned the data, calculated statistics and correlations, and exported the results as JSON. A web dashboard built with HTML, CSS, JavaScript and Chart.js reads those files and shows cards, tables and interactive charts."

## Flow
CSV -> R (load, clean, analyse) -> JSON files -> JavaScript -> dashboard. See `docs/flowchart.png`.

## What I did in R
1. **Loaded** the data with `readr` and looked at head, dimensions, structure.
2. **Checked quality:** 24 duplicate rows, 517 missing precipitation types, and 1,288 pressure + 22 humidity values equal to 0 (impossible).
3. **Cleaned:** removed duplicates, converted dates with `lubridate`, set impossible zeros to NA, filled missing precipitation type with "unknown".
4. **Analysed:** mean, median, mode, standard deviation, variance, min, max; correlations; monthly and seasonal trends.
5. **Exported** with `jsonlite`; **plotted** with `ggplot2`.

## Results to quote (read them from the dashboard after running R)
Average temperature about 11.9 C, range about -21.8 to 39.9 C; July warmest, January coldest; temperature and humidity moderately negatively correlated (about -0.64); rain in most hours, snow in about 11%.

## Likely viva questions
* **Mean vs median vs mode?** Mean = average; median = middle value (not affected by extremes); mode = most frequent value. For decimals I rounded first so values repeat.
* **Variance vs standard deviation?** Variance = average squared distance from the mean; SD = its square root, in the same unit as the data (here C), so easier to interpret.
* **What does correlation -0.64 mean?** When temperature rises, humidity tends to fall; moderate strength. Correlation does not prove cause.
* **Why set pressure = 0 to NA?** Real air pressure is about 1000 mb; 0 is a sensor error and would badly distort the mean and SD (the old SD was 117, the cleaned SD is about 8).
* **Why no rainfall chart?** The dataset has only the type of precipitation, not the amount. I did not invent data; the chart compares rain vs snow.
* **Why JSON and not Flask?** The frontend only needs finished results, so static JSON is simpler. Flask would be useful if users uploaded new data to be analysed live.
* **Why a local server?** Browsers block reading local files from a page opened with `file://`.
* **Limitations:** one location, 7 numeric variables, no rainfall amount; correlations are linear only.
* **Future work:** upload your own CSV, forecasting model, rainfall data.
