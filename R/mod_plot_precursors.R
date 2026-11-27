# mod_plot_precursors — precursor-ion map (DDA) for the included MS2 files.
# Each point is a precursor selected for fragmentation. Click a point to show its
# MS2 spectrum (that exact scan) on the Spectrum tab.

#' @importFrom plotly plotlyOutput
#' @noRd
mod_plot_precursors_ui <- function(id) {
  ns <- NS(id)
  card(
    full_screen = TRUE,
    card_header("Precursor ions (DDA)",
                div(class = "float-end", mod_export_ui(ns("export")))),
    layout_sidebar(
      sidebar = sidebar(
        width = 240, position = "right", open = "open",
        selectInput(ns("color_by"), "Color by",
                    c("File" = "sample_name", "Sample group" = "sample_group",
                      "None" = "none")),
        tags$label(class = "control-label", "Precursor m/z"),
        div(class = "d-flex gap-2",
            numericInput(ns("pmz_min"), NULL, value = NA, step = 0.0001, width = "100%"),
            numericInput(ns("pmz_max"), NULL, value = NA, step = 0.0001, width = "100%")),
        helpText("Uses the included files that contain MS2. Click a point to ",
                 "view its spectrum."),
        helpText("Filters apply to the precursors: rt, polarity and spectrum id ",
                 "as usual; intensity acts on the precursor intensity. The ",
                 "global m/z filter (peaks) is not used here; set the precursor ",
                 "m/z range above. An MS1 level filter is ignored here.")
      ),
      plotlyOutput(ns("plot"), height = "100%")
    )
  )
}

#' @importFrom ggplot2 ggplot aes geom_point scale_color_manual labs theme_bw
#' @importFrom plotly renderPlotly
#' @noRd
mod_plot_precursors_server <- function(id, rv, included) {
  moduleServer(id, function(input, output, session) {

    ms2_files <- reactive({
      inc <- included()
      if (nrow(inc) == 0) return(inc)
      has2 <- vapply(strsplit(inc$ms_levels %||% "", ",\\s*"), function(v)
        any(suppressWarnings(as.integer(v)) > 1, na.rm = TRUE), logical(1))
      inc[has2, , drop = FALSE]
    })

    # Own precursor m/z range, independent of the global (peak) m/z filter.
    # Debounced so typing a number does not re-read every file per keystroke.
    pmz_range <- debounce(reactive({
      num <- function(v) if (is.null(v) || !is.finite(v)) NA_real_ else v
      c(num(input$pmz_min), num(input$pmz_max))
    }), 500)

    # Extract only what the files decide (id + precursors), cached on the MS2 file
    # set, filter and precursor range. Names and groups are joined at plot time, as
    # on the TIC/EIC: renaming a group or (un)ticking a file without MS2 used to
    # re-read every MS2 file.
    prec_df <- reactive({
      f2 <- ms2_files()
      validate(need(nrow(f2) > 0,
                    "No included file contains MS2 spectra (need DDA data)."))
      withProgress(message = "Reading precursors\u2026", value = 0.5, {
        flt <- rv$filter
        pr <- pmz_range()
        extract_over_files(f2, function(p) extract_precursors(p, flt, pr),
                           cols = "sample_id", on_error = notify_read_failures)
      })
    }) %>% bindCache({
      f2 <- ms2_files(); o <- order(f2$path)
      list(paths = f2$path[o], ids = f2$id[o], filter = rv$filter, pmz = pmz_range())
    })

    plot_gg <- reactive({
      df <- prec_df()
      validate(need(nrow(df) > 0, "No precursor ions found (check the Filters)."))
      inc <- included(); idx <- match(df$sample_id, inc$id)
      df$sample_name <- inc$disp_name[idx]   # unique display label (disambiguated)
      df$sample_group <- inc$sample_group[idx]
      unit <- rv$settings$time_unit
      df$rt_disp <- rt_to_disp(df$rt, unit)
      df$.tip <- sprintf("precursor m/z: %.4f\nscan: %s\nrt: %.4g %s | %s",
                         df$precursorMZ, ifelse(is.na(df$scan), "?", df$scan),
                         df$rt_disp, unit, df$sample_name)
      cby <- input$color_by
      # "None" is one colour for every point: a constant .color through the same
      # aesthetic and scale, so there is a single ggplot() call either way.
      df$.color <- if (identical(cby, "none")) "all" else df[[cby]]
      p <- ggplot(df, aes(x = rt_disp, y = precursorMZ,
                          color = .color, key = sample_id, text = .tip)) +
        geom_point(alpha = 0.5, size = 1.2) +
        scale_color_manual(
          values = brewer_named(unique(df$.color), rv$settings$qual_palette),
          guide = if (identical(cby, "none")) "none" else "legend")
      p + labs(x = rt_axis_label(unit), y = "precursor m/z", color = NULL) +
        theme_bw()
    })

    zoom <- zoom_keeper("prec")
    output$plot <- renderPlotly(finalize_plotly(plot_gg(), "prec", zoom$apply))
    # Hand the clicked point's MS2 scan to the Spectrum tab, so it shows that
    # fragment spectrum rather than the nearest scan at the global MS level (MS1).
    # The click gives file (key), displayed rt (x) and precursor m/z (y); match
    # the nearest precursor of that file.
    clicked_scan <- function(ev) {
      df <- isolate(prec_df())
      df <- df[df$sample_id == ev$key, , drop = FALSE]
      if (!nrow(df)) return(NA_integer_)
      rt_sec <- rt_to_sec(ev$x, isolate(rv$settings$time_unit))
      i <- which.min(abs(df$rt - rt_sec) + abs(df$precursorMZ - ev$y))
      as.integer(df$scan[i])
    }
    wire_selection("prec", "prec", rv, mz_from = function(ev) ev$y,
                   scan_from = clicked_scan)

    mod_export_server("export", plot_gg, rv, "precursors", zoom = zoom$ranges)
  })
}
