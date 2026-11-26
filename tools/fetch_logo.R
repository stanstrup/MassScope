# Fetch the MassScope hex sticker into man/figures/ for pkgdown, which picks up
# man/figures/logo.svg automatically. The sticker is maintained in
# stanstrup-hexstickers (private repo) and served from its GitHub Pages site, so
# it is not committed here (git-ignored). Run before pkgdown::build_site():
#   Rscript tools/fetch_logo.R
base <- "https://stanstrup.github.io/stanstrup-hexstickers"
dir.create("man/figures", showWarnings = FALSE, recursive = TRUE)
download.file(file.path(base, "svg", "MassScope.svg"), "man/figures/logo.svg",
              mode = "wb", quiet = TRUE)
