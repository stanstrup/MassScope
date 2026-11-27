# HMDB search links built from a spectrum peak (R/fct_hmdb.R).

q <- function(url) {   # decoded query parameters, repeated keys kept
  kv <- strsplit(strsplit(sub("^[^?]*[?]", "", url), "&")[[1]], "=")
  setNames(vapply(kv, function(p) utils::URLdecode(p[2]), ""),
           vapply(kv, function(p) utils::URLdecode(p[1]), ""))
}

test_that("a positive-mode URL carries the GET fields HMDB's search accepts", {
  u <- hmdb_search_url(181.0707, "pos", c("M+H", "M+Na"), tol = 5, unit = "ppm")
  expect_match(u, "^https://hmdb[.]ca/spectra/ms/search[?]")
  p <- q(u)
  expect_equal(p[["query_masses"]], "181.07070")
  expect_equal(p[["ms_search_ion_mode"]], "positive")
  expect_equal(unname(p[names(p) == "adduct_type[]"]), c("M+H", "M+Na"))
  expect_equal(p[["tolerance"]], "5")
  expect_equal(p[["tolerance_units"]], "ppm")
  expect_equal(p[["commit"]], "Search")
})

test_that("unknown or empty adduct sets fall back to the per-mode defaults", {
  p <- q(hmdb_search_url(179.0561, "neg", character(), tol = 0.005, unit = "Da"))
  expect_equal(p[["ms_search_ion_mode"]], "negative")
  expect_equal(unname(p[names(p) == "adduct_type[]"]), HMDB_DEFAULT_ADDUCTS$neg)
  expect_equal(p[["tolerance_units"]], "Da")
  # a positive-only adduct is not valid in negative mode
  p <- q(hmdb_search_url(179.0561, "neg", "M+H"))
  expect_equal(unname(p[names(p) == "adduct_type[]"]), HMDB_DEFAULT_ADDUCTS$neg)
})

test_that("neutral-mode searches send no adducts", {
  p <- q(hmdb_search_url(180.0634, "neutral"))
  expect_equal(p[["ms_search_ion_mode"]], "neutral")
  expect_false("adduct_type[]" %in% names(p))
})

test_that("our adduct names map to HMDB's spelling", {
  expect_equal(hmdb_adduct_name("[M+H]+", "pos"), "M+H")
  expect_equal(hmdb_adduct_name("[M+2H]2+", "pos"), "M+2H")
  expect_equal(hmdb_adduct_name("[M-H+HCOOH]-", "neg"), "M+FA-H")
  expect_equal(hmdb_adduct_name("[M-2H+Na]-", "neg"), "M+Na-2H")
  expect_true(is.na(hmdb_adduct_name("[M+H-CO2]+", "pos")))
  # every default is a real HMDB option
  for (m in c("pos", "neg"))
    expect_true(all(HMDB_DEFAULT_ADDUCTS[[m]] %in% HMDB_ADDUCTS[[m]]))
})

test_that("a clicked peak searches its annotated adduct, else the defaults", {
  ann <- tibble::tibble(label = c("[M+Na]+", "[M+H-CO2]+"),
                        type = "adduct", mz_obs = c(203.0526, 137.0808),
                        matched = TRUE)
  # annotated as [M+Na]+: search exactly that adduct at the observed m/z
  p <- q(hmdb_peak_url(203.0527, "pos", ann, adducts = c("M+H", "M+K")))
  expect_equal(unname(p[names(p) == "adduct_type[]"]), "M+Na")
  expect_equal(p[["query_masses"]], "203.05260")
  # an adduct HMDB lacks: search the implied neutral mass
  rule <- anchor_adduct_rules("pos"); rule <- rule[rule$name == "[M+H-CO2]+", ]
  skip_if(nrow(rule) != 1, "commonMZ lacks [M+H-CO2]+")
  p <- q(hmdb_peak_url(137.0808, "pos", ann))
  expect_equal(p[["ms_search_ion_mode"]], "neutral")
  expect_equal(as.numeric(p[["query_masses"]]),
               round(neutral_mass(137.0808, rule), 5))
  # an unannotated peak: the configured adducts
  p <- q(hmdb_peak_url(300, "pos", ann, adducts = c("M+H", "M+K")))
  expect_equal(unname(p[names(p) == "adduct_type[]"]), c("M+H", "M+K"))
})
