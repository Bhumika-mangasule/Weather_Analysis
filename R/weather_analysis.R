# ============================================================
# PROJECT: WEATHER PATTERN ANALYSIS AND DATA VISUALIZATION
# LANGUAGE: R
# DATASET: KAGGLE WEATHER DATASET
# ============================================================


# STEP 1: LOAD THE DATASET
# ------------------------------------------------------------

# Select your downloaded Kaggle CSV file
# Reads the project dataset; if it is not found, ask you to pick the file
data_path <- if (file.exists("weather_data/weather.csv")) "weather_data/weather.csv" else file.choose()
weather <- read.csv(data_path, check.names = FALSE)

# Display the dataset
print(head(weather))

# View the complete dataset in spreadsheet format
if (interactive()) View(weather)


# STEP 2: EXPLORE THE DATASET
# ------------------------------------------------------------

cat("\n--- DATASET DIMENSIONS ---\n")
print(dim(weather))

cat("\n--- COLUMN NAMES ---\n")
print(names(weather))

cat("\n--- DATASET STRUCTURE ---\n")
str(weather)

cat("\n--- SUMMARY STATISTICS ---\n")
print(summary(weather))


# STEP 3: CHECK MISSING VALUES AND DUPLICATES
# ------------------------------------------------------------

cat("\n--- MISSING VALUES IN EACH COLUMN ---\n")
print(colSums(is.na(weather)))

cat("\n--- TOTAL DUPLICATE ROWS ---\n")
print(sum(duplicated(weather)))


# STEP 4: CONVERT WEATHER COLUMNS TO NUMERIC
# ------------------------------------------------------------

numeric_columns <- c(
  "Temperature (C)",
  "Apparent Temperature (C)",
  "Humidity",
  "Wind Speed (km/h)",
  "Visibility (km)",
  "Pressure (millibars)"
)

# Convert only columns that exist in the dataset
for (col in numeric_columns) {
  if (col %in% names(weather)) {
    weather[[col]] <- suppressWarnings(
      as.numeric(as.character(weather[[col]]))
    )
  }
}


# STEP 5: MEAN, MEDIAN, AND MODE
# ------------------------------------------------------------

if ("Temperature (C)" %in% names(weather)) {

  temperature <- weather[["Temperature (C)"]]
  temperature <- temperature[!is.na(temperature)]

  cat("\n--- TEMPERATURE STATISTICS ---\n")

  cat("Mean Temperature:",
      mean(temperature), "\n")

  cat("Median Temperature:",
      median(temperature), "\n")

  # Function to calculate statistical mode
  get_mode <- function(x) {
    x <- x[!is.na(x)]

    if (length(x) == 0) {
      return(NA)
    }

    values <- unique(x)
    values[which.max(tabulate(match(x, values)))]
  }

  cat("Mode Temperature:",
      get_mode(temperature), "\n")

} else {
  cat("\nTemperature column not found. Check names(weather).\n")
}


# STEP 6: VARIANCE AND STANDARD DEVIATION
# ------------------------------------------------------------

if ("Temperature (C)" %in% names(weather)) {

  cat("\n--- VARIANCE AND STANDARD DEVIATION ---\n")

  cat("Temperature Variance:",
      var(weather[["Temperature (C)"]], na.rm = TRUE), "\n")

  cat("Temperature Standard Deviation:",
      sd(weather[["Temperature (C)"]], na.rm = TRUE), "\n")
}


# STEP 7: GROUPING AND AGGREGATION
# ------------------------------------------------------------

# Average temperature by precipitation type
if (all(c("Precip Type", "Temperature (C)") %in% names(weather))) {

  cat("\n--- AVERAGE TEMPERATURE BY PRECIPITATION TYPE ---\n")

  precipitation_summary <- aggregate(
    weather[["Temperature (C)"]],
    by = list(Precipitation = weather[["Precip Type"]]),
    FUN = function(x) mean(x, na.rm = TRUE)
  )

  names(precipitation_summary)[2] <- "Average_Temperature"

  print(precipitation_summary)
}

# Count records by weather summary
if ("Summary" %in% names(weather)) {

  cat("\n--- WEATHER CONDITION COUNTS ---\n")

  print(sort(table(weather[["Summary"]]), decreasing = TRUE))
}


# STEP 8: CORRELATION BETWEEN WEATHER VARIABLES
# ------------------------------------------------------------

correlation_columns <- intersect(
  c(
    "Temperature (C)",
    "Apparent Temperature (C)",
    "Humidity",
    "Wind Speed (km/h)",
    "Visibility (km)",
    "Pressure (millibars)"
  ),
  names(weather)
)

if (length(correlation_columns) >= 2) {

  correlation_data <- weather[correlation_columns]

  correlation_matrix <- cor(
    correlation_data,
    use = "pairwise.complete.obs"
  )

  cat("\n--- CORRELATION MATRIX ---\n")
  print(correlation_matrix)
}


# STEP 9: CREATE OUTPUT FOLDERS
# ------------------------------------------------------------

dir.create("plots", showWarnings = FALSE, recursive = TRUE)
dir.create("results", showWarnings = FALSE, recursive = TRUE)


# STEP 10: BAR CHART
# Average temperature by precipitation type
# ------------------------------------------------------------

if (exists("precipitation_summary") &&
    nrow(precipitation_summary) > 0) {

  png("plots/bar_chart.png", width = 1000, height = 700)

  barplot(
    precipitation_summary$Average_Temperature,
    names.arg = precipitation_summary$Precipitation,
    main = "Average Temperature by Precipitation Type",
    xlab = "Precipitation Type",
    ylab = "Average Temperature (C)",
    col = "skyblue",
    las = 2
  )

  dev.off()
}


# STEP 11: HISTOGRAM
# Temperature distribution
# ------------------------------------------------------------

if ("Temperature (C)" %in% names(weather)) {

  png("plots/histogram.png", width = 1000, height = 700)

  hist(
    weather[["Temperature (C)"]],
    main = "Distribution of Weather Temperatures",
    xlab = "Temperature (Celsius)",
    ylab = "Frequency",
    col = "lightblue",
    border = "black"
  )

  dev.off()
}


# STEP 12: BOX PLOT
# Temperature distribution by precipitation type
# ------------------------------------------------------------

if (all(c("Temperature (C)", "Precip Type") %in% names(weather))) {

  box_data <- weather[
    !is.na(weather[["Precip Type"]]) &
      !is.na(weather[["Temperature (C)"]]),
  ]

  if (nrow(box_data) > 0) {

    png("plots/box_plot.png", width = 1000, height = 700)

    boxplot(
      box_data[["Temperature (C)"]] ~ box_data[["Precip Type"]],
      main = "Temperature by Precipitation Type",
      xlab = "Precipitation Type",
      ylab = "Temperature (Celsius)",
      col = "lightgreen"
    )

    dev.off()
  }
}


# STEP 13: LINE GRAPH
# Monthly average temperature
# ------------------------------------------------------------

if (all(c("Formatted Date", "Temperature (C)") %in% names(weather))) {

  weather_date <- as.POSIXct(
    weather[["Formatted Date"]],
    tz = "UTC",
    tryFormats = c(
      "%Y-%m-%d %H:%M:%OS %z",
      "%Y-%m-%d %H:%M:%OS",
      "%Y-%m-%d %H:%M:%S"
    )
  )

  valid_dates <- !is.na(weather_date) &
    !is.na(weather[["Temperature (C)"]])

  if (any(valid_dates)) {

    month <- format(weather_date[valid_dates], "%Y-%m")

    monthly_data <- aggregate(
      weather[["Temperature (C)"]][valid_dates],
      by = list(Month = month),
      FUN = mean
    )

    names(monthly_data)[2] <- "Average_Temperature"

    monthly_data <- monthly_data[order(monthly_data$Month), ]

    png("plots/line_graph.png", width = 1200, height = 700)

    plot(
      seq_len(nrow(monthly_data)),
      monthly_data$Average_Temperature,
      type = "o",
      xaxt = "n",
      main = "Monthly Average Temperature",
      xlab = "Month",
      ylab = "Average Temperature (C)",
      col = "blue",
      pch = 16
    )

    axis(
      1,
      at = seq_len(nrow(monthly_data)),
      labels = monthly_data$Month,
      las = 2,
      cex.axis = 0.7
    )

    dev.off()

  } else {
    cat("\nCould not parse dates for the monthly line graph.\n")
  }
}


# STEP 14: SCATTER PLOT
# Temperature versus humidity
# ------------------------------------------------------------

if (all(c("Temperature (C)", "Humidity") %in% names(weather))) {

  png("plots/scatter_plot.png", width = 1000, height = 700)

  plot(
    weather[["Temperature (C)"]],
    weather[["Humidity"]],
    main = "Temperature vs Humidity",
    xlab = "Temperature (Celsius)",
    ylab = "Humidity",
    pch = 16,
    col = "steelblue"
  )

  dev.off()
}


# STEP 15: PIE CHART
# Most frequent weather conditions
# ------------------------------------------------------------

if ("Summary" %in% names(weather)) {

  weather_counts <- sort(
    table(weather[["Summary"]]),
    decreasing = TRUE
  )

  weather_counts <- head(weather_counts, 6)

  if (length(weather_counts) > 0) {

    png("plots/pie_chart.png", width = 1000, height = 700)

    pie(
      weather_counts,
      labels = names(weather_counts),
      main = "Top 6 Weather Conditions",
      col = rainbow(length(weather_counts))
    )

    dev.off()
  }
}


# STEP 16: SAVE ANALYSIS RESULTS
# ------------------------------------------------------------

# Save the cleaned/current dataset
write.csv(
  weather,
  "results/weather_dataset.csv",
  row.names = FALSE
)

# Save summary statistics for numeric columns
numeric_data <- weather[
  sapply(weather, is.numeric)
]

if (ncol(numeric_data) > 0) {

  summary_data <- data.frame(
    Variable = names(numeric_data),
    Mean = sapply(numeric_data, function(x) mean(x, na.rm = TRUE)),
    Median = sapply(numeric_data, function(x) median(x, na.rm = TRUE)),
    Variance = sapply(numeric_data, function(x) var(x, na.rm = TRUE)),
    Standard_Deviation = sapply(numeric_data, function(x) sd(x, na.rm = TRUE))
  )

  write.csv(
    summary_data,
    "results/weather_statistics.csv",
    row.names = FALSE
  )
}


# STEP 17: DISPLAY COMPLETION MESSAGE
# ------------------------------------------------------------

cat("\n========================================\n")
cat("WEATHER ANALYSIS COMPLETED SUCCESSFULLY!\n")
cat("========================================\n")

cat("\nCheck the plots folder for saved graphs.\n")
cat("Check the results folder for CSV reports.\n")
