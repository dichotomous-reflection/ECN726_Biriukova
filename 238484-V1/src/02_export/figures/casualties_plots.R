################################################################################
# CASUALTIES PLOTS
################################################################################
# Generate figures showing war casualties as a percentage of local population
# across different war types and time periods
# Outputs:
#   - fig_warshock_interstate_barplot_0.1.pdf (Figure 2a): Time series bar plots of interstate war casualties
#   - fig_warshock_other_barplot_0.1.pdf (Figure 2b): Time series bar plots of other war casualties
#   - fig_warshock_histogram_log10_combined.pdf (Figure 3a): Combined histogram showing distribution of casualty rates (log10 scale)
################################################################################

################
# HOUSEKEEPING #
################

# Load required libraries
library(tidyverse)    # Data manipulation and visualization
library(ggplot2)      # Advanced plotting capabilities
library(ggrepel)      # Smart text label positioning to avoid overlaps
library(patchwork)    # Combining multiple plots
library(scales)       # Scale transformations and formatting

################################################################################
# Figure 2a: Interstate war casualties barplot over time
################################################################################

# Load interstate war sites data
sites_interstate <- haven::read_dta("data/02_processed/sites_interstate.dta")
# Set threshold for minimum casualty rate to include
threshold_interstate <- 0.001
# Prepare interstate data
casualties_interstate <- sites_interstate %>%
  select(iso, start, shock_caspop_home) %>%           # iso = country code, start = war start year, shock_caspop_home = casualty rate
  filter(shock_caspop_home > threshold_interstate)    # Only include wars above threshold
# Create interstate war casualties bar plot
fig_interstate <- ggplot(casualties_interstate, aes(x = factor(start), y = 100 * shock_caspop_home, fill = iso)) +
  # Bar plot with each country colored differently, dodged positioning for multiple wars per year
  geom_bar(stat = "identity", position = position_dodge2(preserve = "single")) +
  # Add country labels with smart positioning to avoid overlaps
  geom_text_repel(
    aes(label = iso, color = iso),
    size = 3,                          # Text size
    max.overlaps = 25,                 # Allow up to 25 overlapping labels
    segment.colour = "black",        # Color of connecting lines
    segment.linetype = "dotted",       # Style of connecting lines
    segment.size = 0.5,                # Width of connecting lines
  ) +
  # Axis labels
  labs(x = "Year", y = "Percent") +
  # Y-axis scale from 0 to 100 with 10% increments
  scale_y_continuous(breaks = seq(0, 100, by = 10)) +
  # Apply minimal theme with larger base font size
  theme_minimal(base_size = 16) +
  theme(
    plot.title = element_text(hjust = 0.5),                                     # Center plot title
    axis.title = element_text(size = 20),                                       # Large axis titles
    axis.title.x = element_blank(),                                             # Remove x-axis title
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1, size = 18),  # Rotate x-axis labels
    axis.text.y = element_text(size = 18),                                      # Large y-axis text
    axis.line.y = element_line(
      linetype = "solid", color = "black", linewidth = 0.5                    # Y-axis line styling
    ),
    legend.text = element_text(size = 5),                                         # Small legend text
    legend.position = "none",                                                     # Hide legend (countries labeled directly)
    panel.grid.major = element_line(
      color = "grey90", linetype = "dashed", linewidth = 0.25                   # Major grid lines
    ),
    panel.grid.minor = element_blank()                                            # Remove minor grid lines
  ) +
  # Add horizontal line at y=0 for reference
  geom_hline(
    yintercept = 0, show.legend = FALSE,
    linetype = "solid", color = "black", linewidth = 0.5
  )
# Display the plot
print(fig_interstate)
# Save the plot as PDF with high resolution, filename includes threshold percentage
ggsave(
  filename = paste0("data/03_exports/figures/fig_warshock_interstate_barplot_", threshold_interstate * 100, ".pdf"),
  plot = fig_interstate, dpi = 300, units = "px", width = 4000, height = 1800
)

################################################################################
# Figure 2b: Other war casualties barplot over time
################################################################################

# Load intrastate/other war sites data
sites_other <- haven::read_dta("./data/02_processed/sites_intrastate.dta")
# Set same threshold as interstate wars for consistency
threshold_other <- 0.001
# Prepare other war data
casualties_other <- sites_other %>%
  select(iso, start, shock_caspop_home) %>%          # iso = country code, start = war start year, shock_caspop_home = casualty rate
  filter(shock_caspop_home > threshold_other)        # Only include wars above threshold
# Create intrastate/other war casualties bar plot
fig_other <- ggplot(casualties_other, aes(x = start, y = 100 * shock_caspop_home, fill = iso)) +
  # Bar plot with continuous x-axis (note: start is numeric, not factor like interstate plot)
  geom_bar(stat = "identity", position = position_dodge2(preserve = "single")) +
  # Add country labels with smart positioning (fewer max overlaps than interstate)
  geom_text_repel(
    aes(label = iso, color = iso),
    size = 3,                          # Text size
    max.overlaps = 20,                 # Slightly fewer overlaps allowed
    segment.colour = "black",        # Color of connecting lines
    segment.linetype = "dotted",       # Style of connecting lines
    segment.size = 0.5,                # Width of connecting lines
  ) +
  # Axis labels
  labs(x = "Year", y = "Percent") +
  # X-axis scale: from 1870 to 2025 with 5-year intervals
  scale_x_continuous(breaks = seq(1870, 2025, by = 5)) +
  # Y-axis scale: 0 to 100 with 5% increments (finer than interstate plot)
  scale_y_continuous(breaks = seq(0, 100, by = 5)) +
  # Apply minimal theme with same styling as interstate plot
  theme_minimal(base_size = 16) +
  theme(
    plot.title = element_text(hjust = 0.5),                                     # Center plot title
    axis.title = element_text(size = 20),                                       # Large axis titles
    axis.title.x = element_blank(),                                             # Remove x-axis title
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1, size = 18),  # Rotate x-axis labels
    axis.text.y = element_text(size = 18),                                      # Large y-axis text
    axis.line.y = element_line(
      linetype = "solid", color = "black", linewidth = 0.5                    # Y-axis line styling
    ),
    legend.text = element_text(size = 5),                                       # Small legend text
    legend.position = "none",                                                   # Hide legend (countries labeled directly)
    panel.grid.major = element_line(
      color = "grey90", linetype = "dashed", linewidth = 0.25                 # Major grid lines
    ),
    panel.grid.minor = element_blank()                                          # Remove minor grid lines
  ) +
  # Add horizontal line at y=0 for reference
  geom_hline(
    yintercept = 0, show.legend = FALSE,
    linetype = "solid", color = "black", linewidth = 0.5
  )
# Display the plot
print(fig_other)
# Save the plot as PDF with high resolution, filename includes threshold percentage
ggsave(
  filename = paste0("data/03_exports/figures/fig_warshock_other_barplot_", threshold_other * 100, ".pdf"),
  plot = fig_other, dpi = 300, units = "px", width = 4000, height = 1800
)

################################################################################
# Figure 3a: Combined histogram of war casualty distributions (log10 scale)
################################################################################

# Reset thresholds to 0 to include ALL wars in the histogram
threshold_interstate <- 0
threshold_other <- 0

# Prepare war data
casualties_interstate <- sites_interstate %>%
  select(iso, start, shock_caspop_home) %>%           # iso = country code, start = war start year, shock_caspop_home = casualty rate
  filter(shock_caspop_home > threshold_interstate)    # Include all interstate wars
casualties_other <- sites_other %>%
  select(iso, start, shock_caspop_home) %>%          # iso = country code, start = war start year, shock_caspop_home = casualty rate
  filter(shock_caspop_home > threshold_other)        # Include all other wars

# Create combined histogram with overlapping distributions
hist_combined10 <- ggplot() +
  # Interstate wars histogram (first layer)
  geom_histogram(
    data = casualties_interstate,
    aes(x = shock_caspop_home, fill = "Interstate"),
    binwidth = 0.2,              # Bin width on log10 scale
    alpha = 0.5,                 # Semi-transparent for overlay effect
    color = "white"            # White bin borders for clarity
  ) +
  # Other wars histogram (overlapping second layer)
  geom_histogram(
    data = casualties_other,
    aes(x = shock_caspop_home, fill = "Other"),
    binwidth = 0.2,              # Same bin width for fair comparison
    alpha = 0.5,                 # Semi-transparent for overlay effect
    color = "white"            # White bin borders for clarity
  ) +
  # Log10 scale for x-axis with scientific notation labels
  # Covers 6 orders of magnitude from 0.0001% to 100% casualties
  scale_x_log10(
    breaks = c(10^-6, 10^-4, 10^-2, 10^0),              # Major breaks at powers of 10
    labels = trans_format("log10", math_format(10^.x))  # Format as 10^x
  ) +
  # Custom color palette for war types
  scale_fill_manual(
    name = "War Type",
    values = c("Interstate" = "steelblue", "Other" = "darkorange"),
    labels = c("Interstate" = "Interstate Wars", "Other" = "Other Wars")
  ) +
  # Axis labels with clear descriptions
  labs(
    x = "Casualties / local population (log10 scale)",
    y = "Number of wars"
  ) +
  # Theme
  theme_minimal(base_size = 14) +
  theme(
    # Use serif fonts for academic publication style
    text = element_text(family = "serif"),
    # Clean white background
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA),
    # Typography settings
    plot.title = element_text(
      size = 18,                   # Large title
      face = "bold",               # Bold weight
      hjust = 0,                   # Left-aligned
      margin = margin(b = 5)       # Bottom margin
    ),
    plot.subtitle = element_text(
      size = 14,                   # Medium subtitle
      color = "grey40",          # Subtle color
      hjust = 0,                   # Left-aligned
      margin = margin(b = 20)      # Bottom margin
    ),
    axis.title = element_text(size = 21, color = "grey20"),   # Large, dark grey axis titles
    axis.text = element_text(size = 19, color = "grey30"),    # Large, medium grey axis text
    axis.text.x = element_text(                                 # X-axis text positioning
      angle = 0, # no rotation
      vjust = 0.5,
      hjust = 0.5,
      margin = margin(t = -15) # Move closer to axis
    ),
    # Grid styling for better readability
    panel.grid.major.x = element_line(
      color = "grey92",          # Very light grey
      size = 0.5                   # Medium thickness
    ),
    panel.grid.major.y = element_line(
      color = "grey95",          # Even lighter grey
      size = 0.3                   # Thin lines
    ),
    panel.grid.minor = element_blank(),  # Remove minor grid
    # Legend positioning and styling
    legend.position = c(0.09, 0.85),     # Top-left corner
    legend.background = element_rect(
      fill = alpha("white", 0.9),      # Semi-transparent white background
      color = "grey90",                # Light border
      size = 0.3                         # Thin border
    ),
    legend.title = element_blank(),                           # No legend title
    legend.text = element_text(size = 14),                    # Medium legend text
    legend.key.size = unit(0.8, "cm"),                        # Legend symbol size
    # Plot margins for better spacing
    plot.margin = margin(20, 20, 20, 20)
  ) +
  # Left annotation: indicates lower casualty rates
  geom_text(
    data = data.frame(
      x = 10^-5,                                        # Position on left side of plot
      y = Inf,                                          # Position at top of plot
      label = 'phantom(x) %<-% " Lower casualty rate"'  # LaTeX-style arrow pointing left
    ),
    aes(x = x, y = y, label = label),
    hjust = 0,                     # Left-aligned text
    vjust = 2,                     # Position below top edge
    size = 5,                      # Text size
    color = "grey50",            # Subtle grey color
    fontface = "italic",           # Italic style
    parse = TRUE                   # Parse LaTeX expressions
  ) +
  # Right annotation: indicates higher casualty rates
  geom_text(
    data = data.frame(
      x = 10^-0.25,                                      # Position on right side of plot
      y = Inf,                                           # Position at top of plot
      label = '"Higher casualty rate " %->% phantom(x)'  # LaTeX-style arrow pointing right
    ),
    aes(x = x, y = y, label = label),
    hjust = 1,                     # Right-aligned text
    vjust = 2,                     # Position below top edge
    size = 5,                      # Text size
    color = "grey50",            # Subtle grey color
    fontface = "italic",           # Italic style
    parse = TRUE                   # Parse LaTeX expressions
  )
# Display the combined histogram
print(hist_combined10)
# Save the histogram as PDF with high resolution
ggsave(
  filename = "data/03_exports/figures/fig_warshock_histogram_log10_combined.pdf",
  plot = hist_combined10, dpi = 300, units = "px", width = 4000, height = 1800
)

###########################
# Kolmogorov-Smirnov test #
###########################
# Perform Kolmogorov-Smirnov test
ks_test <- ks.test(casualties_interstate$shock_caspop_home, casualties_other$shock_caspop_home)
print(ks_test)
D_stat <- round(ks_test$statistic, 3)
p_val <- ks_test$p.value
if (p_val < 0.001) {
  p_text <- "p < 0.001"
} else {
  p_text <- paste0("p = ", round(p_val, 3))
}
# Write Kolmogorov-Smirnov test results to file
cat("D =", D_stat, ",", p_text, file = "data/03_exports/figures/kolmogorov_smirnov.txt")
