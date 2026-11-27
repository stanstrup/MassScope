# Code review findings — 2026-11-27

Four independent reviews (data layer; Spectrum + annotation; other plot modules +
shared helpers; app shell, settings + tests), then each reviewer voted on the
merged list. **Votes** = agree / unsure / disagree out of 4. Status is updated as
items are worked: `[x]` done, `[ ]` open, `[-]` deferred (reason given).

## Bugs

- [x] **B1** `chrom_to_df` returns a 0×1 tibble when every chromatogram cell is
  empty (EIC rt window outside the data, no spectra at the level); the EIC
  `left_join(by = "target")` then errors. Return a typed empty tibble.
  `R/fct_extract.R:78`. Votes 4/0/0 (reproduced on faahKO).
- [ ] **B2** The EIC builds ONE rt range from all targets' windows: a target with
  only `rt_min` gives `c(300, -Inf)`, and targets without a window are clipped to
  the others'. Pass a per-target rt matrix (NA ends open per row) and drop the
  post-extraction clip/join. `R/mod_plot_eic.R:184-202`. Votes 4/0/0 (reproduced).
- [ ] **B3** EIC targets are keyed only by label: duplicate labels merge into one
  zig-zag trace and make the join many-to-many. `make.unique()` the labels and
  require a finite tolerance. `R/mod_plot_eic.R:169`. Votes 4/0/0.
- [ ] **B4** NA from an emptied numeric input: `ggsave(dpi = NA)` errors (download
  fails), `width = NA` saves at the 7×5 device default (≠ preview), NA settings
  persist as `"NA"`/`null`, NA `default_tol` reaches new EIC targets. One shared
  positive-number helper; guard the settings observers; type-check on load.
  `R/fct_export.R`, `R/mod_settings.R`, `R/fct_settings_store.R`. Votes 4/0/0.
- [ ] **B5** `make_filter` maps a NULL `ms_level` (Filters panel not yet rendered)
  to NA = all levels, so at startup MS2 scans leak into Spectrum/MS map, and
  opening Filters re-extracts the TIC. Map only `"all"` to NA.
  `R/fct_filters.R:44`. Votes 3/1/0 (reproduced with testServer).
- [ ] **B6** Switching the time unit re-seeds the rt filter boxes with the old
  number under the new unit label (5 min shown as "5" sec). Seed from
  `rt_to_disp(rv$filter$rt_*)`. `R/mod_filter.R:429-475`. Votes 3/1/0 (reproduced).
- [ ] **B7** MS map click always opens the first included file (`inc$id[1]`).
  Carry `key = sample_id` on the traces and use `wire_selection`. Also `export_gg`
  lacks the non-finite/zero `cmax` guard. `R/mod_plot_map.R:162`. Votes 4/0/0.
- [ ] **B8** "Suggest molecular ion" results (an `eventReactive`) go stale after
  moving to another scan/file; the old anchor is drawn on the new spectrum. Reset
  on spectrum change. `R/mod_plot_spectrum.R:367`. Votes 3/1/0.
- [ ] **B9** `text_traces_vertical` rotates the difference-network Δ labels too
  (meant horizontal). `R/mod_plot_spectrum.R:915`. Votes 1/3/0 (reproduced by its
  reviewer).
- [ ] **B10** Facet/Stacked layouts look up the ion mode with the first row's scan
  against the single-view file; it also drives the HMDB search mode.
  `R/mod_plot_spectrum.R:295`. Votes 1/3/0.
- [ ] **B11** `tryCatch(error = function(e) NULL)` around the overlays swallows real
  findMAIN/Rdisop/enviPat failures silently. Keep swallowing `req()`'s silent
  error; notify on the rest (don't rethrow — one overlay must not blank the plot).
  `R/mod_plot_spectrum.R:615,622,668`. Votes 4/0/0.

## Performance

- [ ] **E1** The annotation observer's event expression evaluates
  `ann_candidates()` even with annotation off → an extra extract + pickPeaks on
  every spectrum change. `R/mod_plot_spectrum.R:308`. Votes 4/0/0.
- [ ] **E2** Changing Min int re-reads and re-picks; split the picked pool from the
  intensity floor. `R/mod_plot_spectrum.R:333`. Votes 3/1/0.
- [ ] **E3** Precursors re-extract on a group rename (depend on `included()`, no
  cache); join metadata at plot time, legend by `disp_name`, one `ggplot()` call.
  `R/mod_plot_precursors.R:41-87`. Votes 4/0/0.
- [ ] **E4** MS map scan numbers via `file_scan_table` + float rt matching; take
  `acquisitionNum(sp)` in `extract_peaks`. Check CDF first.
  `R/fct_extract.R:152,237`. Votes 2/2/0.
- [ ] **E5** mzR preload duplicated outside `set_daemons`; `setup_runtime` spawns
  the default pool and the settings restore respawns at the saved size.
  `R/daemons.R`, `R/mod_settings.R:129`. Votes 2/2/0.
- [ ] **E6** `difference_network` is an O(n²) loop with a tibble per hit (2.1 s at
  300 peaks). Index intensities by i,j; vectorise. `R/fct_annotate.R:290`.
  Votes 4/0/0 (low priority).
- [ ] **E7** `iso_neutral` runs Rdisop with annotation unticked
  (`suspendWhenHidden = FALSE`); misleading comment. `R/mod_plot_spectrum.R:447,486`.
  Votes 4/0/0.

## Simplification

- [ ] **C1** One spectrum-selection helper for the three duplicated blocks
  (`spec_df`, `overlay_df`, `ann_candidates`), which have already drifted
  (`f$name` vs `cur_disp()`). With E1/E2. Votes 4/0/0.
- [ ] **C2** TIC and EIC share ~20 lines (extraction, decoration, theme). After
  B1–B3. Votes 4/0/0.
- [ ] **C3** `.flt_rt/.flt_pol/.flt_mz` returning NULL when unset, shared by
  `apply_filters` and `apply_filters_spectra`. Only with the equivalence tests
  green. Votes 2/2/0.
- [ ] **C4** Table-driven settings spec replacing four parallel lists. Votes 1/2/1.
- [ ] **C5** Merge `add_scan_numbers`/`add_precursor_mz`; `memo_by_path()`.
  Votes 1/3/0.
- [ ] **C6** `register_plotly_events` loops over `PLOTLY_EVENTS`. Votes 3/1/0.

## Housekeeping

- [ ] **H1** Delete unused `MS_FILE_EXTS`; remove the cache tmp file when
  `qs_save` fails (`R/fct_cache.R:57`). Votes 4/0/0.
- [ ] **H2** Drop purrr (one `possibly()`); drop the unused
  `importFrom(tibble, as_tibble)`. Votes 4/0/0 (low value).
- [ ] **H3** Delete `tests/testthat/_problems/` and git-ignore it; tests for the
  settings round-trip (empty vectors, NA), filter startup identity (B5), time-unit
  switch (B6). Votes 4/0/0.
- [ ] **H4** Move `isTRUE_vec` to `utils_reactive.R`; `combined_ranges` sorts MS
  levels as text; `detectCores()` NA guard; Da→ppm fallback for findMAIN/Rdisop is
  5 vs 10 ppm and ignores the entered Da. Votes 4/0/0.
- [x] **H5** CLAUDE.md commit trailer — resolved by the user: no Claude mention in
  commit messages at all.
