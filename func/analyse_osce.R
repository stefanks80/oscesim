# =============================================================================
# OSCE Simulation: Analysis Function
# =============================================================================
# Fits a G-theory (mixed-effects) model to a simulated OSCE dataset and
# returns variance components, G/Phi coefficients, and score descriptives.
# =============================================================================


#' Analyse a simulated OSCE dataset using G-theory
#'
#' Fits a three-facet random-effects model:
#'   station_score ~ 1 + (1|cand) + (1|station) + (1|examiner)
#'
#' Returns a one-row data.frame with:
#' \itemize{
#'   \item Variance components (absolute and % of total) for each facet
#'   \item Eρ² (G-coefficient, relative decisions)
#'   \item Phi (absolute decisions)
#'   \item Mean and SD of candidate OSCE scores
#'   \item Pass rate (only if \code{osce_pass} column is present)
#' }
#'
#' @param osce_simdata A data.frame with columns \code{station_score},
#'   \code{osce_score}, \code{cand}, \code{station}, and \code{examiner}.
#'   If \code{osce_pass} is present, pass rate is also computed.
#' @return A one-row data.frame of analysis results.
AnalyseOSCE <- function(osce_simdata, cut_method = c("brm", "constant")) {
  cut_method <- match.arg(cut_method)

  # -- G-theory model ----------------------------------------------------------
  g_model    <- lme4::lmer(station_score ~ 1 + (1 | cand) + (1 | station) +
                             (1 | examiner), data = osce_simdata)
  n_stations <- length(unique(osce_simdata$station))

  vc           <- as.data.frame(lme4::VarCorr(g_model))
  var_cand     <- vc[vc$grp == "cand",     "vcov"]
  var_station  <- vc[vc$grp == "station",  "vcov"]
  var_examiner <- vc[vc$grp == "examiner", "vcov"]
  var_resid    <- vc[vc$grp == "Residual", "vcov"]
  var_total    <- var_cand + var_station + var_examiner + var_resid

  # -- Coefficients ------------------------------------------------------------
  # Eρ²: only residual contributes to relative error (facet means cancel)
  # Phi: all non-person variance contributes to absolute error
  rel_error <- var_resid / n_stations
  abs_error <- (var_station + var_examiner + var_resid) / n_stations

  g_coeff   <- var_cand / (var_cand + rel_error)
  phi_coeff <- var_cand / (var_cand + abs_error)

  sem_rel <- sqrt(rel_error)
  sem_abs <- sqrt(abs_error)

  # -- Score descriptives & classification accuracy ----------------------------
  cand_data <- unique(osce_simdata[, c("cand", "osce_score")])

  has_full <- all(c("osce_pass", "true_score", "osce_true_pass",
                    "constant_cut") %in% names(osce_simdata))

  if (has_full) {
    cand_full <- unique(osce_simdata[, c("cand", "osce_score", "true_score",
                                         "osce_pass", "osce_true_pass",
                                         "constant_cut")])
    if (cut_method == "brm") {
      fail_obs  <- cand_full$osce_score  < cand_full$osce_pass
      fail_true <- cand_full$true_score  < cand_full$osce_true_pass
    } else {
      fail_obs  <- cand_full$osce_score  < cand_full$constant_cut
      fail_true <- cand_full$true_score  < cand_full$constant_cut
    }

    tp <- sum( fail_true &  fail_obs)
    tn <- sum(!fail_true & !fail_obs)
    fp <- sum(!fail_true &  fail_obs)
    fn <- sum( fail_true & !fail_obs)

    n                    <- nrow(cand_full)
    nfail                <- sum(fail_obs)
    pass_rate            <- mean(!fail_obs)
    competent_fail       <- fp
    share_fail_competent <- if ((tp + fp) > 0) fp / (tp + fp) else NA_real_
    incompetent_pass     <- fn
    share_pass_notready  <- if ((fn + tn) > 0) fn / (fn + tn) else NA_real_
    accuracy             <- (tp + tn) / n
  } else {
    pass_rate            <- NA_real_
    competent_fail       <- NA_real_
    share_fail_competent <- NA_real_
    incompetent_pass     <- NA_real_
    share_pass_notready  <- NA_real_
    accuracy             <- NA_real_
  }

  # -- Output ------------------------------------------------------------------
  data.frame(
    var_cand     = round(var_cand,     2),
    var_station  = round(var_station,  2),
    var_examiner = round(var_examiner, 2),
    var_resid    = round(var_resid,    2),
    pct_cand     = round(100 * var_cand     / var_total, 1),
    pct_station  = round(100 * var_station  / var_total, 1),
    pct_examiner = round(100 * var_examiner / var_total, 1),
    pct_resid    = round(100 * var_resid    / var_total, 1),
    g_coeff      = round(g_coeff,   2),
    phi_coeff    = round(phi_coeff, 2),
    sem_rel      = round(sem_rel,   2),
    sem_abs      = round(sem_abs,   2),
    mean_osce    = round(mean(cand_data$osce_score), 1),
    sd_osce      = round(sd(cand_data$osce_score),   1),
    pass_rate            = round(pass_rate            * 100, 1),
    competent_fail       = round(competent_fail,           0),
    share_fail_competent = round(share_fail_competent * 100, 1),
    incompetent_pass     = round(incompetent_pass,         0),
    share_pass_notready  = round(share_pass_notready  * 100, 1),
    accuracy             = round(accuracy             * 100, 1)
  )
}
