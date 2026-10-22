`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

# Markers that wrap everything rswallpaper appends to a base theme, so a
# generated theme can be used as a base again without stacking wallpapers.
MARK_BEGIN <- "/* rswallpaper:begin */"
MARK_END <- "/* rswallpaper:end */"

pkg_version <- function() {
  as.character(utils::packageVersion("rswallpaper"))
}

in_rstudio <- function() {
  rstudioapi::isAvailable("1.2")
}

require_rstudio <- function(what) {
  if (!in_rstudio()) {
    stop(what, " needs to run inside RStudio (>= 1.2).", call. = FALSE)
  }
}

# Internal RStudio helpers live in the "tools:rstudio" environment. They are
# only used to locate theme directories and fall back gracefully if missing.
rs_internal <- function(name) {
  if (!"tools:rstudio" %in% search()) {
    return(NULL)
  }
  get0(name, envir = as.environment("tools:rstudio"), inherits = FALSE)
}

check_string <- function(x, arg) {
  if (!is.character(x) || length(x) != 1 || is.na(x) || !nzchar(x)) {
    stop("`", arg, "` must be a single non-empty string.", call. = FALSE)
  }
  x
}

# Values are interpolated into CSS, so refuse anything that could close the
# declaration or the rule.
check_css_value <- function(x, arg) {
  check_string(x, arg)
  if (grepl("[;{}<>\\\\]", x)) {
    stop("`", arg, "` must be a plain CSS value without ';', '{', '}', '<' or '\\'.",
         call. = FALSE)
  }
  x
}

check_number <- function(x, arg, lower = -Inf, upper = Inf) {
  if (!is.numeric(x) || length(x) != 1 || is.na(x) || x < lower || x > upper) {
    stop("`", arg, "` must be a single number between ", lower, " and ", upper, ".",
         call. = FALSE)
  }
  x
}

check_theme_name <- function(name) {
  check_string(name, "name")
  if (grepl("[*\r\n]", name)) {
    stop("`name` cannot contain '*' or line breaks.", call. = FALSE)
  }
  trimws(name)
}

slugify <- function(x) {
  x <- gsub("[^A-Za-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  if (!nzchar(x)) "theme" else x
}

fmt_num <- function(x) {
  format(round(x, 3), scientific = FALSE, trim = TRUE)
}

# ---- persistent state -------------------------------------------------------

state_dir <- function() {
  getOption("rswallpaper.state_dir", tools::R_user_dir("rswallpaper", "config"))
}

read_state <- function(key) {
  f <- file.path(state_dir(), paste0(key, ".rds"))
  if (file.exists(f)) readRDS(f) else NULL
}

write_state <- function(key, value) {
  d <- state_dir()
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  saveRDS(value, file.path(d, paste0(key, ".rds")))
  invisible(value)
}
