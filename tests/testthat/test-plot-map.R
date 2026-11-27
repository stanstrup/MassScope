# MS map module: the click must carry the clicked segment's file.

skip_if_not_installed("faahKO")

test_that("map traces carry each segment's file id as the click key", {
  # Regression: a map click always opened the FIRST included file's spectrum.
  fs <- list.files(system.file("cdf", "KO", package = "faahKO"), full.names = TRUE)[1:2]
  inc <- tibble::tibble(id = c("a", "b"), path = fs, name = basename(fs),
                        sample_group = "g")
  rv <- make_rv()
  shiny::isolate(rv$filter$mz_min <- 300)
  shiny::isolate(rv$filter$mz_max <- 302)
  shiny::testServer(mod_plot_map_server,
                    args = list(rv = rv, included = function() inc), {
    session$setInputs(mode = "map", contrast = 99, psize = 1, cmode = "off", plot = 1)
    w <- jsonlite::fromJSON(output$plot_out, simplifyVector = FALSE)
    keys <- unlist(lapply(w$x$data, function(tr) unlist(tr$key)))
    expect_setequal(unique(stats::na.omit(keys)), c("a", "b"))
  })
})
