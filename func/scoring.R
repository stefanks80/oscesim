# =============================================================================
# OSCE Simulation: Scoring & Standard-Setting Functions
# =============================================================================
# Functions that convert raw station scores to global ratings (BRM), apply
# standard-setting via regression, determine pass/fail, and compute accuracy.
# =============================================================================


#' Convert station scores to global ratings using a linear BRM mapping
#'
#' Applies a per-examiner slope modifier so that idiosyncratic scale usage is
#' reflected in the global rating.
#'
#' @param df            A data.frame for a single examiner–station combination.
#' @param score_var     Name of the column holding station scores.
#' @param reg_intercept Expected score for a borderline candidate (BRM anchor).
#' @param reg_slope     Score range mapped to one global-rating unit.
#' @param slope_var     Name of the examiner slope-modifier column.
#' @return A data.frame with one column \code{station_global}.
CalcGlobalLm <- function(df,
                         score_var     = "station_score",
                         reg_intercept,
                         reg_slope,
                         slope_var     = "ex_slope") {
  adjusted_slope <- reg_slope * df[[slope_var]]
  global         <- (df[[score_var]] - reg_intercept) / adjusted_slope
  data.frame(station_global = round(global))
}


#' Apply Borderline Regression Method (BRM) standard-setting within a station
#'
#' Fits a linear regression of station score on global rating, then uses the
#' predicted score at \code{brm_pass_level} as the station cut-score.
#'
#' @param station_data   Data.frame for one station (output of \code{CalcGlobalLm}).
#' @param brm_pass_level Global-rating value that defines the passing standard.
#' @return The input data.frame augmented with \code{pass_score_station},
#'   \code{st_fail_observed}, \code{intercept_observed}, and \code{slope_observed}.
StandardSetting <- function(station_data, brm_pass_level = 1) {
  fit                  <- lm(station_score ~ station_global, data = station_data)
  intercept_obs        <- coef(fit)[[1]]
  slope_obs            <- coef(fit)[[2]]
  pass_score           <- intercept_obs + slope_obs * brm_pass_level

  station_data$pass_score_station  <- round(pass_score, 1)
  station_data$st_fail_observed    <- as.integer(station_data$osce_score < pass_score)
  station_data$intercept_observed  <- round(intercept_obs, 1)
  station_data$slope_observed      <- round(slope_obs, 1)
  station_data
}


#' Compute the overall OSCE pass score as the mean of station cut-scores
#'
#' @param sim_result Data.frame with column \code{pass_score_station}.
#' @return The same data.frame with an added column \code{osce_pass}.
CalcOscePass <- function(sim_result) {
  station_cuts       <- unique(sim_result[, c("station", "pass_score_station")])
  sim_result$osce_pass <- round(mean(station_cuts$pass_score_station), 1)
  sim_result
}


#' Compute classification accuracy statistics (observed vs true pass/fail)
#'
#' @param osce_data Data.frame containing columns \code{cand}, \code{osce_score},
#'   \code{true_score}, \code{fail_observed}, \code{fail_true},
#'   \code{pass_score}, and \code{true_pass_score}.
#' @return A one-row data.frame with pass scores, fail counts, and accuracy.
CalcAccStats <- function(osce_data) {
  keep_vars <- c("cand", "osce_score", "true_score",
                 "fail_observed", "fail_true", "pass_score", "true_pass_score")
  cand_data <- unique(osce_data[, keep_vars])

  pred  <- factor(cand_data$fail_observed)
  truth <- factor(cand_data$fail_true)

  # Accuracy only defined when both classes are present
  acc <- if (nlevels(droplevels(interaction(pred, truth))) == 4) {
    ct <- caret::confusionMatrix(pred, truth)
    ct$overall[["Accuracy"]]
  } else {
    NA_real_
  }

  data.frame(
    pass_score      = unique(cand_data$pass_score),
    true_pass_score = unique(cand_data$true_pass_score),
    n_fail_obs      = sum(pred  == 1),
    n_fail_true     = sum(truth == 1),
    acc             = acc
  )
}
