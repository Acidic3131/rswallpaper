test_that("CSS colours are parsed", {
  m <- rswallpaper:::parse_color(c("#abc", "#AABBCC", "rgba(10, 20, 30, 0.5)", "rgb(1 2 3 / 50%)", "white"))
  expect_equal(unname(m[, 1]), c(170, 187, 204, 1))
  expect_equal(unname(m[, 2]), c(170, 187, 204, 1))
  expect_equal(unname(m[, 3]), c(10, 20, 30, 0.5))
  expect_equal(unname(m[, 4]), c(1, 2, 3, 0.5))
  expect_equal(unname(m[, 5]), c(255, 255, 255, 1))
  expect_true(is.na(rswallpaper:::parse_color("not-a-colour")[1, 1]))
})

test_that("mixing, alpha and contrast behave", {
  expect_equal(rswallpaper:::mix("#000000", "#FFFFFF", 0.5), "#808080")
  expect_equal(rswallpaper:::rgba("#FF0000", 0.25), "rgba(255, 0, 0, 0.25)")
  expect_equal(round(rswallpaper:::contrast_ratio("#000000", "#FFFFFF"), 1), 21)
  fixed <- rswallpaper:::ensure_contrast("#FCB3CC", "#FFFFFF", 4.5)
  expect_gte(rswallpaper:::contrast_ratio(fixed, "#FFFFFF"), 4.5)
  fixed <- rswallpaper:::ensure_contrast("#3A0010", "#101010", 4.5)
  expect_gte(rswallpaper:::contrast_ratio(fixed, "#101010"), 4.5)
})

test_that("first_color picks the colour out of shorthand values", {
  expect_equal(rswallpaper:::first_color("#fff url(x.png) no-repeat"), "#fff")
  expect_equal(rswallpaper:::first_color("rgba(0,0,0,.2) !important"), "rgba(0,0,0,.2)")
  expect_true(is.na(rswallpaper:::first_color("none")))
})
