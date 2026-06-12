# =============================================================================
# Beta Distribution Parameter Calculator
# =============================================================================
# Given a desired mean and SD on the 0–100 score scale, compute the alpha and
# beta shape parameters for the Beta distribution used in the OSCE simulation.
#
# Usage
# -----
# Source or run this file, then call beta_params() with your target values:
#
#   beta_params(mean = 75, sd = 6)
#   beta_params(mean = 50, sd = 10, label = "Examiner stringency")
#
# The function also optionally plots the resulting distribution.
# =============================================================================


#' Compute Beta shape parameters from a target mean and SD
#'
#' @param mean   Desired mean on the 0–100 scale.
#' @param sd     Desired SD  on the 0–100 scale.
#' @param label  Optional label printed in output (e.g. "Candidates").
#' @param plot   If TRUE, plot the resulting Beta density on the 0–100 scale.
#' @return A named numeric vector c(alpha = ..., beta = ...) (invisibly).
beta_params <- function(mean, sd, label = NULL, plot = FALSE) {

  # ---- Validate inputs -------------------------------------------------------
  stopifnot(
    "mean must be strictly between 0 and 100" = mean > 0 & mean < 100,
    "sd must be > 0"                           = sd > 0
  )

  # ---- Convert to (0,1) scale ------------------------------------------------
  mu    <- mean / 100
  sigma <- sd   / 100

  if (sigma^2 >= mu * (1 - mu)) {
    stop(sprintf(
      paste0("SD is too large for this mean: on the 0-1 scale, variance (%.6f) ",
             "must be less than mu*(1-mu) = %.6f."),
      sigma^2, mu * (1 - mu)
    ))
  }

  # ---- Method-of-moments estimates -------------------------------------------
  kappa <- mu * (1 - mu) / sigma^2 - 1   # concentration = alpha + beta
  alpha <- mu * kappa
  beta  <- (1 - mu) * kappa

  # ---- Implied properties ----------------------------------------------------
  implied_mean <- alpha / (alpha + beta) * 100
  implied_var  <- alpha * beta / ((alpha + beta)^2 * (alpha + beta + 1)) * 100^2
  implied_sd   <- sqrt(implied_var)

  # ---- Print summary ---------------------------------------------------------
  header <- if (!is.null(label)) paste0(" [", label, "]") else ""
  cat(sprintf("Beta parameters%s\n", header))
  cat(sprintf("  Input:    mean = %.2f, SD = %.2f  (0-100 scale)\n", mean, sd))
  cat(sprintf("  alpha     = %.4f  (round to %d)\n", alpha, round(alpha)))
  cat(sprintf("  beta      = %.4f  (round to %d)\n", beta,  round(beta)))
  cat(sprintf("  Check:    implied mean = %.2f, implied SD = %.2f\n",
              implied_mean, implied_sd))
  cat("\n")

  # ---- Optional plot ---------------------------------------------------------
  if (plot) {
    x     <- seq(0, 100, length.out = 500)
    dens  <- dbeta(x / 100, alpha, beta) / 100
    title <- if (!is.null(label)) label else "Beta distribution"
    plot(x, dens, type = "l", lwd = 2,
         main = title,
         xlab = "Score (0–100)", ylab = "Density",
         col  = "#2166ac")
    abline(v = implied_mean, lty = 2, col = "grey40")
    legend("topright",
           legend = sprintf("alpha=%.1f, beta=%.1f\nmean=%.1f, SD=%.1f",
                            alpha, beta, implied_mean, implied_sd),
           bty = "n", cex = 0.85)
  }

  invisible(c(alpha = alpha, beta = beta))
}


# =============================================================================
# Example: reproduce the Homer 2020 default parameters
# =============================================================================

beta_params(mean = 75, sd = 5.9,  label = "Candidates",     plot = TRUE)
beta_params(mean = 50, sd = 4.5,  label = "Stations",       plot = FALSE)
beta_params(mean = 50, sd = 7.0,  label = "Examiners",      plot = FALSE)
beta_params(mean = 50, sd = 15.1, label = "Residual error", plot = FALSE)
