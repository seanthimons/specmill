# Generated with specmill; do not edit by hand.
# Replay helpers for generated cassette scenario tests. Routine runs replay only.
# A scenario records only when the environment variable named below lists it
# as service/scenario (comma-separated); delete its cassette to re-record it.

replay_record_env <- REPLAY_RECORD_ENV
replay_credentials <- REPLAY_CREDENTIALS
replay_query_credentials <- REPLAY_QUERY_CREDENTIALS
replay_filters <- REPLAY_FILTERS

replay_fresh <- new.env(parent = emptyenv())

replay_recording <- function(service, scenario) {
  listed <- trimws(strsplit(Sys.getenv(replay_record_env), ',', fixed = TRUE)[[
    1L
  ]])
  paste0(service, '/', scenario) %in% listed
}

# A credential can reach a recording raw or URL-encoded in several ways.
replay_secret_forms <- function(value) {
  query <- httr2::req_url_query(
    httr2::request('http://replay.invalid/'),
    value = value
  )$url
  forms <- c(
    value,
    sub('^[^=]*=', '', query),
    utils::URLencode(value, reserved = TRUE, repeated = TRUE)
  )
  unique(c(forms, gsub('%20', '+', forms, fixed = TRUE)))
}

# Checks a new recording for anything redaction missed, so vcr's filters are
# not the only safeguard. A hit deletes the recording and fails the test.
replay_scan <- function(
  service,
  scenario,
  files,
  secrets,
  patterns,
  dropped
) {
  if (!file.exists(files[[1L]])) {
    # Nothing was recorded: drop its credential list, but keep any reviewed
    # signature from an earlier recording.
    unlink(files[[2L]])
    return(invisible())
  }
  text <- paste(
    unlist(lapply(files[file.exists(files)], readLines, warn = FALSE)),
    collapse = '\n'
  )
  # Patterns apply to the recording only; the helper writes the other files.
  clean <- paste(readLines(files[[1L]], warn = FALSE), collapse = '\n')
  for (placeholder in names(patterns)) {
    clean <- gsub(placeholder, '', clean, fixed = TRUE)
  }
  interactions <- yaml::read_yaml(files[[1L]])$http_interactions
  requests <- unlist(lapply(
    interactions,
    function(x) c(x$request$uri, x$request$body$string)
  ))
  headers <- unlist(lapply(interactions, function(x) names(x$response$headers)))
  problem <- if (
    any(vapply(secrets, grepl, logical(1), x = text, fixed = TRUE))
  ) {
    'a credential value'
  } else if (any(tolower(headers) %in% tolower(dropped))) {
    'a response header that should have been dropped'
  } else if (any(vapply(patterns, grepl, logical(1), x = clean))) {
    'a value matching a filter pattern'
  } else if (
    any(vapply(
      as.character(names(patterns)),
      function(x) any(grepl(x, requests, fixed = TRUE)),
      logical(1)
    ))
  ) {
    'a filter placeholder in its request, which replay cannot match'
  }
  if (!is.null(problem)) {
    unlink(files)
    testthat::fail(paste0(
      'Recording of ',
      service,
      '/',
      scenario,
      ' contained ',
      problem,
      ' and was deleted; adjust the testing filter and record again'
    ))
  }
  invisible()
}

# vcr drops headers by exact name, so list the usual spellings of each.
replay_header_forms <- function(x) {
  lower <- tolower(x)
  unique(c(x, lower, gsub('(^|-)([a-z])', '\\1\\U\\2', lower, perl = TRUE)))
}

replay_cassette <- function(
  service,
  scenario,
  match,
  writes = FALSE,
  write_approved = FALSE,
  frame = parent.frame()
) {
  dir <- testthat::test_path('_vcr', service)
  query <- lapply(replay_query_credentials, function(name) {
    paste0('<<', name, '>>')
  })
  extra <- if (is.null(replay_filters[[service]])) {
    list()
  } else {
    replay_filters[[service]]
  }
  cassette <- file.path(dir, paste0(scenario, '.yml'))
  # Names (never values) of the credentials a recording used; header, bearer
  # and cookie credentials leave no placeholder in the cassette itself.
  used_file <- file.path(dir, paste0(scenario, '.credentials'))
  recording <- replay_recording(service, scenario)
  # Only a new recording may rewrite the reviewed signature.
  fresh <- recording && !file.exists(cassette)
  replay_fresh[[paste0(service, '/', scenario)]] <- fresh
  settings <- list(
    dir = dir,
    filter_request_headers = list('Authorization', 'Cookie'),
    filter_response_headers = as.list(replay_header_forms(c(
      'Set-Cookie',
      extra$response_headers
    ))),
    .frame = frame
  )
  if (recording) {
    if (tolower(Sys.getenv('CI')) %in% c('true', '1', 'yes')) {
      stop(
        'Recording is refused while CI is set: ',
        service,
        '/',
        scenario,
        call. = FALSE
      )
    }
    if (writes && !write_approved) {
      stop(
        'Recording ',
        service,
        '/',
        scenario,
        ' would change the live service; ',
        'approve it with record_write in its testing declaration',
        call. = FALSE
      )
    }
    present <- replay_credentials[nzchar(Sys.getenv(replay_credentials))]
    secrets <- unique(unlist(
      lapply(Sys.getenv(present), replay_secret_forms),
      use.names = FALSE
    ))
    filters <- unlist(
      lapply(present, function(name) {
        forms <- replay_secret_forms(Sys.getenv(name))
        stats::setNames(
          as.list(forms),
          rep(paste0('<<', name, '>>'), length(forms))
        )
      }),
      recursive = FALSE
    )
    if (length(extra$patterns)) {
      settings$filter_sensitive_data_regex <- stats::setNames(
        as.list(unname(extra$patterns)),
        names(extra$patterns)
      )
    }
    if (fresh) {
      dir.create(dir, recursive = TRUE, showWarnings = FALSE)
      writeLines(present, used_file)
      signature <- testthat::test_path(
        '_signatures',
        service,
        paste0(scenario, '.yml')
      )
      # Registered before the cassette, so it runs after vcr writes it.
      withr::defer(
        replay_scan(
          service,
          scenario,
          c(cassette, used_file, signature),
          secrets,
          extra$patterns,
          c('Set-Cookie', extra$response_headers)
        ),
        envir = frame
      )
    }
    record <- 'once'
  } else {
    if (!file.exists(cassette)) {
      stop(
        'No recording for ',
        service,
        '/',
        scenario,
        '; list it in ',
        replay_record_env,
        ' to record it on purpose',
        call. = FALSE
      )
    }
    # Replay never sees real credentials: a dummy stands in for each one the
    # recording used, and the rest are unset so authentication cannot change.
    used <- if (file.exists(used_file)) {
      intersect(readLines(used_file, warn = FALSE), replay_credentials)
    } else {
      character()
    }
    if (length(replay_credentials)) {
      values <- stats::setNames(
        rep(NA_character_, length(replay_credentials)),
        replay_credentials
      )
      values[used] <- 'replay-dummy'
      withr::local_envvar(values, .local_envir = frame)
    }
    filters <- if (length(used)) {
      stats::setNames(
        as.list(rep('replay-dummy', length(used))),
        paste0('<<', used, '>>')
      )
    } else {
      list()
    }
    record <- 'none'
  }
  if (length(filters)) {
    settings$filter_sensitive_data <- filters
  }
  if (length(query)) {
    settings$filter_query_parameters <- query
  }
  do.call(vcr::local_vcr_configure, settings)
  # A warning after an error would hide the error from testthat's summary.
  vcr::local_cassette(
    scenario,
    dir = dir,
    record = record,
    match_requests_on = match,
    warn_on_empty = FALSE,
    frame = frame
  )
}

# Type and shape of a result, not its values: class, emptiness, data frame
# column classes, and named or first-item children up to a fixed depth.
replay_signature <- function(x, depth = 3L) {
  signature <- list(
    class = paste(class(x), collapse = '/'),
    empty = NROW(x) == 0L
  )
  if (is.data.frame(x)) {
    signature$columns <- lapply(x, function(column) {
      paste(class(column), collapse = '/')
    })
  } else if (is.list(x) && length(x) && depth > 0L) {
    if (is.null(names(x))) {
      signature$item <- replay_signature(x[[1L]], depth - 1L)
    } else {
      signature$elements <- lapply(x, replay_signature, depth = depth - 1L)
    }
  }
  signature
}

replay_expect_signature <- function(result, service, scenario) {
  path <- testthat::test_path('_signatures', service, paste0(scenario, '.yml'))
  actual <- replay_signature(result)
  if (isTRUE(replay_fresh[[paste0(service, '/', scenario)]])) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeLines(
      c(
        '# Reviewed type signature; rewritten only when this scenario is recorded.',
        sub('\n$', '', yaml::as.yaml(actual))
      ),
      path
    )
    testthat::succeed()
  } else if (!file.exists(path)) {
    testthat::fail(paste0(
      'No reviewed signature for ',
      service,
      '/',
      scenario,
      '; record the scenario first'
    ))
  } else {
    testthat::expect_identical(
      yaml::yaml.load(yaml::as.yaml(actual)),
      yaml::read_yaml(path)
    )
  }
  invisible(actual)
}
