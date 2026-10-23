# rswallpaper

<!-- badges: start -->
[![R-CMD-check](https://github.com/Acidic3131/rswallpaper/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Acidic3131/rswallpaper/actions/workflows/R-CMD-check.yaml)
![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
<!-- badges: end -->

**自定义 RStudio 的主题颜色和编辑区半透明立绘**

[English README](README_en.md)

| 浅色：Matcha 配色 + 立绘 | 深色：自定义灰绿 + 藤紫配色 + 立绘 |
|---|---|
| ![](man/figures/hero-light.png) | ![](man/figures/hero-dark.png) |

> demo中用到的角色是 [小樽潮風高校Project](https://tokyo6.tokyo/) 的花隈千冬（© TOKYO6 ENTERTAINMENT），该免费公开立绘作为demo底图收录在 `inst/extdata/hanakuma_chifuyu.png`

## 功能

- **编辑区立绘背景**：支持 PNG / JPG / WebP / GIF / SVG，可以调透明度、大小、位置、渐隐方向和 CSS 滤镜（模糊、饱和度等）。
- **两种叠放模式**：`overlay` 把图盖在代码上；`behind` 把图垫在文字下面，代码更清晰，可以用更高的透明度。
- **整体主题色**：一个强调色同时改光标、选区、当前行、标签页、面板菜单、工具栏和滚动条；`accent = "auto"` 直接从立绘取色。
- **10 套内置配色**，也可以用一个颜色生成整套配色（`rs_palette()`），或者让立绘自动生成配色（`theme = "auto"`）。所有代码颜色都保证 WCAG 4.5:1 对比度。
- **可以叠在任何主题上**：已安装的 [rsthemes](https://github.com/gadenbuie/rsthemes)、[rstudiothemes](https://github.com/dieghernan/rstudiothemes)、RStudio 自带主题，或者 `.rstheme` / `.tmTheme` 文件。
- **Wallpaper Studio**：可视化面板。
- **随机换图**：给一个底图文件夹，每次打开 RStudio 自动换一张。

## 安装

```r
# install.packages("remotes")
remotes::install_github("Acidic3131/rswallpaper")
library(rswallpaper)

# 推荐一起装：自动压缩大图 / 从图片取色 / 可视化面板
install.packages(c("magick", "shiny", "miniUI"))
```

需要 RStudio ≥ 1.2（建议用较新版本）和 R ≥ 4.0。

> 安装或重装后 RStudio 会重启 R，之后要重新运行 `library(rswallpaper)`，否则会报 `could not find function "wallpaper_studio"`。
> 也可以不加载，直接用 `rswallpaper::wallpaper_studio()`，或者从 **Addins** 菜单打开 *Wallpaper Studio*。

## 快速开始

```r
library(rswallpaper)

# 0. 用自带的demo立绘试试效果
demo <- system.file("extdata", "hanakuma_chifuyu.png", package = "rswallpaper")
set_wallpaper(demo, theme = "matcha", mode = "behind", opacity = 0.45, tint = 0.6)

# 1. 在当前主题上放一张立绘
set_wallpaper("~/Pictures/chifuyo.png")

# 2. 指定底层主题、强调色和叠放方式
set_wallpaper(
  "~/Pictures/chifuyo.png",
  theme   = "OKSolar Light",   # 任意已安装主题，见 list_themes()
  accent  = "#7AA2F7",         # 或 "auto"：从立绘取色
  mode    = "behind",          # 图垫在文字下面
  opacity = 0.3,
  fade    = "left"             # 立绘靠右，往左渐隐，左边写代码的区域保持干净
)

# 3. 用立绘的颜色生成整套深色主题
set_wallpaper("~/Pictures/chifuyo.png", theme = "auto-dark")

# 4. 只换颜色
set_wallpaper(theme = "sakura")

# 撤回所有改变，回到原来的主题
restore_theme()
```

也可以直接打开可视化面板：

```r
wallpaper_studio()
```

![Wallpaper Studio](man/figures/studio.png)

选 *Custom* 强调色时，除了取色器还有分组色卡：从立绘里提取的颜色 / 10 套内置配色的主色 / 和色 / Muted / Jewel / Pastel。鼠标悬停可以看到颜色名和色值。

## 参数一览

| 参数 | 作用 | 默认值 |
|---|---|---|
| `img` | 图片路径、**文件夹**（随机挑一张）、URL，或 `NULL`（不放图） | `NULL` |
| `theme` | 底层主题：当前主题 / 已安装主题名 / 内置配色名 / `"auto"` / `"auto-dark"` / 文件路径 / `rs_palette()` | 当前主题 |
| `accent` | 强调色，`"auto"` 从图片取色，`NULL` 保持原主题 | `NULL` |
| `opacity` | 图片不透明度 0–1 | overlay 0.18，behind 0.28 |
| `position` | CSS `background-position`，如 `"right bottom"`、`"center"`、`"right 24px bottom 0"` | `"right bottom"` |
| `size` | 0–1 的数字表示占编辑区高度的比例；或 `"contain"`、`"cover"`、`"auto 60%"` | `0.75` |
| `mode` | `"overlay"`（盖在代码上）/ `"behind"`（垫在文字下） | `"overlay"` |
| `fade` | 往哪个方向渐隐：`"none"`、`"left"`、`"right"`、`"top"`、`"bottom"` | `"none"` |
| `filter` | CSS 滤镜，如 `"blur(1px) saturate(1.2)"` | `NULL` |
| `target` | `"source"` 只在源码编辑器显示；`"any"` 所有代码编辑器（除 Console） | `"source"` |
| `tint` | 强调色对标签页、工具栏等界面的染色强度 0–1 | `0.35` |
| `name` | 主题名，同名再次运行会直接替换 | `"<底层主题> + Wallpaper"` |
| `max_px` | 超过这个像素的图会被缩小并转成 WebP 再嵌入（需要 magick） | `1600` |

## 每次打开 RStudio 随机换一张

先用一个文件夹设置一次：

```r
set_wallpaper("~/Pictures/rstudio-wallpapers/", theme = "yozora", mode = "behind", fade = "left")
```

然后在 `~/.Rprofile`（可以用 `usethis::edit_r_profile()` 打开）里加上：

```r
setHook("rstudio.sessionInit", function(newSession) {
  if (newSession) rswallpaper::shuffle_wallpaper()
}, action = "append")
```

手动换下一张：`shuffle_wallpaper()`，或 Addins → *Shuffle wallpaper*。

## 预览、导出和管理

```r
preview_theme("~/Pictures/chifuyo.png", theme = "sakura")   # 在 Viewer/浏览器里看效果，不改 IDE
build_theme("~/Pictures/chifuyo.png", theme = "sakura",
            file = "sakura-chifuyo.rstheme")                 # 只导出 .rstheme，可以分享
image_colors("~/Pictures/chifuyo.png")                       # 查看立绘的主色
list_themes()                                                # 所有可用的底层主题
list_wallpapers()                                            # rswallpaper 生成过的主题
remove_wallpapers()                                          # 全部删掉
restore_theme(remove = TRUE)                                 # 还原并清理
```

## 原理

RStudio 的主题（`.rstheme`）本质上是一份 CSS。rswallpaper 读取底层主题，在末尾追加一段带标记的 CSS：

- 立绘以 base64 data URI 嵌进主题文件，所以不依赖外部文件路径；
- `overlay` 模式用源码编辑器（`#rstudio_source_text_editor`）上的 `::after` 伪元素铺一层半透明图片，`pointer-events: none` 保证鼠标照常点击；
- `behind` 模式把图片放在 Ace 编辑器的 `.ace_scroller::before` 上，位于背景色之上、文字层之下，并把当前行等不透明色块改成半透明；
- 强调色复用 RStudio 主题文件里面向界面的选择器（`rstheme_tabLayoutCenter`、`rstheme_toolbarWrapper` 等）给界面染色。

![overlay vs behind](man/figures/modes.png)

*左：overlay，图片盖在代码上；右：behind，代码在图片上方保持清晰（真实 Ace 编辑器渲染）。*

追加的 CSS 包在 `/* rswallpaper:begin */ … /* rswallpaper:end */` 之间，所以拿生成的主题当底层再生成一次也不会叠出两张图。

## 相关项目

- [rsthemes](https://github.com/gadenbuie/rsthemes)
- [rstudiothemes](https://github.com/dieghernan/rstudiothemes)
- [rscodeio](https://github.com/anthonynorth/rscodeio)
- [tmTheme Editor](https://tmtheme-editor.linuxbox.ninja/)

## 开发

```r
devtools::test()             # 单元测试
devtools::check()            # R CMD check
source("data-raw/figures.R") # 重新生成 README 截图（需要 Chrome + magick）
```

## 许可

代码以 MIT 许可发布 © rswallpaper authors。

demo立绘 `inst/extdata/hanakuma_chifuyu.png` 是 [小樽潮風高校Project](https://tokyo6.tokyo/) 角色花隈千冬的免费公开立绘，著作权归合同会社 TOKYO6 ENTERTAINMENT 所有（© TOKYO6 ENTERTAINMENT），**不在 MIT 许可范围内**。收录时只裁掉了透明边缘。使用须遵守 [キャラクター使用ガイドライン](https://tokyo6.tokyo/guidelines/)：个人、同人社团的非商用使用可以；法人使用或商用须另行取得许可；禁止用于政治、歧视、攻击特定个人或团体等用途，以及严重损害角色形象的用途。详见 `inst/extdata/CREDITS`。
