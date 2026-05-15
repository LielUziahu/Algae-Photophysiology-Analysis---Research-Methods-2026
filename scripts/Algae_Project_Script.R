# --- Research Methods 2026: Algae Photophysiology Final Analysis ---
# Processing RLC data from dark.csv and light.csv for 13 algae species.

# 1. Load Required Libraries and Check Versions ----
library(dplyr)
print(paste("dplyr version:", packageVersion("dplyr")))

library(purrr)
print(paste("purrr version:", packageVersion("purrr")))

library(broom)
print(paste("broom version:", packageVersion("broom")))

library(tidyr)
print(paste("tidyr version:", packageVersion("tidyr")))

library(rstatix)
print(paste("rstatix version:", packageVersion("rstatix")))

library(ggplot2)
print(paste("ggplot2 version:", packageVersion("ggplot2")))

# 2. Setup Data and Functions ----
# Load raw files using ';' delimiter
dark_raw  <- read.csv("dark.csv", sep = ";", header = TRUE)
light_raw <- read.csv("light.csv", sep = ";", header = TRUE)

# Scientific Names mapping for the 13 samples
algae_names <- data.frame(
  Sample_Num = 1:13,
  Scientific_Name = c("Colpomenia sinuosa", "Dictyota dichotoma", "Sargassum vulgare", 
                      "Padina pavonica", "Jania rubens", "Ulva lactuca", 
                      "Galaxaura rugosa", "Halopteris scoparia", "Nemalion helminthoides", 
                      "Hypnea musciformis", "Codium elatum", "Cystoseira spp.", "Additional Sp")
)

# Unified function to tidy data and fix naming conventions (R replaces () with dots)
prepare_algae_data <- function(df, treatment_label) {
  df %>%
    # Captures column patterns: ETR1, Y.II.1, Y(II)1, Y.NPQ.1, etc.
    pivot_longer(cols = matches("^(Y.II.|ETR|Y.NPQ.|Y\\(II\\)|Y\\(NPQ\\))\\d+"), 
                 names_to = "Param_ID", values_to = "Value") %>%
    mutate(Treatment = treatment_label,
           Sample_Num = as.numeric(gsub("\\D", "", Param_ID)),
           Parameter_Raw = gsub("\\d", "", Param_ID),
           # Standardize naming for downstream filtering
           Parameter_Type = case_when(
             grepl("Y.II", Parameter_Raw) ~ "Y(II)",
             grepl("Y.NPQ", Parameter_Raw) ~ "Y(NPQ)",
             TRUE ~ Parameter_Raw
           ),
           PAR = as.numeric(PAR)) %>%
    select(-Parameter_Raw)
}

# 3. Create Unified Dataset (Photophysiology) ----
Photophysiology <- bind_rows(
  prepare_algae_data(dark_raw, "Dark"), 
  prepare_algae_data(light_raw, "Light")
) %>%
  left_join(algae_names, by = "Sample_Num") %>%
  filter(!is.na(Value))

# Save the master organized dataset
write.csv(Photophysiology, "Combined_Algae_Data_Organized.csv", row.names = FALSE)

# 4. Calculate P-I Curve Parameters (Summary Table) ----
etr_data <- Photophysiology %>% filter(Parameter_Type == "ETR")

# Pmax (Max ETR per species/treatment)
pmax_summary <- etr_data %>%
  group_by(Scientific_Name, Treatment) %>%
  summarise(Pmax = max(Value, na.rm = TRUE), .groups = "drop")

# Alpha (Initial Slope) - Regression for PAR between 0 and 250
alpha_summary <- etr_data %>%
  filter(PAR > 0 & PAR <= 250) %>%
  group_by(Scientific_Name, Treatment) %>%
  filter(n() > 1) %>% 
  do(model = lm(Value ~ PAR, data = .)) %>%
  mutate(Alpha = coef(model)[2]) %>%
  select(Scientific_Name, Treatment, Alpha)

# Build the final table with Ik (Saturation point)
summary_table <- pmax_summary %>%
  left_join(alpha_summary, by = c("Scientific_Name", "Treatment")) %>%
  mutate(Ik = Pmax / Alpha) %>%
  mutate(across(where(is.numeric), ~round(., 3)))

print(summary_table)
write.csv(summary_table, "Algae_Summary_By_Treatment.csv", row.names = FALSE)

# 5. Visualization ----

# A. ETR vs PAR (Light Response Curves)
etr_curve_plot <- ggplot(etr_data, aes(x = PAR, y = Value, color = Treatment)) +
  geom_line(aes(group = interaction(Scientific_Name, Treatment)), linewidth = 0.7, alpha = 0.5) +
  geom_point(size = 1.5, alpha = 0.6) +
  facet_wrap(~Scientific_Name, scales = "free_y") +
  theme_bw() +
  labs(title = "Photosynthetic Response: ETR vs. PAR",
       x = "Light Intensity (PAR)", y = "Electron Transport Rate (ETR)") +
  theme(strip.text = element_text(face = "italic", size = 8))

print(etr_curve_plot)
ggsave("ETR_Curves_Per_Species.png", plot = etr_curve_plot, width = 14, height = 10)

# B. Y(II) vs PAR (Yield Curves)
# Showing how efficiency decreases as light intensity increases
yield_curve_plot <- ggplot(Photophysiology %>% filter(Parameter_Type == "Y(II)"), 
                           aes(x = PAR, y = Value, color = Treatment)) +
  geom_line(aes(group = interaction(Scientific_Name, Treatment)), size = 0.7, alpha = 0.5) +
  geom_point(size = 1.5, alpha = 0.6) +
  facet_wrap(~Scientific_Name, scales = "free_y") +
  theme_bw() +
  labs(title = "Photosynthetic Efficiency: Yield vs. PAR",
       x = "Light Intensity (PAR)", y = "Effective Quantum Yield (YII)") +
  theme(strip.text = element_text(face = "italic", size = 8))

print(yield_curve_plot)
ggsave("Yield_Curves_Per_Species.png", plot = yield_curve_plot, width = 14, height = 10)

# C. Yield Boxplot (Comparison of ranges)
# Showing the overall stress profile of each individual
yield_boxplot <- ggplot(Photophysiology %>% filter(Parameter_Type == "Y(II)"), 
                        aes(x = Scientific_Name, y = Value, fill = Treatment)) +
  geom_boxplot(alpha = 0.7, outlier.shape = NA) +
  geom_point(aes(color = Treatment), position = position_jitterdodge(jitter.width = 0.2), alpha = 0.4) +
  theme_minimal() +
  labs(title = "Yield Range Distribution: Dark vs. Light",
       x = "Species", y = "Quantum Yield (YII)") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, face = "italic"))

print(yield_boxplot)
ggsave("Yield_Range_Boxplot.png", plot = yield_boxplot, width = 12, height = 7)

# 6. Statistical Analysis (Paired T-test) ----
# Comparing Treatments across all 13 Species (N=13)

paired_data <- summary_table %>%
  select(Scientific_Name, Treatment, Pmax, Alpha) %>%
  pivot_wider(names_from = Treatment, values_from = c(Pmax, Alpha)) %>%
  filter(!is.na(Pmax_Dark) & !is.na(Pmax_Light))

# Test for Pmax differences
t_test_pmax <- t.test(paired_data$Pmax_Light, paired_data$Pmax_Dark, paired = TRUE)
print(t_test_pmax)

# Test for Alpha differences
t_test_alpha <- t.test(paired_data$Alpha_Light, paired_data$Alpha_Dark, paired = TRUE)
print(t_test_alpha)


save.image("Algae_Project_Workspace.RData")