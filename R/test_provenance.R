# Provenance for cassette scenarios (#261): digests of what a recording
# depends on, written beside it when recorded and compared later. Digests
# cover canonical JSON of data and deparsed function sources, never machine
# paths, so they are stable across machines.

provenance_hash <- function(x) {
  json <- jsonlite::toJSON(
    x,
    auto_unbox = TRUE,
    digits = NA,
    null = 'null',
    force = TRUE
  )
  substr(text_hash(json), 1L, 16L)
}

provenance_source <- function(definition) {
  if (is.null(definition)) {
    return(NULL)
  }
  paste(
    deparse(
      definition$expr,
      width.cutoff = 500L,
      control = c('keepNA', 'keepInteger', 'niceNames', 'showAttributes')
    ),
    collapse = '\n'
  )
}

# Response schemas keep their local `$ref`s; include exactly the components
# they reach, so an edit to an unrelated component changes nothing.
provenance_references <- function(x, document) {
  found <- list()
  pending <- character()
  collect <- function(node) {
    if (!is.list(node)) {
      return(invisible())
    }
    ref <- node[['$ref']]
    if (is.character(ref) && length(ref) == 1L && startsWith(ref, '#/')) {
      pending <<- c(pending, ref)
    }
    for (child in node) {
      collect(child)
    }
  }
  collect(x)
  while (length(pending)) {
    ref <- pending[[1L]]
    pending <- pending[-1L]
    if (ref %in% names(found)) {
      next
    }
    target <- document
    for (part in strsplit(sub('^#/', '', ref), '/', fixed = TRUE)[[1L]]) {
      part <- gsub('~0', '~', gsub('~1', '/', part, fixed = TRUE), fixed = TRUE)
      target <- if (is.list(target)) target[[part]] else NULL
    }
    # A missing target is recorded too, so it counts and is not looked up again.
    found[ref] <- list(target)
    collect(target)
  }
  # Radix order is locale-independent, so digests match across machines.
  found[order(names(found) %or% character(), method = 'radix')]
}

# Schema documents with local references left as written, read once each.
provenance_documents <- function() {
  cache <- new.env(parent = emptyenv())
  function(source) {
    if (is.null(cache[[source]])) {
      # External references are inlined; local ones stay for the walk above.
      cache[[source]] <- read_schema_document(
        source,
        resolve_references = TRUE
      )
    }
    cache[[source]]
  }
}

provenance_policy <- function(service, key) {
  settings <- merge_settings(
    service$defaults %or% list(),
    service$operations[[key]] %or% list()
  )
  settings$docs <- NULL
  list(
    settings = settings,
    helper = service$helper,
    hook_callback = service$hook_callback,
    authentication = service$authentication
  )
}

# One digest per component a scenario's recording depends on.
scenario_provenance <- function(
  service,
  scenario,
  declared,
  parsed,
  definitions,
  documents
) {
  routes <- sort(unique(declared$represents), method = 'radix')
  by_key <- stats::setNames(
    parsed,
    vapply(parsed, `[[`, character(1), 'key')
  )
  operation <- function(key) {
    op <- by_key[[key]]
    if (is.null(op)) {
      return(NULL)
    }
    source <- op$source
    op <- op[setdiff(names(op), c('source', 'source_hash', 'response_sources'))]
    list(
      operation = op,
      references = provenance_references(op, documents(source))
    )
  }
  helper <- merge_settings(
    service$defaults %or% list(),
    service$operations[[declared$route]] %or% list()
  )$helper %or%
    service$helper
  callback <- service$hook_callback %or% 'run_hook'
  helpers <- sort(
    unique(c(
      helper,
      if (length(helper)) {
        grep(paste0('^', helper, '_'), names(definitions), value = TRUE)
      },
      callback
    )),
    method = 'radix'
  )
  wrapper <- declared$operation
  chains <- lapply(service$hooks[[wrapper]], unlist, use.names = FALSE)
  hooks <- sort(
    unique(unlist(chains, use.names = FALSE) %or% character()),
    method = 'radix'
  )
  c(
    schema = provenance_hash(lapply(
      stats::setNames(routes, routes),
      operation
    )),
    policy = provenance_hash(lapply(
      stats::setNames(routes, routes),
      function(key) provenance_policy(service, key)
    )),
    helper = provenance_hash(lapply(
      stats::setNames(helpers, helpers),
      function(name) provenance_source(definitions[[name]])
    )),
    hooks = provenance_hash(list(
      chains = chains,
      sources = lapply(
        stats::setNames(hooks, hooks),
        function(name) provenance_source(definitions[[name]])
      )
    )),
    expectation = provenance_hash(list(
      declaration = scenario,
      inputs = declared$input_values,
      wrapper = wrapper
    ))
  )
}

# Digests written in a generated scenario test and beside its recording.
provenance_read <- function(path, pattern) {
  if (!file.exists(path)) {
    return(NULL)
  }
  text <- paste(readLines(path, warn = FALSE), collapse = '\n')
  pairs <- regmatches(text, gregexpr(pattern, text, perl = TRUE))[[1L]]
  if (!length(pairs)) {
    return(NULL)
  }
  stats::setNames(
    sub(pattern, '\\2', pairs, perl = TRUE),
    sub(pattern, '\\1', pairs, perl = TRUE)
  )
}

provenance_embedded <- function(path) {
  provenance_read(path, "'([a-z]+)' = '([0-9a-f]{16})'")
}

provenance_recorded <- function(path) {
  provenance_read(path, '(?m)^([a-z]+): ([0-9a-f]{16})$')
}
