#' Wallpaper Studio: pick an image and colours with a live preview
#'
#' A Shiny gadget (also available as the *Wallpaper Studio* addin) to choose
#' the image, base theme, accent colour, opacity, size, position and fade
#' while watching a live preview, then apply the result to RStudio.
#'
#' Needs the \pkg{shiny} and \pkg{miniUI} packages.
#'
#' @param img Optional image to start with.
#' @param viewer Where to show the gadget; see [shiny::runGadget()].
#' @return The applied theme name (invisibly), or `NULL` if cancelled.
#' @export
wallpaper_studio <- function(img = NULL, viewer = NULL) {
  for (pkg in c("shiny", "miniUI")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("wallpaper_studio() needs the '", pkg, "' package: install.packages(\"", pkg, "\")",
           call. = FALSE)
    }
  }
  shiny::runGadget(
    studio_ui(img), studio_server(img),
    viewer = viewer %||% shiny::dialogViewer("rswallpaper \u00b7 Wallpaper Studio", width = 1280, height = 860),
    stopOnCancel = FALSE
  )
}

studio_theme_choices <- function() {
  th <- list_themes(c("installed", "global", "builtin"))
  th <- th[!th$wallpaper, , drop = FALSE]
  pal <- palettes()
  out <- list(
    "From the image" = list("Auto palette (light)" = "auto", "Auto palette (dark)" = "auto-dark"),
    "rswallpaper palettes" = as.list(stats::setNames(
      pal$name, paste0(pal$label, ifelse(pal$dark, " (dark)", " (light)"))
    )),
    "Installed themes" = as.list(th$name[th$source %in% c("installed", "global")]),
    "RStudio built-in" = as.list(th$name[th$source == "builtin"])
  )
  if (in_rstudio()) {
    out <- c(list("Keep" = list("Current RStudio theme" = CURRENT)), out)
  }
  out[lengths(out) > 0]
}

CURRENT <- "__current__"

swatch_row <- function(label, hex, names) {
  shiny::div(
    class = "rsw-swatch-group",
    shiny::div(class = "rsw-swatch-label", label),
    lapply(seq_along(hex), function(i) {
      shiny::tags$span(class = "rsw-swatch", style = paste0("background:", hex[i]),
                       `data-color` = hex[i], title = paste(names[i], hex[i]))
    })
  )
}

swatch_panel <- function() {
  pal <- palettes()
  groups <- split(SWATCHES, factor(SWATCHES$group, levels = unique(SWATCHES$group)))
  shiny::div(
    class = "rsw-swatches",
    shiny::uiOutput("img_swatches"),
    swatch_row("rswallpaper", pal$accent, pal$label),
    lapply(groups, function(g) swatch_row(g$group[1], g$hex, g$name))
  )
}

color_input <- function(id, value = "#E0628E") {
  shiny::tags$input(id = id, type = "color", value = value, class = "rsw-color")
}

STUDIO_JS <- "
(function() {
  var b = new Shiny.InputBinding();
  $.extend(b, {
    find: function(scope) { return $(scope).find('input.rsw-color'); },
    getValue: function(el) { return el.value; },
    setValue: function(el, v) { el.value = v; },
    subscribe: function(el, cb) { $(el).on('input.rsw change.rsw', function() { cb(true); }); },
    unsubscribe: function(el) { $(el).off('.rsw'); },
    receiveMessage: function(el, data) { if (data.value) { el.value = data.value; $(el).trigger('change'); } },
    getRatePolicy: function() { return { policy: 'debounce', delay: 250 }; }
  });
  Shiny.inputBindings.register(b, 'rswallpaper.color');
  $(document).on('click', '.rsw-swatch', function() {
    var el = document.getElementById('accent_col');
    el.value = $(this).data('color');
    $(el).trigger('change');
    $('.rsw-swatch.on').removeClass('on');
    $(this).addClass('on');
    $('input[name=accent_mode][value=custom]').prop('checked', true).trigger('change');
  });
  $(document).on('input', '#accent_col', function() { $('.rsw-swatch.on').removeClass('on'); });
})();
"

STUDIO_CSS <- "
.rsw-side { padding: 4px 14px 14px 4px; overflow-y: auto; height: 100%; }
.rsw-side .form-group { margin-bottom: 10px; }
.rsw-side label { font-weight: 600; font-size: 12px; }
.rsw-side h5 { margin: 14px 0 6px; font-size: 11px; letter-spacing: .08em; text-transform: uppercase; opacity: .6; }
.rsw-row { display: flex; gap: 6px; align-items: center; }
.rsw-row .form-group { flex: 1; margin-bottom: 0; }
.rsw-color { width: 44px; height: 30px; padding: 0; border: 1px solid #ccc; border-radius: 4px; background: none; }
.rsw-swatches { margin: 8px 0 12px; }
.rsw-swatch-group { display: flex; flex-wrap: wrap; gap: 5px; margin-bottom: 8px; }
.rsw-swatch-label { flex-basis: 100%; font-size: 10px; letter-spacing: .06em; text-transform: uppercase; opacity: .55; }
.rsw-swatch { width: 18px; height: 18px; border-radius: 50%;
  box-shadow: inset 0 0 0 1px rgba(0,0,0,.12); cursor: pointer; transition: transform .12s ease; }
.rsw-swatch:hover { transform: scale(1.18); }
.rsw-swatch.on { box-shadow: 0 0 0 2px #fff, 0 0 0 3.5px #444; }
.rsw-preview { width: 100%; height: 100%; border: 0; border-radius: 6px; box-shadow: 0 1px 6px rgba(0,0,0,.18); }
.rsw-hint { font-size: 11px; opacity: .65; }
"

studio_ui <- function(img) {
  last <- read_state("last")$args %||% list()
  s <- function(x, default) if (is.null(x)) default else x
  img0 <- img %||% read_state("last")$img %||% ""

  miniUI::miniPage(
    shiny::tags$head(shiny::tags$style(shiny::HTML(STUDIO_CSS))),
    shiny::tags$script(shiny::HTML(STUDIO_JS)),
    miniUI::gadgetTitleBar(
      "Wallpaper Studio",
      left = miniUI::miniTitleBarCancelButton(),
      right = miniUI::miniTitleBarButton("done", "Apply & close", primary = TRUE)
    ),
    miniUI::miniContentPanel(
      padding = 10,
      shiny::fillRow(
        flex = c(NA, 1),
        shiny::div(
          class = "rsw-side", style = "width: 330px;",
          shiny::h5("Image"),
          shiny::div(
            class = "rsw-row",
            shiny::textInput("img", NULL, value = img0, placeholder = "path, folder or URL"),
            if (in_rstudio()) shiny::actionButton("browse", "File\u2026", title = "Choose an image")
          ),
          shiny::div(class = "rsw-hint", "A transparent PNG of a character works best. Leave empty for colours only."),
          shiny::h5("Colours"),
          shiny::selectInput("theme", "Base theme", choices = studio_theme_choices(),
                             selected = if (is.character(last$theme)) last$theme else if (in_rstudio()) CURRENT else "sakura"),
          shiny::radioButtons("accent_mode", "Accent colour", inline = TRUE,
                              choices = c("Keep" = "none", "From image" = "auto", "Custom" = "custom"),
                              selected = if (is.null(last$accent)) "none" else if (identical(last$accent, "auto")) "auto" else "custom"),
          shiny::div(
            class = "rsw-row",
            color_input("accent_col", if (is.character(last$accent) && is_color(last$accent)) as_hex(last$accent) else "#E0628E"),
            shiny::div(class = "rsw-hint", "Pick any colour, or a swatch below.")
          ),
          swatch_panel(),
          shiny::sliderInput("tint", "Chrome tint", 0, 1, s(last$tint, 0.35), step = 0.05),
          shiny::h5("Placement"),
          shiny::radioButtons("mode", "Mode", inline = TRUE,
                              choices = c("Overlay" = "overlay", "Behind text" = "behind"),
                              selected = s(last$mode, "overlay")),
          shiny::sliderInput("opacity", "Opacity", 0.02, 0.8, s(last$opacity, 0.18), step = 0.01),
          shiny::div(
            class = "rsw-row",
            shiny::selectInput("fit", "Size", c("Height %" = "height", "Contain" = "contain", "Cover" = "cover"),
                               selected = if (is.character(last$size)) last$size else "height"),
            shiny::selectInput("position", "Position", c(
              "right bottom", "right center", "right top", "center bottom", "center",
              "center top", "left bottom", "left center", "left top"
            ), selected = s(last$position, "right bottom"))
          ),
          shiny::sliderInput("size", "Height (% of editor)", 10, 100,
                             if (is.numeric(last$size)) last$size * 100 else 75, step = 1),
          shiny::div(
            class = "rsw-row",
            shiny::selectInput("fade", "Fade towards", c("none", "left", "right", "top", "bottom"),
                               selected = s(last$fade, "none")),
            shiny::selectInput("target", "Show in", c("Source editors" = "source", "Any editor" = "any"),
                               selected = s(last$target, "source"))
          ),
          shiny::textInput("filter", "CSS filter (optional)", s(last$filter, ""), placeholder = "blur(1px) saturate(1.2)"),
          shiny::textInput("name", "Theme name (optional)", "", placeholder = "<base> + Wallpaper"),
          shiny::div(
            class = "rsw-row",
            shiny::actionButton("apply", "Apply", class = "btn-primary"),
            shiny::actionButton("save", "Save .rstheme\u2026"),
            if (in_rstudio()) shiny::actionButton("restore", "Restore")
          )
        ),
        shiny::uiOutput("preview", style = "height: 100%;")
      )
    )
  )
}

studio_server <- function(img0) {
  function(input, output, session) {
    prev_dir <- tempfile("rsw-preview")
    dir.create(prev_dir)
    prefix <- paste0("rswprev", sample.int(1e6, 1))
    shiny::addResourcePath(prefix, prev_dir)
    counter <- 0

    shiny::observeEvent(input$browse, {
      f <- rstudioapi::selectFile("Choose an image", filter = "Images (*.png *.jpg *.jpeg *.gif *.webp *.svg)")
      if (!is.null(f)) shiny::updateTextInput(session, "img", value = f)
    })

    # A folder means "random image": keep one pick stable while editing.
    image <- shiny::reactive({
      path <- trimws(input$img)
      if (!nzchar(path)) return(NULL)
      tryCatch(resolve_image(path), error = function(e) {
        shiny::showNotification(conditionMessage(e), type = "error", duration = 4)
        NULL
      })
    })

    image_cols <- shiny::reactive({
      if (is.null(image())) return(character())
      tryCatch(image_colors(image(), 6), error = function(e) character())
    })

    output$img_swatches <- shiny::renderUI({
      cols <- image_cols()
      if (length(cols)) swatch_row("From image", cols, cols)
    })

    settings <- shiny::reactive({
      size <- if (input$fit == "height") input$size / 100 else input$fit
      accent <- switch(input$accent_mode, none = NULL, auto = "auto", custom = input$accent_col)
      list(
        theme = if (!identical(input$theme, CURRENT)) input$theme,
        accent = accent, opacity = input$opacity, position = input$position, size = size,
        mode = input$mode, fade = input$fade, target = input$target, tint = input$tint,
        filter = if (nzchar(trimws(input$filter))) trimws(input$filter),
        name = if (nzchar(trimws(input$name))) trimws(input$name)
      )
    })

    # The preview page loads the image by URL; copy it once per image.
    preview_img <- shiny::reactive({
      img <- image()
      if (is.null(img)) return(NULL)
      local <- file.path(prev_dir, paste0("img", sample.int(1e6, 1), ".", image_ext(img)))
      file.copy(img, local, overwrite = TRUE)
      basename(local)
    })

    output$preview <- shiny::renderUI({
      s <- settings()
      img <- image()
      counter <<- counter + 1
      html <- tryCatch({
        base <- resolve_theme(s$theme, img = img, quiet = TRUE)
        wp <- if (!is.null(img)) {
          wallpaper_spec(preview_img(), s$opacity, s$position, s$size, s$mode,
                         s$fade, s$filter, s$target)
        }
        name <- default_name(s$name, base, img, s$accent)
        css <- compose_theme(base, name, wallpaper = wp, accent = s$accent, tint = s$tint, img = img)
        mock_html(css, base$is_dark, name)
      }, error = function(e) {
        sprintf("<p style='font:14px sans-serif;padding:20px;color:#b00'>%s</p>",
                html_escape(conditionMessage(e)))
      })
      unlink(list.files(prev_dir, pattern = "^preview", full.names = TRUE))
      file <- paste0("preview", counter, ".html")
      writeLines(html, file.path(prev_dir, file), useBytes = TRUE)
      shiny::tags$iframe(class = "rsw-preview", src = paste0(prefix, "/", file))
    })

    apply_now <- function() {
      s <- settings()
      typed <- trimws(input$img)
      res <- tryCatch(
        do.call(set_wallpaper, c(list(img = image()), s)),
        error = function(e) {
          shiny::showNotification(conditionMessage(e), type = "error", duration = 6)
          NULL
        }
      )
      if (!is.null(res)) {
        # Apply the image shown in the preview, but remember the folder for
        # shuffle_wallpaper().
        if (nzchar(typed) && dir.exists(path.expand(typed))) {
          last <- read_state("last")
          last$img_dir <- normalizePath(typed, winslash = "/")
          write_state("last", last)
        }
        shiny::showNotification(paste0("Applied \"", res, "\""), duration = 3)
      }
      res
    }

    shiny::observeEvent(input$apply, apply_now())

    shiny::observeEvent(input$save, {
      s <- settings()
      target <- if (in_rstudio()) {
        rstudioapi::selectFile("Save theme as", label = "Save", existing = FALSE,
                               filter = "RStudio theme (*.rstheme)")
      } else {
        file.path(getwd(), "wallpaper.rstheme")
      }
      if (is.null(target)) return()
      if (!grepl("\\.rstheme$", target)) target <- paste0(target, ".rstheme")
      tryCatch({
        do.call(build_theme, c(list(img = image(), file = target), s))
        shiny::showNotification(paste("Saved", target), duration = 4)
      }, error = function(e) shiny::showNotification(conditionMessage(e), type = "error"))
    })

    shiny::observeEvent(input$restore, {
      restore_theme()
      shiny::showNotification("Restored the previous theme.", duration = 3)
    })

    shiny::observeEvent(input$done, {
      res <- if (in_rstudio()) apply_now() else NULL
      shiny::stopApp(invisible(res))
    })
    shiny::observeEvent(input$cancel, shiny::stopApp(invisible(NULL)))
  }
}
