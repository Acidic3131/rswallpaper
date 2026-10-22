#' Put a wallpaper (and/or accent colour) on RStudio
#'
#' Builds a new RStudio theme from a base theme plus a semi-transparent image
#' in the source editor and, optionally, an accent colour for the cursor,
#' selection, tabs, menus and scrollbars. The theme is installed and applied
#' right away. Running it again with the same `name` replaces the theme.
#'
#' @param img Image to show in the editor: a file path, a folder (a random
#'   image is picked -- see [shuffle_wallpaper()]), an `http(s)` URL, or
#'   `NULL` for no image. PNG with transparency works best for character art.
#' @param theme Base theme. One of
#'   * `NULL`: the theme currently active in RStudio;
#'   * the name of any installed or built-in theme (see [list_themes()]);
#'   * a preset palette such as `"sakura"` or `"yozora"` (see [palettes()]);
#'   * `"auto"` / `"auto-dark"`: a palette generated from the image colours;
#'   * a path to an `.rstheme` or `.tmTheme` file;
#'   * an [rs_palette()] object.
#' @param accent Accent colour for the editor highlights and the IDE chrome:
#'   a colour such as `"#E0628E"`, `"auto"` to take it from the image, or
#'   `NULL` to keep the base theme's look (palette themes always use their
#'   own accent unless you override it here).
#' @param opacity Image opacity, 0-1. Defaults to 0.18 for `mode = "overlay"`
#'   and 0.28 for `mode = "behind"`.
#' @param position CSS `background-position`, e.g. `"right bottom"`,
#'   `"center"`, `"right 24px bottom 0"`.
#' @param size Either a number in (0, 1] -- the image height as a fraction of
#'   the editor height -- or a CSS `background-size` such as `"contain"`,
#'   `"cover"` or `"auto 60%"`.
#' @param mode `"overlay"` lays the image over the code (simple and robust;
#'   keep opacity low). `"behind"` draws it under the text so code stays
#'   crisp and you can use a higher opacity.
#' @param fade Fade the image out towards one side of the editor so the text
#'   area stays clean, e.g. `"left"` for an image anchored on the right.
#' @param filter Optional CSS filter for the image, e.g. `"blur(1px)"` or
#'   `"saturate(1.3)"`.
#' @param target `"source"` shows the image in source editors only.
#'   `"any"` shows it in every code editor except the console and
#'   visual-mode chunks; try it if the image does not appear.
#' @param tint How strongly the accent colour tints the IDE chrome, 0-1.
#' @param name Theme name. Defaults to `"<base> + Wallpaper"`.
#' @param max_px Images larger than this (in pixels, either side) are shrunk
#'   and re-encoded as WebP before embedding (needs \pkg{magick}). `NULL`
#'   embeds the original file.
#' @param apply Apply the theme straight away.
#' @return The theme name, invisibly.
#' @seealso [wallpaper_studio()] for an interactive editor with live preview,
#'   [restore_theme()] to go back.
#' @export
#' @examples
#' \dontrun{
#' # Character art on your current theme
#' set_wallpaper("~/Pictures/chifuyo.png")
#'
#' # Pick the base theme and accent colour yourself
#' set_wallpaper("~/Pictures/chifuyo.png", theme = "OKSolar Light",
#'               accent = "#7aa2f7", opacity = 0.25, mode = "behind", fade = "left")
#'
#' # A whole colour scheme generated from the picture
#' set_wallpaper("~/Pictures/chifuyo.png", theme = "auto-dark")
#'
#' # Only colours, no picture
#' set_wallpaper(theme = "sakura")
#' }
set_wallpaper <- function(img = NULL, theme = NULL, accent = NULL, opacity = NULL,
                          position = "right bottom", size = 0.75,
                          mode = c("overlay", "behind"),
                          fade = c("none", "left", "right", "top", "bottom"),
                          filter = NULL, target = c("source", "any"), tint = 0.35,
                          name = NULL, max_px = 1600, apply = TRUE) {
  require_rstudio("set_wallpaper()")
  mode <- match.arg(mode)
  fade <- match.arg(fade)
  target <- match.arg(target)

  img_dir <- if (!is.null(img) && dir.exists(path.expand(img))) normalizePath(img, winslash = "/")
  current <- rstudioapi::getThemeInfo()$editor

  path <- build_theme(
    img = img, theme = theme, accent = accent, opacity = opacity, position = position,
    size = size, mode = mode, fade = fade, filter = filter, target = target, tint = tint,
    name = name, max_px = max_px
  )
  name <- attr(path, "theme_name")
  remember_previous(current)
  install_theme(path, name, apply = apply, fallback = attr(path, "base_name"))

  write_state("last", list(
    img = attr(path, "image"), img_dir = img_dir,
    args = list(theme = theme %||% attr(path, "base_name"),
                accent = accent, opacity = opacity, position = position, size = size,
                mode = mode, fade = fade, filter = filter, target = target, tint = tint,
                name = name, max_px = max_px)
  ))
  message("Applied theme \"", name, "\". Use restore_theme() to go back.")
  invisible(name)
}

#' Write a wallpaper theme to a file without installing it
#'
#' Same as [set_wallpaper()] but only writes the `.rstheme` file, so it also
#' works outside RStudio (e.g. to share a theme, or in scripts and CI). Add
#' the file later with `rstudioapi::addTheme()` or *Tools > Global Options >
#' Appearance > Add...*.
#'
#' @inheritParams set_wallpaper
#' @param file Output path. Defaults to a file in [tempdir()].
#' @return The path of the written file, invisibly, with attributes
#'   `theme_name` and `base_name`.
#' @export
#' @examples
#' f <- build_theme(theme = "sakura", file = tempfile(fileext = ".rstheme"))
#' readLines(f, n = 2)
build_theme <- function(img = NULL, theme = NULL, accent = NULL, opacity = NULL,
                        position = "right bottom", size = 0.75,
                        mode = c("overlay", "behind"),
                        fade = c("none", "left", "right", "top", "bottom"),
                        filter = NULL, target = c("source", "any"), tint = 0.35,
                        name = NULL, max_px = 1600, file = NULL) {
  mode <- match.arg(mode)
  fade <- match.arg(fade)
  target <- match.arg(target)

  img <- resolve_image(img)
  base <- resolve_theme(theme, img = img)
  wallpaper <- if (!is.null(img)) {
    wallpaper_spec(image_data_uri(img, max_px), opacity, position, size, mode, fade, filter, target)
  }
  name <- default_name(name, base, img, accent)

  css <- compose_theme(base, name, wallpaper = wallpaper, accent = accent, tint = tint, img = img)

  if (is.null(file)) {
    tmp <- tempfile(fileext = ".rstheme")
    writeLines(css, tmp, useBytes = TRUE)
    # A content hash in the file name gives RStudio a fresh URL on every
    # rebuild, so the IDE never shows a cached copy of the old theme.
    hash <- substr(unname(tools::md5sum(tmp)), 1, 8)
    dir <- file.path(tempdir(), "rswallpaper")
    dir.create(dir, showWarnings = FALSE)
    file <- file.path(dir, sprintf("rswallpaper_%s_%s.rstheme", slugify(name), hash))
    file.copy(tmp, file, overwrite = TRUE)
    unlink(tmp)
  } else {
    writeLines(css, file, useBytes = TRUE)
  }
  file <- normalizePath(file, winslash = "/")
  invisible(structure(file, theme_name = name, base_name = base$label, image = img))
}

wallpaper_spec <- function(src, opacity, position, size, mode, fade, filter, target) {
  opacity <- opacity %||% if (mode == "overlay") 0.18 else 0.28
  check_number(opacity, "opacity", 0, 1)
  check_css_value(position, "position")
  if (is.numeric(size)) {
    check_number(size, "size", 0.01, 1)
    size <- paste0("auto ", fmt_num(size * 100), "%")
  }
  check_css_value(size, "size")
  if (!is.null(filter)) check_css_value(filter, "filter")
  list(src = src, opacity = opacity, position = position, size = size, mode = mode,
       fade = fade, filter = filter, target = target)
}

default_name <- function(name, base, img, accent) {
  if (!is.null(name)) {
    return(check_theme_name(name))
  }
  suffix <- if (!is.null(img)) {
    " + Wallpaper"
  } else if (!is.null(base$palette)) {
    " {rswallpaper}"
  } else if (!is.null(accent)) {
    " + Accent"
  } else {
    " (rswallpaper)"
  }
  paste0(base$label, suffix)
}

compose_theme <- function(base, name, wallpaper = NULL, accent = NULL, tint = 0.35, img = NULL) {
  check_number(tint, "tint", 0, 1)
  cols <- if (!is.null(base$palette)) {
    list(bg = base$palette$bg, fg = base$palette$fg, active_line = base$palette$roles$active_line,
         foreign_line = base$palette$roles$foreign_line)
  } else {
    theme_colors(base$css, base$is_dark)
  }
  if (identical(accent, "auto")) {
    accent <- auto_accent(img)
  }
  if (!is.null(accent)) {
    accent <- as_hex(accent)
  } else if (!is.null(base$palette)) {
    accent <- base$palette$accent
  }

  extra <- c(
    if (!is.null(accent)) accent_css(accent, cols$bg, cols$fg, base$is_dark, tint),
    if (!is.null(wallpaper)) {
      wallpaper_css(
        wallpaper$src, wallpaper$opacity, wallpaper$position, wallpaper$size, wallpaper$mode,
        wallpaper$fade, wallpaper$filter, wallpaper$target,
        # with an accent the active line is already translucent
        active_line = if (is.null(accent)) cols$active_line,
        foreign_line = cols$foreign_line
      )
    }
  )

  c(
    sprintf("/* rs-theme-name: %s */", name),
    sprintf("/* rs-theme-is-dark: %s */", if (base$is_dark) "TRUE" else "FALSE"),
    sprintf("/* rswallpaper-version: %s */", pkg_version()),
    sprintf("/* rswallpaper-base: %s */", base$label),
    base$css,
    if (length(extra)) c("", MARK_BEGIN, extra, MARK_END)
  )
}

# ---- installing --------------------------------------------------------------

install_theme <- function(path, name, apply = TRUE, fallback = NULL) {
  installed <- scan_theme_dir(local_theme_dirs(), "installed")
  same <- installed[tolower(installed$name) == tolower(name), , drop = FALSE]
  if (any(!same$wallpaper)) {
    stop("A theme called \"", name, "\" already exists and was not made by rswallpaper (",
         same$path[!same$wallpaper][1], "). Choose another `name`.", call. = FALSE)
  }

  current <- rstudioapi::getThemeInfo()$editor
  if (tolower(current) == tolower(name)) {
    # Re-applying a theme under the same name does not trigger a refresh, so
    # step away first. The fallback is the base theme (or a stock one).
    apply <- TRUE
    switch_to_other_theme(name, fallback)
  }
  unlink(same$path)
  rstudioapi::addTheme(path, apply = apply, force = TRUE)
  invisible(name)
}

switch_to_other_theme <- function(name, fallback = NULL) {
  dark <- isTRUE(rstudioapi::getThemeInfo()$dark)
  candidates <- c(fallback, if (dark) "Tomorrow Night" else "Textmate (default)")
  for (cand in candidates) {
    if (!is.null(cand) && !is.na(cand) && tolower(cand) != tolower(name)) {
      ok <- tryCatch({
        rstudioapi::applyTheme(cand)
        TRUE
      }, error = function(e) FALSE)
      if (ok) return(invisible(cand))
    }
  }
  invisible(NULL)
}

remember_previous <- function(current) {
  generated <- scan_theme_dir(local_theme_dirs(), "installed")
  generated <- generated$name[generated$wallpaper]
  if (!tolower(current) %in% tolower(generated)) {
    write_state("previous", current)
  }
}

# ---- everyday helpers ---------------------------------------------------------

#' Show another random image from the wallpaper folder
#'
#' Re-applies the settings of the last [set_wallpaper()] call with a different
#' random image. Give `set_wallpaper()` a folder (or pass `dir` here) to use
#' this. Handy in `.Rprofile` to get a new picture every session:
#'
#' ```r
#' setHook("rstudio.sessionInit", function(newSession) {
#'   if (newSession) rswallpaper::shuffle_wallpaper()
#' }, action = "append")
#' ```
#'
#' @param dir Folder with images. Defaults to the folder used last time.
#' @return The theme name, invisibly.
#' @export
shuffle_wallpaper <- function(dir = NULL) {
  last <- read_state("last")
  if (is.null(last)) {
    stop("No previous wallpaper found. Run set_wallpaper(\"<folder>\") first.", call. = FALSE)
  }
  dir <- dir %||% last$img_dir
  if (is.null(dir)) {
    stop("The last wallpaper was a single file. Pass `dir`, or call set_wallpaper() with a folder.",
         call. = FALSE)
  }
  img <- resolve_image(dir, exclude = last$img)
  args <- last$args
  args$img <- img
  res <- do.call(set_wallpaper, args)
  # keep shuffling from the folder, not from the single picked file
  last <- read_state("last")
  last$img_dir <- normalizePath(dir, winslash = "/")
  write_state("last", last)
  invisible(res)
}

#' Go back to the theme you used before rswallpaper
#'
#' @param remove Also uninstall all themes generated by rswallpaper.
#' @return The restored theme name, invisibly.
#' @export
restore_theme <- function(remove = FALSE) {
  require_rstudio("restore_theme()")
  prev <- read_state("previous")
  if (is.null(prev)) {
    prev <- if (isTRUE(rstudioapi::getThemeInfo()$dark)) "Tomorrow Night" else "Textmate (default)"
  }
  ok <- tryCatch({
    rstudioapi::applyTheme(prev)
    TRUE
  }, error = function(e) FALSE)
  if (!ok) {
    prev <- switch_to_other_theme("", NULL)
  }
  if (remove) {
    remove_wallpapers()
  }
  message("Restored theme \"", prev, "\".")
  invisible(prev)
}

#' List or remove themes generated by rswallpaper
#'
#' @return `list_wallpapers()` returns a data frame (`name`, `base`,
#'   `is_dark`, `size_kb`, `path`). `remove_wallpapers()` returns the removed
#'   names invisibly.
#' @export
list_wallpapers <- function() {
  th <- scan_theme_dir(local_theme_dirs(), "installed")
  th <- th[th$wallpaper, , drop = FALSE]
  data.frame(
    name = th$name, base = th$base, is_dark = th$is_dark,
    size_kb = round(file.size(th$path) / 1024), path = th$path,
    stringsAsFactors = FALSE
  )
}

#' @param name Names of the themes to remove; `NULL` removes all of them.
#' @rdname list_wallpapers
#' @export
remove_wallpapers <- function(name = NULL) {
  th <- list_wallpapers()
  if (!is.null(name)) {
    th <- th[tolower(th$name) %in% tolower(name), , drop = FALSE]
  }
  for (i in seq_len(nrow(th))) {
    if (in_rstudio()) {
      tryCatch(rstudioapi::removeTheme(th$name[i]),
               error = function(e) unlink(th$path[i]))
    } else {
      unlink(th$path[i])
    }
  }
  invisible(th$name)
}
