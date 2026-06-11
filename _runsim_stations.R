# =============================================================================
# Simulation Study: Effect of Number of Stations
# =============================================================================
# Varies number of stations (6, 18, 35) across 1000 replications each and
# produces a summary comparison table.
# =============================================================================

source_dir <- file.path(here::here(), "func")
invisible(lapply(list.files(source_dir, full.names = TRUE), source))

library(flextable)
library(officer)

set.seed(42)

# =============================================================================
# Design
# =============================================================================

station_conditions <- c(6, 12, 18, 24, 48)
n_runs             <- 1000

params <- list(
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

# =============================================================================
# Run simulations
# =============================================================================

results_list <- lapply(station_conditions, function(n_st) {

  message("\n--- Running condition: ", n_st, " stations ---")
  params_cond <- modifyList(params, list(stations = n_st))

  out <- suppressMessages(
    lapply(seq_len(n_runs), function(i) {
      do.call(SimulateOSCE, c(list(nrun = i), params_cond))
    })
  )

  analysis <- lapply(out, AnalyseOSCE)
  do.call(rbind, analysis)
})

names(results_list) <- paste0(station_conditions, " stations")

# =============================================================================
# Per-condition tables (10 sampled runs + mean across all runs)
# =============================================================================

invisible(lapply(names(results_list), function(nm) {
  fname <- paste0("table_osce_", gsub(" ", "_", nm), ".docx")
  set.seed(which(names(results_list) == nm))
  TableOSCE(results_list[[nm]], n_display = 10,
            title     = paste("OSCE simulation results —", nm),
            docx_file = fname)
}))

# =============================================================================
# Cross-condition comparison table
# =============================================================================

TableOSCEConditions(results_list, docx_file = "table_comparisons.docx")
