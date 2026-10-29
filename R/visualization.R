# ============================================================
# FILE: R/visualization.R
# PURPOSE: Create the PNG plots with ggplot2 and save them in /plots
# Defines one function: make_plots(). main_analysis.R calls it.
# ============================================================

library(ggplot2)
library(dplyr)

make_plots <- function(df, plots_dir, corr_matrix) {

  dir.create(plots_dir, showWarnings = FALSE, recursive = TRUE)
  blue      <- "#1e6fd9"
  light_blue <- "#8ec5ff"
  theme_set(theme_minimal(base_size = 13))

  save_plot <- function(p, name) {
    ggsave(file.path(plots_dir, name), plot = p, width = 10, height = 6.5, dpi = 120, bg = "white")
  }

  # 1. Histogram: how are temperatures distributed?
  p1 <- ggplot(df, aes(x = `Temperature (C)`)) +
    geom_histogram(binwidth = 2, fill = blue, colour = "white") +
    labs(title = "Temperature Distribution", x = "Temperature (C)", y = "Number of hours")
  save_plot(p1, "histogram.png")

  # 2. Line graph: monthly average temperature
  monthly <- df %>%
    mutate(YearMonth = as.Date(sprintf("%d-%02d-01", Year, Month))) %>%
    group_by(YearMonth) %>%
    summarise(avg_temp = mean(`Temperature (C)`), .groups = "drop")
  p2 <- ggplot(monthly, aes(x = YearMonth, y = avg_temp)) +
    geom_line(colour = blue, linewidth = 0.9) +
    labs(title = "Monthly Average Temperature (2006-2016)", x = "Month", y = "Average temperature (C)")
  save_plot(p2, "line_graph.png")

  # 3. Scatter plot: temperature vs humidity (every 60th row keeps it readable)
  samp <- df[seq(1, nrow(df), by = 60), ] %>% filter(!is.na(Humidity))
  p3 <- ggplot(samp, aes(x = `Temperature (C)`, y = Humidity)) +
    geom_point(alpha = 0.4, colour = blue) +
    geom_smooth(method = "lm", se = FALSE, colour = "#e8590c", formula = y ~ x) +
    labs(title = "Temperature vs Humidity", x = "Temperature (C)", y = "Humidity (0 to 1)")
  save_plot(p3, "scatter_plot.png")

  # 4. Box plot: temperature for each precipitation type
  p4 <- ggplot(df, aes(x = `Precip Type`, y = `Temperature (C)`, fill = `Precip Type`)) +
    geom_boxplot(show.legend = FALSE) +
    scale_fill_manual(values = c(rain = light_blue, snow = "#d0ebff", unknown = "#ced4da")) +
    labs(title = "Temperature by Precipitation Type", x = "Precipitation type", y = "Temperature (C)")
  save_plot(p4, "box_plot.png")

  # 5. Bar chart: the 10 most common weather conditions
  cond <- df %>% count(Summary, sort = TRUE) %>% head(10)
  p5 <- ggplot(cond, aes(x = reorder(Summary, n), y = n)) +
    geom_col(fill = blue) +
    coord_flip() +
    labs(title = "Top 10 Weather Conditions", x = NULL, y = "Number of hours")
  save_plot(p5, "bar_chart.png")

  # 6. Seasonal pattern: average temperature for each calendar month
  seasonal <- df %>% group_by(Month) %>% summarise(avg_temp = mean(`Temperature (C)`), .groups = "drop")
  p6 <- ggplot(seasonal, aes(x = factor(Month, labels = month.abb), y = avg_temp, group = 1)) +
    geom_line(colour = blue, linewidth = 1.1) + geom_point(colour = blue, size = 3) +
    labs(title = "Average Temperature by Month of Year", x = "Month", y = "Average temperature (C)")
  save_plot(p6, "seasonal_pattern.png")

  # 7. Correlation heat map
  corr_long <- as.data.frame(as.table(corr_matrix))
  names(corr_long) <- c("Var1", "Var2", "r")
  p7 <- ggplot(corr_long, aes(Var1, Var2, fill = r)) +
    geom_tile(colour = "white") +
    geom_text(aes(label = sprintf("%.2f", r)), size = 3.5) +
    scale_fill_gradient2(low = "#e8590c", mid = "white", high = blue, limits = c(-1, 1)) +
    labs(title = "Correlation Between Weather Variables", x = NULL, y = NULL) +
    theme(axis.text.x = element_text(angle = 40, hjust = 1))
  save_plot(p7, "correlation_heatmap.png")

  invisible(TRUE)
}
