# Async backend (mirai) + per-run runtime setup (formerly the side-effecting
# tail of global.R). These run when the app launches, NOT on package load —
# spawning worker processes / setting global options belongs to run_app().

# Default daemon count: one per core, leaving one free. detectCores() can be
# NA on some platforms, which would put NA in the slider and the pool size.
#' @importFrom parallel detectCores
#' @noRd
.default_daemons <- function() {
  n <- detectCores()
  if (isTRUE(n >= 2)) as.integer(n) - 1L else 1L
}

# The pool size set last by set_daemons() in this R session.
.daemon_state <- new.env(parent = emptyenv())

#' (Re)size the mirai daemon pool used by the async file readers, and preload
#' mzR's namespace in each worker (read_ms_header uses mzR::; preloading avoids
#' the per-call load; requireNamespace, not library(), keeps R CMD check happy).
#' Asking for the size the pool already has is a no-op, so restoring the saved
#' count after setup_runtime() spawned it does not tear the pool down again.
#' @param n number of daemons (>= 1).
#' @return the daemon count actually set.
#' @importFrom mirai daemons everywhere
#' @noRd
set_daemons <- function(n = .default_daemons()) {
  n <- max(1L, as.integer(n))
  if (identical(.daemon_state$n, n) && mirai::daemons_set()) return(n)
  daemons(0)        # reset any existing pool
  daemons(n)
  everywhere(suppressWarnings(requireNamespace("mzR", quietly = TRUE)))
  .daemon_state$n <- n
  n
}

#' One-time runtime setup performed by run_app(): seed the daemon pool at the
#' saved size (the workers only read headers via mzR — fast, no BiocParallel),
#' and allow large uploads. SerialParam is registered in .onLoad, not here.
#' @noRd
setup_runtime <- function() {
  set_daemons(load_settings()$daemons %||% .default_daemons())
  options(shiny.maxRequestSize = 5 * 1024^3)
  # Persist bindCache() results to disk so extractions survive app restarts.
  shinyOptions(cache = app_cache())
  invisible(TRUE)
}
