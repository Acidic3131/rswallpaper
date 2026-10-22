test_that("palette themes are complete rstheme files", {
  f <- build_theme(theme = "sakura", file = tempfile(fileext = ".rstheme"))
  css <- readLines(f)
  expect_equal(css[1], "/* rs-theme-name: Sakura {rswallpaper} */")
  expect_equal(css[2], "/* rs-theme-is-dark: FALSE */")
  expect_true(any(grepl(".xtermColor255", css, fixed = TRUE)))
  expect_true(any(grepl(".ace_paren_color_6", css, fixed = TRUE)))
  expect_true(css_balanced(css))
  expect_equal(attr(f, "theme_name"), "Sakura {rswallpaper}")
})

test_that("a wallpaper is added on top of an existing theme file", {
  base <- demo_rstheme()
  f <- build_theme(demo_img(), theme = base, opacity = 0.3, size = 0.6,
                   file = tempfile(fileext = ".rstheme"))
  css <- readLines(f)
  expect_equal(css[1], "/* rs-theme-name: Demo Light + Wallpaper */")
  expect_equal(sum(grepl("rs-theme-name", css)), 1)
  expect_true(any(grepl('[id^="rstudio_source_text_editor"]::after', css, fixed = TRUE)))
  expect_true(any(grepl("background-size: auto 60%;", css, fixed = TRUE)))
  expect_true(any(grepl("opacity: 0.3;", css, fixed = TRUE)))
  expect_true(css_balanced(css))
})

test_that("behind mode draws under the text and softens line markers", {
  f <- build_theme(demo_img(), theme = demo_rstheme(), mode = "behind", fade = "left",
                   file = tempfile(fileext = ".rstheme"))
  css <- paste(readLines(f), collapse = "\n")
  expect_match(css, ".ace_scroller::before", fixed = TRUE)
  expect_match(css, "z-index: 0;", fixed = TRUE)
  expect_match(css, "rgba(241, 233, 210, 0.55) !important", fixed = TRUE)
  expect_match(css, "mask-image: linear-gradient(to left", fixed = TRUE)
})

test_that("the image is kept out of the console, terminal and other panes", {
  src <- '.ace_editor[id^="rstudio_source_text_editor"]'
  cases <- list(
    list(target = "source", mode = "overlay", sel = src, pseudo = "::after"),
    list(target = "any", mode = "overlay", sel = ".ace_editor", pseudo = "::after"),
    list(target = "source", mode = "behind", sel = src, pseudo = " .ace_scroller::before")
  )
  for (cs in cases) {
    f <- build_theme(demo_img(), theme = "sakura", target = cs$target, mode = cs$mode,
                     file = tempfile(fileext = ".rstheme"))
    css <- readLines(f)
    txt <- paste(css, collapse = "\n")
    for (scope in c('[id^="rstudio_workbench_panel_"] ', ".terminal ", '[id*="console"] ', ".ProseMirror ")) {
      expect_match(txt, paste0(scope, cs$sel, cs$pseudo), fixed = TRUE, info = paste(cs$target, cs$mode))
    }
    # :has() lives in a rule of its own so older browsers only drop that rule
    has_line <- grep(":has(.terminal)", css, fixed = TRUE)
    expect_length(has_line, 1)
    expect_false(grepl("rstudio_workbench_panel_", css[has_line], fixed = TRUE))
  }
})

test_that("rebuilding from a generated theme does not stack wallpapers", {
  first <- build_theme(demo_img(), theme = demo_rstheme(), accent = "#E0628E",
                       file = tempfile(fileext = ".rstheme"))
  second <- build_theme(demo_img(), theme = first, file = tempfile(fileext = ".rstheme"))
  css <- readLines(second)
  expect_equal(sum(css == "/* rswallpaper:begin */"), 1)
  expect_equal(sum(grepl("background-image: url(", css, fixed = TRUE)), 1)
  expect_equal(css[1], "/* rs-theme-name: Demo Light + Wallpaper */")
  expect_false(any(grepl("accent: IDE chrome", css, fixed = TRUE)))
})

test_that("accent colours tint the editor and the IDE chrome", {
  f <- build_theme(theme = demo_rstheme(), accent = "#2F80D1", file = tempfile(fileext = ".rstheme"))
  css <- paste(readLines(f), collapse = "\n")
  expect_match(css, "Demo Light + Accent", fixed = TRUE)
  expect_match(css, ".gwt-TabLayoutPanelTab-selected table.rstheme_tabLayoutCenter", fixed = TRUE)
  expect_match(css, "inset 0 -2px 0 #2F80D1", fixed = TRUE)
})

test_that("auto palettes come from the image", {
  f <- build_theme(demo_png(), theme = "auto-dark", file = tempfile(fileext = ".rstheme"))
  css <- readLines(f)
  expect_equal(css[2], "/* rs-theme-is-dark: TRUE */")
})

test_that("CSS injection and bad arguments are refused", {
  expect_error(build_theme(demo_img(), theme = "sakura", position = "left; } body { x"), "plain CSS")
  expect_error(build_theme(demo_img(), theme = "sakura", opacity = 2), "opacity")
  expect_error(build_theme(theme = "sakura", name = "bad*name"), "cannot contain")
  expect_error(build_theme(theme = "definitely-not-a-theme"), "not found")
  expect_error(build_theme(theme = "auto"), "needs an image")
})

test_that("hand-made wallpapers in a base theme are removed", {
  base <- demo_rstheme()
  css <- readLines(base)
  # indent-guide data URIs are not wallpapers
  expect_equal(rswallpaper:::strip_legacy_wallpaper(css)$removed, 0L)

  legacy <- c(css,
    "/* old script: overlay image */",
    ".ace_editor::after {",
    '  content: ""; background-image: url("data:image/png;base64,AAAA");',
    "}",
    ".terminal .terminal-cursor::before { content: ''; background-color: #333; }")
  out <- rswallpaper:::strip_legacy_wallpaper(legacy)
  expect_equal(out$removed, 1L)
  expect_false(any(grepl("base64,AAAA", out$css, fixed = TRUE)))
  expect_true(any(grepl("terminal-cursor::before", out$css, fixed = TRUE)))
  expect_true(any(grepl("ace_indent-guide", out$css, fixed = TRUE)))
  expect_true(css_balanced(out$css))

  f <- tempfile(fileext = ".rstheme")
  writeLines(legacy, f)
  expect_message(
    built <- build_theme(demo_img(), theme = f, file = tempfile(fileext = ".rstheme")),
    "Removed the image"
  )
  built <- readLines(built)
  expect_equal(sum(grepl("background-image: url(", built, fixed = TRUE)), 1)
  expect_false(any(grepl("base64,AAAA", built, fixed = TRUE)))
})

test_that("generated theme names are recognised by the header reader", {
  f <- build_theme(theme = "yozora", file = tempfile(fileext = ".rstheme"))
  h <- rswallpaper:::read_theme_header(f)
  expect_equal(h$name, "Yozora {rswallpaper}")
  expect_true(h$is_dark)
  expect_true(h$generated)
  expect_equal(h$base, "Yozora")
})
