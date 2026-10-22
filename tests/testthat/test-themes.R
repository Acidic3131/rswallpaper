test_that("strip_theme removes headers and previous rswallpaper blocks", {
  css <- c("/* rs-theme-name: X */", "/* rs-theme-is-dark: TRUE */", "/* rswallpaper-base: Y */",
           ".a { color: red; }", "/* rswallpaper:begin */", ".b {}", "/* rswallpaper:end */", ".c {}")
  expect_equal(rswallpaper:::strip_theme(css), c(".a { color: red; }", ".c {}"))
})

test_that("theme directories can be scanned", {
  dir <- tempfile("themes")
  demo_rstheme(dir, "Demo Light")
  demo_rstheme(dir, "Demo Dark", dark = TRUE)
  tab <- rswallpaper:::scan_theme_dir(dir, "installed")
  expect_setequal(tab$name, c("Demo Light", "Demo Dark"))
  expect_equal(tab$is_dark[tab$name == "Demo Dark"], TRUE)
  expect_false(any(tab$wallpaper))
})

test_that("list_themes always includes the palettes", {
  th <- list_themes("palette")
  expect_equal(nrow(th), nrow(palettes()))
  expect_true(all(th$source == "palette"))
})

test_that("functions that need RStudio say so", {
  skip_if(rswallpaper:::in_rstudio())
  expect_error(set_wallpaper(theme = "sakura"), "inside RStudio")
  expect_error(build_theme(), "`theme` is required outside RStudio")
})
