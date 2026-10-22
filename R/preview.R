#' Preview a theme in the browser
#'
#' Renders a mock RStudio window (source editor, console, environment and
#' files panes) styled with the theme, so you can try settings without
#' touching your IDE. Takes the same arguments as [set_wallpaper()], or an
#' existing `.rstheme` file.
#'
#' The mock imitates RStudio's markup closely enough to judge colours,
#' opacity and placement, but it is not RStudio itself.
#'
#' @inheritParams set_wallpaper
#' @param ... Further arguments for [build_theme()], e.g. `accent`,
#'   `opacity`, `mode`.
#' @param rstheme Path to an existing `.rstheme` file to preview instead.
#' @param file Where to write the HTML. Defaults to a temporary file.
#' @param open Open the preview (RStudio Viewer or web browser).
#' @return Path to the HTML file, invisibly.
#' @export
#' @examples
#' demo <- system.file("extdata", "hanakuma_chifuyu.png", package = "rswallpaper")
#' f <- preview_theme(demo, theme = "matcha", mode = "behind", open = FALSE)
#' file.exists(f)
preview_theme <- function(img = NULL, theme = NULL, ..., rstheme = NULL, file = NULL,
                          open = interactive()) {
  rstheme <- rstheme %||% build_theme(img = img, theme = theme, ...)
  css <- readLines(rstheme, warn = FALSE, encoding = "UTF-8")
  header <- read_theme_header(rstheme)
  file <- file %||% file.path(tempdir(), "rswallpaper-preview.html")
  writeLines(mock_html(css, header$is_dark, header$name), file, useBytes = TRUE)
  if (open) {
    if (in_rstudio()) rstudioapi::viewer(file) else utils::browseURL(file)
  }
  invisible(normalizePath(file, winslash = "/"))
}

SAMPLE_CODE <- c(
  "library(ggplot2)",
  "",
  "# Summarise a numeric column by group",
  "summarise_by <- function(df, var = \"bill_len\", na.rm = TRUE) {",
  "  df |>",
  "    dplyr::group_by(species) |>",
  "    dplyr::summarise(mean = mean(.data[[var]], na.rm = na.rm), n = dplyr::n())",
  "}",
  "",
  "res <- summarise_by(penguins)",
  "if (nrow(res) > 0L) {",
  "  ggplot(res, aes(species, mean, fill = species)) +",
  "    geom_col(width = 0.6) +",
  "    labs(title = \"Mean bill length\", x = NULL)",
  "}",
  "",
  "for (i in seq_len(3)) message(\"iteration \", i)",
  "x <- c(1.5, 2e3, NA, TRUE, NULL)  # mixed types",
  "stopifnot(is.numeric(x), length(x) == 4)",
  "",
  "#' @param path where to save",
  "save_plot <- function(p, path = tempfile(fileext = \".png\")) {",
  "  ggsave(path, p, width = 6, height = 4, dpi = 300)",
  "  invisible(path)",
  "}"
)

R_KEYWORDS <- c("function", "if", "else", "for", "while", "repeat", "in", "next", "break", "return")
R_CONSTANTS <- c("TRUE", "FALSE", "NULL", "NA", "Inf", "NaN", "NA_integer_", "NA_real_", "NA_character_")

html_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}

# Minimal R tokenizer producing Ace token classes, enough for a preview.
highlight_r <- function(line) {
  patterns <- c(
    comment = "^#.*",
    string = "^\"(?:[^\"\\\\]|\\\\.)*\"|^'(?:[^'\\\\]|\\\\.)*'",
    number = "^(?:0x[0-9a-fA-F]+|[0-9]+\\.?[0-9]*(?:[eE][+-]?[0-9]+)?L?)",
    word = "^[A-Za-z.][A-Za-z0-9._]*",
    op = "^(?:<-|->|\\|>|%[^%]*%|::|[-+*/^=<>!&|~$@:?]+)",
    paren = "^[][(){}]",
    space = "^\\s+",
    other = "^."
  )
  out <- character()
  while (nchar(line) > 0) {
    for (type in names(patterns)) {
      m <- regmatches(line, regexpr(patterns[[type]], line, perl = TRUE))
      if (length(m) && nchar(m) > 0) break
    }
    line <- substring(line, nchar(m) + 1)
    cls <- switch(type,
      comment = "ace_comment",
      string = "ace_string",
      number = "ace_constant ace_numeric",
      word = if (m %in% R_KEYWORDS) {
        "ace_keyword"
      } else if (m %in% R_CONSTANTS) {
        "ace_constant ace_language"
      } else if (grepl("^\\s*\\(", line)) {
        "ace_identifier ace_support ace_function"
      } else {
        "ace_identifier"
      },
      op = "ace_keyword ace_operator",
      paren = "ace_paren ace_keyword ace_operator",
      NA
    )
    out <- c(out, if (is.na(cls)) html_escape(m) else sprintf('<span class="%s">%s</span>', cls, html_escape(m)))
  }
  paste(out, collapse = "")
}

mock_tabs <- function(labels, selected = 1) {
  tabs <- vapply(seq_along(labels), function(i) {
    sprintf(paste0('<div class="gwt-TabLayoutPanelTab%s"><table class="rstheme_tabLayoutCenter">',
                   '<tbody><tr><td><div class="gwt-Label">%s</div></td></tr></tbody></table></div>'),
            if (i == selected) " gwt-TabLayoutPanelTab-selected" else "", labels[i])
  }, "")
  paste0('<div class="gwt-TabLayoutPanelTabs">', paste(tabs, collapse = ""), "</div>")
}

mock_toolbar <- function(items) {
  paste0('<div class="rstheme_toolbarWrapper">',
         paste0("<button>", items, "</button>", collapse = ""), "</div>")
}

mock_html <- function(theme_css, is_dark, title = "Preview") {
  active <- 12
  n <- length(SAMPLE_CODE)
  gutter <- paste0(
    sprintf('<div class="ace_gutter-cell%s">%d</div>',
            ifelse(seq_len(n) == active, " ace_gutter-active-line", ""), seq_len(n)),
    collapse = ""
  )
  lines <- paste0('<div class="ace_line">', vapply(SAMPLE_CODE, highlight_r, ""), "</div>", collapse = "")
  markers <- paste0(
    sprintf('<div class="ace_active-line" style="top:%dpx"></div>', (active - 1) * 20),
    '<div class="ace_selection" style="top:60px;left:calc(6px + 14ch);width:15ch"></div>',
    '<div class="ace_selected-word" style="top:180px;left:calc(6px + 0ch);width:3ch;height:18px"></div>'
  )
  console <- c(
    paste0('<span class="ace_keyword">&gt;</span> ', highlight_r("res <- summarise_by(penguins)")),
    paste0('<span class="ace_keyword">&gt;</span> ', highlight_r("res")),
    "# A tibble: 3 x 3",
    "  species    mean     n",
    "1 Adelie     38.8   152",
    "2 Chinstrap  48.8    68",
    "3 Gentoo     47.5   124",
    paste0('<span class="ace_keyword">&gt;</span> ', highlight_r("log(-1)")),
    '<span class="ace_console_error">Warning message: In log(-1) : NaNs produced</span>',
    '<span class="ace_keyword">&gt;</span> <span class="ace_cursor-inline"></span>'
  )
  env <- c("res|tibble [3 x 3]", "summarise_by|function (df, var, na.rm)", "x|num [1:4] 1.5 2000 NA 1")
  env_rows <- vapply(strsplit(env, "|", fixed = TRUE), function(r) {
    sprintf("<tr><td><b>%s</b></td><td>%s</td></tr>", r[1], html_escape(r[2]))
  }, "")
  files <- c("analysis.R", "report.Rmd", "data/", "figures/", "README.md")

  body_class <- if (is_dark) "rstudio-themes-dark-grey editor_dark" else "rstudio-themes-default"

  paste0(
    '<!doctype html><html class="rstudio-themes-flat"><head><meta charset="utf-8">',
    "<title>", html_escape(title), "</title>",
    "<style>", MOCK_CSS, "</style>",
    "<style>\n", paste(theme_css, collapse = "\n"), "\n</style>",
    '</head><body class="', body_class, '">',
    '<header role="banner"></header>',
    '<div role="navigation" class="rsw-nav"><table><tbody><tr><td>',
    paste0("<span>", c("File", "Edit", "Code", "View", "Plots", "Session", "Build", "Debug",
                        "Profile", "Tools", "Help"), "</span>", collapse = ""),
    '<span class="rsw-title">', html_escape(title), "</span>",
    "</td></tr></tbody></table></div>",
    '<div class="rsw-grid">',
    '<section class="rsw-pane rsw-source rstudio-themes-border">',
    mock_tabs(c("analysis.R", "report.Rmd", "utils.R")),
    mock_toolbar(c("Source on Save", "Run", "Source")),
    '<div class="ace_editor ace_editor_theme" id="rstudio_source_text_editor">',
    '<div class="ace_gutter"><div class="ace_layer ace_gutter-layer">', gutter, "</div></div>",
    '<div class="ace_scroller"><div class="ace_content">',
    '<div class="ace_layer ace_print-margin-layer"><div class="ace_print-margin" style="left:calc(6px + 80ch)"></div></div>',
    '<div class="ace_layer ace_marker-layer">', markers, "</div>",
    '<div class="ace_layer ace_text-layer">', lines, "</div>",
    sprintf('<div class="ace_layer ace_cursor-layer"><div class="ace_cursor" style="top:%dpx;left:calc(6px + 21ch)"></div></div>',
            (active - 1) * 20),
    "</div></div></div></section>",
    '<section class="rsw-pane rsw-env rstudio-themes-border">',
    mock_tabs(c("Environment", "History", "Connections")),
    mock_toolbar(c("Import Dataset", "Memory", "List")),
    '<div class="rsw-body ace_editor_theme"><table class="rsw-table">', paste(env_rows, collapse = ""),
    "</table></div></section>",
    '<section class="rsw-pane rsw-console rstudio-themes-border">',
    mock_tabs(c("Console", "Terminal", "Background Jobs")),
    '<div class="rsw-body ace_editor_theme rsw-mono">',
    paste0("<div>", console, "</div>", collapse = ""),
    "</div></section>",
    '<section class="rsw-pane rsw-files rstudio-themes-border">',
    mock_tabs(c("Files", "Plots", "Packages", "Help")),
    mock_toolbar(c("New Folder", "Upload", "Delete")),
    '<div class="rsw-body ace_editor_theme">',
    paste0('<div class="rsw-file">', files, "</div>", collapse = ""),
    "</div></section>",
    "</div></body></html>"
  )
}

# Structural CSS standing in for Ace and RStudio's own stylesheets. It comes
# before the theme, so the theme wins wherever it says something.
MOCK_CSS <- '
html, body { margin: 0; height: 100%; }
body { font: 12px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  background: #e4e7eb; color: #333; overflow: hidden; }
body.editor_dark { background: #23262b; color: #ccc; }
.rsw-nav table { width: 100%; border-collapse: collapse; }
.rsw-nav td { padding: 5px 10px; background: #f2f3f5; border-bottom: 1px solid rgba(127,127,127,.25); }
body.editor_dark .rsw-nav td { background: #2d3036; }
.rsw-nav span { margin-right: 14px; }
.rsw-nav .rsw-title { float: right; opacity: .6; margin-right: 0; }
.rsw-grid { position: absolute; top: 33px; left: 6px; right: 6px; bottom: 6px; display: grid;
  grid-template-columns: 1.6fr 1fr; grid-template-rows: 1.55fr 1fr; gap: 6px; }
.rsw-pane { display: flex; flex-direction: column; min-height: 0; overflow: hidden;
  border: 1px solid rgba(127,127,127,.3); border-radius: 5px; }
.rsw-source { grid-row: 1; grid-column: 1; }
.rsw-env { grid-row: 1; grid-column: 2; }
.rsw-console { grid-row: 2; grid-column: 1; }
.rsw-files { grid-row: 2; grid-column: 2; }
.gwt-TabLayoutPanelTabs { display: flex; gap: 2px; padding: 3px 4px 0; background: #e9ebee; }
body.editor_dark .gwt-TabLayoutPanelTabs { background: #2b2e33; }
.gwt-TabLayoutPanelTab table.rstheme_tabLayoutCenter { border-collapse: collapse; border-radius: 4px 4px 0 0;
  background: #e9ebee; }
body.editor_dark .gwt-TabLayoutPanelTab table.rstheme_tabLayoutCenter { background: #2b2e33; }
.gwt-TabLayoutPanelTab td { padding: 4px 12px; }
.gwt-TabLayoutPanelTab-selected table.rstheme_tabLayoutCenter { background: #fff; }
body.editor_dark .gwt-TabLayoutPanelTab-selected table.rstheme_tabLayoutCenter { background: #3a3d44; }
.rstheme_toolbarWrapper { display: flex; gap: 4px; padding: 3px 6px; background: #f7f8f9;
  border-bottom: 1px solid rgba(127,127,127,.2); }
body.editor_dark .rstheme_toolbarWrapper { background: #2f3238; }
.rstheme_toolbarWrapper button { font: inherit; color: inherit; background: none; border: 0; padding: 2px 6px; }
.ace_editor { position: relative; flex: 1; overflow: hidden; font: 13px/20px "SF Mono", Menlo, Monaco, Consolas, monospace; }
.ace_gutter { position: absolute; top: 0; bottom: 0; left: 0; width: 44px; z-index: 4; overflow: hidden; }
.ace_gutter-layer { position: absolute; top: 0; left: 0; width: 100%; }
.ace_gutter-cell { height: 20px; padding-right: 10px; text-align: right; }
.ace_scroller { position: absolute; top: 0; bottom: 0; left: 44px; right: 0; overflow: hidden; background-color: inherit; }
.ace_content { position: absolute; top: 0; left: 0; right: 0; bottom: 0; contain: style size layout; }
.ace_layer { position: absolute; top: 0; left: 0; width: 100%; height: 100%; z-index: 1; overflow: hidden;
  white-space: pre; pointer-events: none; box-sizing: border-box; }
.ace_text-layer { padding: 0 6px; }
.ace_line { height: 20px; }
.ace_marker-layer > div { position: absolute; height: 20px; box-sizing: border-box; }
.ace_marker-layer .ace_active-line { left: 0; right: 0; }
.ace_print-margin { position: absolute; top: 0; bottom: 0; }
.ace_cursor-layer { z-index: 4; }
.ace_cursor { position: absolute; height: 20px; border-left: 2px solid; }
.rsw-body { flex: 1; overflow: hidden; padding: 6px 10px; }
.rsw-mono { font: 12.5px/19px "SF Mono", Menlo, Monaco, Consolas, monospace; white-space: pre; }
.ace_cursor-inline { display: inline-block; width: 0; height: 15px; vertical-align: middle; border-left: 2px solid; }
.rsw-table { border-collapse: collapse; width: 100%; }
.rsw-table td { padding: 3px 6px; border-bottom: 1px solid rgba(127,127,127,.18); }
.rsw-file { padding: 3px 4px; border-bottom: 1px solid rgba(127,127,127,.15); }
'
