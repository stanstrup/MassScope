# The Filters panel is a renderUI whose hints and MS-level choices are read off
# the included files, so it is rebuilt whenever that set changes. It must not
# take the user's typed filter down with it.

# Minimal "included files" rows: combined_ranges() only needs the range columns.
inc_rows <- function(n = 1, ms = "1") {
  tibble::tibble(
    id = paste0("f", seq_len(n)), path = paste0("/d/f", seq_len(n), ".mzML"),
    name = paste0("f", seq_len(n), ".mzML"), sample_group = "group1",
    include = TRUE, status = "ready", n_spectra = 100L,
    rt_min = 0, rt_max = 600, mz_min = 100, mz_max = 1000,
    ms_levels = ms, polarities = "pos", charges = NA_character_,
    spec_mode = "centroid", message = NA_character_)
}

test_that("adding files keeps the filter the user typed", {
  # Regression (#3): including another file re-ran output$controls, which
  # rebuilt every numericInput at its default (NA) and reset MS level/polarity.
  # The user's filter silently vanished the moment they ticked one more file.
  rv <- make_rv()
  files <- shiny::reactiveVal(inc_rows(1, ms = "1"))

  shiny::testServer(mod_filter_server,
                    args = list(rv = rv, included = function() files()), {
    session$setInputs(rt_min = 5, rt_max = 8, mz_min = 200, int_min = 1000,
                      ms_level = "1", polarity = "pos")
    before <- as.character(output$controls$html)
    expect_match(before, 'value="5"')

    files(inc_rows(3, ms = "1, 2"))    # a second/third file joins
    session$flushReact()
    after <- as.character(output$controls$html)

    expect_match(after, 'value="5"')        # rt min survived (was blank)
    expect_match(after, 'value="8"')
    expect_match(after, 'value="200"')
    expect_match(after, 'value="1000"')
    expect_match(after, '<option value="pos" selected>')
    expect_match(after, '<option value="1" selected>')
  })
})

test_that("a filter the new file set cannot honour falls back to the default", {
  # MS level 2 is meaningless once only MS1 files are included.
  rv <- make_rv()
  files <- shiny::reactiveVal(inc_rows(2, ms = "1, 2"))

  shiny::testServer(mod_filter_server,
                    args = list(rv = rv, included = function() files()), {
    session$setInputs(ms_level = "2")
    expect_match(as.character(output$controls$html), '<option value="2" selected>')

    files(inc_rows(1, ms = "1"))            # MS2 file dropped
    session$flushReact()
    expect_match(as.character(output$controls$html), '<option value="1" selected>')
  })
})

test_that("before the panel renders, the filter stays at its default (MS1)", {
  # Regression: the filter observer fires with every input NULL before the
  # Filters section is first opened; NULL ms_level was read as "all levels",
  # so MSn scans reached the Spectrum/MS map views at startup.
  rv <- make_rv()
  shiny::testServer(mod_filter_server,
                    args = list(rv = rv, included = function() NULL), {
    session$elapse(700)
    expect_identical(rv$filter, empty_filter())
  })
  expect_identical(make_filter(list(), "min")$ms_level, 1L)
  expect_true(is.na(make_filter(list(ms_level = "all"), "min")$ms_level))
})

test_that("switching the time unit converts the typed rt bounds", {
  # Regression: 5 (min) was re-seeded as "5" under the "sec" label.
  rv <- make_rv()
  files <- shiny::reactiveVal(inc_rows(1))
  shiny::testServer(mod_filter_server,
                    args = list(rv = rv, included = function() files()), {
    output$controls                       # first render, in minutes
    session$setInputs(rt_min = 5)
    session$elapse(700)
    expect_equal(rv$filter$rt_min, 300)

    rv$settings$time_unit <- "sec"
    session$flushReact()
    expect_match(as.character(output$controls$html), 'value="300"')
  })
})

test_that("an MS2-only file set defaults to all levels before the panel opens", {
  rv <- make_rv()
  shiny::testServer(mod_filter_server,
                    args = list(rv = rv, included = function() inc_rows(1, ms = "2")), {
    session$elapse(700)
    expect_true(is.na(rv$filter$ms_level))
  })
})

test_that("a unit round-trip of an rt bound is not a filter change", {
  rv <- make_rv()
  files <- shiny::reactiveVal(inc_rows(1))
  shiny::testServer(mod_filter_server,
                    args = list(rv = rv, included = function() files()), {
    output$controls
    session$setInputs(rt_min = 37 / 60)
    session$elapse(700)
    f0 <- rv$filter
    # what the browser sends back for value = 37/60 after a sec -> min switch
    session$setInputs(rt_min = as.numeric(format(37 / 60, digits = 15)))
    session$elapse(700)
    expect_identical(rv$filter, f0)
  })
})
