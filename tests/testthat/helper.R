demo_img <- function() {
  system.file("extdata", "hanakuma_chifuyu.png", package = "rswallpaper")
}

demo_svg <- function() {
  f <- tempfile(fileext = ".svg")
  writeLines('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><circle cx="5" cy="5" r="4" fill="#E0628E"/></svg>', f)
  f
}

# A small PNG: left half vivid red, right half vivid blue, bottom rows transparent.
demo_png <- function() {
  skip_if_not_installed("png")
  a <- array(0, c(40, 60, 4))
  a[, 1:30, 1] <- 0.9
  a[, 1:30, 2] <- 0.1
  a[, 1:30, 3] <- 0.15
  a[, 31:60, 1] <- 0.1
  a[, 31:60, 2] <- 0.3
  a[, 31:60, 3] <- 0.95
  a[, , 4] <- 1
  a[35:40, , 4] <- 0
  f <- tempfile(fileext = ".png")
  png::writePNG(a, f)
  f
}

# Minimal installed-theme stand-in.
demo_rstheme <- function(dir = tempfile("themes"), name = "Demo Light", dark = FALSE) {
  dir.create(dir, showWarnings = FALSE)
  f <- file.path(dir, paste0(gsub(" ", "_", name), ".rstheme"))
  writeLines(c(
    sprintf("/* rs-theme-name: %s */", name),
    sprintf("/* rs-theme-is-dark: %s */", if (dark) "TRUE" else "FALSE"),
    ".ace_gutter { background: #f0f0f0; color: #999; }",
    ".ace_editor, .ace_editor_theme { background-color: #FBF7EF; color: #657377; }",
    ".ace_marker-layer .ace_active-line { background: #F1E9D2; }",
    ".ace_keyword { color: #819500; }",
    ".ace_indent-guide { background: url(data:image/png;base64,iVBORw0KGgo=) right repeat-y; }"
  ), f)
  f
}

css_balanced <- function(lines) {
  txt <- gsub('url\\("[^"]*"\\)', "url()", paste(lines, collapse = "\n"))
  nchar(gsub("[^{]", "", txt)) == nchar(gsub("[^}]", "", txt))
}
