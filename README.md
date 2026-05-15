# Algae Photophysiology Analysis - Mediterranean Species (2026)

## Project Overview
This study evaluates the photosynthetic performance of 13 Israeli Mediterranean algae species under two physiological states: **Dark-adapted** and **Light-adapted**. Using Pulse Amplitude Modulation (PAM) fluorometry and Rapid Light Curves (RLC), we analyzed the Electron Transport Rate (ETR) and Quantum Yield (YII) to determine if short-term light exposure induces significant physiological shifts or photoinhibition.

---

## 1. Parameters and Units
The following parameters were extracted and analyzed. A detailed Excel version of this documentation is available in the `/data` directory.

| Parameter | Units | Description |
| :--- | :--- | :--- |
| **PAR** | $\mu mol\ photons\ m^{-2} s^{-1}$ | Photosynthetically Active Radiation (Light intensity). |
| **ETR** | $\mu mol\ electrons\ m^{-2} s^{-1}$ | Electron Transport Rate - measures the rate of photosynthesis. |
| **Y(II)** | Dimensionless (0-1) | Effective Quantum Yield of Photosystem II (Efficiency). |
| **Alpha ($\alpha$)** | $electrons / photons$ | Initial slope of the curve; represents light-harvesting efficiency. |
| **$P_{max}$** | $\mu mol\ electrons\ m^{-2} s^{-1}$ | Maximum Electron Transport Rate (Photosynthetic capacity). |
| **$I_k$** | $\mu mol\ photons\ m^{-2} s^{-1}$ | Light saturation point ($P_{max} / \alpha$). |

---

## 2. Materials and Methods

### Data Processing
Raw data from `dark.csv` and `light.csv` were tidied into a long-format master dataset using R. Column headers were standardized to resolve character encoding issues (e.g., converting `Y.II` back to `Y(II)`). Missing values were filtered to ensure analysis integrity.

### Statistical Analysis
Since each species was represented by a single individual ($N=1$), the species were treated as biological replicates to test the overall effect of light treatment. 
* **Paired T-tests** were performed on the extracted parameters ($P_{max}$ and Alpha) for $N=8$ complete species pairs.
* **Assumptions:** Normality was visually assessed using QQ-plots.

### Software and Reproducibility
* **R Version:** 4.3.1
* **RStudio Version** 2026.04.0+526 
* **Key Packages:** `dplyr`, `tidyr`, `ggplot2`, `rstatix`, `broom`, `purrr`.
* Full session information, including exact package versions, is documented in: [R_Session_Package_Versions.txt](./Output/R_Session_Package_Versions.txt).

---

## 3. Results

### Figure 1: Photosynthetic Capacity (ETR vs. PAR)
![ETR Curves](./Output/ETR_Curves_Per_Species.png)
*Legend: Rapid Light Curves (RLC) showing the Electron Transport Rate (ETR) as a function of light intensity (PAR). Trends compare Dark-adapted (Red) vs. Light-adapted (Blue) states across 13 species. Most species exhibit standard saturation kinetics.*

### Figure 2: Photosynthetic Efficiency (Yield vs. PAR)
![Yield Curves](./Output/Yield_Curves_Per_Species.png)
*Legend: Effective Quantum Yield (YII) as a function of PAR. This graph illustrates the progressive decline in efficiency as light intensity increases, indicating the dynamic downregulation of Photosystem II.*

### Figure 3: Yield Range Distribution
![Yield Boxplot](./Output/Yield_Range_Boxplot.png)
*Legend: Boxplots representing the distribution of Quantum Yield values across all PAR levels. This visualization highlights the inter-specific variability and the overall spread of physiological efficiency during the experiment.*

---

## 4. Interpretation and Conclusions

### Statistical Findings
The Paired T-test analysis revealed **no significant differences** between Dark and Light treatments for both photosynthetic capacity and efficiency:
* **Photosynthetic Capacity ($P_{max}$):** $t(7) = 0.502, p = 0.631$.
* **Light-harvesting Efficiency ($\alpha$):** $t(7) = -0.145, p = 0.889$.
* **Saturation Point ($I_k$):** Saturation levels remained consistent across treatments, reflecting stable metabolic thresholds.

### Conclusions

1. **Physiological Robustness:** The primary photosynthetic machinery of the tested Mediterranean algae is highly robust to short-term light adaptation. The stability of $P_{max}$ and Alpha indicates that the "Light" treatment did not fundamentally alter the primary energy-conversion capacity of the organisms.
  
2. **Dynamic Downregulation vs. Chronic Damage:** While a decline in Yield (YII) was observed as light intensity increased (Figure 2), the lack of a significant drop in $P_{max}$ suggests this was a **dynamic, reversible downregulation** rather than chronic photo-oxidative damage. This reflects an effective photoprotective strategy common in intertidal species.

3. **Interspecific Variability:** The non-significant group-level result is likely driven by high inter-specific variability. The wide range of responses seen in the Yield data (Figure 3) reflects the diverse ecological niches these species occupy, suggesting that species identity is a stronger predictor of photosynthetic performance than the specific adaptation treatment used in this trial.

4. **Limitations:** Given the sample size ($N=8$ complete species pairs), the study provides a robust overview of general trends, though subtle species-specific adaptations might require further replicates to achieve statistical significance.

---

## Repository Structure
* `/Raw_Data`: Raw CSV files.
* `/scripts`: Final R script for analysis and visualization.
* `/Output`: Processed CSV/Excel files, High-resolution graphs, statistical results, and R Environment.

