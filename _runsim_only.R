# =============================================================================
# OSCE Simulation Study — Main Run Script
# =============================================================================

library(flextable)
library(ggplot2)

# -- Source all function files -------------------------------------------------
source_dir <- file.path(here::here(), "func")
invisible(lapply(list.files(source_dir, full.names = TRUE), source))

seed <- 42
set.seed(seed)

# =============================================================================
# Simulation Design
# =============================================================================

n_draws <- 10

# -- Base parameter set --------------------------------------------------------
params_homer2020 <- list(
  stations              = 6,
  candidates            = 300,
  examiners_per_station = 20,
  cand_distr_prop       = c(a = 39, b = 13),
  stations_distr_prop   = c(a = 62, b = 62),
  examiner_distr_prop   = c(a = 25, b = 25),
  error_distr_prop      = c(a = 5,  b = 5),
  cut_score             = 65,
  brm_intercept         = 45,
  brm_slope             = 20,
  brm_gr_passscore      = 1,
  examiner_slope_fact   = c(lo = 0.99, hi = 1.01),
  output_df             = "full"
)

# -- Run -----------------------------------------------------------------------
out <- lapply(seq_len(n_draws), function(i) {
  do.call(SimulateOSCE, c(list(nrun = i), params_homer2020))
})

# -- Analyse -------------------------------------------------------------------
analysis_res <- lapply(out, AnalyseOSCE, cut_method = "constant")
analysis_res <- do.call(rbind, analysis_res)

# -- Table: 5 sampled runs + mean across all 100 -------------------------------
TableOSCE(analysis_res, n_display = 5)
