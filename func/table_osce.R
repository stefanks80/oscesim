# =============================================================================
# OSCE Simulation: Table Function
# =============================================================================
# Builds a publication-ready flextable from AnalyseOSCE() output.
# Displays a sample of individual runs alongside the mean across all runs.
# =============================================================================


#' Build a flextable from OSCE analysis results
#'
#' @param analysis_res  A data.frame from \code{do.call(rbind, lapply(..., AnalyseOSCE))}.
#' @param n_display     Number of individual runs to sample for display (default 5).
#'                      Ignored if \code{sample_idx} is provided.
#' @param sample_idx    Optional integer vector of specific row indices to display.
#' @param title         Table title displayed above the header.
#' @param note          Explanatory note displayed below the table.
#' @param docx_file     Optional path for saving the table to Word (landscape).
#' @return Printed to the viewer.
TableOSCE <- function(analysis_res,
                      n_display  = 5,
                      sample_idx = NULL,
                      title      = "Table X. OSCE simulation results",
                      note       = paste(
                        "Note.",
                        "Sampled runs are shown alongside the mean across all replications (bold).",
                        "Variance components are expressed as percentages of total observed score variance.",
                        "G Coefficient reflects reliability for relative decisions;",
                        "Phi reflects reliability for absolute decisions (pass/fail).",
                        "SEM rel = standard error of measurement for relative decisions;",
                        "SEM abs = standard error of measurement for absolute decisions.",
                        "N competent fail = number of truly competent candidates who failed (false positives);",
                        "N not-ready pass = number of truly not-ready candidates who passed (false negatives).",
                        "Accuracy = overall proportion of correctly classified candidates."
                      ),
                      docx_file  = NULL) {

  # Column order must match add_header_row colwidths below:
  # Score (2) | Variance components (4) | Coefficients (4) | Classification (4)
  cols <- c("mean_osce", "sd_osce",
            "pct_cand", "pct_station", "pct_examiner", "pct_resid",
            "g_coeff", "phi_coeff", "sem_rel", "sem_abs",
            "pass_rate", "competent_fail", "incompetent_pass", "accuracy")

  tab      <- analysis_res[, cols]
  mean_row <- as.data.frame(t(colMeans(tab, na.rm = TRUE)))

  # -- Select rows for display -------------------------------------------------
  if (is.null(sample_idx)) {
    sample_idx <- sort(sample(seq_len(nrow(tab)), min(n_display, nrow(tab))))
  }

  n_total    <- nrow(tab)
  mean_label <- if (n_total > length(sample_idx)) {
    sprintf("Mean (n=%d)", n_total)
  } else {
    "Mean"
  }

  tab_sum     <- rbind(tab[sample_idx, ], mean_row)
  tab_sum$run <- c(as.character(sample_idx), mean_label)
  tab_sum     <- tab_sum[, c("run", cols)]

  # ==========================================================================
  # Table 1: wide format (runs as rows)
  # ==========================================================================
  ft1 <- flextable::flextable(tab_sum)

  ft1 <- flextable::set_header_labels(ft1,
    run              = "Run",
    mean_osce        = "Mean",
    sd_osce          = "SD",
    pct_cand         = "Candidate",
    pct_station      = "Station",
    pct_examiner     = "Examiner",
    pct_resid        = "Residual",
    g_coeff          = "G Coefficient",
    phi_coeff        = "Phi Coefficient",
    sem_rel          = "SEM (rel)",
    sem_abs          = "SEM (abs)",
    pass_rate        = "Pass rate",
    competent_fail   = "N competent fail",
    incompetent_pass = "N not-ready pass",
    accuracy         = "Accuracy"
  )

  ft1 <- flextable::add_header_row(ft1,
    values    = c("", "OSCE Score", "Variance components (%)", "Reliability Coefficients", "Classification"),
    colwidths = c(1, 2, 4, 4, 4)
  )

  ft1 <- flextable::colformat_double(
    ft1,
    j = c("mean_osce", "sd_osce"), digits = 1
  )

  ft1 <- flextable::colformat_double(ft1,
    j = c("pct_cand", "pct_station", "pct_examiner", "pct_resid"), digits = 1)
  ft1 <- flextable::colformat_double(ft1,
    j = c("g_coeff", "phi_coeff"), digits = 2)
  ft1 <- flextable::colformat_double(ft1,
    j = c("sem_rel", "sem_abs"), digits = 2)
  ft1 <- flextable::colformat_double(ft1,
    j = c("competent_fail", "incompetent_pass"),
    digits = 0, na_str = "—")    
  ft1 <- flextable::colformat_double(ft1,
    j = c("pass_rate", "accuracy"),
    digits = 1, suffix = "%", na_str = "—")

  ft1 <- flextable::theme_booktabs(ft1)
  ft1 <- flextable::align(ft1, align = "center", part = "header")
  ft1 <- flextable::align(ft1, j = -1,    align = "right", part = "body")
  ft1 <- flextable::align(ft1, j = "run", align = "left",  part = "all")
  ft1 <- flextable::bold(ft1, i = nrow(tab_sum), bold = TRUE)
  ft1 <- flextable::hline(ft1, i = nrow(tab_sum) - 1)

  # Title
  ft1 <- flextable::add_header_lines(ft1, values = title)
  ft1 <- flextable::align(ft1, i = 1, align = "left", part = "header")
  ft1 <- flextable::bold(ft1,  i = 1, bold = TRUE,    part = "header")
  ft1 <- flextable::hline_top(ft1, part = "header",
    border = officer::fp_border(color = "black", width = 1.5))

  # Note
  ft1 <- flextable::add_footer_lines(ft1, values = note)
  ft1 <- flextable::align(ft1,   align = "left",  part = "footer")
  ft1 <- flextable::italic(ft1,  italic = TRUE,   part = "footer")
  ft1 <- flextable::fontsize(ft1, size = 9,       part = "footer")

  ft1 <- flextable::autofit(ft1)

  if (!is.null(docx_file)) {
    landscape <- officer::prop_section(
      page_size    = officer::page_size(orient = "landscape"),
      page_margins = officer::page_mar()
    )
    flextable::save_as_docx(ft1, path = docx_file, pr_section = landscape)
  }

  print(ft1)
}


#' Compare average results across simulation conditions (conditions as columns)
#'
#' Produces a vertically-oriented table: metrics are rows grouped into sections
#' (Score, Variance components, Coefficients, Classification), and each
#' condition occupies one column.
#'
#' @param results_list  Named list of analysis data.frames, one per condition.
#' @param title         Table title displayed above the header.
#' @param note          Explanatory note displayed below the table.
#' @param docx_file     Optional path for saving to Word (portrait).
#' @return Printed to the viewer.
TableOSCEConditions <- function(
    results_list,
    title = "Table X. Simulation results by number of stations (means across runs)",
    note  = paste(
      "Note.",
      "Variance components are expressed as percentages of total observed score variance.",
      "G Coefficient reflects reliability for relative decisions;",
      "Phi reflects reliability for absolute decisions (pass/fail).",
      "SEM rel = standard error of measurement for relative decisions;",
      "SEM abs = standard error of measurement for absolute decisions.",
      "Share of failing that are competent = proportion of observed failures",
      "who were truly competent (false positive rate among failures).",
      "Share of passing that are not ready = proportion of observed passes",
      "who were truly not ready (false negative rate among passes).",
      "Accuracy = overall proportion of correctly classified candidates."
    ),
    docx_file = NULL) {

  cols <- c("mean_osce", "sd_osce",
            "pct_cand", "pct_station", "pct_examiner", "pct_resid",
            "g_coeff", "phi_coeff", "sem_rel", "sem_abs",
            "pass_rate",
            "competent_fail", "share_fail_competent",
            "incompetent_pass", "share_pass_notready",
            "accuracy")

  metric_labels <- c(
    mean_osce            = "Mean",
    sd_osce              = "SD",
    pct_cand             = "Candidate",
    pct_station          = "Station",
    pct_examiner         = "Examiner",
    pct_resid            = "Residual",
    g_coeff              = "G Coefficient",
    phi_coeff            = "Phi Coefficient",
    sem_rel              = "SEM (rel)",
    sem_abs              = "SEM (abs)",
    pass_rate            = "Pass rate",
    competent_fail       = "N competent fail",
    share_fail_competent = "  Share of failing that are competent",
    incompetent_pass     = "N not-ready pass",
    share_pass_notready  = "  Share of passing that are not ready",
    accuracy             = "Accuracy"
  )

  sections <- c(
    mean_osce            = "OSCE Score",
    sd_osce              = "OSCE Score",
    pct_cand             = "Variance components (%)",
    pct_station          = "Variance components (%)",
    pct_examiner         = "Variance components (%)",
    pct_resid            = "Variance components (%)",
    g_coeff              = "Reliability Coefficients",
    phi_coeff            = "Reliability Coefficients",
    sem_rel              = "Reliability Coefficients",
    sem_abs              = "Reliability Coefficients",
    pass_rate            = "Classification",
    competent_fail       = "Classification",
    share_fail_competent = "Classification",
    incompetent_pass     = "Classification",
    share_pass_notready  = "Classification",
    accuracy             = "Classification"
  )

  # Compute condition means, one named vector per condition
  cond_means <- lapply(results_list, function(res) colMeans(res[, cols], na.rm = TRUE))

  # Build data.frame: section + metric label + one column per condition
  tab <- data.frame(
    section = unname(sections[cols]),
    metric  = unname(metric_labels[cols]),
    stringsAsFactors = FALSE
  )
  for (nm in names(cond_means)) tab[[nm]] <- unname(cond_means[[nm]])

  # -- Row indices by format type ----------------------------------------------
  fmt_rows <- list(
    digits1 = which(cols %in% c("mean_osce", "sd_osce",
                                "pct_cand", "pct_station", "pct_examiner", "pct_resid")),
    digits2 = which(cols %in% c("g_coeff", "phi_coeff", "sem_rel", "sem_abs")),
    pct     = which(cols %in% c("pass_rate", "share_fail_competent",
                                "share_pass_notready", "accuracy")),
    count   = which(cols %in% c("competent_fail", "incompetent_pass"))
  )

  val_cols <- names(cond_means)

  ft <- flextable::flextable(tab)

  ft <- flextable::set_header_labels(ft, section = "", metric = "")

  # Merge repeated section labels in the section column
  ft <- flextable::merge_v(ft, j = "section")
  ft <- flextable::valign(ft, j = "section", valign = "top", part = "body")

  # Per-row numeric formatting on value columns
  ft <- flextable::colformat_double(ft, j = val_cols,
    i = fmt_rows$digits1, digits = 1)
  ft <- flextable::colformat_double(ft, j = val_cols,
    i = fmt_rows$digits2, digits = 2)
  ft <- flextable::colformat_double(ft, j = val_cols,
    i = fmt_rows$pct,     digits = 1, suffix = "%", na_str = "—")
  ft <- flextable::colformat_double(ft, j = val_cols,
    i = fmt_rows$count,   digits = 0,               na_str = "—")

  # Horizontal rules between sections
  section_ends <- c(
    max(which(cols %in% c("mean_osce", "sd_osce"))),          # end of Score
    max(which(startsWith(cols, "pct_"))),                      # end of Variance components
    max(which(cols %in% c("g_coeff", "phi_coeff", "sem_rel", "sem_abs")))  # end of Coefficients
  )
  ft <- flextable::hline(ft, i = section_ends)

  ft <- flextable::theme_booktabs(ft)
  ft <- flextable::align(ft, align = "center", part = "header")
  ft <- flextable::align(ft, j = val_cols,               align = "right", part = "body")
  ft <- flextable::align(ft, j = c("section", "metric"), align = "left",  part = "all")

  # Title
  n_cols <- 2 + length(val_cols)
  ft <- flextable::add_header_lines(ft, values = title)
  ft <- flextable::align(ft, i = 1, align = "left", part = "header")
  ft <- flextable::bold(ft,  i = 1, bold = TRUE,    part = "header")
  ft <- flextable::hline_top(ft, part = "header",
    border = officer::fp_border(color = "black", width = 1.5))

  # Note
  ft <- flextable::add_footer_lines(ft, values = note)
  ft <- flextable::align(ft, align = "left", part = "footer")
  ft <- flextable::italic(ft, italic = TRUE, part = "footer")
  ft <- flextable::fontsize(ft, size = 9, part = "footer")

  ft <- flextable::autofit(ft)

  if (!is.null(docx_file)) {
    flextable::save_as_docx(ft, path = docx_file)
  }

  print(ft)
}
