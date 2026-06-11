# =============================================================================
# OSCE Simulation: Main Simulation Function
# =============================================================================
# SimulateOSCE() generates one complete synthetic OSCE dataset under a
# fully-crossed Generalizability Theory design (candidates × stations, with
# examiners nested within stations), then applies BRM standard-setting.
#
# Dependencies: distributions.R, scoring.R
# =============================================================================


#' Simulate one OSCE administration
#'
#' @param nrun                 Simulation run index (used for progress printing).
#' @param candidates           Number of candidates.
#' @param examiners_per_station Number of examiners per station.
#' @param stations             Number of stations.
#' @param cand_distr_prop      Named numeric vector \code{c(a, b)} for the
#'                             candidate true-score Beta distribution.
#' @param examiner_distr_prop  Named numeric vector \code{c(a, b)} for the
#'                             examiner stringency Beta distribution.
#' @param examiner_slope_fact  Named numeric vector \code{c(lo, hi)} for the
#'                             Uniform slope-modifier bounds.
#' @param stations_distr_prop  Named numeric vector \code{c(a, b)} for the
#'                             station difficulty Beta distribution.
#' @param error_distr_prop     Named numeric vector \code{c(a, b)} for the
#'                             residual error Beta distribution.
#' @param cut_score            Constant (administrative) cut-score for reference.
#' @param brm_intercept        BRM anchor: expected score for a borderline candidate.
#' @param brm_slope            BRM slope: score range per global-rating unit.
#' @param brm_gr_passscore     Global-rating value that defines the passing standard.
#' @param output_df            \code{"minimal"} returns key columns only;
#'                             any other value returns all columns.
#' @return A data.frame with one row per candidate–station observation.
SimulateOSCE <- function(
    nrun                  = 1,
    candidates            = 150,
    examiners_per_station = 5,
    stations              = 50,
    cand_distr_prop       = c(a = 50, b = 15),
    examiner_distr_prop   = c(a = 20, b = 20),
    examiner_slope_fact   = c(lo = 0.99, hi = 1.01),
    stations_distr_prop   = c(a = 15, b = 15),
    error_distr_prop      = c(a = 10, b = 10),
    cut_score             = 50,
    brm_intercept         = 30,
    brm_slope             = 20,
    brm_gr_passscore      = 1,
    output_df             = c("minimal", "full")
) {
  output_df <- match.arg(output_df)

  message("Running simulation: ", nrun)

  # -- Minimal output columns --------------------------------------------------
  min_vars <- c("cand", "examiner", "station",
                "station_effect", "examiner_effect", "error_effect",
                "true_score", "station_score", "osce_score")

  # ---------------------------------------------------------------------------
  # 1. Draw facet distributions
  # ---------------------------------------------------------------------------
  cand_df     <- CandDistr(candidates,
                           alpha = cand_distr_prop[["a"]],
                           beta  = cand_distr_prop[["b"]])

  n_examiners <- examiners_per_station * stations
  examiner_df <- ExaminerDistr(n_examiners,
                               alpha       = examiner_distr_prop[["a"]],
                               beta        = examiner_distr_prop[["b"]],
                               slope_lower = examiner_slope_fact[["lo"]],
                               slope_upper = examiner_slope_fact[["hi"]])

  station_df  <- StationDistr(stations,
                              alpha = stations_distr_prop[["a"]],
                              beta  = stations_distr_prop[["b"]])

  error_effect <- ErrorDistr(candidates * stations,
                             alpha = error_distr_prop[["a"]],
                             beta  = error_distr_prop[["b"]])

  # ---------------------------------------------------------------------------
  # 2. Build the G-theory design matrix
  #    Candidates are fully crossed with stations;
  #    examiners are nested within stations (randomly assigned, then recycled).
  # ---------------------------------------------------------------------------
  osce_design <- expand.grid(cand    = cand_df$cand,
                             station = station_df$station)

  # Assign and recycle examiners within each station
  examiner_matrix <- matrix(sample(examiner_df$examiner), ncol = stations)
  colnames(examiner_matrix) <- station_df$station

  examiner_long <- utils::stack(
    as.data.frame(
      apply(examiner_matrix, 2, rep_len, candidates)
    )
  )
  osce_design$examiner <- examiner_long$values

  # ---------------------------------------------------------------------------
  # 3. Merge facet effects and compute observed station scores
  # ---------------------------------------------------------------------------
  osce_design <- merge(osce_design, station_df,  by = "station")
  osce_design <- merge(osce_design, examiner_df, by = "examiner")
  osce_design <- merge(osce_design, cand_df,     by = "cand")
  osce_design$error_effect <- error_effect

  osce_design$station_score <- with(osce_design,
    true_score + station_effect + examiner_effect + error_effect
  )

  # ---------------------------------------------------------------------------
  # 4. Aggregate to OSCE total score
  # ---------------------------------------------------------------------------
  osce_mean <- aggregate(station_score ~ cand, data = osce_design, FUN = mean)
  names(osce_mean)[2] <- "osce_score"
  osce_design <- merge(osce_design, osce_mean, by = "cand")
  osce_design$osce_score <- round(osce_design$osce_score, 1)

  # ---------------------------------------------------------------------------
  # 5. Calculate global (BRM) ratings and apply standard-setting
  # ---------------------------------------------------------------------------
  station_examiner_list <- split(osce_design,
                                 f = paste(osce_design$examiner,
                                           osce_design$station))

  global_scores <- lapply(station_examiner_list,
                          CalcGlobalLm,
                          reg_intercept = brm_intercept,
                          reg_slope     = brm_slope)

  osce_with_global <- do.call(rbind,
                              mapply(cbind, station_examiner_list, global_scores,
                                     SIMPLIFY = FALSE))

  station_list <- split(osce_with_global, f = osce_with_global$station)
  station_list <- lapply(station_list,
                         StandardSetting,
                         brm_pass_level = brm_gr_passscore)

  # ---------------------------------------------------------------------------
  # 6. Compute OSCE pass score and add reference values
  # ---------------------------------------------------------------------------
  osce_out <- CalcOscePass(do.call(rbind, station_list))
  osce_out$osce_true_pass <- brm_intercept + (brm_slope * brm_gr_passscore)
  osce_out$constant_cut   <- cut_score
  row.names(osce_out)     <- NULL

  if (output_df == "minimal") osce_out <- osce_out[, min_vars]

  osce_out
}
