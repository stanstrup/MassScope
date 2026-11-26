# MassScope — feature showcase video script

A shot-by-shot script for a screen-recorded walkthrough (~10 min). The through-line
is **compound identification from raw LC–MS**, and the spine of it is one loop:
*chromatogram → spectrum → are these peaks one compound? → EICs to check co-elution →
back to the spectrum to annotate.* At each step the voice-over says which question
you're answering, so the tools land as a workflow rather than a tour. Each shot has
**[SCREEN]** (bulleted actions to perform) and **[VO]** (voice-over beats — read as
connected narration, not a list). Times are approximate.

Recording tips: 1440×900 window, browser zoom ~110 % so the sidebar text is legible,
hide the OS cursor trail, and pause ~1 s after each click so the UI settles on camera.
Launch with `MassScope::run_app()` (installed) or, from a clone,
`Rscript -e "pkgload::load_all('.'); run_app()"`. Do one dry run first: TIC/EIC
extractions are cached on disk, so the second pass (the one you record) is fast.

---

## Test files on this machine

Paste these paths straight into the **Files** box. The two public datasets come from
R packages (installed in the R 4.6 library); the small-molecule runs are in
`Downloads`.

| File | Path (paste into Files) | What it is | Use it for |
|---|---|---|---|
| **faahKO KO** (6 CDF) | `C:/Users/tmh331/AppData/Local/R/win-library/4.6/faahKO/cdf/KO` | Centroid MS1, 6 FAAH-knockout samples | TIC/BPC overlay, EIC by group, MS map (fast) |
| **faahKO WT** (6 CDF) | `C:/Users/tmh331/AppData/Local/R/win-library/4.6/faahKO/cdf/WT` | Centroid MS1, 6 wild-type samples | Second group for the KO-vs-WT EIC at *m/z* **335.1** |
| **MS3TMT11.mzML** | `C:/Users/tmh331/AppData/Local/R/win-library/4.6/msdata/proteomics/MS3TMT11.mzML` | Profile MS1 + centroid MS2/MS3, DDA (peptides) | Profile line, peak picking, isotope envelope (scan **22413**, anchor **582.3448**), Precursors map, precursor m/z in hovers |
| **18052015-005.mzML** | `C:/Users/tmh331/Downloads/18052015-005.mzML` | Urine, positive QTOF, centroid MS1 only, 7 min | Adduct / fragment / findMAIN annotation — scan **1408** (rt 5.434 min), base peak [M+H]⁺ |
| **20130222-020.mzML** | `C:/Users/tmh331/Downloads/20130222-020.mzML` | Urine, positive, centroid MS1 + 31 MS2 (all precursor *m/z* 525), 6 min | Small-molecule Precursors view; second urine file for spectrum **Facet / Stacked** comparison |
| **DIME SCFA…Blank + IS.mzML** | `C:/Users/tmh331/Downloads/DIME SCFA240_20220529_SSCFA_061_neg_Reaction Blank + IS.mzML` | Truncated mzML (cut off before its closing tags) — unreadable | Showing that a broken file gets an error badge and the rest still load |

Getting the public paths on another machine:
`system.file("cdf", "KO", package = "faahKO")`, `.../"WT"`, and
`list.files(system.file("proteomics", package = "msdata"), "mzML$", full.names = TRUE)`.

> **Iron-formate (metal complex) demo:** neither urine file has a convincing
> iron-formate series — *m/z* 131.95 / 132.96 only reach ~10–24 counts (best:
> `18052015-005.mzML` scan acq **150**, rt 0.58 min; `20130222-020.mzML` scan acq
> **291**, rt 0.68 min). Use a run with real steel-tubing background if you have one;
> otherwise demo the mechanics on those scans and keep it short.

---

## 0. Cold open (0:00–0:20)

**[SCREEN]**
- Title card (MassScope hex sticker), then cut to the app open on **TIC / BPC** with faahKO loaded and the overlay on screen.

**[VO]**
- MassScope is a local app for reading *raw* LC–MS data by eye — before any peak picking or alignment.
- I use it mostly to figure out what a compound actually is.
- There's one loop I run over and over: chromatogram → spectrum → extract the ions → back to the spectrum. Let me show you that loop.

---

## 1. Loading files — three ways, and which one copies (0:20–1:45)

**[SCREEN]** Empty app, **Files** panel. Show each control in turn:
- Paste the faahKO **KO** folder path into the box → **Add**; then the **WT** path → **Add**.
- Click **Choose folder…** (native OS folder dialog) — cancel it.
- Click **Browse files…**, and separately **drag a file onto it**.

**[VO]**
- Three ways to get files in — and the difference matters once your files are large.
- **Paste a path**, or **Choose folder…**, loads the data **in place — nothing is copied**; a multi-gigabyte file just stays on disk and the app reads it there.
- The path box also takes a **single file**, and a folder load grabs every MS file in *that* folder only — it **doesn't descend into sub-folders**, so KO and WT go in as two folders.
- **Browse files…** — or **dragging files onto it** — is the ordinary OS file dialog, and it **copies** everything into a temp folder first.
- So: handy for a file or two, but for big or many files, paste the path and skip the copy.

**[SCREEN]**
- Let the files read in the background — status badges flip to ✅.
- Point at the **MS**, **Pol**, and **Mode** (`prof`/`cent`/`mix`) columns.
- Double-click a **Group** cell and rename the WT files' group to `WT` (KO → `KO`).
- Click **All** to include everything; show **None** and **Invert** too, then **All** again.

**[VO]**
- Reading happens in the background — several files at once — so the interface never blocks.
- Each row tells me the MS levels, the polarity, and whether the file is **profile or centroided**, which decides how the views behave.
- I set my sample groups right here in the table, and select rows to include files in the plots — All, None, Invert for quick changes.
- Two files can even share a name from different folders — they're kept apart by their parent folder.

**[SCREEN]** *(Optional, 10 s)*
- Paste the truncated **DIME SCFA** file path → **Add**. It gets an error badge and a "Skipped unreadable file" note while the others stay usable.

**[VO]**
- And a broken file doesn't take the session down — it's flagged, skipped, and everything else keeps working.

---

## 2. Chromatogram → click a peak → spectrum (1:45–3:15)

**[SCREEN]**
- On **TIC / BPC**, toggle **BPC (max)** vs **TIC (sum)**.
- Set **Color by** = *Sample group*; tick **Show data points**.
- Hover a trace — tooltip shows file, scan, rt and intensity.
- **Click a peak** on the trace.
- Switch to **Spectrum** — it's already loaded at that scan.

**[VO]**
- I start at the chromatogram just to get oriented — where the run is busy, and whether the groups look alike.
- Then the core move: I **click a peak**, and the mass spectrum at that exact scan is waiting on the Spectrum tab.
- Everything here is linked like that — a click always takes me to the data underneath.

**[SCREEN]** Switch to **MS3TMT11** (trash button clears the list; paste its path → Add → All):
- On **TIC / BPC**, with MS level *all* in Filters, hover an MS2 point — the tooltip now also shows its **precursor m/z**.
- On **Spectrum**, type scan **22413** in *…or scan (acquisition) number* — the title reads "… • profile" and the scan is drawn as a line.
- Tick **Show data points (profile)**.
- Open **Peak picking** → **Raw + centroids overlay**; zoom one cluster.
- Show the **S/N**, **Half-window**, and **m/z accuracy** controls.
- Switch to **Centroid profile scans** for a clean stick spectrum.

**[VO]**
- On DDA data the chromatogram hover even tells me which precursor each MS2 scan fragmented.
- I can jump to a spectrum by retention time *or* by scan number.
- Profile data is drawn as a **line** — thousands of detector samples per peak, which I can even show as points.
- To work with masses I **centroid** it — and because that's *data processing*, it lives right here, per view, not in a global filter.
- I **overlay** the centroids first to see exactly what picking keeps, then switch to a clean **stick spectrum**.

**[SCREEN]**
- Click **Table** → the peak list (rt, m/z, intensity) for what's on screen; show **Copy** and **Download CSV**; close.
- Click **Scan list** → filter by MS level / precursor m/z / polarity / spectrumId → click a row to jump to that scan; close.

**[VO]**
- The numbers behind the plot are one click away — copy them straight into a spreadsheet, or save a CSV.
- And if I don't have a peak to click my way to, every scan's metadata is in the scan list — filter it and jump straight there.

---

## 3. "Are these peaks the same compound?" → EICs (3:15–4:45)

**[SCREEN]** Load **18052015-005.mzML** (urine). On **Spectrum**, go to scan **1408**:
- Set **Click on a peak** to **→ EIC list**.
- **Click several peaks** — the base peak, a neighbour a couple of Da away, a suspected adduct further out (click, click, click).
- Switch to the **EIC** tab — the targets table is populated and the overlaid EICs render.

**[VO]**
- Here's the question a single spectrum can't answer: I see several peaks — but do they belong to **one** compound (a molecular ion with its adducts, isotopes and fragments), or are they different things that just happen to co-elute?
- A spectrum is one slice in time; to tell them apart I need their **chromatograms**.
- So I click each peak into the **EIC list** and pull them out.

**[SCREEN]**
- Set **Scale intensity** = *Normalise each trace (÷ own max)*.
- Point at the peaks that rise and fall together, versus one that peaks at a different time or with a different shape.
- In the targets table, double-click a cell: rename a **label**, change a **tol**, type an **rt_min / rt_max** window to zoom one target.

**[VO]**
- Normalising each trace to its own height throws away abundance and shows me pure **shape**.
- These **rise and fall together** — same retention time, same profile — that's one compound.
- One that peaks slightly earlier, with a different shape, is a **separate species** that was just sitting under the same scan.
- That co-elution test is the difference between annotating a real adduct series and chasing a coincidence.
- Each target is editable — label, tolerance, even its own retention-time window.

**[SCREEN]** *(faahKO, KO + WT included)*
- Paste `335.1` into the paste box (± tol 10 ppm) → **Add to list**.
- Set **Color by** = *Sample group* and **Scale** = *Normalise per target (÷ target max)*.
- Tick **Facet by file**; then try **Log10 (y-axis)**.

**[VO]**
- The same view answers a different question too — across many samples, is my compound more abundant in one group?
- Here's 335 in the FAAH knockouts versus wild-type, clearly up where the biology says it should be.
- I can split it per file, or log-scale it to see the small ones.

---

## 4. Back to the spectrum → annotate the ion set (4:45–6:15)

**[SCREEN]** Return to **Spectrum**, urine scan **1408**:
- Tick **Annotate adducts / fragments**.
- Note **Ion mode** auto-set from the scan polarity; leave **Manual anchor** (base peak default) — the base peak labels **[M+H]⁺**.
- Point at the labelled adduct / fragment / isotope peaks and the *"N candidate peaks feed matching"* readout.
- Open the matching options: **± tol**, **Match S/N**, **Min int (% base)**, **Annotate only top N peaks**, isotope tolerance / **Max isotope M+n** / **Max charge**, **In-source fragments**.
- Tick **Show expected-but-absent**.

**[VO]**
- Now that I know which peaks belong together, I annotate them.
- I anchor on the molecular-ion candidate; the app projects the common adducts and in-source fragments and labels the ones actually present.
- The ion mode follows the scan, and matching runs against **real centroids** at a signal-to-noise I control — with a readout of how many peaks feed it, so nothing is hidden.
- I can also show what *should* be there but isn't — an absent sodium adduct is evidence too.

**[SCREEN]**
- Switch **Mode** → **Auto-suggest (findMAIN)** → **Suggest molecular ion** → click a ranked row.
- Then switch to **Difference network** → show the peak-pair Δ labels.

**[VO]**
- If I'm unsure which peak is the molecule, **findMAIN** ranks the hypotheses for me.
- Or I drop the anchor entirely and annotate the **differences** between peaks — to catch a neutral loss or an adduct relationship I hadn't assumed.

---

## 5. From a mass to a formula — fine isotopes and contaminants (6:15–7:15)

**[SCREEN]** Back on **MS3TMT11**, scan **22413**, peak picking *Raw*, **Show data points** on:
- **Mode** → **Isotope pattern (formula)**; anchor **582.3448**, adduct **[M+H]⁺**.
- Show the candidate-formula table (formula, mass, ppm, DBE, ✓).
- Pick a row → the translucent green **envelope** overlays the raw cluster; zoom to ~580.5–586.5.
- Adjust **Resolving power**; click **From data** to estimate it from the peak width.

**[VO]**
- With the right ion and its neutral mass, I want a **formula**.
- The app decomposes the mass into candidates, then overlays the **fine** isotope pattern for each — the true ¹³C, ¹⁵N, ³⁴S structure, simulated at my instrument's resolving power.
- The envelope is **translucent**, so I can see the raw peaks underneath and judge the fit.
- That's how a mass becomes a confident formula.

**[SCREEN]** *(see the iron-formate note under Test files)*
- Add **Fe** to the **Elements** selector.
- Choose the **[M]+** adduct and turn **off** *Chemically valid only*.
- Anchor **131.9504** or **132.9582** → an iron-formate formula at low ppm.

**[VO]**
- Half of identification is ruling out **contaminants**.
- Iron-formate clusters leach from steel tubing and carry an intrinsic charge from the metal's oxidation state.
- Add iron, pick the metal-ion type, relax the organic-only rule — and the background ion names itself.

---

## 6. MS map — surveying the neighbourhood (7:15–8:00)

**[SCREEN]** faahKO included:
- Go to **MS map**, press **Plot**.
- Drag the **Contrast** slider on the 2-D m/z × rt map; show **rt bin**, **m/z bin**, **Intensity percentile cutoff**, **Line/point size**.
- Note **Peak picking = Centroid profile scans** is on by default.
- Switch to **3D surface**, press **Plot**, and rotate it; then **3D points**.
- Back on 2-D, click a pixel → Spectrum loads that scan.

**[VO]**
- Sometimes I zoom out from one peak and survey the neighbourhood — co-eluting isomers, an adduct series marching across m/z, a contaminant ladder.
- The map bins exact centroids over mass and time; I set the bin sizes, lower the contrast for the weak stuff, or rotate a 3-D view.
- It only draws when I press Plot, because a full map can be millions of points.
- And, as everywhere, click a point to read the spectrum underneath.

---

## 7. Precursors — MS2 for structure (8:00–8:40)

**[SCREEN]**
- With **MS3TMT11** (DDA) included, go to **Precursors**.
- Show the rt × precursor-m/z scatter; **Color by** file.
- Type a range into **Precursor m/z** (e.g. 500–700) — the map narrows.
- Set a global **m/z** filter in Filters — the map does *not* change.
- Click a point → its MS2 loads on the Spectrum tab.
- *(Small-molecule version: include `20130222-020.mzML` — its MS2 all sit on precursor m/z 525.)*

**[VO]**
- For the structural layer of an ID I need **fragmentation**.
- The Precursors map shows exactly what the instrument fragmented and when.
- It has its own precursor-mass range: the global m/z filter selects *peaks*, which on an MS2 means fragments — a different thing — so it's kept separate.
- Click a precursor and I'm reading its MS2, ready to annotate it the same way.

---

## 8. Filters, settings, export (8:40–9:45)

**[SCREEN]**
- Open **Filters**: set an rt window and MS level, add a **Spectrum ID** rule (e.g. `function=1`); watch a plot update; **Reset filters**.
- Open **Settings**: switch the time unit (minutes ↔ seconds) and palette, tick **Invert colour scale**; show the **Parallel readers** slider and the EIC/export defaults.

**[VO]**
- Two housekeeping notes.
- **Global filters** — retention time, m/z, intensity, MS level, polarity, even spectrum-ID rules — narrow every view at once.
- **Settings** — time unit, ColorBrewer and viridis palettes, how many files read in parallel, and the defaults for new EICs and exports — persist across restarts.

**[SCREEN]**
- Zoom into a plot, then press **Save** → the export dialog previews exactly the zoomed view; drag its corner to resize; show png / svg / pdf / rds, width, height, units, DPI.

**[VO]**
- When I've made the case, **Save** exports what I'm looking at — zoom included — as a publication image, or the raw ggplot object to keep tweaking in R.

---

## 9. Close (9:45–10:00)

**[SCREEN]**
- Zoom out to the full app; end card with the hex sticker, the repo URL (`github.com/stanstrup/MassScope`) and the site (`stanstrup.github.io/MassScope`).

**[VO]**
- That's the loop — chromatogram, spectrum, extract the ions to prove they belong together, then annotate to a formula and a structure.
- Raw LC–MS, one click at a time.
- It installs from GitHub or runs from a Docker image, and the website has a guide for every tab.

---

### Feature checklist (make sure the recording hits all of these)

- [ ] Loading: paste-path / Choose folder (no copy) vs Browse / drag-and-drop (copies to temp); single file or non-recursive folder
- [ ] Async parallel reading, status badges, Mode column (prof/cent/mix), group editing, All/None/Invert, clear-all, same-name disambiguation, unreadable file flagged + skipped
- [ ] TIC vs BPC, colour by sample/group, show data points, hover (scan, rt, int, precursor m/z of MSn), click-to-spectrum
- [ ] Spectrum by rt or scan number; Single / Facet by file / Stacked layouts
- [ ] Profile spectrum as a line; show data points
- [ ] Peak picking modes: raw / overlay / centroid / force; S/N, half-window, m/z accuracy
- [ ] Spectrum **Table** (copy / CSV) and **Scan list** browser (typed filters, click a row)
- [ ] **Co-elution loop**: click peaks → EIC list; normalise-each-trace to compare shapes; same-vs-different call
- [ ] EIC targets table (label, tol, rt window editable; add/remove rows); paste list with tolerance
- [ ] EIC cross-sample: colour by group; scale raw / per trace / per target / log10; facet by file; data points
- [ ] Annotation: manual anchor, findMAIN auto, difference network; ion mode from scan; Match S/N + candidate readout; top N, isotope/charge limits, in-source fragments, expected-but-absent
- [ ] Isotope pattern: candidate formulas, translucent envelope, resolving power, From data
- [ ] Metal complexes: Elements + [M]+ + valid-only off (131.9504 / 132.9582)
- [ ] MS map: Plot button, 2D contrast, rt/m/z bins, intensity cutoff, point size, 3D surface / points, click-to-spectrum
- [ ] Precursors: DDA map, colour by, own precursor m/z range (independent of the m/z filter), click-to-MS2
- [ ] Filters (incl. spectrum-ID rules, reset), Settings (persisted; palettes, invert, parallel readers, defaults)
- [ ] Export: zoom-aware, resizable preview, png/svg/pdf/rds, size/units/DPI
