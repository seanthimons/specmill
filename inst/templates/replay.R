# Generated with specmill; do not edit by hand.
# Replay helpers for generated cassette scenario tests. Routine runs replay only.
# A scenario records only when the environment variable named below lists it
# as service/scenario (comma-separated); delete its cassette to re-record it.

replay_record_env <- REPLAY_RECORD_ENV
replay_credentials <- REPLAY_CREDENTIALS
replay_query_credentials <- REPLAY_QUERY_CREDENTIALS
replay_filters <- REPLAY_FILTERS

replay_fresh <- new.env(parent = emptyenv())
replay_signed <- new.env(parent = emptyenv())

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

# vcr keeps bodies it cannot read as text (no content type, binary, gzip) as
# base64, where its filters do not apply; decode them so the scan sees them.
replay_raw_bodies <- function(interactions) {
  decode <- function(text, gzip) {
    tryCatch(
      {
        bytes <- jsonlite::base64_dec(gsub('\\s', '', text))
        if (gzip) {
          bytes <- memDecompress(bytes, type = 'gzip')
        }
        rawToChar(bytes[bytes != as.raw(0L)])
      },
      # Undecodable is not clean: the scan treats NA as a problem.
      error = function(e) NA_character_
    )
  }
  side <- function(body) {
    if (!is.null(body$raw_gzip)) {
      decode(body$raw_gzip, TRUE)
    } else if (!is.null(body$base64_string)) {
      decode(body$base64_string, FALSE)
    }
  }
  unlist(lapply(interactions, function(x) {
    c(side(x$request$body), side(x$response$body))
  }))
}

# Checks a new recording for anything redaction missed, so vcr's filters are
# not the only safeguard. A hit deletes the recording and fails the test.
replay_scan <- function(
  service,
  scenario,
  files,
  secrets,
  patterns,
  dropped,
  provenance = NULL,
  provenance_file = NULL
) {
  if (!file.exists(files[[1L]])) {
    # Nothing was recorded: drop its credential list and provenance, but keep
    # any reviewed signature from an earlier recording.
    unlink(c(files[[2L]], provenance_file))
    return(invisible())
  }
  if (!isTRUE(replay_signed[[paste0(service, '/', scenario)]])) {
    # The test failed before the result's signature was written, for example on
    # an error response: keep nothing from an incomplete recording.
    unlink(c(files[[1L]], files[[2L]], provenance_file))
    testthat::fail(paste0(
      'Recording of ',
      service,
      '/',
      scenario,
      ' did not complete and was deleted; fix the failure and record again'
    ))
    return(invisible())
  }
  # Any scan error keeps nothing: an unscanned recording is never trusted.
  problem <- tryCatch(
    {
      text <- paste(
        unlist(lapply(files[file.exists(files)], readLines, warn = FALSE)),
        collapse = '\n'
      )
      interactions <- yaml::read_yaml(files[[1L]])$http_interactions
      raw <- replay_raw_bodies(interactions)
      text <- paste(c(text, raw[!is.na(raw)]), collapse = '\n')
      # Patterns apply to the recording only; the helper writes the other files.
      clean <- paste(
        c(readLines(files[[1L]], warn = FALSE), raw[!is.na(raw)]),
        collapse = '\n'
      )
      for (placeholder in names(patterns)) {
        clean <- gsub(placeholder, '', clean, fixed = TRUE, useBytes = TRUE)
      }
      requests <- unlist(lapply(
        interactions,
        function(x) c(x$request$uri, x$request$body$string)
      ))
      headers <- unlist(lapply(
        interactions,
        function(x) names(x$response$headers)
      ))
      # Bodies may be binary or another encoding; match bytes, not characters.
      found <- function(pattern, x, fixed = FALSE) {
        any(grepl(pattern, x, fixed = fixed, useBytes = TRUE))
      }
      if (anyNA(raw)) {
        'a body that could not be decoded for checking'
      } else if (any(vapply(secrets, found, logical(1), x = text, fixed = TRUE))) {
        'a credential value'
      } else if (any(tolower(headers) %in% tolower(dropped))) {
        'a response header that should have been dropped'
      } else if (any(vapply(patterns, found, logical(1), x = clean))) {
        'a value matching a filter pattern'
      } else if (
        any(vapply(
          as.character(names(patterns)),
          found,
          logical(1),
          x = requests,
          fixed = TRUE
        ))
      ) {
        'a filter placeholder in its request, which replay cannot match'
      }
    },
    error = function(e) paste('content the scan could not check:', conditionMessage(e))
  )
  if (!is.null(problem)) {
    unlink(c(files, provenance_file))
    testthat::fail(paste0(
      'Recording of ',
      service,
      '/',
      scenario,
      ' contained ',
      problem,
      ' and was deleted; adjust the testing filter and record again'
    ))
    return(invisible())
  }
  # What this recording depends on (digests only), for later change review.
  if (length(provenance)) {
    writeLines(paste0(names(provenance), ': ', provenance), provenance_file)
  } else {
    # A test generated before provenance must not inherit an older file.
    unlink(provenance_file)
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
  provenance = NULL,
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
  replay_signed[[paste0(service, '/', scenario)]] <- FALSE
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
    prepare <- get0('api_oauth_prepare_recording', mode = 'function')
    if (!is.null(prepare)) prepare()
    present <- replay_credentials[nzchar(Sys.getenv(replay_credentials))]
    secrets <- unique(unlist(
      lapply(c(Sys.getenv(present), replay_oauth_secrets()), replay_secret_forms),
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
      writeLines(c(present, replay_oauth_signed_in()), used_file)
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
          # OAuth tokens can change while recording (refresh); scan both.
          unique(c(
            secrets,
            unlist(lapply(replay_oauth_secrets(), replay_secret_forms))
          )),
          extra$patterns,
          c('Set-Cookie', extra$response_headers),
          provenance,
          file.path(dir, paste0(scenario, '.provenance'))
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
    listed <- if (file.exists(used_file)) {
      readLines(used_file, warn = FALSE)
    } else {
      character()
    }
    used <- intersect(listed, replay_credentials)
    if (length(replay_credentials)) {
      values <- stats::setNames(
        rep(NA_character_, length(replay_credentials)),
        replay_credentials
      )
      values[used] <- 'replay-dummy'
      withr::local_envvar(values, .local_envir = frame)
    }
    stub <- get0('api_oauth_replay', mode = 'function')
    if (!is.null(stub)) {
      restore <- stub(listed)
      withr::defer(restore(), envir = frame)
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
    replay_signed[[paste0(service, '/', scenario)]] <- TRUE
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

# OAuth credentials signed in when the client generates OAuth login.
replay_oauth_signed_in <- function() {
  signed_in <- get0('api_oauth_signed_in', mode = 'function')
  if (is.null(signed_in)) character() else signed_in()
}

# Current OAuth token values when the client generates OAuth login.
replay_oauth_secrets <- function() {
  values <- get0('api_oauth_secrets', mode = 'function')
  if (is.null(values)) character() else values()
}

