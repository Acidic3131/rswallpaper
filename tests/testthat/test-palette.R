test_that("every preset palette is readable", {
  for (id in palettes()$name) {
    p <- rswallpaper:::preset_palette(id)
    code <- unlist(p$roles[c("keyword", "operator", "string", "number", "func", "type", "tag")])
    ratios <- vapply(code, rswallpaper:::contrast_ratio, numeric(1), b = p$bg)
    expect_true(all(ratios >= 4.5), info = id)
    expect_gte(rswallpaper:::contrast_ratio(p$roles$comment, p$bg), 3)
    expect_equal(rswallpaper:::is_dark_color(p$bg), p$dark, info = id)
  }
})

test_that("rs_palette accepts overrides and rejects unknown roles", {
  p <- rs_palette("#4FB0A5", dark = TRUE, name = "Teal", string = "#ffcc00")
  expect_s3_class(p, "rsw_palette")
  expect_equal(p$roles$string, "#FFCC00")
  expect_error(rs_palette("#4FB0A5", bogus = "#000"), "Unknown palette role")
  expect_error(rs_palette("nope"), "Not a valid colour")
  expect_output(print(p), "Teal")
})

test_that("palettes() lists the presets", {
  p <- palettes()
  expect_true(all(c("sakura", "yozora") %in% p$name))
  expect_named(p, c("name", "label", "dark", "accent", "background", "foreground"))
})
