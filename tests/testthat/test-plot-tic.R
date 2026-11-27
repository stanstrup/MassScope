# TIC/BPC module and the chromatogram helpers it shares with the EIC.

test_that("decorate_chrom joins current metadata, display rt and colour key", {
  df <- tibble::tibble(sample_id = c("b", "a"), rt = c(60, 120), intensity = 1,
                       scan = c(1L, 2L))
  meta <- tibble::tibble(id = c("a", "b"), sample_group = c("g1", "g2"),
                         disp_name = c("A", "B"), path = c("/x/a", "/x/b"))
  local_mocked_bindings(add_precursor_mz = function(df, meta) {
    df$precursorMZ <- NA_real_; df })
  d <- decorate_chrom(df, meta, "sample_group", "min")
  expect_identical(d$sample_name, c("B", "A"))
  expect_identical(d$.color, c("g2", "g1"))
  expect_equal(d$rt_disp, c(1, 2))
  expect_match(chrom_tip(d, "min")[1], "^B\nscan: 1\nrt: 1 min")
})

test_that("the TIC module draws one trace per file with the shared style", {
  skip_if_not_installed("faahKO")
  fs <- list.files(system.file("cdf", "KO", package = "faahKO"), full.names = TRUE)[1:2]
  meta <- tibble::tibble(id = c("a", "b"), name = basename(fs), path = fs,
                         sample_group = c("g1", "g2"), disp_name = c("a", "b"))
  x <- build_msexp(meta)
  rv <- make_rv()
  old_cache <- shiny::getShinyOption("cache")
  shiny::shinyOptions(cache = cachem::cache_mem())
  on.exit(shiny::shinyOptions(cache = old_cache), add = TRUE)
  suppressWarnings(shiny::testServer(mod_plot_tic_bpc_server,
    args = list(rv = rv, dataset = reactive(x), meta = reactive(meta),
                data_key = reactive("k")), {
    session$setInputs(agg = "sum", color_by = "sample_group", points = FALSE)
    g <- plot_gg()
    expect_setequal(unique(g$data$.color), c("g1", "g2"))
    expect_identical(g$theme$legend.position, "bottom")
    expect_match(g$labels$title, "TIC")
  }))
})
