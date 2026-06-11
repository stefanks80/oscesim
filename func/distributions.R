# =============================================================================
# OSCE Simulation: Distribution Sampling Functions
# =============================================================================
# These functions draw random effects for each facet of the G-theory model:
# candidates (true scores), examiners (stringency + slope), stations (difficulty),
# and residual error. All effects are mean-centred so the grand mean is preserved.
# =============================================================================


#' Draw candidate true scores from a Beta distribution
#'
#' @param n_cand   Number of candidates.
#' @param alpha    Alpha shape parameter of the Beta distribution.
#' @param beta     Beta  shape parameter of the Beta distribution.
#' @return A data.frame with columns \code{cand} (ID) and \code{true_score}.
CandDistr <- function(n_cand, alpha = 70, beta = 50) {
  true_scores <- rbeta(n_cand, alpha, beta)
  true_scores <- round(true_scores * 100, 1)

  n_digits  <- nchar(n_cand) - 1
  cand_ids  <- formatC(seq_len(n_cand), digits = n_digits, flag = "0")
  cand_ids  <- paste0("CAND-", cand_ids)

  data.frame(cand = cand_ids, true_score = true_scores)
}


#' Draw examiner stringency effects and slope modifiers
#'
#' Stringency effects are drawn from a Beta distribution and mean-centred.
#' Slope modifiers (leniency in mapping scores) are drawn from a Uniform.
#'
#' @param n_examiner        Number of examiners.
#' @param alpha             Alpha shape for stringency Beta distribution.
#' @param beta              Beta  shape for stringency Beta distribution.
#' @param slope_lower       Lower bound of Uniform for slope modifier.
#' @param slope_upper       Upper bound of Uniform for slope modifier.
#' @return A data.frame with columns \code{examiner}, \code{examiner_effect},
#'   and \code{ex_slope}.
ExaminerDistr <- function(n_examiner,
                          alpha       = 10,
                          beta        = 50,
                          slope_lower = 0.90,
                          slope_upper = 1.10) {
  # Mean-centred stringency effects (scaled to 0–100 metric)
  raw_effect       <- rbeta(n_examiner, alpha, beta)
  examiner_effect  <- round((mean(raw_effect) - raw_effect) * 100, 1)

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


#' Draw station difficulty effects from a Beta distribution
#'
#' @param n_station Number of stations.
#' @param alpha     Alpha shape parameter.
#' @param beta      Beta  shape parameter.
#' @return A data.frame with columns \code{station} and \code{station_effect}.
StationDistr <- function(n_station, alpha = 8, beta = 50) {
  raw_effect     <- rbeta(n_station, alpha, beta)
  station_effect <- round((mean(raw_effect) - raw_effect) * 100, 1)

  n_digits    <- nchar(n_station) - 1
  station_ids <- formatC(seq_len(n_station), digits = n_digits, flag = "0")
  station_ids <- paste0("STATION-", station_ids)

  data.frame(station = station_ids, station_effect = station_effect)
}


#' Draw residual (error) effects from a Beta distribution
#'
#' @param n_error  Number of error terms (= candidates × stations).
#' @param alpha    Alpha shape parameter.
#' @param beta     Beta  shape parameter.
#' @return A numeric vector of mean-centred error effects.
ErrorDistr <- function(n_error, alpha = 10, beta = 10) {
  raw_effect <- rbeta(n_error, alpha, beta)
  round((mean(raw_effect) - raw_effect) * 100, 1)
}
