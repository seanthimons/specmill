# Route-derived public names (`naming = 'path'`), see #206.
#
# Scope: this runs only while proposing configuration (`configure_client()`,
# `initialize_client()`). The result is written to the service YAML `names:` map,
# where a reviewer can read and edit each name. Generation never re-derives
# names, so changing an option cannot silently rename an exported function.

path_naming_fields <- c(
  'prefix',
  'drop_segments',
  'strip_stem',
  'collision_suffix',
  'by_param'
)

# Check `naming_options` and fill defaults. Returns NULL unless `naming` is
# 'path', and rejects options given with another strategy: ignoring them
# silently would look like a rule that did not apply.
validate_naming_options <- function(naming, naming_options) {
  if (!identical(naming, 'path')) {
    if (length(naming_options)) {
      stop('naming_options requires naming = "path"')
    }
    return(NULL)
  }
  naming_options <- naming_options %or% list()
  if (
    !is.list(naming_options) ||
      (length(naming_options) &&
        (is.null(names(naming_options)) ||
          anyNA(names(naming_options)) ||
          anyDuplicated(names(naming_options)) ||
          any(!nzchar(names(naming_options)))))
  ) {
    stop('naming_options must be a named list')
  }
  unknown <- setdiff(names(naming_options), path_naming_fields)
  if (length(unknown)) {
    stop(
      'Unknown naming_options: ',
      paste(unknown, collapse = ', '),
      '. Supported: ',
      paste(path_naming_fields, collapse = ', ')
    )
  }
  token <- function(x) {
    is.character(x) &&
      length(x) == 1L &&
      !is.na(x) &&
      grepl('^[A-Za-z0-9_]+$', x)
  }
  flag <- function(x, field) {
    if (!is.logical(x) || length(x) != 1L || is.na(x)) {
      stop('naming_options$', field, ' must be TRUE or FALSE')
    }
    x
  }
  # A bare string covers one schema; a named list covers a catalogue (below).
  prefix <- naming_options$prefix
  if (!is.null(prefix)) {
    prefix <- as.list(prefix)
    if (length(prefix) == 1L && is.null(names(prefix))) {
      names(prefix) <- 'default'
    }
    if (
      is.null(names(prefix)) ||
        anyNA(names(prefix)) ||
        anyDuplicated(names(prefix)) ||
        !all(vapply(prefix, token, logical(1)))
    ) {
      stop('naming_options$prefix must be a string or a named list of strings')
    }
  }
  drop <- naming_options$drop_segments %or% 'api'
  drop <- as.character(unlist(drop))
  if (anyNA(drop) || any(!nzchar(drop))) {
    stop('naming_options$drop_segments must be non-empty strings')
  }
  suffix <- as.list(naming_options$collision_suffix %or% list())
  if (
    length(suffix) &&
      (is.null(names(suffix)) ||
        anyDuplicated(names(suffix)) ||
        !all(
          names(suffix) %in%
            c(
              'GET',
              'POST',
              'PUT',
              'PATCH',
              'DELETE',
              'HEAD',
              'OPTIONS',
              'TRACE'
            )
        ) ||
        !all(vapply(suffix, token, logical(1))))
  ) {
    stop(
      'naming_options$collision_suffix must map upper-case HTTP methods to ',
      'name fragments, for example list(POST = "bulk")'
    )
  }
  list(
    prefix = prefix,
    drop_segments = drop,
    strip_stem = flag(naming_options$strip_stem %or% TRUE, 'strip_stem'),
    collision_suffix = suffix,
    by_param = flag(naming_options$by_param %or% TRUE, 'by_param')
  )
}

# The `prefix` option is a named list, not a single string.
#
# A single string was the simpler design, and it is enough for one schema. It
# falls short for a catalogue: ComptoxR combines `ctx_*`, `chemi_*` and `epi_*`
# APIs that must become `ct_`, `chemi_` and `epi_`. With one string the user
# must run one configure call per family, or hand-edit hundreds of names. Keys
# are matched most-specific first, so the list stays short:
#   1. the exact API id        list(ctx_chemical = 'ct_chem')  -> ct_chem
#   2. the API's family token  list(ctx = 'ct')                -> ctx_chemical -> ct_chemical
#   3. `default`               list(default = 'x')             -> x
# With no match the API id itself is the head, which is what the other naming
# strategies already do for a catalogue.
path_naming_head <- function(prefix, api) {
  if (is.null(api)) {
    return(prefix$default)
  }
  if (!is.null(prefix[[api]])) {
    return(prefix[[api]])
  }
  family <- sub('_.*$', '', api)
  if (!is.null(prefix[[family]])) {
    rest <- sub('^[^_]*_?', '', api)
    return(paste(c(prefix[[family]], if (nzchar(rest)) rest), collapse = '_'))
  }
  prefix$default %or% api
}

# Route words: no `{param}` segments, no `drop_segments`, optionally no leading
# segment equal to the API's own name. `path_naming_stems()` supplies the names
# to strip. The service id is used rather than the schema file name because file
# names are arbitrary (`schema.json`), while the id is a reviewed identity.
path_naming_stems <- function(api) {
  if (is.null(api)) {
    return(character())
  }
  remainder <- sub('^[^_]*_', '', api)
  unique(tolower(c(api, remainder, sub('_prod$', '', remainder))))
}

path_operation_name <- function(method, path, options, api = NULL) {
  segments <- strsplit(path, '/', fixed = TRUE)[[1L]]
  segments <- segments[nzchar(segments) & !grepl('[{}]', segments)]
  segments <- gsub('^_+|_+$', '', gsub('[^A-Za-z0-9]+', '_', segments))
  segments <- segments[
    nzchar(segments) & !tolower(segments) %in% tolower(options$drop_segments)
  ]
  if (
    options$strip_stem &&
      length(segments) &&
      tolower(segments[[1L]]) %in% path_naming_stems(api)
  ) {
    segments <- segments[-1L]
  }
  head <- path_naming_head(options$prefix, api)
  name <- paste(c(head, segments), collapse = '_')
  if (!nzchar(name)) 'root' else name
}

path_parameter_names <- function(path) {
  found <- regmatches(path, gregexpr('\\{[^}]+\\}', path))[[1L]]
  gsub(
    '^_+|_+$',
    '',
    gsub('[^A-Za-z0-9]+', '_', substring(found, 2L, nchar(found) - 1L))
  )
}

# Resolve names that become equal once case is applied. Two stages, because
# the two ways routes collapse need different fixes:
#
# 1. `by_param`: `GET /reports` and `GET /reports/{id}` share a method, so a
#    method suffix cannot separate them. The routes that take path parameters
#    are qualified with those parameters (`reports_by_id`), the same wording
#    ComptoxR already uses and what the caller sees in the function signature.
# 2. Method suffix: `GET /rdkit` and `POST /rdkit` differ only by method. The
#    first method in GET, POST, PUT, ... order keeps the bare name and the
#    others take `collision_suffix[[METHOD]]` or the lower-case method. A
#    mapped suffix such as `POST = 'bulk'` is what separates a bulk call from
#    the single call.
#
# Anything still equal afterwards is left for `configuration_name_diagnostics()`
# to report as `name_collision`; guessing further would hide a real ambiguity.
# Each rename adds a `name_collision_resolved` diagnostic so the plan shows what
# the rule changed.
resolve_path_name_collisions <- function(records, options, final) {
  diagnostics <- list()
  order_of <- function(method) {
    match(method, c('GET', 'POST', 'PUT', 'PATCH', 'DELETE'), nomatch = 99L)
  }
  rename <- function(i, raw, how) {
    diagnostics[[length(diagnostics) + 1L]] <<- list(
      key = records[[i]]$key,
      code = 'name_collision_resolved',
      message = paste0(
        'Renamed ',
        final(records[[i]]$raw),
        ' to ',
        final(raw),
        ' (',
        how,
        ')'
      )
    )
    records[[i]]$raw <<- raw
  }
  sets <- function() {
    names <- vapply(records, function(x) tolower(final(x$raw)), character(1))
    Filter(function(i) length(i) > 1L, unname(split(seq_along(names), names)))
  }
  if (options$by_param) {
    for (set in sets()) {
      signatures <- vapply(
        set,
        function(i) {
          paste(path_parameter_names(records[[i]]$path), collapse = '/')
        },
        character(1)
      )
      if (length(unique(signatures)) < 2L) {
        next
      }
      for (i in set[nzchar(signatures)]) {
        parameters <- path_parameter_names(records[[i]]$path)
        rename(
          i,
          paste(
            c(records[[i]]$raw, 'by', paste(parameters, collapse = '_and_')),
            collapse = '_'
          ),
          'qualified by path parameter'
        )
      }
    }
  }
  for (set in sets()) {
    methods <- vapply(set, function(i) records[[i]]$method, character(1))
    # Only a different method can be told apart by a method suffix. Records
    # that share the leading method stay as they are and are reported.
    bare <- methods[[which.min(order_of(methods))]]
    for (i in set[methods != bare]) {
      suffix <- options$collision_suffix[[records[[i]]$method]] %or%
        tolower(records[[i]]$method)
      rename(i, paste(records[[i]]$raw, suffix, sep = '_'), 'method suffix')
    }
  }
  list(records = records, diagnostics = diagnostics)
}
