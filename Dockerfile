# Run MassScope as a Shiny server app.
#
#   docker build -t massscope .
#   docker run --rm -p 3838:3838 -v /path/to/ms-data:/data massscope
#
# Then open http://localhost:3838 and paste /data (your mounted MS files) into the
# Files box. Settings persist to a per-user config dir inside the container; mount
# a volume at /root/.config/R if you want them to survive container restarts.
#
# Fast build: rocker/r-ver (Ubuntu + R, CRAN preconfigured to Posit Package
# Manager's Linux BINARIES) plus P3M's Bioconductor mirror, which also serves
# Linux binaries (Spectra, xcms, mzR, ...). Almost nothing is compiled; pak adds
# the system libraries the binaries need (netCDF, libxml2, ...) via apt.
# Keep the R minor version in step with the Bioconductor release below.
FROM rocker/r-ver:4.6

ENV R_BIOC_VERSION=3.24
RUN . /etc/os-release \
 && echo "options(BioC_mirror = 'https://p3m.dev/bioconductor/__linux__/${VERSION_CODENAME}/latest')" \
      >> "${R_HOME}/etc/Rprofile.site" \
 && Rscript -e "install.packages('pak')"

WORKDIR /srv/MassScope

# Dependencies first, in their own layer: editing the package source then reuses
# this layer instead of reinstalling everything. Hard deps only (Suggests such
# as testthat/msdata/faahKO are not needed to run the app). The download caches
# are removed in the same layer (~1 GB otherwise baked into the image).
COPY DESCRIPTION /srv/MassScope/
RUN Rscript -e "pak::local_install_deps('.', ask = FALSE, dependencies = NA)" \
 && Rscript -e "pak::cache_clean(); pak::meta_clean(force = TRUE)" \
 && rm -rf /tmp/* /root/.cache/R /var/lib/apt/lists/*

COPY . /srv/MassScope
RUN Rscript -e "pak::local_install('.', ask = FALSE, dependencies = FALSE)" \
 && Rscript -e "library(MassScope)"  # fail the build early if it can't load

# Large uploads via the browser are allowed (run_app sets shiny.maxRequestSize);
# prefer mounting data and pasting the path for big/many files.
EXPOSE 3838
CMD ["Rscript", "-e", "MassScope::run_app(host = '0.0.0.0', port = 3838, launch.browser = FALSE)"]
