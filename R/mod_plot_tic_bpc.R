# mod_plot_tic_bpc — TIC/BPC overlay of included files, colored by metadata.
# Click a trace to load that scan's spectrum (rv$selection).

#' @importFrom plotly plotlyOutput
#' @noRd
mod_plot_tic_bpc_ui <- function(id) {
  ns <- NS(id)
  card(
    full_screen = TRUE,
    card_header(
      "Total / base-peak chromatograms",
      div(class = "float-end", mod_export_ui(ns("export")))
    ),
    layout_sidebar(
      sidebar = sidebar(
        width = 230, position = "right", open = "open",
        radioButtons(ns("agg"), "Chromatogram",
                     c("TIC (sum)" = "sum", "BPC (max)" = "max")),
        selectInput(ns("color_by"), "Color by",
                    c("Sample" = "sample_name", "Sample group" = "sample_group")),
        checkboxInput(ns("points"), "Show data points", value = FALSE),
        helpText("Click a trace to show its spectrum on the Spectrum tab.")
      ),
      plotlyOutput(ns("plot"), height = "100%")
    )
  )
}

#' @importFrom ggplot2 ggplot aes geom_line geom_point scale_color_manual labs theme_bw theme
#' @importFrom plotly renderPlotly
#' @noRd
mod_plot_tic_bpc_server <- function(id, rv, dataset, meta, data_key) {
  moduleServer(id, function(input, output, session) {

    chrom_label <- reactive(if (input$agg == "sum") "TIC" else "BPC")

    # TIC/BPC via xcms::chromatogram (fast under SerialParam), cached on
    # (path set + filter + aggregation) so group/color changes never re-extract.
    chrom_df <- reactive({
      x <- dataset(); req(x)
      extract_chrom(x, meta(), rv$filter, labels = chrom_label(),
                    message = "Extracting chromatograms\u2026",
                    aggregationFun = input$agg)
    }) %>% bindCache(data_key(), input$agg)

    # The ggplot (source of truth for export).
    plot_gg <- reactive({
      df <- chrom_df(); req(nrow(df) > 0)
      unit <- rv$settings$time_unit
      df <- decorate_chrom(df, meta(), input$color_by, unit)
      df$.tip <- chrom_tip(df, unit)
      pal <- brewer_named(unique(df$.color), rv$settings$qual_palette)
      p <- ggplot(df, aes(
        x = rt_disp, y = intensity, group = sample_id, color = .color,
        key = sample_id, text = .tip)) +
        geom_line(linewidth = 0.5)
      if (isTRUE(input$points)) p <- p + geom_point(size = 0.9)
      p +
        labs(x = rt_axis_label(unit), y = "intensity", color = NULL,
             title = paste0(chrom_label(), " \u2014 ", length(unique(df$sample_id)),
                            " file(s)")) +
        chrom_style(pal)
    })

    zoom <- zoom_keeper("tic")
    output$plot <- renderPlotly(finalize_plotly(plot_gg(), "tic", zoom$apply))
    # Click -> selection that drives the Spectrum tab.
    wire_selection("tic", "tic", rv)

    mod_export_server("export", plot_gg, rv, reactive(tolower(chrom_label())),
                      zoom = zoom$ranges)
  })
}
