batch_combine_acceptance <- function() {
  template <- if (file.exists('inst/templates/request.R')) {
    'inst/templates/request.R'
  } else {
    system.file('templates/request.R', package = 'specmill', mustWork = TRUE)
  }
  code <- paste(readLines(template), collapse = '\n')
  code <- gsub('BASE_URL', deparse('http://127.0.0.1:1'), code, fixed = TRUE)
  code <- gsub(
    'DRY_RUN_ENV',
    deparse('BATCH_COMBINE_DRY_RUN'),
    code,
    fixed = TRUE
  )
  runtime <- new.env(parent = baseenv())
  eval(parse(text = code), runtime)

  # One record collection per input, as a response policy would extract it.
  responses <- list(
    a = list(list(sex = 'F', id = '007')),
    b = list(list(sex = 'MF', id = '12')),
    c = list(list(sex = 'F', id = '5')),
    d = list(list(sex = 'F', id = '5'), list(sex = 'F', id = '6'))
  )
  # A chunk can hold several ids; each id's records keep their own attribution.
  records <- function(id) {
    do.call(
      c,
      unname(lapply(id, function(one) {
        runtime$api_request_records(responses[[one]], query = one)
      }))
    )
  }
  table <- function(id, ...) runtime$api_request_table(records(id), ...)
  everything <- function(ids, ...) {
    runtime$api_request_table(
      do.call(c, unname(lapply(ids, records))),
      ...
    )
  }

  # Types are guessed once over all requests, as an unbatched call would (#100).
  batched <- runtime$api_request_each(table, c('a', 'b'), 1L)
  stopifnot(
    identical(batched$sex, c('F', 'MF')),
    identical(batched$id, c(7L, 12L)),
    identical(batched$query, c('a', 'b')),
    identical(batched, everything(c('a', 'b')))
  )
  # Without batching a lone table is unchanged and carries no bookkeeping.
  alone <- table('a')
  stopifnot(
    is.null(attr(alone, 'api_request_source')),
    identical(alone$sex, FALSE),
    !runtime$api_request_batch_state$active
  )
  # Whatever the chunking, the result matches one pass over every record.
  ids <- c('a', 'b', 'c', 'd')
  for (size in 1:5) {
    stopifnot(identical(
      runtime$api_request_each(table, ids, size),
      everything(ids)
    ))
  }
  # A single request is rebuilt through the same path.
  single <- runtime$api_request_each(table, 'd', 1L)
  stopifnot(
    identical(single, table('d')),
    is.null(attr(single, 'api_request_source'))
  )
  # Options travel with the table: no type recovery, a names_to column, a custom table class.
  raw <- runtime$api_request_each(
    function(id) table(id, type_convert = FALSE),
    c('a', 'b'),
    1L
  )
  stopifnot(identical(raw$id, c('007', '12')), identical(raw$sex, c('F', 'MF')))
  numbered <- runtime$api_request_each(
    function(id) table(id, names_to = 'n'),
    c('a', 'b', 'c'),
    1L
  )
  stopifnot(identical(numbered$n, c(1L, 2L, 3L)))
  tibbles <- runtime$api_request_each(
    function(id) table(id, as_table = tibble::as_tibble),
    c('a', 'b'),
    1L
  )
  stopifnot(
    inherits(tibbles, 'tbl_df'),
    identical(tibbles, everything(c('a', 'b'), as_table = tibble::as_tibble))
  )

  # An inline as_table closure is new on every request; it must not defeat the rebuild.
  inline <- runtime$api_request_each(
    function(id) table(id, as_table = function(x) tibble::as_tibble(x)),
    c('a', 'b'),
    1L
  )
  stopifnot(identical(inline$sex, c('F', 'MF')), inherits(inline, 'tbl_df'))

  # A table edited by a hook is not rebuilt; its edit survives (today's stacking).
  edited <- runtime$api_request_each(
    function(id) {
      x <- table(id)
      x$edited <- TRUE
      x
    },
    c('a', 'b'),
    1L
  )
  stopifnot(
    identical(edited$edited, c(TRUE, TRUE)),
    identical(edited$sex, c('FALSE', 'MF'))
  )
  # So are plain data frames (for example a skipped request's cached result), and
  # requests whose options differ.
  mixed <- runtime$api_request_each(
    function(id) {
      if (id == 'b') {
        data.frame(sex = 'MF', id = 12L, query = 'b')
      } else {
        table(id)
      }
    },
    c('a', 'b'),
    1L
  )
  stopifnot(identical(mixed$query, c('a', 'b')), nrow(mixed) == 2L)
  differing <- runtime$api_request_each(
    function(id) {
      table(id, type_convert = id == 'a')
    },
    c('a', 'b'),
    1L
  )
  stopifnot(identical(differing$sex, c('FALSE', 'MF')))
  # as_table closures with the same code but different captured values are different
  # tables: each request keeps its own, never the first request's.
  tagged <- function(tag) {
    function(x) {
      x$tag <- tag
      tibble::as_tibble(x)
    }
  }
  captured <- runtime$api_request_each(
    function(id) table(id, as_table = tagged(id)),
    c('a', 'b'),
    1L
  )
  stopifnot(identical(captured$tag, c('a', 'b')))
  # Attributes a policy attaches to a page are not edits: the tables are still typed once,
  # and the combined result does not carry the per-page attributes.
  tagged_pages <- runtime$api_request_each(
    function(id) {
      x <- table(id)
      attr(x, 'paging') <- list(page = id)
      x
    },
    c('a', 'b'),
    1L
  )
  stopifnot(
    identical(tagged_pages$sex, c('F', 'MF')),
    is.null(attr(tagged_pages, 'paging'))
  )
  # A table mixed with plain records leaves no bookkeeping behind.
  with_list <- runtime$api_request_each(
    function(id) {
      if (id == 'a') table(id) else list(id)
    },
    c('a', 'b'),
    1L
  )
  stopifnot(
    is.list(with_list),
    is.null(attr(with_list[[1L]], 'api_request_source'))
  )
  # Record names only matter when names_to uses them.
  unnamed_mix <- runtime$api_request_each(
    function(id) {
      runtime$api_request_table(
        if (id == 'a') setNames(records('a'), 'first') else records('b')
      )
    },
    c('a', 'b'),
    1L
  )
  stopifnot(identical(unnamed_mix, everything(c('a', 'b'))))
  # Records that are named in some requests only are stacked, not renumbered.
  keyed <- runtime$api_request_each(
    function(id) {
      runtime$api_request_table(
        if (id == 'a') setNames(records('a'), 'first') else records('b'),
        names_to = 'key'
      )
    },
    c('a', 'b'),
    1L
  )
  stopifnot(identical(keyed$key, c('first', '1')))

  # The batch flag is restored after errors and around nested batches.
  fails <- function(id) {
    if (id == 'b') {
      stop('boom')
    }
    table(id)
  }
  error <- tryCatch(
    runtime$api_request_each(fails, c('a', 'b'), 1L),
    error = identity
  )
  stopifnot(inherits(error, 'error'), !runtime$api_request_batch_state$active)
  seen <- logical()
  nested <- runtime$api_request_each(
    function(id) {
      seen <<- c(seen, runtime$api_request_batch_state$active)
      inner <- runtime$api_request_each(table, c('b', 'c'), 1L)
      seen <<- c(seen, runtime$api_request_batch_state$active)
      inner
    },
    'a',
    1L
  )
  stopifnot(
    identical(seen, c(TRUE, TRUE)),
    !runtime$api_request_batch_state$active,
    identical(nested, everything(c('b', 'c')))
  )

  # An inner batch inside several outer requests: the outer batch still types everything once.
  outer <- runtime$api_request_each(
    function(id) {
      runtime$api_request_each(table, c('a', 'b'), 1L)
    },
    c('x', 'y'),
    1L
  )
  stopifnot(identical(outer, everything(c('a', 'b', 'a', 'b'))))

  # Dropped requests are recorded, and the rest are typed together.
  dropped <- suppressWarnings(runtime$api_request_each(
    fails,
    c('a', 'b', 'c'),
    1L,
    on_error = 'drop'
  ))
  stopifnot(
    identical(attr(dropped, 'failed'), c(b = 'boom')),
    identical(dropped$query, c('a', 'c'))
  )
  attr(dropped, 'failed') <- NULL
  stopifnot(identical(dropped, everything(c('a', 'c'))))
  # A client can keep its own table shape: build() replaces the built-in rows (here it keeps
  # list-columns and puts query first), and the combined table is still built once, by the
  # same function, over every request's records.
  tagged_records <- list(
    a = runtime$api_request_records(
      list(list(sex = 'F', tags = list('x', 'y'))),
      query = 'a'
    ),
    b = runtime$api_request_records(
      list(list(sex = 'MF', tags = list('z'))),
      query = 'b'
    )
  )
  keep_lists <- function(records, type_convert, names_to) {
    out <- data.frame(
      query = vapply(
        records,
        function(x) as.character(attr(x, 'query')),
        character(1)
      ),
      stringsAsFactors = FALSE
    )
    out$sex <- utils::type.convert(
      vapply(records, function(x) x$sex, character(1)),
      as.is = TRUE
    )
    out$tags <- lapply(records, function(x) x$tags)
    out
  }
  custom <- runtime$api_request_each(
    function(id) {
      runtime$api_request_table(tagged_records[[id]], build = keep_lists)
    },
    c('a', 'b'),
    1L
  )
  stopifnot(
    identical(names(custom), c('query', 'sex', 'tags')),
    identical(custom$sex, c('F', 'MF')),
    identical(custom$tags, list(list('x', 'y'), list('z'))),
    identical(
      custom,
      runtime$api_request_table(
        c(tagged_records$a, tagged_records$b),
        build = keep_lists
      )
    )
  )
  for (bad in list(
    list(
      build = function(...) list(),
      pattern = 'build must return a data frame'
    ),
    list(build = 'nope', pattern = 'build must be NULL or a function')
  )) {
    error <- tryCatch(
      runtime$api_request_table(tagged_records$a, build = bad$build),
      error = identity
    )
    stopifnot(
      inherits(error, 'error'),
      grepl(bad$pattern, conditionMessage(error), fixed = TRUE)
    )
  }
  # Requests built with different builders are stacked, each by its own builder.
  upper <- function(records, type_convert, names_to) {
    data.frame(v = vapply(records, function(x) x$sex, character(1)))
  }
  lower <- function(records, type_convert, names_to) {
    data.frame(v = tolower(vapply(records, function(x) x$sex, character(1))))
  }
  different <- runtime$api_request_each(
    function(id) {
      runtime$api_request_table(
        tagged_records[[id]],
        build = if (id == 'a') upper else lower
      )
    },
    c('a', 'b'),
    1L
  )
  stopifnot(identical(different$v, c('F', 'mf')))
  # A builder that fails on another request's records during the comparison falls back
  # to stacking instead of failing the call (same code, different captured value).
  strictly <- function(strict) {
    function(records, type_convert, names_to) {
      v <- vapply(records, function(x) x$sex, character(1))
      if (strict && any(v == 'MF')) {
        stop('strict builder')
      }
      data.frame(v = v)
    }
  }
  fallback <- runtime$api_request_each(
    function(id) {
      runtime$api_request_table(
        tagged_records[[id]],
        build = strictly(id == 'a')
      )
    },
    c('a', 'b'),
    1L
  )
  stopifnot(identical(fallback$v, c('F', 'MF')))
  # The page loop needs the pagination companion; without it the error says so (the
  # base template must not name the companion's function, or a clean check would flag it).
  error <- tryCatch(
    runtime$api_request_pages(function(page) NULL, 'p', 1L, 3L),
    error = identity
  )
  stopifnot(
    inherits(error, 'error'),
    grepl('Paging needs the pagination companion', conditionMessage(error))
  )
  cat(
    'Batch combine: one type-recovery pass over all requests, fallbacks and flag handling passed.\n'
  )
}

if (sys.nframe() == 0L) {
  batch_combine_acceptance()
}
