# rswallpaper 0.1.0

* First release.
* `set_wallpaper()` / `build_theme()`: semi-transparent image in the source
  editor on top of any RStudio theme, in `"overlay"` or `"behind"` mode, with
  position, size, fade and CSS filter options.
* Accent colours re-tint the cursor, selection, tabs, menus, toolbars and
  scrollbars; `accent = "auto"` takes the colour from the image.
* Ten preset palettes (`palettes()`), custom palettes (`rs_palette()`) and
  palettes generated from an image (`theme = "auto"`, `palette_from_image()`).
* `wallpaper_studio()` gadget with live preview, curated accent swatches
  (image colours, palettes, Japanese traditional colours, muted, jewel and
  pastel tones), plus addins.
* Hand-made wallpapers already embedded in a base theme are removed
  automatically, so images never stack.
* `preview_theme()`, `shuffle_wallpaper()`, `restore_theme()`,
  `list_themes()`, `list_wallpapers()`, `remove_wallpapers()`.
