# Precursor map module: metadata edits must not re-read the files.

skip_if_not_installed("msdata")

test_that("renaming a group recolours without re-extracting", {
  p <- normalizePath(list.files(system.file("proteomics", package = "msdata"),
                                full.names = TRUE, pattern = "mzML$")[1])
  inc <- shiny::reactiveVal(tibble::tibble(
    id = "f1", path = p, name = basename(p), sample_group = "g1",
    ms_levels = "1, 2, 3", disp_name = "MS3TMT11"))
  rv <- make_rv()
  reads <- 0L
  real <- extract_precursors
  local_mocked_bindings(extract_precursors = function(...) {
    reads <<- reads + 1L; real(...)
  })
  old_cache <- shiny::getShinyOption("cache")
  shiny::shinyOptions(cache = cachem::cache_mem())
  on.exit(shiny::shinyOptions(cache = old_cache), add = TRUE)
  suppressWarnings(shiny::testServer(mod_plot_precursors_server,
                    args = list(rv = rv, included = function() inc()), {
    session$setInputs(color_by = "sample_group", pmz_min = NA, pmz_max = NA)
    session$elapse(600)
    g <- plot_gg()
    expect_equal(reads, 1L)
    expect_identical(unique(g$data$.color), "g1")

    x <- inc(); x$sample_group <- "renamed"; inc(x)
    session$flushReact()
    g <- plot_gg()
    expect_equal(reads, 1L)                        # served from the cache
    expect_identical(unique(g$data$.color), "renamed")
  }))
})
