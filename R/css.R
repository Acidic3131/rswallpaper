# ---- tiny CSS writer / reader ----------------------------------------------

# rule(".a", background_color = "#fff") -> ".a {\n  background-color: #fff;\n}"
# Leading underscores become "-" so `_webkit_mask_image` gives `-webkit-mask-image`.
rule <- function(selector, ...) {
  decl <- list(...)
  decl <- decl[!vapply(decl, is.null, logical(1))]
  if (!length(decl)) {
    return(character())
  }
  props <- gsub("_", "-", names(decl), fixed = TRUE)
  paste0(
    paste(selector, collapse = ",\n"), " {\n",
    paste0("  ", props, ": ", unlist(decl), ";", collapse = "\n"),
    "\n}"
  )
}

# Cartesian product of selector prefixes and suffixes.
sel <- function(prefix, suffix) {
  as.vector(outer(prefix, suffix, paste))
}

parse_css_rules <- function(css) {
  txt <- paste(css, collapse = "\n")
  txt <- gsub("/\\*.*?\\*/", "", txt, perl = TRUE)
  blocks <- regmatches(txt, gregexpr("[^{}]+\\{[^{}]*\\}", txt, perl = TRUE))[[1]]
  data.frame(
    selector = trimws(sub("\\{.*$", "", blocks)),
    body = sub("^[^{]*\\{", "", sub("\\}\\s*$", "", blocks)),
    stringsAsFactors = FALSE
  )
}

# Value of `prop` in the last rule whose selector list contains `selector`.
css_prop <- function(rules, selector, prop) {
  norm <- function(s) gsub("\\s+", " ", trimws(s))
  target <- norm(selector)
  hits <- which(vapply(strsplit(rules$selector, ",", fixed = TRUE),
                       function(s) target %in% norm(s), logical(1)))
  pattern <- paste0("(?:^|;|\\s)", prop, "\\s*:\\s*([^;]+)")
  for (i in rev(hits)) {
    m <- regmatches(rules$body[i], regexec(pattern, rules$body[i], perl = TRUE))[[1]]
    if (length(m)) {
      return(trimws(sub("!important", "", m[2], fixed = TRUE)))
    }
  }
  NA_character_
}

css_color <- function(rules, selector, props = c("background-color", "background")) {
  for (p in props) {
    col <- first_color(css_prop(rules, selector, p))
    if (!is.na(col)) {
      return(as_hex(col))
    }
  }
  NA_character_
}

# Key colours of an existing theme, used to derive UI tints.
theme_colors <- function(css, is_dark) {
  rules <- parse_css_rules(css)
  bg <- css_color(rules, ".ace_editor")
  fg <- css_color(rules, ".ace_editor", "color")
  if (is.na(bg)) bg <- if (is_dark) "#1E1E1E" else "#FFFFFF"
  if (is.na(fg)) fg <- if (is_dark) "#D4D4D4" else "#333333"
  list(
    bg = bg, fg = fg,
    active_line = css_color(rules, ".ace_marker-layer .ace_active-line"),
    foreign_line = css_color(rules, ".ace_marker-layer .ace_foreign_line"),
    keyword = css_color(rules, ".ace_keyword", "color")
  )
}

# ---- complete scheme from a palette -----------------------------------------

palette_css <- function(p) {
  r <- p$roles
  bg <- p$bg
  fg <- p$fg
  c(
    rule(".ace_gutter", background = r$gutter_bg, color = r$gutter_fg),
    rule(".ace_print-margin", width = "1px", background = r$border),
    rule(c(".ace_editor", ".ace_editor_theme .profvis-flamegraph", ".ace_editor_theme"),
         background_color = bg, color = fg),
    rule(".ace_cursor", color = p$accent),
    rule(".ace_marker-layer .ace_selection", background = r$selection),
    rule(".ace_selection.ace_start", box_shadow = paste("0 0 3px 0px", bg), border_radius = "2px"),
    rule(".ace_marker-layer .ace_step", background = mix(bg, "#FFD54F", 0.6)),
    rule(".ace_marker-layer .ace_bracket", margin = "-1px 0 0 -1px",
         border = paste("1px solid", rgba(p$accent, 0.6))),
    rule(".ace_marker-layer .ace_active-line", background = r$active_line),
    rule(".ace_gutter-active-line", background_color = r$gutter_active),
    rule(".ace_marker-layer .ace_selected-word", border = paste("1px solid", r$selection)),
    rule(".ace_invisible", color = r$invisible),
    rule(c(".ace_keyword", ".ace_meta", ".ace_storage", ".ace_storage.ace_type"), color = r$keyword),
    rule(".ace_keyword.ace_operator", color = r$operator),
    rule(c(".ace_constant.ace_character", ".ace_constant.ace_language", ".ace_constant.ace_numeric",
           ".ace_keyword.ace_other.ace_unit", ".ace_support.ace_constant", ".ace_variable.ace_parameter"),
         color = r$number),
    rule(".ace_constant.ace_other", color = fg),
    rule(".ace_invalid", color = bg, background_color = r$error),
    rule(".ace_invalid.ace_deprecated", color = bg, background_color = r$keyword),
    rule(".ace_fold", background_color = r$func, border_color = fg),
    rule(c(".ace_entity.ace_name.ace_function", ".ace_support.ace_function"), color = r$func),
    rule(c(".ace_support.ace_class", ".ace_support.ace_type"), color = r$type),
    rule(c(".ace_heading", ".ace_markup.ace_heading"), color = r$keyword, font_weight = "bold"),
    rule(".ace_markup.ace_list", color = r$operator),
    rule(".ace_string", color = r$string),
    rule(".ace_string.ace_regexp", color = r$tag),
    rule(c(".ace_entity.ace_name.ace_tag", ".ace_entity.ace_other.ace_attribute-name",
           ".ace_meta.ace_tag", ".ace_variable"), color = r$tag),
    rule(".ace_comment", color = r$comment, font_style = "italic"),
    rule(".ace_indent-guide",
         background = paste0("linear-gradient(to left, ", r$guide, " 1px, transparent 1px, transparent)")),
    rule(".nocolor.ace_editor .ace_line span", color = paste(r$keyword, "!important")),
    rule(".ace_bracket", margin = "0 !important", border = "0 !important",
         background_color = rgba(p$accent, 0.25)),
    rule(".ace_marker-layer .ace_foreign_line", position = "absolute", z_index = "-1",
         background_color = r$foreign_line),
    rule(".ace_node-selector", background_color = p$accent),
    rule(".ace_comment-highlight", color = fg, background_color = mix(bg, "#FFD54F", 0.35)),
    rule(".ace_marker-layer .ace_active_debug_line", position = "absolute", z_index = "-1",
         background_color = r$debug_line),
    rule(".ace_marker-layer .ace_find_line", position = "absolute", z_index = "-1",
         background_color = r$find_line),
    rule(".ace_console_error", background_color = mix(bg, r$error, 0.12)),
    terminal_css(bg, fg, p$accent, p$ansi),
    rule(".ace_layer", z_index = "3"),
    rule(".ace_layer.ace_print-margin-layer", z_index = "2"),
    rule(".ace_layer.ace_marker-layer", z_index = "1"),
    rainbow_css(p$rainbow)
  )
}

terminal_css <- function(bg, fg, accent, ansi) {
  cube <- c(0, 95, 135, 175, 215, 255)
  grid <- expand.grid(b = cube, g = cube, r = cube)
  xterm <- c(
    ansi,
    grDevices::rgb(grid$r, grid$g, grid$b, maxColorValue = 255),
    grDevices::rgb(8 + 10 * 0:23, 8 + 10 * 0:23, 8 + 10 * 0:23, maxColorValue = 255)
  )
  i <- seq_along(xterm) - 1
  c(
    rule(".terminal", background_color = bg, color = fg, font_feature_settings = '"liga" 0',
         position = "relative", user_select = "none", `_ms_user_select` = "none",
         `_webkit_user_select` = "none"),
    rule(".terminal.xterm-cursor-style-block.focus:not(.xterm-cursor-blink-on) .terminal-cursor",
         background_color = accent, color = bg),
    rule(c(".terminal.focus.xterm-cursor-style-bar:not(.xterm-cursor-blink-on) .terminal-cursor::before",
           ".terminal.focus.xterm-cursor-style-underline:not(.xterm-cursor-blink-on) .terminal-cursor::before"),
         content = "''", position = "absolute", background_color = accent),
    rule(".terminal:not(.focus) .terminal-cursor", outline = paste("1px solid", accent),
         outline_offset = "-1px"),
    rule(".terminal .xterm-selection div", position = "absolute", background_color = rgba(accent, 0.3)),
    rule(".terminal .xterm-viewport", background_color = bg, overflow_y = "scroll"),
    rule(".xtermInvertColor", color = bg),
    rule(".xtermInvertBgColor", background_color = fg),
    rule(".xtermBold", font_weight = "bold"),
    rule(".xtermUnderline", text_decoration = "underline"),
    rule(".xtermItalic", font_style = "italic"),
    rule(".xtermStrike", text_decoration = "line-through"),
    rule(".xtermHidden", visibility = "hidden"),
    sprintf(".xtermColor%d { color: %s !important; }", i, xterm),
    sprintf(".xtermBgColor%d { background-color: %s; }", i, xterm)
  )
}

rainbow_css <- function(cols) {
  i <- seq_along(cols)
  c(
    sprintf(".ace_paren_color_%d, .editor_dark .ace_paren_color_%d { color: %s; }", i - 1, i - 1, cols),
    sprintf(paste0(".rstudio_rainbow_indent_guides .ace_line .ace_indent-guide:nth-child(7n+%d) ",
                   "{ background: linear-gradient(to left, %s 1px, transparent 1px, transparent); }"),
            i, hex_alpha(cols, 0.73)),
    sprintf(paste0(".rstudio_rainbow_indent_fills .ace_line .ace_indent-guide:nth-child(7n+%d) ",
                   "{ background: linear-gradient(to left, %s 1px, %s 1px, %s); }"),
            i, hex_alpha(cols, 0.73), hex_alpha(cols, 0.2), hex_alpha(cols, 0.2))
  )
}

# ---- accent colour: editor highlights + IDE chrome --------------------------

accent_css <- function(accent, bg, fg, dark, tint = 0.35) {
  t <- tint
  # Pastel accents picked from images can vanish on light backgrounds.
  accent <- ensure_contrast(accent, bg, 2.5)
  frame <- mix(if (dark) mix(bg, "#000000", 0.28) else mix(bg, fg, 0.07), accent, 0.30 * t)
  panel <- mix(if (dark) mix(bg, "#000000", 0.12) else mix(bg, fg, 0.03), accent, 0.18 * t)
  tab_active <- mix(bg, accent, 0.10 + 0.14 * t)
  tab_hover <- mix(frame, tab_active, 0.5)
  border <- mix(mix(bg, fg, 0.16), accent, 0.25 * t)
  menu_bg <- mix(bg, accent, 0.03 + 0.05 * t)
  menu_sel <- mix(bg, accent, 0.22)
  acc_text <- ensure_contrast(accent, tab_active, 4.5)
  acc_menu <- ensure_contrast(accent, menu_sel, 4.5)
  muted <- mix(fg, bg, 0.2)

  # Same selector shapes RStudio's own theme files use for the IDE chrome.
  flat <- c(".rstudio-themes-flat .rstudio-themes-default", ".rstudio-themes-flat .rstudio-themes-dark-grey",
            ".rstudio-themes-flat .rstudio-themes-alternate")
  mode <- c(".rstudio-themes-default", ".rstudio-themes-dark-grey", ".rstudio-themes-alternate")
  popups <- c(".popupMiddleCenter", ".menuPopupMiddleCenter", ".suggestPopupMiddleCenter")

  c(
    "/* accent: editor */",
    rule(".ace_cursor", color = paste(accent, "!important")),
    rule(".ace_marker-layer .ace_selection", background = rgba(accent, if (dark) 0.35 else 0.25)),
    rule(".ace_marker-layer .ace_active-line", background = rgba(accent, if (dark) 0.10 else 0.07)),
    rule(".ace_gutter-active-line", background_color = rgba(accent, 0.16)),
    rule(".ace_marker-layer .ace_selected-word", border = paste("1px solid", rgba(accent, 0.6))),
    rule(".ace_marker-layer .ace_bracket", border = paste("1px solid", rgba(accent, 0.7))),
    rule(".ace_bracket", background_color = rgba(accent, 0.22)),
    rule(".ace_marker-layer .ace_find_line", background_color = rgba(accent, 0.12)),
    "/* accent: IDE chrome */",
    rule(c(flat, sel(flat, ".rstudio-themes-background")), background = frame, color = fg),
    rule(sel(flat, c('[role="banner"] + [role="navigation"] > table > tbody > tr > td',
                     'header + [role="navigation"] > table > tbody > tr > td')),
         background = frame, border_color = border),
    rule(sel(flat, ".rstudio-themes-border"), border_color = border),
    rule(sel(mode, c(".gwt-SplitLayoutPanel-HDragger", ".gwt-SplitLayoutPanel-VDragger")),
         background = paste(frame, "!important")),
    rule(sel(mode, ".rstheme_toolbarWrapper"), background = panel, color = fg),
    rule(sel(mode, c(".rstheme_toolbarWrapper button", ".rstheme_toolbarWrapper a",
                     ".rstheme_toolbarWrapper div")), color = fg),
    rule(sel(mode, c(".rstheme_secondaryToolbar", ".dataGridHeader")), background = panel, color = fg),
    rule(sel(mode, c(".gwt-TabLayoutPanelTabs", ".rstheme_multiPodUtilityTabArea")), background = frame),
    rule(sel(mode, c(".gwt-TabLayoutPanelTabs table.rstheme_tabLayoutCenter",
                     ".rstheme_minimizedWindowObject table.rstheme_tabLayoutCenter")),
         background = frame),
    rule(sel(mode, c(".gwt-TabLayoutPanelTabs table.rstheme_tabLayoutCenter .gwt-Label",
                     ".rstheme_minimizedWindowObject table.rstheme_tabLayoutCenter .gwt-Label")),
         color = muted),
    rule(sel(mode, ".gwt-TabLayoutPanelTab:hover .rstheme_tabLayoutCenter"), background = tab_hover),
    rule(sel(mode, ".gwt-TabLayoutPanelTabs .gwt-TabLayoutPanelTab-selected table.rstheme_tabLayoutCenter"),
         background = tab_active, box_shadow = paste("inset 0 -2px 0", accent)),
    rule(sel(mode, ".gwt-TabLayoutPanelTabs .gwt-TabLayoutPanelTab-selected table.rstheme_tabLayoutCenter .gwt-Label"),
         color = acc_text),
    rule(sel(mode, popups), background = menu_bg, color = fg),
    rule(sel(mode, c(paste(popups, ".item.item-selected"), ".gwt-MenuItem.gwt-MenuItem-selected",
                     ".gwt-MenuItem.gwt-MenuItem-selected > table")),
         background = menu_sel, color = acc_menu),
    rule(sel(mode, c(".popupContent", ".gwt-PopupPanel .popupContent")), background = menu_bg),
    rule(sel(mode, ".themedPopupPanel"), border = paste("solid 1px", border)),
    rule(c(".rstheme_toolbarWrapper [role=\"progressbar\"] > div", ".windowframe [role=\"progressbar\"] > div"),
         background_color = accent),
    rule(c(".ace_scrollbar", sel(mode, ".gwt-TabLayoutPanelContentContainer")),
         scrollbar_color = paste(rgba(accent, 0.45), "transparent")),
    rule(c("input[type=\"checkbox\"]", "input[type=\"radio\"]", "input[type=\"range\"]", "progress"),
         accent_color = accent)
  )
}

# ---- wallpaper ---------------------------------------------------------------

EDITOR_SELECTORS <- list(
  source = '.ace_editor[id^="rstudio_source_text_editor"]',
  any = ".ace_editor"
)

wallpaper_css <- function(src, opacity, position, size, mode, fade, filter, target,
                          active_line = NULL, foreign_line = NULL) {
  editor <- EDITOR_SELECTORS[[target]]
  mask <- switch(fade,
    none = NULL,
    paste0("linear-gradient(to ", fade, ", #000 35%, transparent 92%)")
  )
  layer <- list(
    content = '""', position = "absolute",
    top = "0", right = "0", bottom = "0", left = "0",
    background_image = sprintf('url("%s")', src),
    background_repeat = "no-repeat",
    background_position = position,
    background_size = size,
    opacity = fmt_num(opacity),
    filter = filter,
    `_webkit_mask_image` = mask,
    mask_image = mask,
    pointer_events = "none"
  )

  if (mode == "overlay") {
    # Above every editor layer (gutter is z-index 4): tints the code slightly
    # but works no matter how the theme paints its layers.
    out <- do.call(rule, c(list(paste0(editor, "::after")), layer, z_index = "100"))
  } else {
    # Inside the scroller, beneath .ace_content: text stays crisp. Opaque line
    # markers would hide the picture, so they are made translucent.
    out <- c(
      do.call(rule, c(list(paste(editor, ".ace_scroller::before")), layer, z_index = "0")),
      if (!is.null(active_line) && !is.na(active_line)) {
        rule(paste(editor, ".ace_marker-layer .ace_active-line"),
             background = paste(rgba(active_line, 0.55), "!important"))
      },
      if (!is.null(foreign_line) && !is.na(foreign_line)) {
        rule(paste(editor, ".ace_marker-layer .ace_foreign_line"),
             background_color = paste(rgba(foreign_line, 0.6), "!important"))
      }
    )
  }

  # Keep every pane except the source editors clean. Ace editors inside the
  # Console/Terminal/Jobs/... tabs can carry source-editor ids too, so exclude
  # them by their workbench tab panel (#rstudio_workbench_panel_<tab>) and by the
  # terminal's own classes; also the console input and visual-mode chunks.
  pseudo <- if (mode == "overlay") "::after" else " .ace_scroller::before"
  hidden <- c(
    paste0('[id^="rstudio_workbench_panel_"] ', editor, pseudo),
    paste0(".terminal ", editor, pseudo),
    paste0(".xterm ", editor, pseudo),
    paste0('[id*="console"] ', editor, pseudo),
    paste0(editor, '[id*="console"]', pseudo),
    paste0(".ProseMirror ", editor, pseudo),
    paste0('[class*="pm-ace"] ', editor, pseudo)
  )
  # :has() in its own rule: a browser without it drops only this rule.
  has_terminal <- paste0(editor, c(":has(.terminal)", ":has(.xterm)"), pseudo)
  out <- c(out, rule(hidden, display = "none !important"),
           rule(has_terminal, display = "none !important"))
  c(sprintf("/* wallpaper (%s) */", mode), out)
}
