# EIC module extraction: per-target rt windows, label keys, empty results.
# Drives the real module on two faahKO CDF files.

skip_if_not_installed("faahKO")

eic_fixture <- function() {
  fs <- list.files(system.file("cdf", "KO", package = "faahKO"), full.names = TRUE)[1:2]
  meta <- tibble::tibble(id = c("a", "b"), name = basename(fs), path = fs,
                         sample_group = "g", disp_name = c("a", "b"))
  x <- build_msexp(meta)
  list(meta = meta, x = x)
}

# testServer captures its expression unevaluated, so splice the test body in.
run_eic <- function(targets, code) {
  fx <- eic_fixture()
  rv <- make_rv(); rv$eic_targets <- targets
  shiny::isolate(rv$settings$time_unit <- "sec")
  args <- list(rv = rv, dataset = reactive(fx$x), meta = reactive(fx$meta),
               data_key = reactive(runif(1)))
  eval(bquote(shiny::testServer(mod_plot_eic_server, args = args, .(substitute(code)))))
}

tg <- function(mz, rt_min = NA_real_, rt_max = NA_real_, label = NULL, tol = 0.5) {
  t <- new_eic_target(mz, tol = tol, unit = "Da")
  if (!is.null(label)) t$label <- label
  t$rt_min <- rt_min; t$rt_max <- rt_max
  t
}

test_that("each target keeps its own rt window; an unset end stays open", {
  targets <- dplyr::bind_rows(tg(300.5, rt_min = 3000, label = "late"),
                              tg(400.5, label = "all"))
  run_eic(targets, {
    df <- eic_df()
    late <- df[df$target == "late", ]; all <- df[df$target == "all", ]
    expect_gt(nrow(late), 0)
    expect_gte(min(late$rt), 3000)          # start bound applied
    expect_lt(min(all$rt), 3000)            # NOT clipped to the other target
    expect_gt(max(late$rt), 4000)           # open end is open, not -Inf
  })
})

test_that("an rt window outside the data gives an empty, well-formed result", {
  run_eic(tg(300.5, rt_min = 1e6, label = "none"), {
    df <- eic_df()
    expect_equal(nrow(df), 0)
    expect_true(all(c("target", "sample_id", "rt", "intensity") %in% names(df)))
  })
})

test_that("duplicate labels become separate traces; bad tolerances are skipped", {
  targets <- dplyr::bind_rows(tg(300.5, label = "x"), tg(400.5, label = "x"),
                              tg(500.5, label = "bad", tol = NA_real_))
  run_eic(targets, {
    expect_identical(enabled_targets()$label, c("x", "x #1"))
    expect_setequal(unique(eic_df()$target), c("x", "x #1"))
  })
})
