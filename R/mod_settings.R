# mod_settings — backend choice, palette, async pool, export defaults.

#' @importFrom parallel detectCores
#' @noRd
mod_settings_ui <- function(id) {
  ns <- NS(id)
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
                    value = .default_daemons(), step = 1)
      ),
      settings_card(
        "EIC defaults",
        helpText("Applied to new targets and the paste box."),
        row(c(6, 6),
            numericInput(ns("default_tol"), "Default \u00b1 tolerance", value = 10, min = 0),
            selectInput(ns("default_tol_unit"), "Unit", choices = c("ppm", "Da")))
      ),
      settings_card(
        "HMDB search",
        helpText("A Spectrum peak click set to \u201csearch HMDB\u201d opens hmdb.ca with ",
                 "these. An annotated peak searches its own adduct instead. Usually ",
                 "narrower than the EIC tolerance."),
        row(c(6, 6),
            numericInput(ns("hmdb_tol"), "\u00b1 tolerance", value = 5, min = 0),
            selectInput(ns("hmdb_tol_unit"), "Unit", choices = c("ppm", "Da"))),
        selectizeInput(ns("hmdb_adducts_pos"), "Adducts, positive mode",
                       choices = HMDB_ADDUCTS$pos, selected = HMDB_DEFAULT_ADDUCTS$pos,
                       multiple = TRUE, width = "100%"),
        selectizeInput(ns("hmdb_adducts_neg"), "Adducts, negative mode",
                       choices = HMDB_ADDUCTS$neg, selected = HMDB_DEFAULT_ADDUCTS$neg,
                       multiple = TRUE, width = "100%")
      )
    ),
    settings_card(
      "Appearance & export",
      radioButtons(ns("time_unit"), "Retention-time unit", inline = TRUE,
                   choices = c("Minutes" = "min", "Seconds" = "sec"), selected = "min"),
      selectInput(ns("qual_palette"), "Qualitative palette (groups, EICs)",
                  choices = QUAL_PALETTES),
      selectInput(ns("seq_palette"), "Sequential palette (maps, 3D)",
                  choices = SEQ_PALETTES),
      checkboxInput(ns("invert_scale"), "Invert colour scale (light \u2192 dark)",
                    value = TRUE),
      hr(),
      selectInput(ns("export_format"), "Default export format",
                  choices = c("png", "svg", "pdf", "rds")),
      row(c(4, 4, 4),
          numericInput(ns("export_width"),  "Width",  value = 8, min = 1),
          numericInput(ns("export_height"), "Height", value = 5, min = 1),
          selectInput(ns("export_units"),   "Units",  choices = c("in", "cm", "mm", "px"))),
      numericInput(ns("export_dpi"), "DPI (png)", value = 300, min = 36, max = 1200)
    )
  )
}

#' @noRd
mod_settings_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Restore persisted settings into the controls on startup; the per-field
    # observers below then propagate them into rv$settings. Runs once.
    saved <- load_settings()
    if (length(saved)) {
      if (!is.null(saved$time_unit))    updateRadioButtons(session, "time_unit", selected = saved$time_unit)
      if (!is.null(saved$qual_palette)) updateSelectInput(session, "qual_palette", selected = saved$qual_palette)
      if (!is.null(saved$seq_palette))  updateSelectInput(session, "seq_palette", selected = saved$seq_palette)
      if (!is.null(saved$invert_scale)) updateCheckboxInput(session, "invert_scale", value = saved$invert_scale)
      if (!is.null(saved$default_tol))      updateNumericInput(session, "default_tol", value = saved$default_tol)
      if (!is.null(saved$default_tol_unit)) updateSelectInput(session, "default_tol_unit", selected = saved$default_tol_unit)
      if (!is.null(saved$hmdb_tol))      updateNumericInput(session, "hmdb_tol", value = saved$hmdb_tol)
      if (!is.null(saved$hmdb_tol_unit)) updateSelectInput(session, "hmdb_tol_unit", selected = saved$hmdb_tol_unit)
      # An empty list searches the defaults (hmdb_search_url), so restore it as
      # the defaults too: an empty box would misstate what a click searches.
      if (length(saved$hmdb_adducts_pos)) updateSelectizeInput(session, "hmdb_adducts_pos", selected = unlist(saved$hmdb_adducts_pos))
      if (length(saved$hmdb_adducts_neg)) updateSelectizeInput(session, "hmdb_adducts_neg", selected = unlist(saved$hmdb_adducts_neg))
      if (!is.null(saved$daemons))      updateSliderInput(session, "daemons", value = saved$daemons)
      if (!is.null(saved$export_format))updateSelectInput(session, "export_format", selected = saved$export_format)
      if (!is.null(saved$export_width)) updateNumericInput(session, "export_width", value = saved$export_width)
      if (!is.null(saved$export_height))updateNumericInput(session, "export_height", value = saved$export_height)
      if (!is.null(saved$export_units)) updateSelectInput(session, "export_units", selected = saved$export_units)
      if (!is.null(saved$export_dpi))   updateNumericInput(session, "export_dpi", value = saved$export_dpi)
    }

    # Push each control into its own rv$settings field. Per-field observers (not
    # one observe over all inputs) so changing one setting writes only that field
    # and invalidates only its consumers (rv$settings is a nested reactiveValues).
    observeEvent(input$time_unit,     rv$settings$time_unit     <- input$time_unit)
    observeEvent(input$qual_palette,  rv$settings$qual_palette  <- input$qual_palette)
    observeEvent(input$seq_palette,   rv$settings$seq_palette   <- input$seq_palette)
    observeEvent(input$invert_scale,  rv$settings$invert_scale  <- input$invert_scale)
    # Numeric settings: an emptied field sends NA, which must not replace the
    # last good value (it would persist as "NA" and reach ggsave / new targets).
    for (k in c("default_tol", "hmdb_tol", "export_width", "export_height", "export_dpi"))
      local({
        k <- k
        observeEvent(input[[k]], if (is_pos_num(input[[k]])) rv$settings[[k]] <- input[[k]])
      })
    observeEvent(input$default_tol_unit, rv$settings$default_tol_unit <- input$default_tol_unit)
    observeEvent(input$hmdb_tol_unit, rv$settings$hmdb_tol_unit <- input$hmdb_tol_unit)
    # ignoreNULL = FALSE: clearing every adduct is a real choice (falls back to
    # the defaults at search time), not "no event".
    observeEvent(input$hmdb_adducts_pos, ignoreNULL = FALSE,
                 rv$settings$hmdb_adducts_pos <- as.character(input$hmdb_adducts_pos))
    observeEvent(input$hmdb_adducts_neg, ignoreNULL = FALSE,
                 rv$settings$hmdb_adducts_neg <- as.character(input$hmdb_adducts_neg))
    observeEvent(input$export_format, rv$settings$export_format <- input$export_format)
    observeEvent(input$export_units,  rv$settings$export_units  <- input$export_units)

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
