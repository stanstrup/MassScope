# Persist the Settings-tab values across app restarts. Stored as JSON in the
# per-user config directory (tools::R_user_dir) so it is independent of where the
# app is launched from and never lands in the project tree. Only user
# preferences are saved — not transient/session state.

#' The app's settings, declared once. Per field: its `default`, its `kind` (the
#' shape a value must have) and the `control` that edits it in the Settings tab.
#' Everything else is built from this table: the defaults in make_rv(), the
#' persisted allow-list and the load-time shape check here, and the restore and
#' the per-field observers in mod_settings_server(). Adding a setting means one
#' entry here plus its control in mod_settings_ui(), whose initial values also
#' come from here.
#'
#' kind: "chr" one string, "chrs" a character vector (may be empty), "lgl"
#' TRUE/FALSE, "num" one positive number. control: "radio", "select",
#' "selectize", "checkbox", "numeric" or "slider".
#'
#' A function, not a constant: the defaults read other package objects
#' (HMDB_DEFAULT_ADDUCTS, the core count) that must not be evaluated at build time.
#' @noRd
settings_spec <- function() {
  s <- function(default, kind, control)
    list(default = default, kind = kind, control = control)
  list(
    time_unit        = s("min", "chr", "radio"),        # display unit for rt
    qual_palette     = s("Set1", "chr", "select"),
    seq_palette      = s("viridis", "chr", "select"),
    invert_scale     = s(TRUE, "lgl", "checkbox"),
    default_tol      = s(10, "num", "numeric"),         # EIC tolerance for new targets
    default_tol_unit = s("ppm", "chr", "select"),
    # HMDB search from a spectrum peak: its own (typically narrower) tolerance
    # and the adducts searched for an unannotated peak, per ion mode.
    hmdb_tol         = s(5, "num", "numeric"),
    hmdb_tol_unit    = s("ppm", "chr", "select"),
    hmdb_adducts_pos = s(HMDB_DEFAULT_ADDUCTS$pos, "chrs", "selectize"),
    hmdb_adducts_neg = s(HMDB_DEFAULT_ADDUCTS$neg, "chrs", "selectize"),
    daemons          = s(.default_daemons(), "num", "slider"),
    export_format    = s("png", "chr", "select"),
    export_width     = s(8, "num", "numeric"),
    export_height    = s(5, "num", "numeric"),
    export_units     = s("in", "chr", "select"),
    export_dpi       = s(300, "num", "numeric"))
}

#' Default value of every setting, as a named list.
#' @noRd
settings_defaults <- function() lapply(settings_spec(), `[[`, "default")

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
    num  = if (is_pos_num(v)) v)
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
  spec <- settings_spec()
  out <- out[intersect(names(out), names(spec))]
  out <- Map(function(v, k) clean_setting(v, spec[[k]]$kind), out, names(out))
  Filter(Negate(is.null), out)
}

#' Write the persisted subset of `settings` (a plain list, e.g. from
#' reactiveValuesToList(rv$settings)) to disk, creating the config dir. Failures
#' warn rather than error — saving settings must never crash the app.
#' @importFrom jsonlite write_json
#' @noRd
save_settings <- function(settings) {
  f <- settings_file()
  keep <- settings[intersect(names(settings), names(settings_spec()))]
  tryCatch({
    dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
    write_json(keep, f, auto_unbox = TRUE, pretty = TRUE)
  }, error = function(e) warning("Could not save settings: ", conditionMessage(e)))
  invisible(f)
}
