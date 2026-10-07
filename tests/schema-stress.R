# A frozen schema and temporary local HTTP harness, never a maintained NP client.
schema_stress_acceptance <- function() {
  schema <- system.file(
    'schema-stress/natural-products.json',
    package = 'specmill',
    mustWork = TRUE
  )
  origin <- jsonlite::read_json(system.file(
    'schema-stress/natural-products-origin.json',
    package = 'specmill'
  ))
  stopifnot(identical(
    digest::digest(file = schema, algo = 'sha256'),
    origin$sha256
  ))
  document <- jsonlite::read_json(schema)
  stopifnot(
    document$openapi == '3.1.0',
    document$servers[[1L]]$url == '/latest',
    paste0(
      sub('/latest/openapi.json$', '', origin$source),
      document$servers[[1L]]$url
    ) ==
      'https://api.naturalproducts.net/latest'
  )
  parsed <- specmill::read_operations(schema)
  status <- vapply(parsed$inventory, `[[`, character(1), 'status')
  stopifnot(
    length(status) == 43L,
    sum(status == 'selected') == 43L,
    sum(status == 'unsupported') == 0L,
    length(parsed$diagnostics) == 0L
  )
  reasons <- setNames(
    vapply(
      parsed$inventory,
      function(x) if (is.null(x$reason)) '' else x$reason,
      character(1)
    ),
    vapply(parsed$inventory, `[[`, character(1), 'key')
  )
  stopifnot(
    reasons[['POST /chem/standardize']] == '',
    reasons[['POST /convert/cdx-to-mol']] == '',
    reasons[['POST /ocsr/process-upload']] == '',
    reasons[['POST /convert/batch']] == '',
    reasons[['GET /chem/tanimoto']] == '',
    reasons[['GET /depict/2D']] == '',
    reasons[['GET /depict/2D_enhanced']] == ''
  )
  text <- Filter(
    function(op) identical(op$body_media, 'text/plain'),
    parsed$operations
  )
  stopifnot(setequal(
    vapply(text, `[[`, character(1), 'key'),
    c(
      'POST /chem/standardize',
      'POST /chem/all_filters',
      'POST /chem/all_filters_detailed',
      'POST /convert/molblock',
      'POST /convert/xyz'
    )
  ))
  uploads <- Filter(
    function(op) identical(unname(op$body_media), 'multipart/form-data'),
    parsed$operations
  )
  stopifnot(setequal(
    vapply(uploads, `[[`, character(1), 'key'),
    c('POST /convert/cdx-to-mol', 'POST /ocsr/process-upload')
  ))
  stopifnot(length(specmill::operation_fixtures(uploads)) == 2L)
  stopifnot(all(
    c('application/json', 'image/svg+xml') %in%
      names(
        document$paths[['/depict/2D_enhanced']]$get$responses[['200']]$content
      )
  ))
  port_file <- tempfile('stress-port-')
  request_file <- tempfile('stress-request-')
  server <- callr::r_bg(
    function(port_file, request_file) {
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(request) {
          saveRDS(
            list(
              method = request$REQUEST_METHOD,
              path = request$PATH_INFO,
              query = request$QUERY_STRING,
              body = rawToChar(request$rook.input$read()),
              type = request$CONTENT_TYPE
            ),
            request_file
          )
          body <- if (request$PATH_INFO == '/latest/chem/HOSEcode') {
            '{"hose_codes":["fixture"]}'
          } else if (request$PATH_INFO == '/latest/ocsr/process') {
            '{"message":"Success","reference":"fixture","smiles":"CCO"}'
          } else {
            '{"id":1,"label":"fixture","classification_status":"Done","number_of_elements":0,"number_of_pages":0,"invalid_entities":[],"entities":[]}'
          }
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = body
          )
        })
      )
      on.exit(server$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    args = list(port_file, request_file),
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
  root <- tempfile('schema-stress-')
  specmill::initialize_client(
    root,
    schema,
    package = 'schemastress',
    group_by = 'none',
    title = 'Temporary Schema Stress Harness',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'maintainer@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = paste0('http://127.0.0.1:', readLines(port_file), '/latest')
  )
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  fails <- function(expr) {
    stopifnot(inherits(
      tryCatch(
        {
          force(expr)
          NULL
        },
        error = identity
      ),
      'error'
    ))
  }
  before <- hashes()
  plan <- specmill::generate_client(
    validation = FALSE,
    root,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(
    identical(before, hashes()),
    length(plan$diagnostics) == 3L,
    setequal(
      vapply(plan$diagnostics, `[[`, character(1), 'parameter'),
      c('nBits', 'radius', 'arrow')
    )
  )
  fails(specmill::generate_client(
    validation = FALSE,
    root,
    config = 'specmill.yml',
    mode = 'apply'
  ))
  stopifnot(identical(before, hashes()))
  service_path <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_path)
  service$schemas$files <- as.list(service$schemas$files)
  service$operations <- list(
    'GET /chem/tanimoto' = list(
      parameters = list(
        'query nBits' = list(default = 2048L),
        'query radius' = list(default = 2L)
      )
    ),
    'GET /depict/2D_enhanced' = list(
      parameters = list(
        'query arrow' = list(default = NULL)
      )
    )
  )
  yaml::write_yaml(service, service_path)
  full <- specmill::generate_client(
    validation = FALSE,
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  stopifnot(length(full$operations) == 43L, !length(full$diagnostics))
  selected <- c(
    '/chem/HOSEcode',
    '/chem/classyfire/{jobid}/result',
    '/ocsr/process',
    '/chem/standardize',
    '/chem/tanimoto',
    '/depict/2D',
    '/depict/2D_enhanced'
  )
  service$selection <- list(
    exclude = as.list(paste0(
      '^\\Q',
      setdiff(names(document$paths), selected),
      '\\E$'
    ))
  )
  service$names <- list(
    'GET /chem/HOSEcode' = 'hose_code',
    'GET /chem/classyfire/{jobid}/result' = 'job_result',
    'POST /ocsr/process' = 'process_image',
    'POST /chem/standardize' = 'standardize_text',
    'GET /chem/tanimoto' = 'tanimoto',
    'GET /depict/2D' = 'depict',
    'GET /depict/2D_enhanced' = 'depict_enhanced'
  )
  yaml::write_yaml(service, service_path)
  generated <- specmill::generate_client(
    validation = FALSE,
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  stopifnot(length(generated$operations) == 7L, !length(generated$diagnostics))
  before <- hashes()
  specmill::generate_client(
    validation = FALSE,
    root,
    config = 'specmill.yml',
    mode = 'check'
  )
  specmill::generate_client(
    validation = FALSE,
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  stopifnot(identical(before, hashes()))
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), '\\.R$', full.names = TRUE)) {
    sys.source(file, runtime)
  }
  stopifnot(identical(
    runtime$hose_code(
      'C/C=C\\C',
      spheres = 0L,
      toolkit = NULL,
      ringsize = FALSE
    ),
    list(hose_codes = list('fixture'))
  ))
  request <- readRDS(request_file)
  stopifnot(
    request$method == 'GET',
    request$path == '/latest/chem/HOSEcode',
    request$query == '?smiles=C%2FC%3DC%5CC&spheres=0&ringsize=FALSE',
    request$body == ''
  )
  before_request <- tools::md5sum(request_file)
  fails(runtime$hose_code('CCO'))
  stopifnot(identical(before_request, tools::md5sum(request_file)))
  stopifnot(identical(
    runtime$job_result('job/a b'),
    list(
      id = 1L,
      label = 'fixture',
      classification_status = 'Done',
      number_of_elements = 0L,
      number_of_pages = 0L,
      invalid_entities = list(),
      entities = list()
    )
  ))
  stopifnot(
    readRDS(request_file)$path == '/latest/chem/classyfire/job%2Fa%20b/result'
  )
  body <- list(
    path = '/server-only/missing-image.png',
    reference = 'fixture',
    img = 'ZmFrZQ==',
    hand_drawn = FALSE
  )
  stopifnot(
    !file.exists(body$path),
    identical(
      runtime$process_image(body),
      list(message = 'Success', reference = 'fixture', smiles = 'CCO')
    )
  )
  request <- readRDS(request_file)
  stopifnot(
    request$method == 'POST',
    request$path == '/latest/ocsr/process',
    identical(jsonlite::fromJSON(request$body, simplifyVector = FALSE), body)
  )
  text <- '\n  CDK α\n\n  1  0  0  0\nM  END\n'
  runtime$standardize_text(body = text)
  request <- readRDS(request_file)
  stopifnot(
    request$method == 'POST',
    request$path == '/latest/chem/standardize',
    request$type == 'text/plain',
    identical(charToRaw(request$body), charToRaw(enc2utf8(text)))
  )
  # Corrected configuration defaults now work without per-call overrides.
  before_request <- tools::md5sum(request_file)
  fails(runtime$tanimoto('CCO,CC', nBits = '2048'))
  stopifnot(identical(before_request, tools::md5sum(request_file)))
  runtime$tanimoto('CCO,CC')
  stopifnot(grepl(
    'nBits=2048&radius=2',
    readRDS(request_file)$query,
    fixed = TRUE
  ))
  runtime$tanimoto('CCO,CC', nBits = 2048L, radius = NULL)
  request <- readRDS(request_file)
  stopifnot(
    request$path == '/latest/chem/tanimoto',
    request$query ==
      '?smiles=CCO%2CCC&toolkit=rdkit&fingerprinter=ECFP&nBits=2048'
  )
  runtime$depict('CCO', width = NULL, highlight = 'C/O')
  request <- readRDS(request_file)
  stopifnot(
    request$path == '/latest/depict/2D',
    !grepl('width=', request$query, fixed = TRUE),
    grepl('height=512', request$query, fixed = TRUE),
    grepl('highlight=C%2FO', request$query, fixed = TRUE)
  )
  # An empty arrow default needs omission under the existing query contract.
  runtime$depict_enhanced('CCO', width = 256L, title = 'a b')
  request <- readRDS(request_file)
  stopifnot(
    request$path == '/latest/depict/2D_enhanced',
    grepl('width=256', request$query, fixed = TRUE),
    grepl('title=a%20b', request$query, fixed = TRUE),
    !grepl('arrow=', request$query, fixed = TRUE)
  )
  cat(
    'Schema stress: 43 supported operations; multipart fixtures and seven local HTTP contracts, nullable scalars, source-default limitations, encoding, zero/false, omission, server-side path and successful JSON returns passed.\n'
  )
}
if (sys.nframe() == 0L) {
  schema_stress_acceptance()
}
