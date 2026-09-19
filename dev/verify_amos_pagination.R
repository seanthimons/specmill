# Opt-in live reads only. Never runs as part of package tests.
# Rscript dev/verify_amos_pagination.R [development|staging] [output-directory]
verify_amos_pagination <- function(
  environment = 'development',
  output = 'dev/audits/pagination'
) {
  origins <- c(
    development = 'https://cim-dev.sciencedataexperts.com',
    staging = 'https://cim.sciencedataexperts.com'
  )
  stopifnot(length(environment) == 1L, environment %in% names(origins))
  origin <- unname(origins[[environment]])
  schema_url <- paste0(origin, '/api/amos/swagger.json')
  response <- httr2::req_perform(httr2::req_timeout(
    httr2::request(schema_url),
    20
  ))
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(schema))
  writeBin(httr2::resp_body_raw(response), schema)
  document <- jsonlite::read_json(schema)
  path <- '/api/amos/method_keyset_pagination/{limit}'
  stopifnot(all(c('get', 'post') %in% names(document$paths[[path]])))
  parsed <- specmill::read_operations(schema)
  runtime <- new.env(parent = baseenv())
  template <- paste(
    readLines(system.file('templates/request.R', package = 'specmill')),
    collapse = '\n'
  )
  template <- gsub('BASE_URL', deparse(origin), template, fixed = TRUE)
  template <- gsub(
    'DRY_RUN_ENV',
    deparse('SPECMILL_AMOS_VALIDATION_DRY_RUN'),
    template,
    fixed = TRUE
  )
  eval(parse(text = template), runtime)
  for (method in c('GET', 'POST')) {
    operations <- Filter(
      function(x) identical(x$path, path) && identical(x$method, method),
      parsed$operations
    )
    stopifnot(length(operations) == 1L)
    operation <- operations[[1L]]
    operation$name <- if (method == 'GET') 'amos_page' else 'amos_filtered'
    operation$server <- list(url = origin)
    operation$request_controls <- list(timeout = 20, max_retries = 0)
    eval(
      parse(
        text = specmill::render_operation(
          operation,
          list(helper = 'api_request')
        )
      ),
      runtime
    )
  }
  get_page <- runtime$amos_page
  single <- get_page(limit = 2)
  stopifnot(
    is.list(single$results),
    length(single$results) == 2,
    isTRUE(single$pagination$hasNext),
    is.character(single$pagination$nextCursor)
  )
  next_cursor <- function(x) {
    stopifnot(
      is.logical(x$pagination$hasNext),
      length(x$pagination$hasNext) == 1L
    )
    if (isTRUE(x$pagination$hasNext)) {
      stopifnot(
        is.character(x$pagination$nextCursor),
        nzchar(x$pagination$nextCursor)
      )
      x$pagination$nextCursor
    } else {
      NULL
    }
  }
  result <- specmill::paginated(
    get_page,
    mode = 'cursor',
    parameter = 'cursor',
    size_parameter = 'limit',
    page_size = 2,
    items = function(x) x$results,
    next_cursor = next_cursor,
    max_pages = 3,
    max_items = 5
  )
  records <- do.call(c, result$pages)
  ids <- vapply(records, function(x) x$internal_id, '')
  stopifnot(
    result$requests == 3,
    result$item_count == 5,
    result$stop_reason == 'max_items',
    !anyDuplicated(ids),
    identical(runtime$amos_page, get_page)
  )
  # POST is a documented read-only filter. Fix one observed ID to exercise natural completion.
  filtered <- function(cursor, limit) {
    runtime$amos_filtered(
      limit = limit,
      body = list(
        cursor = if (is.null(cursor)) '' else cursor,
        filters = list(
          internal_id = list(
            filterType = 'text',
            type = 'equals',
            filter = ids[[1L]]
          )
        ),
        include_total = FALSE
      )
    )
  }
  completed <- specmill::paginated(
    filtered,
    mode = 'cursor',
    parameter = 'cursor',
    size_parameter = 'limit',
    page_size = 2,
    items = function(x) x$results,
    next_cursor = next_cursor,
    max_pages = 2,
    max_items = 4
  )
  stopifnot(
    completed$requests == 1,
    completed$item_count == 1,
    completed$stop_reason == 'no_next_cursor',
    identical(completed$pages[[1L]][[1L]]$internal_id, ids[[1L]])
  )
  report <- list(
    environment = environment,
    origin = origin,
    checked_at = format(Sys.time(), tz = 'UTC', usetz = TRUE),
    schema_url = schema_url,
    schema_sha256 = digest::digest(file = schema, algo = 'sha256'),
    endpoint = path,
    response_fields = names(single),
    pagination_fields = names(single$pagination),
    single_request_items = length(single$results),
    bounded_get = result[c('requests', 'item_count', 'stop_reason')],
    filtered_post = completed[c('requests', 'item_count', 'stop_reason')],
    unique_ids = length(unique(ids)),
    note = 'Generated GET and filtered read-only POST wrappers. No credentials, no production requests. AMOS validates cursor mode; next-link behavior is covered by localhost tests.'
  )
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(
    report,
    file.path(output, paste0('amos-', environment, '.json')),
    auto_unbox = TRUE,
    pretty = TRUE
  )
  cat(
    environment,
    ': generated AMOS wrappers, bounded cursor traversal and filtered completion passed.\n'
  )
  invisible(report)
}
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  verify_amos_pagination(
    if (length(args)) args[[1L]] else 'development',
    if (length(args) > 1L) args[[2L]] else 'dev/audits/pagination'
  )
}
