# Regenerates the images in man/figures used by the README.
# Needs Google Chrome (headless), internet access (Ace from cdnjs) and the
# magick and jsonlite packages.
# Run from the package root: Rscript data-raw/figures.R
library(rswallpaper)

chrome <- Sys.getenv("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
img <- system.file("extdata", "hanakuma_chifuyu.png", package = "rswallpaper")
out <- "man/figures"
dir.create(out, showWarnings = FALSE, recursive = TRUE)

shot <- function(html, png, width = 1280, height = 800) {
  png <- normalizePath(png, mustWork = FALSE)
  # Never leave a stale image behind if Chrome fails.
  unlink(png)
  for (attempt in 1:2) {
    # system2() does not quote arguments, and paths may contain spaces.
    log <- system2(chrome, shQuote(c(
      "--headless=new", "--disable-gpu", "--hide-scrollbars", "--virtual-time-budget=4000",
      paste0("--user-data-dir=", tempfile("chrome")),
      paste0("--screenshot=", png),
      paste0("--window-size=", width, ",", height),
      paste0("file://", normalizePath(html))
    )), stdout = TRUE, stderr = TRUE)
    if (file.exists(png)) return(invisible(png))
  }
  stop("Chrome did not write ", png, ":\n", paste(utils::tail(log, 5), collapse = "\n"))
}

preview <- function(file, ...) {
  html <- preview_theme(..., file = tempfile(fileext = ".html"), open = FALSE)
  shot(html, file.path(out, file))
}

preview("hero-light.png", img, theme = "matcha", mode = "behind", opacity = 0.45, size = 0.95, tint = 0.6)
# Low-saturation grey-green with a wisteria accent that echoes the skirt trim.
sage_wisteria <- rs_palette("#B3AEDB", dark = TRUE, name = "Sage Wisteria", bg = "#1D2220", bg_hue = 150)
preview("hero-dark.png", img, theme = sage_wisteria, mode = "behind", opacity = 0.55, size = 0.95)

# Overlay vs behind on a real Ace editor (loaded from cdnjs), image pushed over
# the code so the layering is visible.
ace_page <- function(mode) {
  css <- readLines(build_theme(img, theme = "matcha", mode = mode, opacity = 0.75,
                               position = "left 40px top 0", size = "auto 130%"))
  code <- jsonlite::toJSON(paste(rswallpaper:::SAMPLE_CODE, collapse = "\n"), auto_unbox = TRUE)
  html <- tempfile(fileext = ".html")
  writeLines(c(
    '<!doctype html><html><head><meta charset="utf-8"><style>', css, '</style>',
    '<style>body{margin:0}#rstudio_source_text_editor{position:absolute;inset:0;font-size:14px}</style></head><body>',
    '<div id="rstudio_source_text_editor"></div>',
    '<script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.32.6/ace.js"></script>',
    '<script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.32.6/mode-r.js"></script>',
    '<script>var e = ace.edit("rstudio_source_text_editor");',
    'e.setTheme({cssClass: "ace-rs", cssText: "", isDark: false});',
    paste0('e.session.setMode("ace/mode/r"); e.setValue(', code, ', -1); e.gotoLine(12, 10);</script>'),
    '</body></html>'
  ), html)
  png <- tempfile(fileext = ".png")
  shot(html, png, 1000, 560)
  magick::image_crop(magick::image_read(png), "500x330+0+0")
}
magick::image_write(magick::image_append(c(ace_page("overlay"), ace_page("behind"))),
                    file.path(out, "modes.png"))

for (f in list.files(out, pattern = "\\.png$", full.names = TRUE)) {
  magick::image_write(magick::image_read(f), f, format = "png", quality = 95)
}
