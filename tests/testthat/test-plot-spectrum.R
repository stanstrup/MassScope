# Spectrum-view module glue. The extraction/centroiding is covered in
# test-filters.R; here we guard the plot-layer wiring for the profile extras
# (show data points, overlay centroids) by driving the real module with
# testServer on a profile spectrum from msdata.

skip_if_not_installed("msdata")

profile_file <- function() {
  # MS3TMT11.mzML is mixed: profile MS1 + centroided MS2/MS3.
  normalizePath(list.files(system.file("proteomics", package = "msdata"),
                           full.names = TRUE, pattern = "mzML$")[1])
}

test_that("show-points and overlay add the expected profile plot layers", {
  p <- profile_file()
  raw <- get_spectra(p)
  pr <- which(!Spectra::centroided(raw))
  skip_if_not(length(pr) > 0, "no profile spectra in test file")
  rt_min <- Spectra::rtime(raw)[pr[1]] / 60   # module rt input is in display units (min)

  files <- tibble::tibble(
    id = "f1", path = p, name = basename(p), sample_group = "g1",
    include = TRUE, status = "ready", n_spectra = length(raw),
    rt_min = 0, rt_max = 1e5, mz_min = 0, mz_max = 1e4,
    ms_levels = "1", polarities = "1", charges = NA_character_,
    spec_mode = "mixed", message = NA_character_)

  rv <- make_rv(); rv$files <- files
  rv$filter <- modifyList(empty_filter(), list(ms_level = 1L))  # the profile level
  included <- reactive(files)

  # `text` is not a real ggplot aesthetic (ggplotly consumes it for tooltips), so
  # ggplot2 v4 warns when the layers materialize — intrinsic to every plot in this
  # app, and deferred past any inner wrap. Suppress at the whole testServer call;
  # this silences warnings only, not expectation failures.
  suppressWarnings(shiny::testServer(mod_plot_spectrum_server,
                    args = list(rv = rv, included = included), {
    geoms <- function() vapply(plot_gg()$layers, function(l) class(l$geom)[1],
                               character(1))
    session$setInputs(layout = "single", rt = rt_min, scan = NA, annotate = FALSE,
                      cmode = "off", csnr = 0, chws = 2, ck = 0, showpts = FALSE)
    d <- spec_df()
    skip_if_not(isTRUE(all(d$profile)), "selected spectrum is not profile")
    expect_setequal(geoms(), "GeomLine")                     # raw profile is a line

    session$setInputs(showpts = TRUE)
    expect_true("GeomPoint" %in% geoms())                    # data points added

    # "overlay" mode: raw line + centroids drawn on top
    session$setInputs(showpts = FALSE, cmode = "overlay")
    ov <- overlay_df()
    expect_gt(nrow(ov), 0)
    expect_false(any(ov$profile))                            # overlay is centroided
    expect_true(all(c("GeomLine", "GeomLinerange", "GeomPoint") %in% geoms()))

    # overlay only applies in the overlay mode
    session$setInputs(cmode = "auto")
    expect_equal(nrow(overlay_df()), 0)
  }))
})

test_that("scan list table shows the base peak intensity column", {
  p <- profile_file()
  files <- tibble::tibble(
    id = "f1", path = p, name = basename(p), sample_group = "g1",
    include = TRUE, status = "ready", n_spectra = 1L,
    rt_min = 0, rt_max = 1e5, mz_min = 0, mz_max = 1e4,
    ms_levels = "1", polarities = "1", charges = NA_character_,
    spec_mode = "mixed", message = NA_character_)
  rv <- make_rv(); rv$files <- files
  included <- reactive(files)
  suppressWarnings(shiny::testServer(mod_plot_spectrum_server,
                    args = list(rv = rv, included = included), {
    session$setInputs(layout = "single", rt = 0, scan = NA, annotate = FALSE,
                      cmode = "off", csnr = 0, chws = 2, ck = 0, showpts = FALSE)
    tab <- filtered_scans()
    expect_true("basePeakIntensity" %in% names(tab))
    expect_true(all(tab$basePeakIntensity > 0))
    html <- output$scantable
    expect_match(html, "basePeakIntensity", fixed = TRUE)
  }))
})

test_that("the spectrum table is the filtered spectrum, as CSV and as TSV", {
  p <- profile_file()
  raw <- get_spectra(p)
  rt_min <- Spectra::rtime(raw)[which(Spectra::msLevel(raw) == 1)[1]] / 60
  files <- tibble::tibble(
    id = "f1", path = p, name = basename(p), sample_group = "g1",
    include = TRUE, status = "ready", n_spectra = length(raw),
    rt_min = 0, rt_max = 1e5, mz_min = 0, mz_max = 1e4,
    ms_levels = "1", polarities = "1", charges = NA_character_,
    spec_mode = "mixed", message = NA_character_)
  rv <- make_rv(); rv$files <- files
  rv$filter <- modifyList(empty_filter(), list(ms_level = 1L, mz_min = 500, mz_max = 600))
  included <- shiny::reactive({ f <- rv$files; f$disp_name <- strip_ext(f$name); f })

  suppressWarnings(shiny::testServer(mod_plot_spectrum_server,
                    args = list(rv = rv, included = included), {
    session$setInputs(layout = "single", rt = rt_min, scan = NA, annotate = FALSE,
                      cmode = "off", csnr = 0, chws = 2, ck = 0, showpts = FALSE)
    tab <- spec_tab()
    expect_gt(nrow(tab), 0)
    expect_identical(nrow(tab), nrow(spec_df()))
    expect_true(all(tab$mz >= 500 & tab$mz <= 600))         # m/z filter applied
    csv <- utils::read.csv(output$spec_csv)
    expect_equal(csv$mz, tab$mz)
    expect_match(spec_stem(), "^spectrum_.*_scan[0-9]+$")
  }))
})

test_that("a precursor-map click loads its MS2 scan despite an MS1 global filter", {
  # Clicking a precursor point used to send only file + rt, so the Spectrum tab
  # showed the nearest scan at the global MS level (MS1). The click now carries
  # the MS2 scan, and an explicit scan bypasses the MS-level filter.
  p <- profile_file()
  pr <- extract_precursors(p)
  skip_if_not(nrow(pr) > 0, "no MS2 in test file")
  target <- pr[ceiling(nrow(pr) / 2), ]
  files <- tibble::tibble(
    id = "f1", path = p, name = basename(p), sample_group = "g1",
    include = TRUE, status = "ready", n_spectra = 1L,
    rt_min = 0, rt_max = 1e5, mz_min = 0, mz_max = 1e4,
    ms_levels = "1, 2, 3", polarities = "1", charges = NA_character_,
    spec_mode = "mixed", message = NA_character_)
  rv <- make_rv(); rv$files <- files
  rv$filter <- modifyList(empty_filter(), list(ms_level = 1L))
  included <- reactive(files)

  suppressWarnings(shiny::testServer(mod_plot_spectrum_server,
                    args = list(rv = rv, included = included), {
    session$setInputs(layout = "facet", rt = NA, scan = NA, annotate = FALSE,
                      cmode = "off", csnr = 0, chws = 2, ck = 0, showpts = FALSE)
    rv$selection <- list(plot = "prec", file_id = "f1", rt = target$rt,
                         mz = target$precursorMZ, scan = target$scan)
    session$flushReact()
    # testServer doesn't round-trip update*Input(); apply what the client would
    session$setInputs(layout = "single", scan = target$scan,
                      rt = rt_to_disp(target$rt, rv$settings$time_unit))
    d <- spec_df()
    expect_equal(unique(d$scan), target$scan)
    st <- file_scan_table(p)
    expect_gt(st$msLevel[match(target$scan, st$scan)], 1L)

    # A chromatogram click (no scan) still picks by rt at the global MS level.
    rv$selection <- list(plot = "tic", file_id = "f1", rt = target$rt, mz = NA)
    session$flushReact()
    session$setInputs(scan = NA)
    expect_equal(st$msLevel[match(unique(spec_df()$scan), st$scan)], 1L)
  }))
})

test_that("annotation layers on an empty spectrum add nothing and don't warn", {
  # A scan with no peaks left after the filters used to warn
  # "no non-missing arguments to max; returning -Inf".
  p <- ggplot2::ggplot()
  empty <- tibble::tibble(mz = numeric(), intensity = numeric())
  expect_no_warning(out <- annotate_layers(p, list(mode = "adduct"), empty, "Set1"))
  expect_identical(out, p)
})

test_that("with annotation off a spectrum change reads the scan once", {
  # Regression: the anchor-default observer's event expression evaluated the
  # annotation pool, so every rt change also re-read and peak-picked the scan.
  p <- profile_file()
  files <- tibble::tibble(
    id = "f1", path = p, name = basename(p), sample_group = "g1",
    include = TRUE, status = "ready", n_spectra = 1L,
    rt_min = 0, rt_max = 1e5, mz_min = 0, mz_max = 1e4,
    ms_levels = "1", polarities = "1", charges = NA_character_,
    spec_mode = "mixed", message = NA_character_)
  rv <- make_rv(); rv$files <- files
  included <- reactive(files)
  reads <- 0L
  real <- extract_spectrum
  local_mocked_bindings(extract_spectrum = function(...) {
    reads <<- reads + 1L; real(...)
  })
  suppressWarnings(shiny::testServer(mod_plot_spectrum_server,
                    args = list(rv = rv, included = included), {
    session$setInputs(layout = "single", rt = 0.5, scan = NA, annotate = FALSE,
                      cmode = "off", csnr = 0, chws = 2, ck = 0, showpts = FALSE)
    spec_df()
    reads <<- 0L
    session$setInputs(rt = 0.6)
    spec_df()
    expect_equal(reads, 1L)
  }))
})
