IMAGE_TYPES <- c(
  png = "image/png", jpg = "image/jpeg", jpeg = "image/jpeg", gif = "image/gif",
  webp = "image/webp", svg = "image/svg+xml", avif = "image/avif", bmp = "image/bmp"
)

image_ext <- function(path) {
  tolower(tools::file_ext(path))
}

list_images <- function(dir) {
  pattern <- paste0("\\.(", paste(names(IMAGE_TYPES), collapse = "|"), ")$")
  list.files(dir, pattern = pattern, full.names = TRUE, ignore.case = TRUE)
}

# NULL, a file, a folder (random pick) or an http(s) URL -> local file path.
resolve_image <- function(img, exclude = NULL) {
  if (is.null(img)) {
    return(NULL)
  }
  check_string(img, "img")
  if (grepl("^https?://", img)) {
    ext <- image_ext(sub("[?#].*$", "", img))
    if (!ext %in% names(IMAGE_TYPES)) ext <- "png"
    dest <- tempfile("rsw-download", fileext = paste0(".", ext))
    utils::download.file(img, dest, mode = "wb", quiet = TRUE)
    return(dest)
  }
  img <- path.expand(img)
  if (dir.exists(img)) {
    files <- normalizePath(list_images(img), winslash = "/")
    if (length(files) > 1 && !is.null(exclude)) {
      files <- setdiff(files, normalizePath(exclude, winslash = "/", mustWork = FALSE))
    }
    if (!length(files)) {
      stop("No images (", paste(names(IMAGE_TYPES), collapse = ", "), ") found in ", img, call. = FALSE)
    }
    img <- files[sample.int(length(files), 1)]
  }
  if (!file.exists(img)) {
    stop("Image not found: ", img, call. = FALSE)
  }
  if (!image_ext(img) %in% names(IMAGE_TYPES)) {
    stop("Unsupported image type '.", image_ext(img), "'. Use one of: ",
         paste(names(IMAGE_TYPES), collapse = ", "), call. = FALSE)
  }
  normalizePath(img, winslash = "/")
}

# Shrinks large raster images (needs magick) so the theme file stays light.
# Returns list(path, mime).
prepare_image <- function(path, max_px = 1600) {
  ext <- image_ext(path)
  mime <- IMAGE_TYPES[[ext]]
  if (ext %in% c("svg", "gif") || is.null(max_px)) {
    return(list(path = path, mime = mime))
  }
  if (requireNamespace("magick", quietly = TRUE)) {
    out <- tryCatch({
      im <- magick::image_read(path)
      info <- magick::image_info(im)
      if (max(info$width, info$height) > max_px || file.size(path) > 1.5e6) {
        im <- magick::image_scale(im, paste0(max_px, "x", max_px, ">"))
        out <- tempfile("rsw-img", fileext = ".webp")
        magick::image_write(im, out, format = "webp", quality = 88)
        out
      }
    }, error = function(e) NULL)
    if (!is.null(out) && file.exists(out) && file.size(out) > 0 && file.size(out) < file.size(path)) {
      return(list(path = out, mime = "image/webp"))
    }
  } else if (file.size(path) > 3e6) {
    message("The image is ", round(file.size(path) / 1e6, 1), " MB; it will be embedded as is. ",
            "Install the 'magick' package to shrink it automatically.")
  }
  list(path = path, mime = mime)
}

image_data_uri <- function(path, max_px = 1600) {
  img <- prepare_image(path, max_px)
  base64enc::dataURI(file = img$path, mime = img$mime)
}

# n x 4 matrix (r, g, b, alpha in 0-1) of a downsampled image.
read_pixels <- function(path, max = 120) {
  ext <- image_ext(path)
  if (requireNamespace("magick", quietly = TRUE)) {
    im <- magick::image_read(path)[1]
    im <- magick::image_scale(im, paste0(max, "x", max, ">"))
    arr <- as.integer(magick::image_data(im, "rgba")) / 255
  } else if (ext == "png" && requireNamespace("png", quietly = TRUE)) {
    arr <- png::readPNG(path)
  } else if (ext %in% c("jpg", "jpeg") && requireNamespace("jpeg", quietly = TRUE)) {
    arr <- jpeg::readJPEG(path)
  } else {
    stop("Reading colours from .", ext, " images needs the 'magick' package",
         if (ext == "png") " (or 'png')" else if (ext %in% c("jpg", "jpeg")) " (or 'jpeg')",
         ".", call. = FALSE)
  }
  if (length(dim(arr)) == 2) arr <- array(arr, c(dim(arr), 1))
  d <- dim(arr)
  rows <- unique(round(seq(1, d[1], length.out = min(d[1], max))))
  cols <- unique(round(seq(1, d[2], length.out = min(d[2], max))))
  arr <- arr[rows, cols, , drop = FALSE]
  ch <- dim(arr)[3]
  px <- matrix(arr, ncol = ch)
  switch(as.character(ch),
    "1" = cbind(px, px, px, 1),
    "2" = cbind(px[, 1], px[, 1], px[, 1], px[, 2]),
    "3" = cbind(px, 1),
    px[, 1:4]
  )
}

#' Dominant colours of an image
#'
#' Finds the most prominent *vivid* colours of an image, ignoring transparent
#' pixels, near-greys and very dark or very light areas. For character art
#' this tends to pick hair, eye and outfit colours rather than skin or the
#' background. Used by `accent = "auto"` and `theme = "auto"`.
#'
#' @param img Path to an image file.
#' @param n Maximum number of colours to return.
#' @return A character vector of hex colours, most prominent first (may be
#'   shorter than `n`, or empty for greyscale images).
#' @export
#' @examples
#' \dontrun{
#' image_colors("~/Pictures/miku.png")
#' }
image_colors <- function(img, n = 5) {
  img <- resolve_image(img)
  px <- read_pixels(img)
  px <- px[px[, 4] > 0.5, 1:3, drop = FALSE]
  if (!nrow(px)) {
    return(character())
  }
  luv <- matrix(grDevices::convertColor(px, from = "sRGB", to = "Luv"), ncol = 3)
  l <- luv[, 1]
  chroma <- sqrt(luv[, 2]^2 + luv[, 3]^2)
  hue <- (atan2(luv[, 3], luv[, 2]) * 180 / pi) %% 360
  keep <- chroma > 25 & l > 20 & l < 92
  if (!any(keep)) {
    return(character())
  }
  l <- l[keep]
  chroma <- chroma[keep]
  hue <- hue[keep]
  # Favour saturated pixels so skin tones and muddy shades lose out.
  w <- (chroma - 20)^2
  bins <- floor(hue / 15)
  score <- tapply(w, factor(bins, levels = 0:23), sum)
  score[is.na(score)] <- 0

  picked <- character()
  used <- numeric()
  for (b in order(score, decreasing = TRUE) - 1) {
    if (length(picked) >= n || score[b + 1] <= 0) break
    centre <- b * 15 + 7.5
    if (length(used) && any(abs(((centre - used) + 180) %% 360 - 180) < 30)) next
    inb <- bins == b
    hh <- atan2(sum(w[inb] * sin(hue[inb] * pi / 180)), sum(w[inb] * cos(hue[inb] * pi / 180))) * 180 / pi
    picked <- c(picked, hcl_hex(hh, stats::quantile(chroma[inb], 0.6, names = FALSE),
                                stats::median(l[inb])))
    used <- c(used, centre)
  }
  picked
}

auto_accent <- function(img) {
  if (is.null(img)) {
    stop("`accent = \"auto\"` needs an image.", call. = FALSE)
  }
  cols <- tryCatch(image_colors(img, 1), error = function(e) {
    message("Could not read colours from the image: ", conditionMessage(e))
    character()
  })
  if (!length(cols)) {
    message("No vivid colour found in the image; keeping the theme's own colours.")
    return(NULL)
  }
  cols[1]
}
