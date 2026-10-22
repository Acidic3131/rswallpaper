test_that("preview_theme writes a self-contained HTML page", {
  out <- tempfile(fileext = ".html")
  f <- preview_theme(demo_img(), theme = "sakura", mode = "behind", file = out, open = FALSE)
  html <- paste(readLines(f), collapse = "\n")
  expect_match(html, 'id="rstudio_source_text_editor"', fixed = TRUE)
  expect_match(html, "ace_keyword", fixed = TRUE)
  expect_match(html, "data:image/png;base64", fixed = TRUE)
})

test_that("the R tokenizer produces ace classes", {
  h <- rswallpaper:::highlight_r('x <- f(1L, "a") # hi')
  expect_match(h, '<span class="ace_keyword ace_operator">&lt;-</span>', fixed = TRUE)
  expect_match(h, '<span class="ace_identifier ace_support ace_function">f</span>', fixed = TRUE)
  expect_match(h, '<span class="ace_constant ace_numeric">1L</span>', fixed = TRUE)
  expect_match(h, '<span class="ace_string">&quot;a&quot;</span>|<span class="ace_string">"a"</span>')
  expect_match(h, '<span class="ace_comment"># hi</span>', fixed = TRUE)
})
