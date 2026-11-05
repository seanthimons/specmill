# Generic compatibility helpers. Native readers live in importer_openapi.R.

sanitize_name <- function(x) {
  x <- stringr::str_replace_all(x, "[^A-Za-z0-9_]", "_")
  x <- stringr::str_replace_all(x, "_+", "_")
  x <- stringr::str_trim(x)
  x
}


method_path_name <- function(route, method) {
  p <- gsub("^/|/$", "", route)
  p <- gsub("\\{([^}]+)\\}", "by_\\1", p)
  p <- gsub("[^A-Za-z0-9]+", "_", p)
  p <- gsub("_+", "_", p)
  tolower(paste0(method, "_", p))
}


order_path_by_route <- function(path_names, route) {
  if (!length(path_names)) {
    return(character(0))
  }
  m <- stringr::str_match_all(route, "\\{([^}]+)\\}")
  if (length(m) >= 1 && length(m[[1]]) && nrow(m[[1]]) > 0) {
    unique(m[[1]][, 2])
  } else {
    unique(path_names)
  }
}


detect_pagination <- function(
  route,
  path_params,
  query_params,
  body_params,
  registry = PAGINATION_REGISTRY
) {
  # Split comma-separated param strings into character vectors
  split_params <- function(x) {
    if (is.null(x) || !nzchar(x)) {
      return(character(0))
    }
    trimws(strsplit(x, ",")[[1]])
  }

  path_vec <- split_params(path_params)
  query_vec <- split_params(query_params)
  body_vec <- split_params(body_params)

  for (entry_name in names(registry)) {
    entry <- registry[[entry_name]]

    # If route_pattern is specified, check route first
    if (!is.null(entry$route_pattern)) {
      if (!stringr::str_detect(route, entry$route_pattern)) {
        next
      }
    }

    # AMOS keyset cursors are query parameters for GET and body fields for POST.
    if (identical(entry$strategy, "cursor")) {
      cursor_location <- if ("cursor" %in% query_vec) {
        "query"
      } else if ("cursor" %in% body_vec) {
        "body"
      } else {
        NA_character_
      }
      if ("limit" %in% path_vec && !is.na(cursor_location)) {
        return(list(
          strategy = entry$strategy,
          registry_key = entry_name,
          params = entry$param_names,
          param_location = entry$param_location,
          cursor_location = cursor_location,
          description = entry$description
        ))
      }
      next
    }

    # Match based on param_location
    location <- entry$param_location
    matched <- FALSE

    if (identical(location, "path")) {
      matched <- all(entry$param_names %in% path_vec)
    } else if (identical(location, "query")) {
      matched <- all(entry$param_names %in% query_vec)
    } else if (identical(location, "body")) {
      matched <- all(entry$param_names %in% body_vec)
    }

    if (matched) {
      return(list(
        strategy = entry$strategy,
        registry_key = entry_name,
        params = entry$param_names,
        param_location = entry$param_location,
        cursor_location = NA_character_,
        description = entry$description
      ))
    }
  }

  # No match found - check if params resemble pagination
  pagination_like_params <- c(
    "page",
    "pageNumber",
    "pageSize",
    "offset",
    "limit",
    "size",
    "cursor",
    "itemsPerPage",
    "skip",
    "top",
    "after",
    "before",
    "startIndex",
    "count"
  )

  all_params <- c(path_vec, query_vec, body_vec)
  suspicious <- intersect(all_params, pagination_like_params)

  if (length(suspicious) > 0) {
    cli::cli_warn(c(
      "Parameters resemble pagination but no registry pattern matched.",
      "i" = "Route: {.val {route}}",
      "i" = "Suspicious params: {.val {suspicious}}",
      "i" = "Consider adding a new entry to PAGINATION_REGISTRY in 00_config.R"
    ))
  }

  list(
    strategy = "none",
    registry_key = NA_character_,
    params = character(0),
    param_location = NA_character_,
    cursor_location = NA_character_,
    description = "No pagination detected"
  )
}
