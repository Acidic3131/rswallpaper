PRESETS <- list(
  sakura   = list(label = "Sakura",   accent = "#E0628E", dark = FALSE),
  matcha   = list(label = "Matcha",   accent = "#7A9450", dark = FALSE, bg_hue = 80),
  sora     = list(label = "Sora",     accent = "#2F80D1", dark = FALSE),
  lavender = list(label = "Lavender", accent = "#8A5CD1", dark = FALSE),
  mikan    = list(label = "Mikan",    accent = "#E07020", dark = FALSE),
  yozora   = list(label = "Yozora",   accent = "#F48FB1", dark = TRUE, bg_hue = 265),
  kuro     = list(label = "Kuro",     accent = "#B69CFF", dark = TRUE, bg_hue = 285),
  ruri     = list(label = "Ruri",     accent = "#5CC8FF", dark = TRUE, bg_hue = 240),
  hotaru   = list(label = "Hotaru",   accent = "#C6E36B", dark = TRUE, bg_hue = 160),
  momiji   = list(label = "Momiji",   accent = "#FF8A65", dark = TRUE, bg_hue = 25)
)

# Curated accent swatches shown in Wallpaper Studio: traditional Japanese
# colours, muted film tones, jewel tones and pastels.
swatch_group <- function(group, ...) {
  x <- c(...)
  data.frame(group = group, name = names(x), hex = unname(x), stringsAsFactors = FALSE)
}

SWATCHES <- rbind(
  swatch_group(
    "\u548c\u8272 Wa-iro",
    "\u7d05\u6885 Kobai" = "#E16B8C",
    "\u8584\u7d05 Usubeni" = "#E87A90",
    "\u831c Akane" = "#CB4042",
    "\u73ca\u745a\u6731 Sangoshu" = "#F17C67",
    "\u5c71\u5439 Yamabuki" = "#FFB11B",
    "\u67f3\u67d3 Yanagizome" = "#91AD70",
    "\u82e5\u7af9 Wakatake" = "#5DAC81",
    "\u9752\u7af9 Aotake" = "#00896C",
    "\u6d45\u8471 Asagi" = "#33A6B8",
    "\u7460\u7483 Ruri" = "#005CAF",
    "\u85e4 Fuji" = "#8B81C3",
    "\u7d05\u85e4 Benifuji" = "#B481BB",
    "\u5229\u4f11\u9f20 Rikyu-nezumi" = "#707C74"
  ),
  swatch_group(
    "Muted",
    "Dusty rose" = "#C49A98",
    "Clay" = "#B9826F",
    "Terracotta" = "#C0694E",
    "Ochre" = "#C99A3B",
    "Olive" = "#8C8A52",
    "Sage" = "#8FA58A",
    "Eucalyptus" = "#5F8B7E",
    "Fog blue" = "#8EA4B8",
    "Slate" = "#5F6F8F",
    "Haze lilac" = "#A497B8",
    "Mauve" = "#9E7A8F",
    "Ink" = "#3A4660"
  ),
  swatch_group(
    "Jewel",
    "Garnet" = "#8E2C48",
    "Ruby" = "#B5294E",
    "Amber" = "#E0912F",
    "Citrine" = "#D8B32A",
    "Emerald" = "#1E8C64",
    "Jade" = "#4FA38A",
    "Teal" = "#1F7A80",
    "Sapphire" = "#2F5DA8",
    "Amethyst" = "#8A5FB0",
    "Tourmaline" = "#D45A88"
  ),
  swatch_group(
    "Pastel",
    "Blush" = "#F2B5C4",
    "Peach" = "#F7B9A1",
    "Butter" = "#F2D88A",
    "Pistachio" = "#BFD8A6",
    "Mint" = "#A8DCC8",
    "Sky" = "#A9CBEA",
    "Periwinkle" = "#B8BDF0",
    "Lilac" = "#CDB7E6"
  )
)

#' Preset colour palettes
#'
#' rswallpaper ships a handful of complete colour schemes. Use the `name`
#' column as the `theme` argument of [set_wallpaper()] (e.g.
#' `theme = "sakura"`) to get a full editor + IDE theme in that colour.
#'
#' @return A data frame with one row per palette: `name`, `label`, `dark`,
#'   `accent`, `background` and `foreground`.
#' @export
#' @examples
#' palettes()
palettes <- function() {
  rows <- lapply(names(PRESETS), function(id) {
    p <- preset_palette(id)
    data.frame(
      name = id, label = p$name, dark = p$dark, accent = p$accent,
      background = p$bg, foreground = p$fg, stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

preset_palette <- function(id) {
  p <- PRESETS[[tolower(id)]]
  if (is.null(p)) {
    return(NULL)
  }
  rs_palette(p$accent, dark = p$dark, name = p$label, bg_hue = p$bg_hue)
}

#' Create a colour palette for a complete theme
#'
#' Derives a readable syntax-highlighting scheme and IDE colours from one
#' accent colour. Hues are spread around the accent in HCL space and every
#' code colour is adjusted to a WCAG contrast of at least 4.5:1 against the
#' background (3:1 for comments).
#'
#' @param accent Accent colour (any CSS/R colour, e.g. `"#E0628E"`).
#' @param dark Build a dark scheme instead of a light one.
#' @param name Display name; becomes the base of the RStudio theme name.
#' @param bg,fg Optional explicit background / foreground colours.
#' @param bg_hue Hue (0-360) used to tint the background and neutrals.
#'   Defaults to the accent hue.
#' @param ... Named overrides for individual roles: `keyword`, `operator`,
#'   `string`, `number`, `func`, `type`, `tag`, `comment`, `selection`,
#'   `active_line`, ...
#' @return An object of class `rsw_palette`.
#' @export
#' @examples
#' p <- rs_palette("#4FB0A5", dark = TRUE, name = "Teal Night")
#' p
#' \dontrun{
#' set_wallpaper("~/Pictures/miku.png", theme = p)
#' }
rs_palette <- function(accent, dark = FALSE, name = "Custom", bg = NULL, fg = NULL,
                       bg_hue = NULL, ...) {
  accent <- as_hex(accent)
  name <- check_theme_name(name)
  h <- col_hcl(accent)[1, "h"]
  hb <- bg_hue %||% h

  if (!dark) {
    bg <- as_hex(bg %||% hcl_hex(hb, 5, 98))
    fg <- as_hex(fg %||% hcl_hex(hb, 14, 27))
    code <- list(
      keyword  = hcl_hex(h, 72, 48),
      operator = hcl_hex(h, 30, 50),
      string   = hcl_hex(h + 140, 55, 47),
      number   = hcl_hex(h + 65, 65, 52),
      func     = hcl_hex(h - 115, 55, 45),
      type     = hcl_hex(h + 30, 55, 48),
      tag      = hcl_hex(h - 40, 60, 48)
    )
    comment <- hcl_hex(hb, 10, 60)
  } else {
    bg <- as_hex(bg %||% hcl_hex(hb, 9, 13))
    fg <- as_hex(fg %||% hcl_hex(hb, 6, 88))
    code <- list(
      keyword  = hcl_hex(h, 55, 74),
      operator = hcl_hex(h, 25, 76),
      string   = hcl_hex(h + 140, 45, 80),
      number   = hcl_hex(h + 65, 55, 78),
      func     = hcl_hex(h - 115, 45, 76),
      type     = hcl_hex(h + 30, 50, 78),
      tag      = hcl_hex(h - 40, 50, 74)
    )
    comment <- hcl_hex(hb, 10, 55)
  }

  roles <- lapply(code, ensure_contrast, bg = bg, ratio = 4.5)
  roles$comment <- ensure_contrast(comment, bg, ratio = 3)
  roles <- c(roles, list(
    gutter_bg     = mix(bg, fg, 0.035),
    gutter_fg     = mix(fg, bg, 0.55),
    selection     = mix(bg, accent, if (dark) 0.32 else 0.24),
    active_line   = mix(bg, accent, 0.07),
    gutter_active = mix(bg, accent, 0.16),
    invisible     = mix(bg, fg, 0.25),
    guide         = mix(bg, fg, 0.14),
    border        = mix(bg, fg, 0.12),
    error         = ensure_contrast(hcl_hex(12, 85, if (dark) 65 else 50), bg, 4.5),
    debug_line    = mix(bg, hcl_hex(85, 70, 85), if (dark) 0.25 else 0.55),
    find_line     = mix(bg, accent, 0.12),
    foreign_line  = mix(bg, fg, 0.04)
  ))

  overrides <- list(...)
  if (length(overrides)) {
    bad <- setdiff(names(overrides), names(roles))
    if (length(bad) || is.null(names(overrides))) {
      stop("Unknown palette role(s): ", paste(bad, collapse = ", "), call. = FALSE)
    }
    roles[names(overrides)] <- lapply(overrides, as_hex)
  }

  # 7 hues for rainbow parentheses / indent guides, starting at the accent.
  rainbow <- hcl_hex(h + seq(0, 360 * 6 / 7, length.out = 7), if (dark) 50 else 60,
                     if (dark) 72 else 55)

  structure(
    list(name = name, dark = dark, accent = accent, bg = bg, fg = fg,
         roles = roles, rainbow = rainbow, ansi = ansi_colors(dark, bg, fg)),
    class = "rsw_palette"
  )
}

ansi_colors <- function(dark, bg, fg) {
  hues <- c(red = 12, green = 130, yellow = 75, blue = 255, magenta = 330, cyan = 195)
  normal <- hcl_hex(hues, 65, if (dark) 66 else 45)
  bright <- hcl_hex(hues, 75, if (dark) 80 else 58)
  black <- if (dark) mix(bg, "#000000", 0.4) else mix(fg, "#000000", 0.3)
  white <- if (dark) mix(fg, bg, 0.15) else mix(bg, fg, 0.25)
  c(black, normal, white, mix(black, white, 0.45), bright, if (dark) fg else "#ffffff")
}

#' Build a palette from the colours of an image
#'
#' Picks the most prominent vivid colour of `img` (hair, eyes, clothes, ...)
#' as the accent and builds a full palette around it with [rs_palette()].
#' Passing `theme = "auto"` (or `"auto-dark"`) to [set_wallpaper()] does the
#' same thing automatically.
#'
#' @param img Path to an image. Reading pixels needs the \pkg{magick}
#'   package, or \pkg{png} / \pkg{jpeg} for those formats.
#' @inheritParams rs_palette
#' @return An `rsw_palette`.
#' @export
#' @examples
#' \dontrun{
#' p <- palette_from_image("~/Pictures/miku.png", dark = TRUE)
#' plot(p)
#' }
palette_from_image <- function(img, dark = FALSE, name = NULL) {
  cols <- image_colors(img, n = 3)
  if (!length(cols)) {
    stop("Could not find any vivid colours in the image.", call. = FALSE)
  }
  name <- name %||% tools::toTitleCase(gsub("[_-]+", " ", tools::file_path_sans_ext(basename(img))))
  bg_hue <- if (length(cols) > 1) col_hcl(cols[2])[1, "h"] else NULL
  rs_palette(cols[1], dark = dark, name = name, bg_hue = bg_hue)
}

#' @export
print.rsw_palette <- function(x, ...) {
  cat("<rsw_palette> ", x$name, if (x$dark) " (dark)" else " (light)", "\n", sep = "")
  show <- c(background = x$bg, foreground = x$fg, accent = x$accent,
            unlist(x$roles[c("keyword", "operator", "string", "number", "func", "comment")]))
  for (i in seq_along(show)) {
    cat(sprintf("  %-11s %s\n", names(show)[i], show[[i]]))
  }
  invisible(x)
}

#' @export
plot.rsw_palette <- function(x, ...) {
  show <- c(bg = x$bg, fg = x$fg, accent = x$accent,
            unlist(x$roles[c("keyword", "operator", "string", "number", "func", "type", "comment")]))
  op <- graphics::par(mar = c(0.5, 0.5, 2, 0.5))
  on.exit(graphics::par(op))
  n <- length(show)
  graphics::plot.new()
  graphics::plot.window(xlim = c(0, n), ylim = c(0, 1))
  graphics::rect(0:(n - 1), 0, 1:n, 1, col = show, border = NA)
  txt <- ifelse(vapply(show, is_dark_color, logical(1)), "white", "black")
  graphics::text(0:(n - 1) + 0.5, 0.5, names(show), col = txt, srt = 90, cex = 0.8)
  graphics::title(x$name)
  invisible(x)
}
