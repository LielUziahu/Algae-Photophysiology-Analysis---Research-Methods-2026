#Research_methods_2026
# Photophysiology- 2nd attempt

# requried libraries. if any gives you an error, you need to install it.
# installation- Tools,Install packages, choose name of package, install.
library(dplyr) # data manipulation
library(lubridate) # format date data
library(hms) # format time data
library(tidyr) # data manipulation
library(ggplot2) # graphics
library(purrr) # data manipulation
library(broom) # data manipulation
library(patchwork)# graphics


# set the working directory
## you will need to change the path to the one in which you want to work


#load metadata
metadata=read.csv("Photophysiology_metadata.csv", header=TRUE)
str(metadata)


#load photophysiology data_group light
light_PAM=read.csv("light.csv", header=TRUE, sep=";")
str(light_PAM) #inspect the data

# let us change the date and time variables to read as date and time.
library(lubridate)
light_PAM$Date <- dmy(light_PAM$Date)
library(hms)
light_PAM$Time <- as_hms(light_PAM$Time)

#check that it worked
str(light_PAM)

# we will now select the relevant columns from the dataset. i.e., the ETR measurments.
light_ETR <- light_PAM[, c("Date", "Time", "PAR", "ETR1","ETR2","ETR3","ETR4","ETR5","ETR6","ETR7","ETR8","ETR9","ETR10","ETR11","ETR12","ETR13")]
str(light_ETR)

# change format from wide to long
library(dplyr)
library(tidyr)
light_ETR_long <- light_ETR %>%  pivot_longer(., cols = starts_with("ETR"), names_to = "Sample")
colnames(light_ETR_long)[5] ="ETR"
str(light_ETR_long)


# add information on the sample
str(metadata)
metadata_light=metadata[metadata$Group=="Light",]
metadata_light$ETR_name=paste("ETR",metadata_light$Sample, sep="")

light_ETR_long$Sample_ID=metadata_light$Sample_ID[match(light_ETR_long$Sample, metadata_light$ETR_name)]
light_ETR_long$Taxon=metadata_light$Taxon[match(light_ETR_long$Sample, metadata_light$ETR_name)]
str(metadata)

# take a first look at the data

library(ggplot2)
light_ETR_long %>%
  ggplot(aes(x=PAR, y=ETR, color=Sample_ID))+
  geom_point()+
  geom_line()+
  facet_wrap("Taxon")+
  theme_bw()


# when ETR hits zero at PAR >0, the measurment had ended, i.e., not relevant anymore.
#therefore, we need to remove all zero values for ETR >0

light_ETR_long$ETR[light_ETR_long$ETR == 0 & light_ETR_long$PAR > 0] <- NA

# take a look now

library(ggplot2)
light_ETR_long %>%
  ggplot(aes(x=PAR, y=ETR, color=Sample_ID))+
  geom_point()+
  geom_line()+
  facet_wrap("Taxon")+
  theme_bw()

# what sampled do we want to remove? ones that do not reach expected curve.
light_ETR_long_filt=light_ETR_long[light_ETR_long$Sample_ID!="Light_3" & light_ETR_long$Sample_ID!="Light_9",]

str(light_ETR_long_filt)
unique(light_ETR_long_filt$Sample_ID)

# now we will fit curves to the actual data
#Start by estimating the curve parameters by non-linear least squares method
# from the fitted curve we get the parameters of aquatic photosynthesis we wanted (following the word of the great Falkowski):
# Am = asymptotic maximum = Pmax= max photosynthesis
# AQY = initial sloap = alpha = Fv/Fm
# Rd =  the y intercept of the curve = dark respiration
# Ik = Am/AQY, the irradiance level at which  photosynthesis transitions from light-limited to saturation-limited.


# we will first calculate these parameters for the entire dataset.
set.seed(123) #Random Number Generation important whan the process/calculation is iterative. if you change it, you may get different results....

light_ETR_pi <- light_ETR_long_filt %>% subset(PAR<600) 
curve.nlsPIC <- light_ETR_pi %>% nls(ETR ~ (Am*((AQY*PAR)/(sqrt(Am^2 + (AQY*PAR)^2)))-Rd), data=., start=list(Am=0.7,  AQY=0.001, Rd=.4))
coef(curve.nlsPIC)
plot(ETR ~ PAR, data = light_ETR_pi)
lines(0:600,
      predict(curve.nlsPIC,
              newdata = data.frame(PAR = 0:600)))


# now we will calculate the parameters for each and every sample

library(purrr)
library(broom)

light_nls_data <- light_ETR_pi %>%
  group_by(Sample_ID) %>%
  nest(-Sample_ID) %>%
  mutate(model1 = map(data, ~
                        nls(ETR ~ (Am*((AQY*PAR)/(sqrt(Am^2 + (AQY*PAR)^2)))-Rd), data=., start=list(Am=0.7,  AQY=0.001, Rd=.4)) %>%
                        tidy %>%
                        dplyr::select(term, estimate) %>%
                        spread(term, estimate))) %>%
  unnest(model1) %>%
  mutate(Ik = Am/AQY)


colnames(light_nls_data)
write.csv(light_nls_data[,-c(2)], "light_group_photo_parameters.csv")

augmented_light <- light_ETR_pi %>%
  filter(PAR <600) %>%
  nest(-Sample_ID) %>% 
  mutate(
    fit = map(data, ~ nls(ETR ~ (Am*((AQY*PAR)/(sqrt(Am^2 + (AQY*PAR)^2)))-Rd), data=., start=list(Am=0.7,  AQY=0.001, Rd=.4))),
    augmented = map(fit, augment),
  ) %>% 
  unnest(augmented)

augmented_light$ID = augmented_light$Sample_ID
augmented_light$Taxon = metadata_light$Taxon[match(augmented_light$Sample_ID, metadata_light$Sample_ID)]


PI.curves_light <- augmented_light %>%
  ggplot(aes(x=PAR, y=ETR, color=Taxon))+
  geom_point() + 
  geom_line(aes(y=.fitted, x=PAR,group=Sample_ID))+
  theme_classic()+
  ylim(0,50)+
  labs(x = expression(paste('PAR (', mu, "mol photons m"^-2, 's'^-1,")")),
       y = expression(paste("ETR")),
       title = "Light")+
  theme(legend.position = "right")#+
#facet_wrap(.~Taxon)
PI.curves_light


##########################
#load photophysiology data_group dark
dark_PAM=read.csv("dark.csv", header=TRUE, sep=";")
str(dark_PAM) #inspect the data

# let us change the date and time variables to read as date and time.
library(lubridate)
dark_PAM$Date <- dmy(dark_PAM$Date)
library(hms)
dark_PAM$Time <- as_hms(dark_PAM$Time)

#check that it worked
str(dark_PAM)

# we will now select the relevant columns from the dataset. i.e., the ETR measurments.
dark_ETR <- dark_PAM[, c("Date", "Time", "PAR", "ETR1","ETR2","ETR3","ETR4","ETR5","ETR6","ETR7","ETR8")]
str(dark_ETR)

# change format from wide to long
library(dplyr)
library(tidyr)
dark_ETR_long <- dark_ETR %>%  pivot_longer(., cols = starts_with("ETR"), names_to = "Sample")
colnames(dark_ETR_long)[5] ="ETR"
str(dark_ETR_long)


# add information on the sample
str(metadata)
metadata_dark=metadata[metadata$Group=="Dark",]
metadata_dark$ETR_name=paste("ETR",metadata_dark$Sample, sep="")
str(metadata_dark)

dark_ETR_long$Sample_ID=metadata_dark$Sample_ID[match(dark_ETR_long$Sample, metadata_dark$ETR_name)]
dark_ETR_long$Taxon=metadata_dark$Taxon[match(dark_ETR_long$Sample, metadata_dark$ETR_name)]
str(dark_ETR_long)

# take a first look at the data

library(ggplot2)
dark_ETR_long %>%
  ggplot(aes(x=PAR, y=ETR, color=Sample_ID))+
  geom_point()+
  geom_line()+
  facet_wrap("Taxon")+
  theme_bw()


# when ETR hits zero at PAR >0, the measurment had ended, i.e., not relevant anymore.
#therefore, we need to remove all zero values for ETR >0

dark_ETR_long$ETR[dark_ETR_long$ETR == 0 & dark_ETR_long$PAR > 0] <- NA
str(dark_ETR_long)

# take a look now

library(ggplot2)
dark_ETR_long %>%
  ggplot(aes(x=PAR, y=ETR, color=Sample_ID))+
  geom_point()+
  geom_line()+
  facet_wrap("Taxon")+
  theme_bw()

# what sampled do we want to remove? ones that do not reach expected curve.
#do we remove anything here?
#dark_ETR_long_filt=dark_ETR_long[dark_ETR_long$Sample_ID!="??" & dark_ETR_long$Sample_ID!="??",]


unique(dark_ETR_long$Sample_ID)

# fit curves to the actual data
# Estimating the curve parameters by non-linear least squares method
# from the fitted curve we get the parameters of aquatic photosynthesis we wanted:
# Am = asymptotic maximum = Pmax= max photosynthesis
# AQY = initial sloap = alpha = Fv/Fm
# Rd =  the y intercept of the curve = dark respiration
# Ik = Am/AQY, the irradiance level at which  photosynthesis transitions from light-limited to saturation-limited.


# we will first calculate these parameters for the entire dataset.
set.seed(123) #Random Number Generation important whan the process/calculation is iterative.

dark_ETR_pi <- dark_ETR_long %>% subset(PAR<600) 
curve.nlsPIC <- dark_ETR_pi %>% nls(ETR ~ (Am*((AQY*PAR)/(sqrt(Am^2 + (AQY*PAR)^2)))-Rd), data=., start=list(Am=0.7,  AQY=0.001, Rd=.4))
coef(curve.nlsPIC)
plot(ETR ~ PAR, data = dark_ETR_pi)
lines(0:600,
      predict(curve.nlsPIC,
              newdata = data.frame(PAR = 0:600)))


# now we will calculate the parameters for each and every sample

library(purrr)
library(broom)

dark_nls_data <- dark_ETR_pi %>%
  group_by(Sample_ID) %>%
  nest(-Sample_ID) %>%
  mutate(model1 = map(data, ~
                        nls(ETR ~ (Am*((AQY*PAR)/(sqrt(Am^2 + (AQY*PAR)^2)))-Rd), data=., start=list(Am=0.7,  AQY=0.001, Rd=.4)) %>%
                        tidy %>%
                        dplyr::select(term, estimate) %>%
                        spread(term, estimate))) %>%
  unnest(model1) %>%
  mutate(Ik = Am/AQY)


colnames(dark_nls_data)
write.csv(dark_nls_data[,-c(2)], "dark_group_photo_parameters.csv")

augmented_dark <- dark_ETR_pi %>%
  filter(PAR <600) %>%
  nest(-Sample_ID) %>% 
  mutate(
    fit = map(data, ~ nls(ETR ~ (Am*((AQY*PAR)/(sqrt(Am^2 + (AQY*PAR)^2)))-Rd), data=., start=list(Am=0.7,  AQY=0.001, Rd=.4))),
    augmented = map(fit, augment),
  ) %>% 
  unnest(augmented)

augmented_dark$ID = augmented_dark$Sample_ID
augmented_dark$Taxon = metadata_dark$Taxon[match(augmented_dark$Sample_ID, metadata_dark$Sample_ID)]


PI.curves_dark <- augmented_dark %>%
  ggplot(aes(x=PAR, y=ETR, color=Taxon))+
  geom_point() + 
  geom_line(aes(y=.fitted, x=PAR,group=Sample_ID))+
  theme_classic()+
  ylim(0,50)+
  labs(x = expression(paste('PAR (', mu, "mol photons m"^-2, 's'^-1,")")),
       y = expression(paste("ETR")),
       title = "Dark")+
  theme(legend.position = "right")#+
#facet_wrap(.~Taxon)
PI.curves_dark



library(patchwork)
PI.curves_light+PI.curves_dark



### fix limits to dark group data- to reduce miss-fit ?
# needs to be at Taxon level.


# Collect all the estimated parameters for all samples.
str(light_nls_data)
str(dark_nls_data)

nls_data=as.data.frame(rbind(light_nls_data, dark_nls_data))
nls_data=nls_data[,-c(2)]
str(nls_data)

nls_data$Taxon=metadata$Taxon[match(nls_data$Sample_ID, metadata$Sample_ID)]
nls_data$Group=metadata$Group[match(nls_data$Sample_ID, metadata$Sample_ID)]
str(nls_data)
nls_data_long=nls_data %>%
  pivot_longer(
    cols = c(Am, AQY, Rd, Ik),
    names_to = "Photo_vars",
    values_to = "Value"
  )
str(nls_data_long)

# Let's summarize the data to see what's what.

Photophysiology_summary_table <- nls_data_long %>%
  group_by(Photo_vars, Group) %>%
  summarise(
    n       = sum(!is.na(Value)),
    mean    = mean(Value, na.rm = TRUE),
    sd      = sd(Value, na.rm = TRUE),
    min     = min(Value, na.rm = TRUE),
    q25     = quantile(Value, 0.25, na.rm = TRUE),
    median  = median(Value, na.rm = TRUE),
    q75     = quantile(Value, 0.75, na.rm = TRUE),
    max     = max(Value, na.rm = TRUE),
    .groups = "drop"
  )

View(Photophysiology_summary_table)


library(ggplot2)


ggplot(nls_data_long, aes(sample = Value, color = Group)) +
  stat_qq() +
  stat_qq_line() +
  ylab("Value")+
  xlab("theoretical quantile")+
  facet_wrap(~Photo_vars, scales = "free")


ggplot(nls_data_long, aes(x=Group, y=Value))+
  geom_boxplot()+
  geom_point(aes(color=Group), size=2, position=position_jitter(width=0.2))+
  facet_wrap(~Photo_vars, scales = "free")


ggplot(nls_data_long, aes(x=Group, y=Value))+
  geom_boxplot()+
  geom_point(aes(color=Taxon), size=2, position=position_jitter(width=0.2))+
  facet_wrap(~Photo_vars, scales = "free")

# filter unpaired taxa
library(dplyr)

nls_data_long_filtered <- nls_data_long %>%
  group_by(Taxon) %>%
  filter(n_distinct(Group) == 2) %>%
  ungroup()

ggplot(nls_data_long_filtered, aes(x=Group, y=Value))+
  geom_boxplot()+
  geom_point(aes(color=Taxon), size=2, position=position_jitter(width=0.2))+
  facet_wrap(~Photo_vars, scales = "free")

# calculate the difference between light and dark for each species

library(dplyr)
library(tidyr)

diff_by_taxon <-nls_data_long_filtered %>%
  group_by(Taxon, Photo_vars, Group) %>%
  summarise(
    Value = mean(Value, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from = Group,
    values_from = Value
  ) %>%
  mutate(
    Difference = Light- Dark,
    Ratio= Light/ Dark
  )

str(diff_by_taxon)

Difference_plot=ggplot(diff_by_taxon, aes(x=Taxon, y=Difference))+
  geom_bar(stat="identity", aes(fill=Taxon))+
  facet_wrap(.~Photo_vars, scales="free")+
  theme_bw()
Difference_plot


Ratio_plot=ggplot(diff_by_taxon, aes(x=Taxon, y=Ratio))+
  geom_bar(stat="identity", aes(fill=Taxon))+
  geom_hline(yintercept = 1,linetype = "dashed",color = "red",linewidth = 0.8)+
  facet_wrap(.~Photo_vars, scales="free")+
  theme_bw()
Ratio_plot


Difference_plot+Ratio_plot


ggplot(diff_by_taxon, aes(sample = Difference)) +
  stat_qq() +
  stat_qq_line() +
  ylab("Value")+
  xlab("theoretical quantile")+
  facet_wrap(~Photo_vars, scales = "free")

library(dplyr)

test_paired <- nls_data_long_filtered %>%
  select(Taxon, Group, Photo_vars, Value) %>%
  pivot_wider(
    names_from = Group,
    values_from = Value
  ) %>%
  group_by(Photo_vars) %>%
  summarise(
    p = wilcox.test(Light, Dark, paired = TRUE)$p.value,
    .groups = "drop"
  ) %>%
  mutate(
    padj = p.adjust(p, method = "BH")
  )

test_paired 

test_paired_no_Colpomenia <- nls_data_long_filtered[nls_data_long_filtered$Taxon!="Colpomenia",] %>%
  select(Taxon, Group, Photo_vars, Value) %>%
  pivot_wider(
    names_from = Group,
    values_from = Value
  ) %>%
  group_by(Photo_vars) %>%
  summarise(
    p = wilcox.test(Light, Dark, paired = TRUE)$p.value,
    .groups = "drop"
  ) %>%
  mutate(
    padj = p.adjust(p, method = "BH")
  )
test_paired_no_Colpomenia


# ==============================================================
# FINAL IMAGE EXPORT STACK - ATTACH TO THE END OF YOUR SCRIPT
# ==============================================================

message("Starting high-resolution export (600 DPI)...")

# 1. Save the Fitted Photosynthesis-Irradiance (P-I) Curves (Light adapted)
if (exists("PI.curves_light")) {
  ggsave(
    filename = "Figure_1_PI_Curves_Light_Adapted_600DPI.png",
    plot = PI.curves_light,
    dpi = 600, width = 12, height = 8, units = "in"
  )
}

# 2. Save the Fitted Photosynthesis-Irradiance (P-I) Curves (Dark adapted)
if (exists("PI.curves_dark")) {
  ggsave(
    filename = "Figure_2_PI_Curves_Dark_Adapted_600DPI.png",
    plot = PI.curves_dark,
    dpi = 600, width = 12, height = 8, units = "in"
  )
}

# 3. Save the Absolute Difference Bar Plot
if (exists("Difference_plot")) {
  ggsave(
    filename = "Figure_3_Algae_Difference_Plot_600DPI.png",
    plot = Difference_plot,
    dpi = 600, width = 11, height = 7, units = "in"
  )
}

# 4. Save the Proportional Response Ratio Bar Plot
if (exists("Ratio_plot")) {
  ggsave(
    filename = "Figure_4_Algae_Ratio_Plot_600DPI.png",
    plot = Ratio_plot,
    dpi = 600, width = 11, height = 7, units = "in"
  )
}

# 5. Save the Combined Patchwork Panel (Difference + Ratio side-by-side)
if (exists("Difference_plot") & exists("Ratio_plot")) {
  combined_panel <- Difference_plot + Ratio_plot
  ggsave(
    filename = "Figure_5_Algae_Combined_Panel_600DPI.png",
    plot = combined_panel,
    dpi = 600, width = 18, height = 10, units = "in"
  )
}

# 6. Re-run and Save the Final Quantile-Quantile (Q-Q) Plot for Methods section
if (exists("diff_by_taxon")) {
  qq_output <- ggplot(diff_by_taxon, aes(sample = Difference)) +
    stat_qq() +
    stat_qq_line() +
    ylab("Value") +
    xlab("Theoretical Quantile") +
    facet_wrap(~Photo_vars, scales = "free") +
    theme_bw()
  
  ggsave(
    filename = "Figure_6_Normality_QQ_Plot_600DPI.png",
    plot = qq_output,
    dpi = 600, width = 10, height = 7, units = "in"
  )
}

message("All relevant plots saved to your folder in 600 DPI.")


# 7. EXPORT SOFTWARE AND PACKAGE VERSIONS FOR REPRODUCIBILITY

# 7.1. Capture and save the complete session environment details (R version, OS, loaded apps)
sink("R_software_and_package_versions.txt")
cat("==============================================================\n")
cat("RESEARCH METHODS 2026 - PHOTOPHYSIOLOGY SYSTEM VERSIONS LOG\n")
cat("Generated on:", as.character(Sys.time()), "\n")
cat("==============================================================\n\n")
print(sessionInfo())
sink()

# 7.2. Compile a clean, structured table for the core project packages
core_project_packages <- c("dplyr", "tidyr", "purrr", "broom", "rstatix", 
                           "ggplot2", "patchwork", "lubridate", "hms", "writexl")

package_versions_table <- data.frame(
  Package_Name = core_project_packages,
  Version = sapply(core_project_packages, function(pkg) {
    if (requireNamespace(pkg, quietly = TRUE)) as.character(packageVersion(pkg)) else "Not Loaded"
  }),
  stringsAsFactors = FALSE
)

# 7.3. Export the structured package list into a clean CSV file
write.csv(package_versions_table, "Detailed_Package_Versions_List.csv", row.names = FALSE)

# 7.4 Print confirmation message to the R console
message("Success! 'R_software_and_package_versions.txt' and 'Detailed_Package_Versions_List.csv' have been saved to your working directory.")
# ==============================================================
