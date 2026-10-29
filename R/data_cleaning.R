# ============================================================
# FILE: R/data_cleaning.R
# PURPOSE: Load the weather CSV and clean it.
# This file only defines functions. main_analysis.R calls them.
# ============================================================

library(readr)
library(dplyr)
library(lubridate)

# ------------------------------------------------------------
# 1. Load the dataset
# ------------------------------------------------------------
load_weather <- function(path) {
  # We tell R that the date and text columns are TEXT, so that R does not
  # try to guess (and possibly mis-read) them.
  read_csv(
    path,
    col_types = cols(
      `Formatted Date` = col_character(),
      `Summary`        = col_character(),
      `Precip Type`    = col_character(),
      `Daily Summary`  = col_character(),
      .default         = col_double()
    )
  )
}

# ------------------------------------------------------------
# 2. Clean the dataset
# Returns a list with two things:
#   $data   -> the cleaned data frame
#   $report -> counts of what was found/fixed (used for the dashboard)
# ------------------------------------------------------------
clean_weather <- function(raw) {

  report <- list()
  report$rows_raw          <- nrow(raw)
  report$missing_raw       <- colSums(is.na(raw))
  report$duplicates        <- sum(duplicated(raw))

  # Step A: remove exact duplicate rows
  df <- distinct(raw)

  # Step B: convert the date column.
  # Dates look like "2006-04-01 00:00:00.000 +0200". We keep the first
  # 19 characters (the local clock time) and convert them to a date-time.
  df <- df %>%
    mutate(`Formatted Date` = ymd_hms(substr(`Formatted Date`, 1, 19), tz = "UTC")) %>%
    arrange(`Formatted Date`) %>%                    # file is not in date order
    mutate(Year = year(`Formatted Date`),
           Month = month(`Formatted Date`))

  # Step C: impossible zero values -> NA
  # Humidity = 0 and Pressure = 0 are sensor errors, not real weather.
  report$zero_humidity <- sum(df$Humidity == 0, na.rm = TRUE)
  report$zero_pressure <- sum(df$`Pressure (millibars)` == 0, na.rm = TRUE)
  df$Humidity[df$Humidity == 0] <- NA
  df$`Pressure (millibars)`[df$`Pressure (millibars)` == 0] <- NA

  # Step D: missing precipitation type -> "unknown"
  report$precip_filled <- sum(is.na(df$`Precip Type`))
  df$`Precip Type`[is.na(df$`Precip Type`)] <- "unknown"

  report$rows_clean      <- nrow(df)
  report$missing_after   <- colSums(is.na(df))

  list(data = df, report = report)
}
