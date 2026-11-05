# Source at the repo root, then call check_arcgis_cases() on a client initialized
# from a reviewed directory capture with default operation-id naming. This makes
# bounded live GET queries; ordinary package tests never call this function.
check_arcgis_cases <- function(
  root,
  capture_index = file.path(root, 'captures/directory.json'),
  output = NULL
) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  catalogue <- suppressWarnings(specmill::configure_apis(
    root,
    schemas = capture_index,
    review = FALSE
  ))
  package <- read.dcf(file.path(root, 'DESCRIPTION'))[1L, 'Package']
  prefix <- tolower(gsub('[^A-Za-z0-9]', '_', package))
  options <- stats::setNames(
    list(FALSE, list(timeout = 30, max_retries = 0L)),
    paste0(prefix, c('.dry_run', '.request'))
  )
  withr::local_options(options)
  env <- new.env(parent = baseenv())
  for (file in list.files(
    file.path(root, 'R'),
    pattern = '\\.R$',
    full.names = TRUE
  )) {
    sys.source(file, env)
  }
  rows <- list()
  for (i in seq_len(nrow(catalogue))) {
    capture <- jsonlite::read_json(file.path(root, catalogue$schema[[i]]))
    for (entry in capture$layers) {
      layer <- entry$document
      name <- paste0(catalogue$api[[i]], '_query_layer_', layer$id)
      oid <- layer$objectIdField
      if (is.null(oid)) {
        oid <- layer$objectIdFieldName
      }
      if (is.null(oid) || !nzchar(oid)) {
        oid <- Filter(
          function(field) field$type == 'esriFieldTypeOID',
          layer$fields
        )[[1L]]$name
      }
      paged <- isTRUE(layer$advancedQueryCapabilities$supportsPagination)
      args <- list(outFields = oid, returnGeometry = FALSE)
      if (paged) {
        args <- c(args, list(resultRecordCount = 2L, max_pages = 2L))
      } else {
        args$where <- paste0(oid, ' IN (1,2)')
      }
      outcome <- tryCatch(
        suppressWarnings(do.call(env[[name]], args)),
        error = identity
      )
      failed <- inherits(outcome, 'error')
      paging <- if (!failed) attr(outcome, 'pagination') else NULL
      rows[[length(rows) + 1L]] <- data.frame(
        service = capture$url,
        layer = layer$id,
        wrapper = name,
        paging_advertised = paged,
        status = if (failed) 'error' else 'passed',
        rows = if (failed) {
          NA_integer_
        } else if (paged) {
          length(outcome)
        } else {
          length(outcome$features)
        },
        requests = if (failed) {
          NA_integer_
        } else if (is.null(paging$requests)) {
          1L
        } else {
          paging$requests
        },
        stop_reason = if (is.null(paging$stop_reason)) {
          'single_request'
        } else {
          paging$stop_reason
        },
        reason = if (failed) conditionMessage(outcome) else '',
        stringsAsFactors = FALSE
      )
    }
  }
  result <- do.call(rbind, rows)
  if (!is.null(output)) {
    utils::write.csv(result, output, row.names = FALSE)
  }
  if (
    !all(result$status == 'passed') ||
      !all(result$requests <= 2L) ||
      !all(result$rows <= 4L)
  ) {
    stop('ArcGIS live case validation failed; inspect the result CSV')
  }
  cli::cli_alert_success(
    '{nrow(result)} ArcGIS layer/table queries passed in {sum(result$requests)} bounded GET requests'
  )
  invisible(result)
}
