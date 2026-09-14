# Exercise three generated ComptoxR workflows through their real HTTP helper.
verify_comptoxr_acceptance <- function(
  comptox_root = 'C:/Users/sxthi/Documents/ComptoxR',
  output = 'dev/audits/comptoxr-acceptance'
) {
  stopifnot(
    dir.exists(comptox_root),
    requireNamespace('pkgload', quietly = TRUE),
    requireNamespace('testthat', quietly = TRUE)
  )
  pkgload::load_all(comptox_root, quiet = TRUE, export_all = FALSE)
  fixture_file <- file.path(
    comptox_root,
    'tests/testthat/fixtures/apipak/ctx.rds'
  )
  contracts <- readRDS(fixture_file)
  workflows <- c(
    'ct_chemical_detail_search',
    'ct_chemical_detail_search_bulk',
    'ct_hazard_toxval_search'
  )
  contracts <- contracts[workflows]
  stopifnot(
    !any(vapply(contracts, is.null, logical(1))),
    all(vapply(contracts, function(x) length(x$calls) == 1L, logical(1))),
    all(vapply(
      contracts,
      function(x) identical(x$calls[[1L]]$helper, 'generic_request'),
      logical(1)
    ))
  )
  for (file in paste0('test-contract-', workflows, '.R')) {
    testthat::test_file(
      file.path(comptox_root, 'tests/testthat', file),
      reporter = 'stop'
    )
  }

  port_file <- tempfile('comptoxr-port-')
  request_file <- tempfile('comptoxr-request-')
  on.exit(unlink(c(port_file, request_file)), add = TRUE)
  records <- lapply(contracts, function(x) {
    lapply(seq_len(nrow(x$result)), function(i) lapply(x$result, `[[`, i))
  })
  responses <- vapply(
    records,
    jsonlite::toJSON,
    character(1),
    auto_unbox = TRUE,
    null = 'null'
  )
  expected_results <- lapply(
    records,
    getFromNamespace('safe_tidy_bind', 'ComptoxR')
  )
  server <- callr::r_bg(
    function(port_file, request_file, responses) {
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(request) {
          path <- request$PATH_INFO
          workflow <- if (grepl('/chemical/', path)) {
            if (request$REQUEST_METHOD == 'POST') {
              'ct_chemical_detail_search_bulk'
            } else {
              'ct_chemical_detail_search'
            }
          } else {
            'ct_hazard_toxval_search'
          }
          saveRDS(
            list(
              method = request$REQUEST_METHOD,
              path = path,
              query = request$QUERY_STRING,
              key = request$HTTP_X_API_KEY,
              content_type = request$CONTENT_TYPE,
              body = rawToChar(request$rook.input$read())
            ),
            request_file
          )
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = responses[[workflow]]
          )
        })
      )
      on.exit(server$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    args = list(port_file, request_file, responses),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  deadline <- Sys.time() + 20
  while (
    !file.exists(port_file) && server$is_alive() && Sys.time() < deadline
  ) {
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))
  withr::local_options(list(
    ComptoxR.ctx_burl = paste0(
      'http://127.0.0.1:',
      readLines(port_file),
      '/ctx-api/'
    )
  ))
  withr::local_envvar(c(ctx_api_key = 'fixture-only-key', batch_limit = '200'))

  observed <- lapply(workflows, function(name) {
    contract <- contracts[[name]]
    result <- do.call(getExportedValue('ComptoxR', name), contract$inputs)
    request <- readRDS(request_file)
    stopifnot(identical(result, expected_results[[name]]))
    c(list(workflow = name), request)
  })
  names(observed) <- workflows
  expected <- list(
    ct_chemical_detail_search = list(
      method = 'GET',
      path = '/ctx-api/chemical/detail/search/by-dtxsid/DTXSID7020182',
      query = '?projection=chemicaldetailall',
      content_type = NULL,
      body = ''
    ),
    ct_chemical_detail_search_bulk = list(
      method = 'POST',
      path = '/ctx-api/chemical/detail/search/by-dtxsid/',
      query = '?projection=chemicaldetailall',
      content_type = 'application/json',
      body = '["DTXSID7020182"]'
    ),
    ct_hazard_toxval_search = list(
      method = 'GET',
      path = '/ctx-api/hazard/toxval/search/by-dtxsid/DTXSID7020182',
      query = '',
      content_type = NULL,
      body = ''
    )
  )
  for (name in workflows) {
    stopifnot(
      identical(observed[[name]][names(expected[[name]])], expected[[name]]),
      identical(observed[[name]]$key, 'fixture-only-key')
    )
  }

  amos_paths <- c(
    '/api/amos/retrieve_fact_sheets/',
    '/api/amos/retrieve_product_declarations/',
    '/api/amos/retrieve_safety_data_sheets/',
    '/api/amos/search_for_document_ids/{record_type}'
  )
  blockers <- read.csv('dev/audits/source-contracts/active/operations.csv')
  blockers <- blockers[
    blockers$api == 'amos' & blockers$path %in% amos_paths,
  ]
  stopifnot(
    setequal(blockers$path, amos_paths),
    all(blockers$classification == 'schema_defect'),
    all(blockers$reason == 'Invalid input schema type')
  )

  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  rows <- do.call(
    rbind,
    lapply(observed, function(x) {
      data.frame(
        workflow = x$workflow,
        method = x$method,
        path = x$path,
        query = x$query,
        content_type = if (is.null(x$content_type)) '' else x$content_type,
        body = x$body,
        generated_contract_passed = TRUE,
        http_result_matches_recorded_response = TRUE
      )
    })
  )
  write.csv(rows, file.path(output, 'requests.csv'), row.names = FALSE)
  write.csv(
    data.frame(
      method = 'POST',
      path = amos_paths,
      disposition = 'excluded_from_acceptance_slice',
      blocker = 'Invalid input schema type'
    ),
    file.path(output, 'excluded-amos.csv'),
    row.names = FALSE
  )
  cat(
    'ComptoxR acceptance: three generated contracts and localhost HTTP requests/results passed; four AMOS blockers remained excluded.\n'
  )
  invisible(list(requests = rows, amos = blockers))
}
