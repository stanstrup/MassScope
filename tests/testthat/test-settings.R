# Settings: one declared table (settings_spec) drives the defaults, the
# persisted list, the restore and the control -> rv$settings observers.

test_that("make_rv's settings are exactly the spec's defaults", {
  rv <- make_rv()
  got <- shiny::isolate(shiny::reactiveValuesToList(rv$settings))
  expect_identical(got[names(settings_defaults())], settings_defaults())
  expect_setequal(names(got), names(settings_spec()))
  kinds <- vapply(settings_spec(), `[[`, "", "kind")
  expect_true(all(kinds %in% c("chr", "chrs", "lgl", "num")))
})

test_that("each restored setting goes to its control; empty adducts are skipped", {
  withr::local_envvar(R_USER_CONFIG_DIR = withr::local_tempdir())
  save_settings(list(time_unit = "sec", default_tol = 20, invert_scale = FALSE,
                     hmdb_adducts_pos = character(), hmdb_adducts_neg = "M-H",
                     export_dpi = NA_real_, daemons = 2))
  calls <- list()
  local_mocked_bindings(restore_control = function(session, id, control, value)
    calls[[id]] <<- list(control = control, value = value))
  shiny::testServer(mod_settings_server, args = list(rv = make_rv()), {
    expect_identical(calls$time_unit, list(control = "radio", value = "sec"))
    expect_identical(calls$default_tol, list(control = "numeric", value = 20L))
    expect_identical(calls$invert_scale$control, "checkbox")
    expect_identical(calls$daemons$control, "slider")
    expect_identical(calls$hmdb_adducts_neg$value, "M-H")
    expect_null(calls$hmdb_adducts_pos)     # empty -> controls keep the defaults
    expect_null(calls$export_dpi)           # NA was dropped on load
  })
})

test_that("controls write their settings; NA numbers and cleared adducts behave", {
  withr::local_envvar(R_USER_CONFIG_DIR = withr::local_tempdir())
  rv <- make_rv()
  shiny::testServer(mod_settings_server, args = list(rv = rv), {
    session$setInputs(time_unit = "sec", export_dpi = 150, default_tol = 7)
    expect_identical(rv$settings$time_unit, "sec")
    expect_equal(rv$settings$export_dpi, 150)
    session$setInputs(export_dpi = NA)                 # emptied field
    expect_equal(rv$settings$export_dpi, 150)          # keeps the last good value
    session$setInputs(hmdb_adducts_pos = c("M+H", "M+K"))
    expect_identical(rv$settings$hmdb_adducts_pos, c("M+H", "M+K"))
    session$setInputs(hmdb_adducts_pos = NULL)         # all cleared
    expect_identical(rv$settings$hmdb_adducts_pos, character())
  })
})
