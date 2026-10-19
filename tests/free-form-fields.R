free_form_fields_acceptance <- function() {
  root <- tempfile('free-form-')
  port_file <- tempfile('free-form-port-')
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(c(root, port_file, schema), recursive = TRUE), add = TRUE)
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      history <- list()
      httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          if (req$PATH_INFO != '/history') {
            history[[length(history) + 1L]] <<- list(
              body = rawToChar(req$rook.input$read()),
              media = req$CONTENT_TYPE
            )
          }
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = jsonlite::toJSON(history, auto_unbox = TRUE)
          )
        })
      )
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    list(port_file),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  for (i in seq_len(200L)) {
    if (file.exists(port_file)) {
      break
    }
    if (!server$is_alive()) {
      server$get_result()
    }
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))
  origin <- paste0('http://127.0.0.1:', readLines(port_file))
  operation <- function(name, media, open = TRUE) {
    list(
      operationId = name,
      requestBody = list(
        required = TRUE,
        content = setNames(
          list(list(
            schema = list(
              type = 'object',
              additionalProperties = open,
              properties = list(count = list(type = 'integer', minimum = 0))
            )
          )),
          media
        )
      ),
      responses = list('200' = list(description = 'OK'))
    )
  }
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Forms', version = '1'),
      servers = list(list(url = origin)),
      paths = list(
        '/open' = list(
          post = operation('open_form', 'application/x-www-form-urlencoded')
        ),
        '/closed' = list(
          post = operation(
            'closed_form',
            'application/x-www-form-urlencoded',
            FALSE
          )
        ),
        '/parts' = list(post = operation('open_parts', 'multipart/form-data'))
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'freeform',
    title = 'Free Forms',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply',
    validation = TRUE
  )
  env <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, env)
  }
  history <- function() {
    httr2::resp_body_json(
      httr2::req_perform(httr2::request(paste0(origin, '/history'))),
      simplifyVector = FALSE
    )
  }
  body <- list(
    username = 'invented user',
    password = 'fixture only',
    flag = FALSE,
    count = 2L,
    fraction = 1.5,
    blank = '',
    punctuation = 'a&b=+/?'
  )
  env$open_form(body)
  sent <- history()
  stopifnot(
    length(sent) == 1L,
    identical(sent[[1L]]$media, 'application/x-www-form-urlencoded'),
    identical(
      sent[[1L]]$body,
      'username=invented%20user&password=fixture%20only&flag=false&count=2&fraction=1.5&blank=&punctuation=a%26b%3D%2B%2F%3F'
    )
  )
  env$open_form(list())
  stopifnot(identical(tail(history(), 1L)[[1L]]$body, ''))
  env$open_parts(list(label = 'invented', flag = FALSE, count = 2L))
  parts <- tail(history(), 1L)[[1L]]
  stopifnot(
    startsWith(parts$media, 'multipart/form-data;'),
    grepl('name="label"', parts$body, fixed = TRUE),
    grepl('invented', parts$body, fixed = TRUE),
    grepl('false', parts$body, fixed = TRUE)
  )
  sent <- length(history())
  for (value in list(
    NULL,
    NA_character_,
    Inf,
    character(),
    c('a', 'b'),
    list('a'),
    list(nested = 'a'),
    as.raw(1),
    structure(1, class = 'Date')
  )) {
    error <- tryCatch(env$open_form(list(unknown = value)), error = identity)
    stopifnot(inherits(error, 'error'), length(history()) == sent)
  }
  for (args in list(
    list(unknown = 'value'),
    list(count = -1L),
    list(count = 'wrong')
  )) {
    error <- tryCatch(env$closed_form(args), error = identity)
    stopifnot(inherits(error, 'error'), length(history()) == sent)
  }
  check <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'check',
    validation = TRUE
  )
  stopifnot(nrow(check$diagnostics) == 0L)
  cat(
    'Free-form fields: declared additionalProperties scalars encode exactly; empty, declared constraints, closed forms and ambiguous values remain protected; localhost URL-encoded/multipart and freshness passed.\n'
  )
}
if (sys.nframe() == 0L) {
  free_form_fields_acceptance()
}
