# mod_settings — backend choice, palette, async pool, export defaults.

#' @importFrom parallel detectCores
#' @noRd
mod_settings_ui <- function(id) {
  ns <- NS(id)
  d <- settings_defaults()   # initial values come from the one settings table
  # The nav panel is a fillable container, and a fillable card body shrinks its
  # children to fit the card's height: the inline rows (tolerance + unit, width +
  # height + units) collapsed and the next field's label was drawn over them.
  # Non-filling cards / bodies and rows keep every field at its natural height
  # and let the page scroll instead.
  settings_card <- function(title, ...)
    card(fill = FALSE, class = "ms-settings", card_header(title),
         card_body(fillable = FALSE, ...))
  row <- function(widths, ...) layout_columns(col_widths = widths, fill = FALSE, ...)
  # Non-filling bodies drop the flex gap, so give help texts their own spacing.
  css <- tags$style(".ms-settings .help-block{display:block;margin-bottom:.6rem}")
  layout_columns(
    col_widths = c(6, 6), fill = FALSE,
    div(
      css,
      settings_card(
        "Data reading",
        helpText(HTML("Files are read via <code>Spectra</code>/<code>xcms</code> with ",
                 "<code>BiocParallel::SerialParam()</code> registered \u2014 the default ",
                 "<code>SnowParam</code> backend is ~100\u00d7 slower.")),
        sliderInput(ns("daemons"), "Parallel readers (mirai daemons)",
                    min = 1, max = max(2L, detectCores(), na.rm = TRUE),
                    value = d$daemons, step = 1)
      ),
      settings_card(
        "EIC defaults",
        helpText("Applied to new targets and the paste box."),
        row(c(6, 6),
            numericInput(ns("default_tol"), "Default \u00b1 tolerance",
                         value = d$default_tol, min = 0),
            selectInput(ns("default_tol_unit"), "Unit", choices = c("ppm", "Da"),
                        selected = d$default_tol_unit))
      ),
      settings_card(
        "HMDB search",
        helpText("A Spectrum peak click set to \u201csearch HMDB\u201d opens hmdb.ca with ",
                 "these. An annotated peak searches its own adduct instead. Usually ",
                 "narrower than the EIC tolerance."),
        row(c(6, 6),
            numericInput(ns("hmdb_tol"), "\u00b1 tolerance", value = d$hmdb_tol, min = 0),
            selectInput(ns("hmdb_tol_unit"), "Unit", choices = c("ppm", "Da"),
                        selected = d$hmdb_tol_unit)),
        selectizeInput(ns("hmdb_adducts_pos"), "Adducts, positive mode",
                       choices = HMDB_ADDUCTS$pos, selected = d$hmdb_adducts_pos,
                       multiple = TRUE, width = "100%"),
        selectizeInput(ns("hmdb_adducts_neg"), "Adducts, negative mode",
                       choices = HMDB_ADDUCTS$neg, selected = d$hmdb_adducts_neg,
                       multiple = TRUE, width = "100%")
      )
    ),
    settings_card(
      "Appearance & export",
      radioButtons(ns("time_unit"), "Retention-time unit", inline = TRUE,
                   choices = c("Minutes" = "min", "Seconds" = "sec"),
                   selected = d$time_unit),
      selectInput(ns("qual_palette"), "Qualitative palette (groups, EICs)",
                  choices = QUAL_PALETTES, selected = d$qual_palette),
      selectInput(ns("seq_palette"), "Sequential palette (maps, 3D)",
                  choices = SEQ_PALETTES, selected = d$seq_palette),
      checkboxInput(ns("invert_scale"), "Invert colour scale (light \u2192 dark)",
                    value = d$invert_scale),
      hr(),
      selectInput(ns("export_format"), "Default export format",
                  choices = c("png", "svg", "pdf", "rds"), selected = d$export_format),
      row(c(4, 4, 4),
          numericInput(ns("export_width"),  "Width",  value = d$export_width, min = 1),
          numericInput(ns("export_height"), "Height", value = d$export_height, min = 1),
          selectInput(ns("export_units"),   "Units",  choices = c("in", "cm", "mm", "px"),
                      selected = d$export_units)),
      numericInput(ns("export_dpi"), "DPI (png)", value = d$export_dpi, min = 36, max = 1200)
    )
  )
}

#' Set a Settings control to a restored value, by the control's kind (from
#' settings_spec()).
#' @noRd
restore_control <- function(session, id, control, value) {
  switch(control,
    radio     = updateRadioButtons(session, id, selected = value),
    select    = updateSelectInput(session, id, selected = value),
    selectize = updateSelectizeInput(session, id, selected = value),
    checkbox  = updateCheckboxInput(session, id, value = value),
    numeric   = updateNumericInput(session, id, value = value),
    slider    = updateSliderInput(session, id, value = value),
    stop("unknown settings control: ", control))
}

#' @noRd
mod_settings_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    spec <- settings_spec()

    # Restore persisted settings into the controls on startup (load_settings has
    # already dropped values of the wrong shape); the observers below then
    # propagate them into rv$settings. Runs once.
    saved <- load_settings()
    for (k in names(saved)) {
      # An empty adduct list searches the defaults (hmdb_search_url), so it is
      # restored as the defaults: an empty box would misstate what a click searches.
      if (identical(spec[[k]]$kind, "chrs") && !length(saved[[k]])) next
      restore_control(session, k, spec[[k]]$control, saved[[k]])
    }

    # Push each control into its own rv$settings field. Per-field observers (not
    # one observe over all inputs) so changing one setting writes only that field
    # and invalidates only its consumers (rv$settings is a nested reactiveValues).
    # The daemon count is handled below: it resizes the worker pool.
    for (k in setdiff(names(spec), "daemons")) local({
      k <- k
      switch(spec[[k]]$kind,
        # An emptied numeric field sends NA, which must not replace the last good
        # value (it would persist as "NA" and reach ggsave / new EIC targets).
        num  = observeEvent(input[[k]],
                            if (is_pos_num(input[[k]])) rv$settings[[k]] <- input[[k]]),
        # ignoreNULL = FALSE: clearing every adduct is a real choice (it falls
        # back to the defaults at search time), not "no event".
        chrs = observeEvent(input[[k]], ignoreNULL = FALSE,
                            rv$settings[[k]] <- as.character(input[[k]])),
        observeEvent(input[[k]], rv$settings[[k]] <- input[[k]]))
    })

    # Resize the mirai pool when the user changes the daemon count (debounced).
    daemon_n <- reactive(input$daemons) %>% debounce(800)
    observeEvent(daemon_n(), {
      req(daemon_n())
      rv$settings$daemons <- set_daemons(daemon_n())
    }, ignoreInit = TRUE)

    # Persist settings across restarts (debounced; ignoreInit so loading doesn't
    # immediately rewrite). reactiveValuesToList tracks every field.
    settings_snapshot <- reactive(reactiveValuesToList(rv$settings)) %>% debounce(1000)
    observeEvent(settings_snapshot(), save_settings(settings_snapshot()),
                 ignoreInit = TRUE)
  })
}
