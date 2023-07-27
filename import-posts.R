#' Import a Jekyll blog post
#' @param url_raw the full url to a raw .Rmd file
#' @param overwrite whether to overwrite an existing `index.qmd` file. Defaults
#'   to `FALSE`. When migrating a post, we may need to hand-fix some issues in
#'   the `index.qmd`. We don't want to overwrite these changes on accident.
#' @return a list containing the contents of the original post, the modified
#'   post, and metadata about the post.
import_jekyll_post <- function(url_raw, overwrite = FALSE) {
  file <- file.path(tempdir(), basename(url_raw))
  download_result <- download.file(url_raw, file, quiet = TRUE)

  data_file <- read_post_data(file)

  if (dir.exists(data_file$path_post_dir)) {
    cli::cli_alert_info(
      "Post folder already exists {.path {data_file$path_post_dir}}"
    )
  } else {
    dir.create(data_file$path_post_dir, showWarnings = FALSE)
    cli::cli_alert_success(
      "Post folder created {.path {data_file$path_post_dir}}"
    )
  }

  data_file <- data_file |>
    migrate_yaml_data() |>
    patch_body_lines() |>
    migrate_assets()

  data_file$lines_migrated <- c(
    "---",
    convert_list_to_yaml_lines(data_file$data_yaml_migrated),
    "---",
    data_file$lines_body
  )

  if (!overwrite & file.exists(data_file$path_post)) {
    cli::cli_warn(c(
      "!" = "Post file already exists {.path {data_file$path_post}}",
      "*" = "Set {.arg  overwrite = TRUE} to replace files"
    ))
  } else {
    brio::write_lines(data_file$lines_migrated, data_file$path_post)
    cli::cli_alert_success("Post file created {.path {data_file$path_post}}")
  }

  if (overwrite) {
    knitr::convert_chunk_header(
      input = data_file$path_post,
      output = identity,
      type = "yaml",
      width = 60
    )
    cli::cli_alert_success(
      "Converted in-header chunk options to in-body options"
    )
  }


  data_file$lines_current <- brio::read_lines(data_file$path_post)
  invisible(data_file)
}

#' @param file path to a file to read in
read_post_data <- function(file) {
  # Check the file for a weird number of YAML delimiters
  lines <- brio::read_lines(file)
  lines_yaml <- lines |>
    stringr::str_which("^[.-]{3}$")

  if (length(lines_yaml) > 2) {
    msg <- glue::glue(
      "More than 2 YAML delimiters found in {basename(file)}
      Lines: `{deparse(dput(lines_yaml))}`"
    )
    warning(msg)
  }

  if (length(lines_yaml) < 2) {
    msg <- glue::glue(
      "Less than YAML delimiters found in {basename(file)}
      Lines: `{deparse(dput(lines_yaml))}`"
    )
    stop(msg)
  }

  lines_body <-  lines[-seq(lines_yaml[1], lines_yaml[2])]

  # Let RMarkdown read the YAML metadata for us.
  # (This does not handle general case where there is more than
  # one yaml block in a file.)
  data_yaml <- rmarkdown::yaml_front_matter(file)

  tibble::lst(
    basename = basename(file),
    date = basename |>
      stringr::str_extract("\\d{4}-\\d{1,2}-\\d{1,2}"),
    slug = basename |>
      stringr::str_remove("\\d{4}-\\d{1,2}-\\d{1,2}-") |>
      stringr::str_remove("[.](Rmd|md|rmd)$"),
    lines = lines,
    lines_body = lines_body,
    data_yaml = data_yaml,
    path_post_dir = file.path("posts", tools::file_path_sans_ext(basename)),
    path_post = file.path(path_post_dir, "index.qmd")
  )
}


migrate_yaml_data <- function(data_file) {
  # New fields
  d <- data_file$data_yaml
  d$date <- data_file$date
  d$`date-modified` <- "`r format(Sys.Date())`"

  # Renamed fields
  d$description <- d$excerpt
  d$categories <- d$tags
  d$image_header <- d$header
  d$excerpt <- NULL
  d$categories <- NULL
  d$header <- NULL

  d$aliases <- list(paste0("/", data_file$slug, "/"))
  data_file$data_yaml_migrated <- d
  data_file
}

convert_list_to_yaml_lines <- function(data) {
  file_yaml <- tempfile(fileext = ".yaml")
  yaml::write_yaml(data, file_yaml)
  brio::read_lines(file_yaml)
}

# Miscellaneous fixes
patch_body_lines <- function(data_file) {
  l <- data_file$lines_body

  # Replace old footer stuff
  ind_footer_child <- l |>
    stringr::str_which("child = \"_R/_footer.Rmd\"")

  if (length(ind_footer_child) == 0) {
    cli::cli_warn(c(
      "Could not find {.code child = \"_R/_footer.Rmd\"} chunk to replace.",
      "*" = "Manually remove existing footer in file."
    ))

    data_file$lines_body <- c(l, "", c("{{< include ../_footer.Rmd >}}", ""))
    return(data_file)
  }

  l[c(ind_footer_child, ind_footer_child + 1)] <-
    c("{{< include ../_footer.Rmd >}}", "")

  ind_parent_doc <- l |>
    stringr::str_which(".parent_doc <- knitr::current_input()")

  l <- l[-c(ind_parent_doc + c(-1, 0, 1))]

  data_file$lines_body <- l
  data_file
}



migrate_assets <- function(data_file, base_url = "https://raw.githubusercontent.com/tjmahr/tjmahr.github.io/master/") {
  asset_paths <- data_file$lines |>
    stringr::str_subset("/?assets/images/.*(jpeg|jpg|png|gif)") |>
    stringr::str_extract("/?assets/images/.*(jpeg|jpg|png|gif)")

  to_dl <- file.path(base_url, asset_paths)
  for (url in to_dl) {
    destfile <- file.path(data_file$path_post_dir, basename(url))
    result <- curl::curl_download(url, destfile, quiet = TRUE)
    if (file.exists(result)) {
      cli::cli_alert_success("Migrated {.var {basename(destfile)}}")
    }
  }

  if (!is.null(data_file$data_yaml_migrated$..header$overlay_image)) {
    data_file$data_yaml_migrated$..header$overlay_image <-
      basename(data_file$data_yaml_migrated$..header$overlay_image)
  }

  data_file$lines_body <- data_file$lines_body |>
    stringr::str_replace("/?assets/images/(.*)(jpeg|jpg|png|gif)", "\\1\\2")
  data_file
}


check_post <- function(lines) {
  create_regex_checker <- function(pattern, message, tip = character(0)) {
    function(xs) {
      pattern_main <- pattern
      pattern_preview <- paste0(".{0,30}(", pattern_main, ").{0,30}")
      lines_flagged <- stringr::str_which(xs, pattern_main)
      any_found <- length(lines_flagged) > 0
      if (any_found) {
        previews <- xs[lines_flagged] |>
          stringr::str_extract(pattern_preview)
        l <- glue::glue(
          "[<<<lines_flagged>>>] <<<previews>>>",
          .open = "<<<",
          .close = ">>>"
        )
        cli::cli_warn(c(
          message,
          cli::format_bullets_raw(l),
          tip
        ))
      }
      invisible(any_found)
    }
  }

  check_jekyll <- create_regex_checker(
    "\\{%|\\{:",
    "Jekyll macro syntax found:"
  )
  check_assets <- create_regex_checker(
    "assets/",
    "`/assets/` paths found:"
  )
  check_codelinks <- create_regex_checker(
    "\\[`\\w+",
    "Manually linked code found:"
  )
  check_github_emoji <- create_regex_checker(
    "(\\b|\\s):\\w+:(\\b|\\s)",
    "GitHub emoji found",
    tip = c("i" = "Cheatsheet: {.url https://github.com/ikatyang/emoji-cheat-sheet/blob/master/README.md}")
  )
  check_emo_ji <- create_regex_checker(
    "`r emo::ji",
    "`emo::ji()` found:"
  )
  check_magrittr <- create_regex_checker(
    "(library.magrittr.)|(%>%)",
    "`emo::ji()` found:"
  )

  result <- any(
    check_assets(lines),
    check_jekyll(lines),
    check_codelinks(lines),
    check_github_emoji(lines),
    check_emo_ji(lines)
  )
  invisible(result)
}




slugs <- fs::path_home_r() |>
  fs::path("GitRepos/tjmahr.github.io/_R") |>
  fs::dir_ls(regexp = "\\d{4}") |>
  basename()

urls <- file.path("https://raw.githubusercontent.com/tjmahr/tjmahr.github.io/master/_R", slugs)

url_raw <- sample(urls, size = 1)
d <- import_jekyll_post(url_raw)
check_post(d$lines_current)




url_raw <- "https://raw.githubusercontent.com/tjmahr/tjmahr.github.io/master/_R/2016-08-15-recent-adventures-with-lazyeval.Rmd"
d <- import_jekyll_post(url_raw)
check_post(d$lines_current)
url_raw <- "https://raw.githubusercontent.com/tjmahr/tjmahr.github.io/master/_R/2015-10-06-confusion-matrix-late-talkers.Rmd"
d <- import_jekyll_post(url_raw)
check_post(d$lines_current)
url_raw <- "https://raw.githubusercontent.com/tjmahr/tjmahr.github.io/master/_R/2017-08-15-set-na-where-nonstandard-evaluation-use-case.Rmd"
d <- import_jekyll_post(url_raw)
check_post(d$lines_current)



d <- import_jekyll_post(url_raw)
check_post(d$lines_current)
# usethis::edit_file(d$path_post)



current_posts <- fs::dir_ls("posts", glob = "*index.qmd", recurse = TRUE)


for (post in current_posts) {
  withr::with_options(list(warn = 1), {
    cli::cli_inform("{.strong {post}}")
    check_post(brio::read_lines(post))
  })

}

d$data_yaml
d$data_yaml_migrated
d$lines_migrated |> head(20)
