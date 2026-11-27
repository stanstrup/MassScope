# HMDB LC-MS search links. The search form (https://hmdb.ca/spectra/ms/search)
# POSTs with a CSRF token, but the same fields as a GET query run the search too,
# so a peak can open its results as a plain link. Nothing is fetched server-side:
# HMDB sits behind a Cloudflare challenge that only a real browser passes.

#' HMDB's adduct names (the values of its `adduct_type[]` select), per ion mode.
#' @noRd
HMDB_ADDUCTS <- list(
  pos = c("M+H", "M+H-2H2O", "M+H-H2O", "M+NH4-H2O", "M+Li", "M+NH4", "M+Na",
          "M+CH3OH+H", "M+K", "M+ACN+H", "M+2Na-H", "M+IsoProp+H", "M+ACN+Na",
          "M+2K-H", "M+DMSO+H", "M+2ACN+H", "M+IsoProp+Na+H", "M+H+HCOONa",
          "2M+H", "2M+NH4", "2M+Na", "2M+2H+3H2O", "2M+K", "2M+ACN+H",
          "2M+ACN+Na", "2M+H-H2O", "M+2H", "M+H+NH4", "M+H+Na", "M+H+K",
          "M+ACN+2H", "M+2Na", "M+2ACN+2H", "M+3ACN+2H", "M+3H", "M+2H+Na",
          "M+H+2Na", "M+3Na", "M+H+2K"),
  neg = c("M-H", "M-H20-H", "M+F", "M+Na-2H", "M+Cl", "M+K-2H", "M+FA-H",
          "M+Hac-H", "M+Br", "M+TFA-H", "M-H+HCOONa", "2M-H", "2M+FA-H",
          "2M+Hac-H", "3M-H", "M-2H", "M-3H"))

#' Default adducts searched when a clicked peak carries no annotation.
#' @noRd
HMDB_DEFAULT_ADDUCTS <- list(pos = c("M+H", "M+Na", "M+NH4"),
                             neg = c("M-H", "M+Cl", "M+FA-H"))

#' Map one of our (commonMZ) adduct names, e.g. `[M+H]+` or `[M-H+HCOOH]-`, to
#' HMDB's spelling (`M+H`, `M+FA-H`). NA when HMDB has no such adduct.
#' @noRd
hmdb_adduct_name <- function(name, mode = c("pos", "neg")) {
  mode <- match.arg(mode)
  core <- sub("^\\[(.*)\\][0-9]*[+\u2212-]$", "\\1", name)
  core <- gsub("\u2212", "-", core)
  # Same ion, different spelling: formic acid as an add-on vs HMDB's "FA".
  alias <- c("M-H+HCOOH" = "M+FA-H", "2M-H+HCOOH" = "2M+FA-H",
             "M-H+CH3COOH" = "M+Hac-H", "2M-H+CH3COOH" = "2M+Hac-H",
             "M-H-H2O" = "M-H20-H",          # sic: HMDB's value has a zero
             "M-2H+Na" = "M+Na-2H", "M-2H+K" = "M+K-2H")
  if (core %in% names(alias)) core <- alias[[core]]
  if (core %in% HMDB_ADDUCTS[[mode]]) core else NA_character_
}

#' Build an HMDB LC-MS search URL.
#' @param mz query m/z (or neutral mass when `mode = "neutral"`); several allowed.
#' @param mode "pos", "neg" or "neutral".
#' @param adducts HMDB adduct names; unknown names are dropped, and an empty set
#'   falls back to the defaults. Ignored for "neutral".
#' @param tol,unit search tolerance and its unit ("ppm" or "Da").
#' @noRd
hmdb_search_url <- function(mz, mode = c("pos", "neg", "neutral"), adducts = NULL,
                            tol = 5, unit = c("ppm", "Da")) {
  mode <- match.arg(mode); unit <- match.arg(unit)
  enc <- function(x) utils::URLencode(as.character(x), reserved = TRUE)
  q <- c(utf8 = "\u2713",
         query_masses = paste(sprintf("%.5f", mz), collapse = "\n"),
         ms_search_ion_mode = c(pos = "positive", neg = "negative",
                                neutral = "neutral")[[mode]])
  parts <- paste0(names(q), "=", vapply(q, enc, ""))
  if (mode != "neutral") {
    adducts <- intersect(adducts, HMDB_ADDUCTS[[mode]])
    if (!length(adducts)) adducts <- HMDB_DEFAULT_ADDUCTS[[mode]]
    parts <- c(parts, paste0(enc("adduct_type[]"), "=", vapply(adducts, enc, "")))
  }
  parts <- c(parts, paste0("tolerance=", enc(format(tol))),
             paste0("tolerance_units=", unit), "commit=Search")
  paste0("https://hmdb.ca/spectra/ms/search?", paste(parts, collapse = "&"))
}

#' The HMDB search for a clicked peak. When the annotation labels that peak as an
#' adduct, search exactly that adduct -- or, if HMDB has no such adduct, the
#' implied neutral mass. Otherwise search the clicked m/z with the default adducts.
#' @param mz clicked m/z.
#' @param mode "pos" / "neg" (the scan's ion mode).
#' @param ann annotation table (label, type, mz_obs, matched) or NULL.
#' @param match_tol_da how close (Da) an annotated peak must be to the click.
#' @noRd
hmdb_peak_url <- function(mz, mode, ann = NULL, adducts = NULL, tol = 5,
                          unit = "ppm", match_tol_da = 0.01) {
  if (!is.null(ann) && nrow(ann)) {
    hit <- ann[ann$matched & ann$type == "adduct" &
                 abs(ann$mz_obs - mz) <= match_tol_da, , drop = FALSE]
    if (nrow(hit)) {
      hit <- hit[which.min(abs(hit$mz_obs - mz)), ]
      name <- hmdb_adduct_name(hit$label, mode)
      if (!is.na(name))
        return(hmdb_search_url(hit$mz_obs, mode, name, tol, unit))
      rule <- anchor_adduct_rules(mode)
      rule <- rule[rule$name == hit$label, , drop = FALSE]
      if (nrow(rule) == 1)
        return(hmdb_search_url(neutral_mass(hit$mz_obs, rule), "neutral",
                               tol = tol, unit = unit))
    }
  }
  hmdb_search_url(mz, mode, adducts, tol, unit)
}

# --- opening the search from a plot click ------------------------------------
# Browsers only allow a new tab while handling the user's click. The server
# builds the URL, but its reply arrives after the click handler has returned,
# and a window.open() then is blocked as a pop-up. So the click itself opens a
# blank tab (arm_hmdb_on_click) and the server's message points it at the URL.

#' Client-side half: a custom-message handler that sends the armed blank tab to
#' the search URL (or opens one if none is armed). Include once in the UI.
#' @noRd
hmdb_click_script <- function() {
  tags$script(HTML("
(function () {
  if (window.MassScopeOpenUrl) return;
  var pending = null;
  window.MassScopeArmTab = function () {
    pending = window.open('', '_blank');
    if (pending) pending.opener = null;   // the search page gets no handle on the app
  };
  window.MassScopeOpenUrl = function (m) {
    if (pending && !pending.closed) pending.location.href = m.url;
    else window.open(m.url, '_blank', 'noopener');
    pending = null;
  };
  Shiny.addCustomMessageHandler('massscope-open-url', window.MassScopeOpenUrl);
})();"))
}

#' Arm a blank tab on a plotly click while the radio `input_name` is "hmdb".
#' The listener is replaced (not stacked) on every re-render.
#' @importFrom htmlwidgets onRender
#' @noRd
arm_hmdb_on_click <- function(p, input_name) {
  onRender(p, "
function (el, x, name) {
  if (el.__massscopeArm) el.removeListener('plotly_click', el.__massscopeArm);
  el.__massscopeArm = function () {
    var r = document.querySelector('input[name=\"' + name + '\"]:checked');
    if (r && r.value === 'hmdb' && window.MassScopeArmTab) window.MassScopeArmTab();
  };
  el.on('plotly_click', el.__massscopeArm);
}", data = input_name)
}
