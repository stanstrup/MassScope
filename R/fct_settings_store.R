# Persist the Settings-tab values across app restarts. Stored as JSON in the
# per-user config directory (tools::R_user_dir) so it is independent of where the
# app is launched from and never lands in the project tree. Only user
# preferences are saved — not transient/session state.

# Fields persisted (a stable allow-list; anything else in settings is ignored),
# with the shape each must have: "chr" one string, "chrs" a character vector
# (possibly empty), "lgl" TRUE/FALSE, "num" one finite number.
.SETTING_KINDS <- c(
  time_unit = "chr", qual_palette = "chr", seq_palette = "chr", invert_scale = "lgl",
  default_tol = "num", default_tol_unit = "chr", daemons = "num",
  hmdb_tol = "num", hmdb_tol_unit = "chr",
  hmdb_adducts_pos = "chrs", hmdb_adducts_neg = "chrs",
  export_format = "chr", export_width = "num", export_height = "num",
  export_units = "chr", export_dpi = "num")
.PERSISTED_SETTINGS <- names(.SETTING_KINDS)

#' Coerce a value read back from JSON to its setting's shape, or NULL when it
#' doesn't fit (a cleared numeric saved as "NA", a logical NA saved as null, a
#' hand-edited file). An empty JSON array reads back as list(), hence "chrs".
#' @noRd
clean_setting <- function(v, kind) {
  switch(kind,
    chrs = if (is.null(v) || (is.list(v) && !length(v))) character()
           else if (is.character(v)) v[!is.na(v)],
    chr  = if (is.character(v) && length(v) == 1 && !is.na(v)) v,
    lgl  = if (is.logical(v) && length(v) == 1 && !is.na(v)) v,
    num  = if (is.numeric(v) && length(v) == 1 && is.finite(v)) v)
}

#' Path to the persisted settings file (per-user config dir).
#' @importFrom tools R_user_dir
#' @noRd
settings_file <- function() {
  f <- file.path(R_user_dir("MassScope", "config"), "settings.json")
  # One-time carry-over from the package's former name (xcmsVisGUI), so the
  # rename does not reset saved preferences. Remove once nobody has the old dir.
  old <- file.path(R_user_dir("xcmsVisGUI", "config"), "settings.json")
  if (!file.exists(f) && file.exists(old)) {
    dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
    file.copy(old, f)
  }
  f
}

#' Load persisted settings as a named list (known fields only). Returns an empty
#' list when nothing is saved or the file is missing/unreadable/corrupt — so a
#' bad file never blocks startup.
#' @importFrom jsonlite read_json
#' @noRd
load_settings <- function() {
  f <- settings_file()
  if (!file.exists(f)) return(list())
  out <- tryCatch(read_json(f, simplifyVector = TRUE),
                  error = function(e) list())
  if (!is.list(out)) return(list())
  out <- out[intersect(names(out), .PERSISTED_SETTINGS)]
  out <- Map(clean_setting, out, .SETTING_KINDS[names(out)])
  Filter(Negate(is.null), out)
}

#' Write the persisted subset of `settings` (a plain list, e.g. from
#' reactiveValuesToList(rv$settings)) to disk, creating the config dir. Failures
#' warn rather than error — saving settings must never crash the app.
#' @importFrom jsonlite write_json
#' @noRd
save_settings <- function(settings) {
  f <- settings_file()
  keep <- settings[intersect(names(settings), .PERSISTED_SETTINGS)]
  tryCatch({
    dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
    write_json(keep, f, auto_unbox = TRUE, pretty = TRUE)
  }, error = function(e) warning("Could not save settings: ", conditionMessage(e)))
  invisible(f)
}
