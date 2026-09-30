plain_text_acceptance <- function() {
  workspace <- tempfile('plain-text-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  port_file <- file.path(workspace, 'port')
  count_file <- file.path(workspace, 'count')
  server <- callr::r_bg(
    function(port_file, count_file) {
      port <- httpuv::randomPort()
      count <- 0L
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          count <<- count + 1L
          writeLines(as.character(count), count_file)
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = jsonlite::toJSON(
              list(
                bytes = as.integer(req$rook.input$read()),
                type = req$CONTENT_TYPE,
                query = req$QUERY_STRING,
                key = req$HTTP_X_API_KEY
              ),
              auto_unbox = TRUE,
              null = 'null'
            )
          )
        })
      )
      on.exit(server$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    list(port_file, count_file),
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
  for (version in c('3.0.3', '3.1.0', '2.0')) {
    root <- file.path(workspace, paste0('client-', version))
    schema <- file.path(workspace, paste0(version, '.json'))
    query <- list(
      name = 'tag',
      'in' = 'query',
      type = 'array',
      items = list(type = 'string'),
      collectionFormat = 'multi'
    )
    if (version != '2.0') {
      query <- list(
        name = 'tag',
        'in' = 'query',
        schema = list(type = 'array', items = list(type = 'string'))
      )
    }
    operation <- function(name, required = FALSE) {
      op <- list(
        operationId = name,
        parameters = list(query),
        responses = list('200' = list(description = 'OK'))
      )
      if (version == '2.0') {
        op$consumes <- list('application/json', 'text/plain')
        op$parameters <- c(
          op$parameters,
          list(list(
            name = 'body',
            'in' = 'body',
            required = required,
            schema = list(type = 'string')
          ))
        )
      } else {
        op$requestBody <- list(
          required = required,
          content = list(
            'application/json' = list(schema = list(type = 'string')),
            'text/plain' = list(schema = list(type = 'string'))
          )
        )
      }
      op
    }
    document <- list(
      info = list(title = 'Text transport', version = '1'),
      paths = list(
        '/scalar' = list(post = operation('send_scalar')),
        '/lines' = list(post = operation('send_lines')),
        '/required' = list(post = operation('send_required', TRUE))
      )
    )
    key <- list(type = 'apiKey', name = 'x-api-key', 'in' = 'header')
    document$security <- list(list(key = list()))
    if (version == '2.0') {
      document$swagger <- version
      document$securityDefinitions <- list(key = key)
    } else {
      document$openapi <- version
      document$components <- list(securitySchemes = list(key = key))
    }
    jsonlite::write_json(document, schema, auto_unbox = TRUE)
    specmill::initialize_client(
      root,
      schema,
      package = 'textclient',
      title = 'Text transport',
      author = list(
        given = 'Test',
        family = 'Maintainer',
        email = 'test@example.org'
      ),
      license = 'MIT + file LICENSE',
      base_url = paste0('http://127.0.0.1:', readLines(port_file))
    )
    service_path <- file.path(root, 'apis', 'default.yml')
    service <- yaml::read_yaml(service_path, handlers = list(seq = identity))
    service$defaults$body_media <- 'text/plain'
    service$defaults$batch <- list(max_bytes = 64)
    service$operations[['POST /lines']] <- list(
      text_encoding = 'lines',
      batch = list(max_items = 3)
    )
    yaml::write_yaml(service, service_path)
    withr::local_envvar(c(TEXTCLIENT_KEY = 'fixture-key'))
    plan <- specmill::generate_client(
      validation = FALSE,
      root,
      config = 'specmill.yml',
      mode = 'apply'
    )
    stopifnot(!length(plan$diagnostics), length(plan$operations) == 3L)
    repeat_plan <- specmill::generate_client(
      validation = FALSE,
      root,
      config = 'specmill.yml',
      mode = 'apply'
    )
    stopifnot(all(vapply(
      repeat_plan$files,
      function(x) x$action %in% c('unchanged', 'retained'),
      logical(1)
    )))
    runtime <- new.env(parent = baseenv())
    for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
      sys.source(file, runtime)
    }
    stopifnot(
      !grepl('specmill', read.dcf(file.path(root, 'DESCRIPTION'))[1, 'Imports'])
    )
    check_wire <- function(result, expected) {
      stopifnot(
        identical(
          as.integer(unlist(result$bytes)),
          as.integer(charToRaw(enc2utf8(expected)))
        ),
        result$type == 'text/plain',
        result$key == 'fixture-key'
      )
    }
    for (text in c('one', 'first\n\nlast\n', 'α\nβ\r\n', '')) {
      result <- runtime$send_scalar(body = text, tag = c('a/b', 'blue sky'))
      check_wire(result, text)
      stopifnot(result$query == '?tag=a%2Fb&tag=blue%20sky')
    }
    check_wire(runtime$send_lines(body = c('same', '', 'same')), 'same\n\nsame')
    check_wire(runtime$send_lines(body = c('a\nb', 'c\n')), 'a\nb\nc\n')
    check_wire(runtime$send_lines(body = character()), '')
    check_wire(runtime$send_lines(body = 'single'), 'single')
    if (version == '3.0.3') {
      standalone <- callr::r(
        function(root) {
          stopifnot(!isNamespaceLoaded('specmill'))
          runtime <- new.env(parent = baseenv())
          for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
            sys.source(file, runtime)
          }
          Sys.setenv(TEXTCLIENT_KEY = 'fixture-key')
          scalar <- runtime$send_scalar(body = 'α\n\nend\n')
          lines <- runtime$send_lines(body = c('α', '', 'end\n'))
          for (result in list(scalar, lines)) {
            stopifnot(
              identical(
                as.integer(unlist(result$bytes)),
                as.integer(charToRaw(enc2utf8('α\n\nend\n')))
              ),
              result$type == 'text/plain',
              result$key == 'fixture-key'
            )
          }
          stopifnot(!isNamespaceLoaded('specmill'))
          TRUE
        },
        list(root)
      )
      stopifnot(standalone)
    }
    omitted <- runtime$send_scalar()
    stopifnot(is.null(omitted$type), !length(omitted$bytes))
    count <- readLines(count_file)
    for (call in list(
      function() runtime$send_scalar(body = c('a', 'b')),
      function() runtime$send_scalar(body = NA_character_),
      function() runtime$send_scalar(body = NULL),
      function() runtime$send_scalar(body = 1),
      function() runtime$send_lines(body = matrix('a')),
      function() runtime$send_lines(body = c(named = 'a')),
      function() runtime$send_lines(body = structure('a', class = 'custom')),
      function() runtime$send_lines(body = c('a', NA_character_)),
      function() runtime$send_lines(body = letters[1:4]),
      function() runtime$send_scalar(body = paste(rep('α', 33), collapse = '')),
      function() runtime$send_required(),
      function() runtime$send_required(body = NULL)
    )) {
      stopifnot(
        inherits(try(call(), silent = TRUE), 'try-error'),
        identical(readLines(count_file), count)
      )
    }
    constrained <- plan$operations[[which(vapply(
      plan$operations,
      function(x) x$name == 'send_lines',
      logical(1)
    ))]]
    constrained$name <- 'check_lines'
    constrained$body$enum <- list('a\nb')
    constrained$body$minLength <- 3L
    context <- new.env(parent = baseenv())
    context$checked_request <- function(...) list(...)
    eval(
      parse(
        text = specmill::render_operation(
          constrained,
          list(helper = 'checked_request')
        )
      ),
      context
    )
    stopifnot(
      identical(context$check_lines(body = c('a', 'b'))$body, 'a\nb'),
      inherits(try(context$check_lines(body = 'a'), silent = TRUE), 'try-error')
    )
    # A declared scalar text body works without a media override too.
    if (version == '2.0') {
      document$paths[['/scalar']]$post$consumes <- list('text/plain')
    } else {
      document$paths[['/scalar']]$post$requestBody$content <- document$paths[[
        '/scalar'
      ]]$post$requestBody$content['text/plain']
    }
    jsonlite::write_json(document, schema, auto_unbox = TRUE)
    stopifnot(
      specmill::read_operations(schema)$operations$send_scalar$body_media ==
        'text/plain'
    )
    # Unsupported text schemas and lines with JSON remain parser diagnostics.
    for (shape in list(
      list(type = 'array', items = list(type = 'string')),
      list(type = 'object'),
      list(type = 'string', format = 'binary'),
      list(type = 'string', oneOf = list(list(type = 'string')))
    )) {
      bad <- document
      if (version == '2.0') {
        bad$paths[['/scalar']]$post$parameters[[2]]$schema <- shape
      } else {
        bad$paths[['/scalar']]$post$requestBody$content[[
          'text/plain'
        ]]$schema <- shape
      }
      jsonlite::write_json(bad, schema, auto_unbox = TRUE)
      stopifnot(length(specmill::read_operations(schema)$diagnostics) > 0L)
    }
    jsonlite::write_json(document, schema, auto_unbox = TRUE)
    parsed <- specmill::read_operations(
      schema,
      list(text_encoding = 'lines', body_media = 'application/json')
    )
    stopifnot(length(parsed$diagnostics) > 0L)
    helper <- file.path(root, 'R', 'api_request.R')
    cat('\n# Client customization retained.\n', file = helper, append = TRUE)
    before <- tools::md5sum(helper)
    specmill::generate_client(validation = FALSE, root, config = 'specmill.yml', mode = 'apply')
    stopifnot(identical(before, tools::md5sum(helper)))
  }
  cat(
    'Plain text: OAS/Swagger generation, exact bytes, explicit lines, empty/omitted bodies, UTF-8 limits, auth/query, no-op generation and helper ownership passed.\n'
  )
}
if (sys.nframe() == 0L) {
  plain_text_acceptance()
}
