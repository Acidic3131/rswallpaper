test_that("image_colors finds the dominant hues", {
  cols <- image_colors(demo_png(), n = 3)
  expect_length(cols, 2)
  hues <- rswallpaper:::col_hcl(cols)[, "h"]
  # red-ish (~10) and blue-ish (~255) in polar Luv
  expect_true(any(hues < 30 | hues > 340))
  expect_true(any(hues > 220 & hues < 290))
})

test_that("the bundled demo image yields an accent colour", {
  skip_if_not_installed("png")
  cols <- image_colors(demo_img(), n = 3)
  expect_gte(length(cols), 1)
  expect_true(all(grepl("^#[0-9A-F]{6}$", cols)))
})

test_that("resolve_image handles folders and bad input", {
  d <- tempfile("imgs")
  dir.create(d)
  file.copy(demo_img(), file.path(d, "a.png"))
  file.copy(demo_svg(), file.path(d, "b.svg"))
  writeLines("x", file.path(d, "notes.txt"))
  picked <- rswallpaper:::resolve_image(d)
  expect_match(basename(picked), "^(a\\.png|b\\.svg)$")
  other <- rswallpaper:::resolve_image(d, exclude = picked)
  expect_false(identical(other, picked))
  expect_error(rswallpaper:::resolve_image(file.path(d, "notes.txt")), "Unsupported")
  expect_error(rswallpaper:::resolve_image(file.path(d, "missing.png")), "not found")
})

test_that("images are embedded as data URIs", {
  expect_match(rswallpaper:::image_data_uri(demo_img()), "^data:image/png;base64,")
  expect_match(rswallpaper:::image_data_uri(demo_svg()), "^data:image/svg\\+xml;base64,")
})
