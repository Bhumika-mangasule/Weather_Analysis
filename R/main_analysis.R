# ============================================================
# PROJECT : Weather Data Analysis and Visualization System
# FILE    : R/main_analysis.R   (RUN THIS FILE)
# PURPOSE : 1. Load + explore the dataset
#           2. Clean it            (uses R/data_cleaning.R)
#           3. Calculate statistics, correlations, trends
#           4. Save plots          (uses R/visualization.R)
#           5. Export JSON files for the web dashboard
#
# HOW TO RUN (from the project folder, in Command Prompt):
#     Rscript R\main_analysis.R
# ============================================================

# ---- 0. Setup ------------------------------------------------
needed <- c("readr", "dplyr", "lubridate", "ggplot2", "jsonlite")
missing_pkgs <- needed[!needed %in% rownames(installed.packages())]
if (length(missing_pkgs) > 0) {
  install.packages(missing_pkgs, repos = "https://cloud.r-project.org")
}
suppressPackageStartupMessages({
  library(readr); library(dplyr); library(lubridate); library(jsonlite)
})

# Find the project folder: when run with Rscript, it is the parent of the R/ folder.
get_project_root <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) > 0) {
    script_path <- normalizePath(sub("^--file=", "", file_arg[1]))
    return(dirname(dirname(script_path)))
  }
  getwd()   # in RStudio: use setwd() to the project folder first
}
root <- get_project_root()
setwd(root)
cat("Project folder:", root, "\n")

source(file.path("R", "data_cleaning.R"))
source(file.path("R", "visualization.R"))

dir.create("results", showWarnings = FALSE)
dir.create("plots",   showWarnings = FALSE)

# ---- 1. Load and explore -------------------------------------
data_file <- file.path("weather_data", "weather.csv")
raw <- load_weather(data_file)

cat("\n--- FIRST SIX ROWS ---\n");      print(head(raw))
cat("\n--- COLUMN NAMES ---\n");        print(names(raw))
cat("\n--- DIMENSIONS (rows, cols) ---\n"); print(dim(raw))
cat("\n--- STRUCTURE ---\n");           str(raw)
cat("\n--- MISSING VALUES PER COLUMN ---\n"); print(colSums(is.na(raw)))
cat("\n--- DUPLICATE ROWS ---\n");      print(sum(duplicated(raw)))

# ---- 2. Clean -------------------------------------------------
cleaned <- clean_weather(raw)
df      <- cleaned$data
report  <- cleaned$report

cat("\n--- CLEANING REPORT ---\n")
cat("Duplicate rows removed      :", report$duplicates, "\n")
cat("Humidity zeros set to NA    :", report$zero_humidity, "\n")
cat("Pressure zeros set to NA    :", report$zero_pressure, "\n")
cat("Precip Type filled 'unknown':", report$precip_filled, "\n")
cat("Rows after cleaning         :", report$rows_clean, "\n")

# Save the cleaned dataset (date written as text so Excel reads it properly)
cleaned_out <- df %>% mutate(`Formatted Date` = format(`Formatted Date`, "%Y-%m-%d %H:%M:%S"))
write_csv(cleaned_out, file.path("results", "weather_cleaned.csv"), na = "")

# ---- 3. Statistics -------------------------------------------
# Variables to analyse, and how many decimals to use when finding the mode.
# (Loud Cover is left out: every value is 0, so it carries no information.)
stat_vars <- c("Temperature (C)" = 1, "Apparent Temperature (C)" = 1, "Humidity" = 2,
               "Wind Speed (km/h)" = 1, "Wind Bearing (degrees)" = 0,
               "Visibility (km)" = 1, "Pressure (millibars)" = 1)

# Mode = the most frequent value. For decimals we round first, otherwise
# almost every value would be unique.
get_mode <- function(x, digits) {
  x  <- round(x[!is.na(x)], digits)
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

statistics <- do.call(rbind, lapply(names(stat_vars), function(col) {
  x <- df[[col]]
  data.frame(variable = col,
             n        = sum(!is.na(x)),
             mean     = round(mean(x, na.rm = TRUE), 4),
             median   = round(median(x, na.rm = TRUE), 4),
             mode     = round(get_mode(x, stat_vars[[col]]), 4),
             sd       = round(sd(x, na.rm = TRUE), 4),
             variance = round(var(x, na.rm = TRUE), 4),
             min      = round(min(x, na.rm = TRUE), 4),
             max      = round(max(x, na.rm = TRUE), 4),
             stringsAsFactors = FALSE)
}))
cat("\n--- STATISTICS ---\n"); print(statistics)

# Correlations (pairwise.complete.obs = ignore the few missing values)
corr_matrix <- cor(df[names(stat_vars)], use = "pairwise.complete.obs")
cat("\n--- CORRELATION MATRIX ---\n"); print(round(corr_matrix, 2))

# Rainfall: this dataset only has "Precip Type" (rain/snow), not an amount.
rain_cols <- names(df)[grepl("rain", names(df), ignore.case = TRUE) & sapply(df, is.numeric)]
rainfall_available <- length(rain_cols) > 0
total_rainfall <- if (rainfall_available) sum(df[[rain_cols[1]]], na.rm = TRUE) else NA

# ---- 4. Trends and groups (used for charts + findings) -------
temp <- df$`Temperature (C)`

# Temperature histogram: bins of 2 degrees
lo <- floor(min(temp) / 2) * 2
hi <- ceiling(max(temp) / 2) * 2
breaks <- seq(lo, hi, by = 2)
hist_counts <- as.integer(table(cut(temp, breaks = breaks, right = FALSE, include.lowest = TRUE)))
hist_labels <- paste(head(breaks, -1), "to", tail(breaks, -1))

# Monthly average temperature (132 months)
monthly <- df %>%
  mutate(YearMonth = sprintf("%d-%02d", Year, Month)) %>%
  group_by(YearMonth) %>%
  summarise(avg_temp = mean(`Temperature (C)`), .groups = "drop") %>%
  arrange(YearMonth)

# Average for each calendar month (Jan..Dec) -> shows the seasons
seasonal <- df %>%
  group_by(Month) %>%
  summarise(avg_temp = mean(`Temperature (C)`), avg_hum = mean(Humidity, na.rm = TRUE), .groups = "drop") %>%
  arrange(Month)

yearly <- df %>% group_by(Year) %>% summarise(avg_temp = mean(`Temperature (C)`), .groups = "drop")

# Top 10 weather conditions
conditions <- df %>%
  group_by(Summary) %>%
  summarise(n = n(), avg_temp = mean(`Temperature (C)`), avg_hum = mean(Humidity, na.rm = TRUE), .groups = "drop") %>%
  arrange(desc(n)) %>%
  head(10)

# Precipitation type comparison
precip <- df %>%
  group_by(`Precip Type`) %>%
  summarise(n = n(), avg_temp = mean(`Temperature (C)`), avg_hum = mean(Humidity, na.rm = TRUE),
            avg_wind = mean(`Wind Speed (km/h)`), .groups = "drop") %>%
  arrange(desc(n))

# Scatter sample: every 60th row (same rule every time, so results are repeatable)
samp <- df[seq(1, nrow(df), by = 60), ] %>% filter(!is.na(Humidity))

# ---- 5. Plots -------------------------------------------------
make_plots(df, "plots", corr_matrix)
cat("\nPlots saved in the plots/ folder.\n")

# ---- 6. Findings (sentences built from the real numbers) -----
fmt_int  <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
strength <- function(r) if (abs(r) >= 0.7) "strong" else if (abs(r) >= 0.4) "moderate" else "weak"

st <- function(var, what) statistics[[what]][statistics$variable == var]
t_mean <- st("Temperature (C)", "mean"); t_med <- st("Temperature (C)", "median")
t_min  <- st("Temperature (C)", "min");  t_max <- st("Temperature (C)", "max")
t_sd   <- st("Temperature (C)", "sd")

hot  <- seasonal$Month[which.max(seasonal$avg_temp)]
cold <- seasonal$Month[which.min(seasonal$avg_temp)]
tc   <- corr_matrix["Temperature (C)", "Humidity"]

# strongest correlation, ignoring Temperature vs Apparent Temperature
vars <- names(stat_vars); best <- NULL
for (i in 1:(length(vars) - 1)) for (j in (i + 1):length(vars)) {
  if (setequal(c(vars[i], vars[j]), c("Temperature (C)", "Apparent Temperature (C)"))) next
  r <- corr_matrix[i, j]
  if (is.null(best) || abs(r) > abs(best$r)) best <- list(a = vars[i], b = vars[j], r = r)
}

p_rain <- precip[precip$`Precip Type` == "rain", ]
p_snow <- precip[precip$`Precip Type` == "snow", ]
first_date <- min(df$`Formatted Date`); last_date <- max(df$`Formatted Date`)

findings <- c(
  sprintf("The cleaned dataset has %s hourly records from %s to %s.",
          fmt_int(nrow(df)), format(first_date, "%d %b %Y"), format(last_date, "%d %b %Y")),
  sprintf("Temperature averages %.2f C (median %.2f C) and ranges from %.1f C to %.1f C. The standard deviation is %.2f C, so temperatures vary a lot through the year.",
          t_mean, t_med, t_min, t_max, t_sd),
  sprintf("%s is the hottest month on average (%.1f C) and %s is the coldest (%.1f C).",
          month.abb[hot], max(seasonal$avg_temp), month.abb[cold], min(seasonal$avg_temp)),
  sprintf("Temperature and humidity have a %s %s correlation (r = %.2f): %s.",
          strength(tc), if (tc < 0) "negative" else "positive", tc,
          if (tc < 0) "warmer hours tend to be drier" else "warmer hours tend to be more humid"),
  sprintf("The strongest relationship (ignoring Temperature vs Apparent Temperature) is %s vs %s (r = %.2f).",
          best$a, best$b, best$r),
  sprintf("'%s' is the most common weather condition (%.1f%% of all records).",
          conditions$Summary[1], 100 * conditions$n[1] / nrow(df)),
  sprintf("Rain is recorded in %s hours and snow in %s hours. Average temperature is %.1f C during rain and %.1f C during snow.",
          fmt_int(p_rain$n), fmt_int(p_snow$n), p_rain$avg_temp, p_snow$avg_temp),
  sprintf("The warmest year on average was %d (%.2f C) and the coolest was %d (%.2f C).",
          yearly$Year[which.max(yearly$avg_temp)], max(yearly$avg_temp),
          yearly$Year[which.min(yearly$avg_temp)], min(yearly$avg_temp)),
  sprintf("Data quality: %s pressure readings and %s humidity readings were exactly 0, which is physically impossible, so they were treated as sensor errors and set to missing before calculating statistics.",
          fmt_int(report$zero_pressure), fmt_int(report$zero_humidity)),
  if (rainfall_available) "A rainfall column was found and used for the rainfall total." else
    "The dataset has no rainfall-amount column, so total rainfall cannot be calculated. Only the precipitation type (rain / snow) is available."
)
cat("\n--- FINDINGS ---\n"); cat(paste0("* ", findings, collapse = "\n"), "\n")

# ---- 7. Export JSON for the dashboard ------------------------
missing_rows <- lapply(names(raw), function(col) {
  zeros <- 0; note <- "No problem found"
  if (col == "Humidity")             { zeros <- report$zero_humidity; note <- "Zeros are impossible humidity values -> set to missing (NA)" }
  if (col == "Pressure (millibars)") { zeros <- report$zero_pressure; note <- "Zeros are impossible pressure values -> set to missing (NA)" }
  if (col == "Loud Cover")           { note <- "Every value is 0 (no information) -> kept in file, excluded from statistics" }
  after <- sum(is.na(df[[col]]))
  if (col == "Precip Type") { note <- "Missing precipitation type -> filled with 'unknown'"; after <- 0 }
  list(column = col,
       missing_in_raw_file    = as.integer(report$missing_raw[[col]]),
       invalid_zeros_found    = as.integer(zeros),
       missing_after_cleaning = as.integer(after),
       treatment              = note)
})

summary_list <- list(
  generated_by = R.version.string,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  dataset = list(file = "weather_data/weather.csv",
                 rows_raw = report$rows_raw, rows_clean = report$rows_clean,
                 duplicates_removed = report$duplicates, columns = ncol(raw),
                 column_names = names(raw),
                 date_start = format(first_date, "%Y-%m-%d"), date_end = format(last_date, "%Y-%m-%d"),
                 rainfall_available = rainfall_available),
  cards = list(avg_temperature = t_mean, max_temperature = t_max, min_temperature = t_min,
               avg_humidity = st("Humidity", "mean"), avg_wind_speed = st("Wind Speed (km/h)", "mean"),
               total_rainfall = total_rainfall, total_records = nrow(df)),
  missing_values = missing_rows,
  statistics     = statistics,
  correlations   = list(variables = vars, matrix = round(unname(corr_matrix), 3)),
  findings       = as.list(findings)
)

chart_list <- list(
  generated_by = R.version.string,
  temperature_histogram = list(labels = hist_labels, counts = hist_counts),
  monthly_temperature   = list(labels = monthly$YearMonth, values = round(monthly$avg_temp, 4)),
  seasonal_pattern      = list(labels = month.abb, avg_temperature = round(seasonal$avg_temp, 4),
                               avg_humidity = round(seasonal$avg_hum, 4)),
  weather_conditions    = list(labels = conditions$Summary, counts = as.integer(conditions$n),
                               avg_temperature = round(conditions$avg_temp, 4),
                               avg_humidity = round(conditions$avg_hum, 4)),
  precipitation_types   = list(labels = precip$`Precip Type`, counts = as.integer(precip$n),
                               avg_temperature = round(precip$avg_temp, 4),
                               avg_humidity = round(precip$avg_hum, 4),
                               avg_wind_speed = round(precip$avg_wind, 4)),
  temp_vs_humidity      = list(note = "Every 60th hourly record (about 1,600 points) so the chart stays fast.",
                               temperature = round(samp$`Temperature (C)`, 2),
                               humidity = round(samp$Humidity, 2)),
  rainfall_available    = rainfall_available
)

preview <- cleaned_out %>%
  select(-Year, -Month) %>%
  head(200) %>%
  mutate(across(where(is.numeric), ~ round(.x, 2)))
preview_list <- list(columns = names(preview), rows = preview)

save_json <- function(obj, file) {
  write_json(obj, file.path("results", file), auto_unbox = TRUE, pretty = TRUE,
             na = "null", digits = NA)
}
save_json(summary_list, "summary.json")
save_json(chart_list,   "chart_data.json")
save_json(preview_list, "preview.json")

cat("\n========================================\n")
cat("ANALYSIS COMPLETED SUCCESSFULLY\n")
cat("========================================\n")
cat("Dashboard files : results/summary.json, results/chart_data.json, results/preview.json\n")
cat("Cleaned dataset : results/weather_cleaned.csv\n")
cat("Plots           : plots/*.png\n")
