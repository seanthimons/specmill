# ==============================================================================
# Path Manipulation
# ==============================================================================

#' Strip curly parameter placeholders from endpoint paths
#'
#' This utility removes `{}` parameter tokens from endpoint strings and optionally
#' normalises leading and trailing slashes.
#' @param paths Character vector of endpoint paths that may contain tokens such as `{id}`.
#' @param keep_trailing_slash Logical; if FALSE the trailing slash is removed.
#' @param leading_slash Character, one of "keep", "ensure", "remove" to control the leading slash.
#' @return A character vector of cleaned endpoint paths.
#' @examples
#' strip_curly_params(c("/hazard/{id}/"))
#' @export
strip_curly_params <- function(
  paths,
  keep_trailing_slash = TRUE,
  leading_slash = c("keep", "ensure", "remove")
) {
  leading_slash <- match.arg(leading_slash)

  # 1) Remove {param} tokens
  out <- stringr::str_replace_all(paths, "\\{[^}]+\\}", "")

  # 2) Collapse duplicate slashes
  out <- stringr::str_replace_all(out, "/{2,}", "/")

  # 3) Trailing slash handling
  if (!keep_trailing_slash) {
    out <- stringr::str_remove(out, "/$")
  }

  # 4) Leading slash handling
  if (leading_slash == "ensure") {
    out <- ifelse(stringr::str_starts(out, "/"), out, paste0("/", out))
  } else if (leading_slash == "remove") {
    # Remove any leading slash(es)
    out <- stringr::str_remove(out, "^/+")
  } # "keep" leaves as-is

  out
}

# The tar portability gate counts the package prefix as well as the filename.
portable_output_path <- function(root, file) {
  description <- file.path(root, 'DESCRIPTION')
  package <- if (file.exists(description)) {
    unname(read.dcf(description)[1L, 'Package'])
  } else basename(root)
  budget <- min(100L, 100L - nchar(paste0(package, '/', dirname(file), '/'), type = 'bytes'))
  component <- basename(file)
  if (nchar(component, type = 'bytes') <= budget) return(file)
  extension <- paste0('.', tools::file_ext(component))
  suffix <- paste0('_', substr(text_hash(file), 1L, 16L), extension)
  prefix_budget <- budget - nchar(suffix, type = 'bytes')
  if (prefix_budget < 1L) {
    stop('Package name leaves no portable output filename space; use a shorter package name')
  }
  prefix <- tools::file_path_sans_ext(component)
  while (nchar(prefix, type = 'bytes') > prefix_budget) {
    prefix <- substr(prefix, 1L, nchar(prefix) - 1L)
  }
  paste0(dirname(file), '/', prefix, suffix)
}
