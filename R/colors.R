# Small colour toolkit built on grDevices only. Colours are passed around as
# "#RRGGBB" strings; alpha is expressed separately as CSS rgba() when needed.

# Parse CSS colours (#rgb, #rgba, #rrggbb, #rrggbbaa, rgb(), rgba(), and the
# colour names R knows) into a 4 x n matrix of r, g, b (0-255) and alpha (0-1).
parse_color <- function(x) {
  out <- vapply(as.character(x), parse_color1, numeric(4), USE.NAMES = FALSE)
  rownames(out) <- c("r", "g", "b", "alpha")
  out
}

parse_color1 <- function(x) {
  x <- trimws(sub("!important", "", x, fixed = TRUE))
  if (is.na(x) || !nzchar(x)) {
    return(rep(NA_real_, 4))
  }
  if (grepl("^#[0-9a-fA-F]{3,4}$", x)) {
    chars <- strsplit(substring(x, 2), "")[[1]]
    x <- paste0("#", paste0(chars, chars, collapse = ""))
  }
  if (grepl("^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$", x)) {
    v <- grDevices::col2rgb(x, alpha = TRUE)[, 1]
    return(c(v[1:3], v[4] / 255))
  }
  m <- regmatches(x, regexec(
    "^rgba?\\(\\s*([0-9.]+)\\s*[, ]\\s*([0-9.]+)\\s*[, ]\\s*([0-9.]+)\\s*(?:[,/]\\s*([0-9.]+)(%?))?\\s*\\)$",
    x, perl = TRUE
  ))[[1]]
  if (length(m)) {
    a <- if (nzchar(m[5])) as.numeric(m[5]) else 1
    if (nzchar(m[6])) a <- a / 100
    return(c(as.numeric(m[2:4]), a))
  }
  v <- tryCatch(grDevices::col2rgb(x, alpha = TRUE)[, 1], error = function(e) NULL)
  if (is.null(v)) {
    return(rep(NA_real_, 4))
  }
  c(v[1:3], v[4] / 255)
}

is_color <- function(x) {
  !anyNA(parse_color(x)[1:3, , drop = FALSE])
}

as_hex <- function(x) {
  m <- parse_color(x)
  if (anyNA(m[1:3, ])) {
    stop("Not a valid colour: ", paste(x[is.na(m[1, ])], collapse = ", "), call. = FALSE)
  }
  grDevices::rgb(m[1, ], m[2, ], m[3, ], maxColorValue = 255)
}

# Pick the first colour token out of a CSS value such as "#fff url(...) no-repeat".
first_color <- function(value) {
  if (is.null(value) || is.na(value)) {
    return(NA_character_)
  }
  m <- regmatches(value, regexpr(
    "#[0-9a-fA-F]{3,8}\\b|rgba?\\([^)]*\\)|\\b[a-zA-Z]+\\b", value, perl = TRUE
  ))
  if (!length(m) || !is_color(m)) NA_character_ else m
}

# Linear interpolation in sRGB: t = 0 gives a, t = 1 gives b.
mix <- function(a, b, t) {
  ma <- parse_color(a)[1:3, , drop = FALSE]
  mb <- parse_color(b)[1:3, , drop = FALSE]
  m <- round(ma * (1 - t) + mb * t)
  grDevices::rgb(m[1, ], m[2, ], m[3, ], maxColorValue = 255)
}

rgba <- function(col, alpha) {
  m <- parse_color(col)
  sprintf("rgba(%d, %d, %d, %s)", round(m[1, ]), round(m[2, ]), round(m[3, ]), fmt_num(alpha))
}

# "#RRGGBBAA" form, handy inside gradients.
hex_alpha <- function(col, alpha) {
  paste0(as_hex(col), sprintf("%02x", round(alpha * 255)))
}

luminance <- function(col) {
  m <- parse_color(col)[1:3, , drop = FALSE] / 255
  m <- ifelse(m <= 0.04045, m / 12.92, ((m + 0.055) / 1.055)^2.4)
  as.vector(c(0.2126, 0.7152, 0.0722) %*% m)
}

contrast_ratio <- function(a, b) {
  la <- luminance(a)
  lb <- luminance(b)
  (pmax(la, lb) + 0.05) / (pmin(la, lb) + 0.05)
}

is_dark_color <- function(col) {
  luminance(col) < 0.2
}

# Polar CIE-Luv, the same space grDevices::hcl() works in.
col_hcl <- function(col) {
  m <- t(parse_color(col)[1:3, , drop = FALSE] / 255)
  luv <- grDevices::convertColor(m, from = "sRGB", to = "Luv")
  luv <- matrix(luv, ncol = 3)
  h <- (atan2(luv[, 3], luv[, 2]) * 180 / pi) %% 360
  cbind(h = h, c = sqrt(luv[, 2]^2 + luv[, 3]^2), l = luv[, 1])
}

hcl_hex <- function(h, c, l) {
  grDevices::hcl(h %% 360, c, pmin(pmax(l, 0), 100), fixup = TRUE)
}

# Nudge the lightness of `col` away from `bg` until the WCAG contrast ratio
# reaches `ratio` (or lightness runs out).
ensure_contrast <- function(col, bg, ratio = 4.5) {
  col <- as_hex(col)
  if (contrast_ratio(col, bg) >= ratio) {
    return(col)
  }
  hc <- col_hcl(col)[1, ]
  step <- if (is_dark_color(bg)) 1.5 else -1.5
  l <- hc[["l"]]
  out <- col
  while (contrast_ratio(out, bg) < ratio && l > 0 && l < 100) {
    l <- l + step
    out <- hcl_hex(hc[["h"]], hc[["c"]], l)
  }
  out
}
