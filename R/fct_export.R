# Plot export. The ggplot is the source of truth, so static exports are crisp
# vectors (svg/pdf) or high-DPI raster (png) regardless of the on-screen plotly,
# "html" ships a standalone interactive plotly (the same ggplotly the app shows),
# and "rds" saves the ggplot object itself for further editing/replotting in R.

#' Is a Pandoc install reachable? htmlwidgets::saveWidget(selfcontained=TRUE)
#' shells out to Pandoc to inline the JS/CSS into one file; without it the
#' interactive HTML export can't produce a single self-contained document.
#' @noRd
has_pandoc <- function() {
  nzchar(Sys.which("pandoc")) ||
    (requireNamespace("rmarkdown", quietly = TRUE) && rmarkdown::pandoc_available())
}

#' Is `v` one finite number above zero? An emptied numericInput sends NA (and a
#' not-yet-bound one NULL), neither of which `%||%` catches.
#' @noRd
is_pos_num <- function(v) length(v) == 1 && is.numeric(v) && isTRUE(is.finite(v) && v > 0)

#' `v` when it is a usable positive number, else `default`.
#' @noRd
pos_num <- function(v, default) if (is_pos_num(v)) v else default

#' Save a ggplot to file using the user's export settings.
#' @param gg a ggplot object
#' @param file destination path
#' @param settings rv$settings list (format/width/height/units/dpi/title)
#' @importFrom ggplot2 ggsave
#' @importFrom grDevices cairo_pdf svg
#' @noRd
save_gg <- function(gg, file, settings) {
  fmt <- settings$export_format %||% "png"
  # "rds": save the ggplot object itself (readRDS() it to tweak/replot in R).
  if (identical(fmt, "rds")) { saveRDS(gg, file); return(invisible(file)) }
  # "html": a standalone interactive widget. Build the same ggplotly the app
  # renders (tooltip from the `text` aes, dynamic ticks) and self-contain it.
  if (identical(fmt, "html")) {
    w <- plotly::ggplotly(gg, tooltip = "text", dynamicTicks = TRUE)
    htmlwidgets::saveWidget(w, file, selfcontained = TRUE,
                            title = settings$export_title %||% "plot")
    return(invisible(file))
  }
  # The same fallback as the preview (preview_dims): if EITHER side is unusable
  # both become 8 x 5, so an emptied field can't save a file shaped differently
  # from what was shown.
  w <- settings$export_width; h <- settings$export_height
  if (!is_pos_num(w) || !is_pos_num(h)) { w <- 8; h <- 5 }
  args <- list(
    filename = file, plot = gg, width = w, height = h,
    units = settings$export_units %||% "in"
  )
  if (fmt == "png") {
    args$device <- "png"; args$dpi <- pos_num(settings$export_dpi, 300)
  } else if (fmt == "pdf") {
    args$device <- cairo_pdf
  } else if (fmt == "svg") {
    # Prefer svglite; fall back to grDevices::svg (cairo) if unavailable.
    args$device <- if (requireNamespace("svglite", quietly = TRUE)) "svg" else svg
  }
  do.call(ggsave, args)
}

#' The spectrum as an export table: one row per peak (or profile sample) with
#' file, scan, rt in the display `unit`, m/z, intensity and whether it is a raw
#' profile sample. Input is the spectrum view's own (already filtered and, if
#' asked, peak-picked) data, so the table is exactly what is drawn.
#' @noRd
spectrum_table <- function(df, unit = "sec") {
  out <- data.frame(
    file = df$sample_name %||% rep(NA_character_, nrow(df)),
    scan = df$scan, rt = rt_to_disp(df$rt, unit),
    mz = df$mz, intensity = df$intensity,
    mode = ifelse(df$profile %in% TRUE, "profile", "centroid"),
    stringsAsFactors = FALSE)
  names(out)[3] <- paste0("rt_", unit)
  out
}

#' Tab-separated text of a table (header + rows) for the clipboard: TSV is what
#' spreadsheets split into cells on paste. Full precision — no rounding.
#' @importFrom utils write.table
#' @noRd
table_tsv <- function(tab) {
  con <- textConnection("out", "w", local = TRUE)
  on.exit(close(con))
  write.table(tab, con, sep = "\t", quote = FALSE, row.names = FALSE, na = "")
  paste(textConnectionValue(con), collapse = "\n")
}
