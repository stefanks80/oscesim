# =============================================================================
# OSCE Simulation: Distribution Sampling Functions — Normal Distribution Variant
# =============================================================================
# Drop-in replacement for func/distributions.R. Function signatures are
# identical so SimulateOSCE() works without changes. Parameter semantics differ:
#
#   alpha  →  mean  (formerly Beta alpha shape)
#   beta   →  sd    (formerly Beta beta  shape)
#
# For CandDistr, alpha/beta are the mean and sd of candidate true scores on
# the 0–100 scale. For the effect distributions (examiner, station, error),
# only beta (sd) matters because effects are mean-centred; alpha is accepted
# but ignored.
# =============================================================================


#' Draw candidate true scores from a Normal distribution
#'
#' @param n_cand   Number of candidates.
#' @param alpha    Mean of the Normal distribution (0–100 scale).
#' @param beta     Standard deviation of the Normal distribution.
#' @return A data.frame with columns \code{cand} (ID) and \code{true_score}.
CandDistr <- function(n_cand, alpha = 75, beta = 10) {
  true_scores <- rnorm(n_cand, mean = alpha, sd = beta)
  true_scores <- round(true_scores, 1)

  n_digits  <- nchar(n_cand) - 1
  cand_ids  <- formatC(seq_len(n_cand), digits = n_digits, flag = "0")
  cand_ids  <- paste0("CAND-", cand_ids)

  data.frame(cand = cand_ids, true_score = true_scores)
}


#' Draw examiner stringency effects and slope modifiers
#'
#' Stringency effects are drawn from a Normal distribution and mean-centred.
#' Slope modifiers (leniency in mapping scores) are drawn from a Uniform.
#'
#' @param n_examiner        Number of examiners.
#' @param alpha             Ignored (effects are mean-centred at zero).
#' @param beta              SD of the Normal stringency distribution (score units).
#' @param slope_lower       Lower bound of Uniform for slope modifier.
#' @param slope_upper       Upper bound of Uniform for slope modifier.
#' @return A data.frame with columns \code{examiner}, \code{examiner_effect},
#'   and \code{ex_slope}.
ExaminerDistr <- function(n_examiner,
                          alpha       = 0,
                          beta        = 5,
                          slope_lower = 0.90,
                          slope_upper = 1.10) {
  # Mean-centred stringency effects
  raw_effect      <- rnorm(n_examiner, mean = 0, sd = beta)
  examiner_effect <- round(raw_effect - mean(raw_effect), 1)

  # Slope modifier (how steeply each examiner uses the rating scale)
  ex_slope <- round(runif(n_examiner, slope_lower, slope_upper), 2)

  # Examiner IDs
  n_digits     <- nchar(n_examiner) - 1
  examiner_ids <- formatC(seq_len(n_examiner), digits = n_digits, flag = "0")
  examiner_ids <- paste0("EXAMINER-", examiner_ids)

  data.frame(examiner = examiner_ids,
             examiner_effect = examiner_effect,
             ex_slope = ex_slope)
}


#' Draw station difficulty effects from a Normal distribution
#'
#' @param n_station Number of stations.
#' @param alpha     Ignored (effects are mean-centred at zero).
#' @param beta      SD of the Normal difficulty distribution (score units).
#' @return A data.frame with columns \code{station} and \code{station_effect}.
StationDistr <- function(n_station, alpha = 0, beta = 5) {
  raw_effect     <- rnorm(n_station, mean = 0, sd = beta)
  station_effect <- round(raw_effect - mean(raw_effect), 1)

  n_digits    <- nchar(n_station) - 1
  station_ids <- formatC(seq_len(n_station), digits = n_digits, flag = "0")
  station_ids <- paste0("STATION-", station_ids)

  data.frame(station = station_ids, station_effect = station_effect)
}


#' Draw residual (error) effects from a Normal distribution
#'
#' @param n_error  Number of error terms (= candidates × stations).
#' @param alpha    Ignored (effects are mean-centred at zero).
#' @param beta     SD of the Normal error distribution (score units).
#' @return A numeric vector of mean-centred error effects.
ErrorDistr <- function(n_error, alpha = 0, beta = 10) {
  raw_effect <- rnorm(n_error, mean = 0, sd = beta)
  round(raw_effect - mean(raw_effect), 1)
}
