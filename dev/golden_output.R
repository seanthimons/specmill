# Golden-output harness for the importer refactor (#229, epic #224).
#
# Snapshots what specmill derives from every OpenAPI and Swagger fixture: the
# operation records, the schema validation report, schema and operation
# comparisons, generation diagnostics, and freshly generated client files. Each artifact is
# reduced to a SHA-256 over normalized content, so a manifest in git stays small
# and a refactor can be compared with the behavior recorded before it.
#
# Usage, from the repository root in an interactive session:
#   source('dev/golden_output.R')
#   golden_compare()            # snapshot the working tree, diff the baseline
#   golden_write_baseline()     # only on a revision whose behavior is the reference
#   golden_snapshot(keep = 'artifacts/golden')   # keep the full artifacts to diff
#
# Normalization removes values that change between runs without changing
# behavior: temporary paths, the manifest toolkit version, the copyright
# year and its ownership/input hashes, and the validator version. Provenance
# digests of recorded cassettes belong to the follow-up in #279.

golden_baseline_path <- 'dev/audits/ir-golden/manifest.csv'

golden_load <- function() {
  if (
    !file.exists('DESCRIPTION') ||
      !identical(read.dcf('DESCRIPTION', 'Package')[[1L]], 'specmill')
  ) {
    stop('Run the golden harness from the specmill repository root')
  }
  if (!requireNamespace('pkgload', quietly = TRUE)) {
    stop('Install pkgload to snapshot the working tree')
  }
  pkgload::load_all('.', quiet = TRUE)
  invisible(NULL)
}

golden_read_document <- function(path, resolve_references = FALSE) {
  read <- utils::getFromNamespace('read_schema_document', 'specmill')
  read(path, resolve_references = resolve_references)
}

# Fixtures keep a stable id. YAML and JSON forms of the same document are both
# present so that the document reader is exercised through both.
golden_fixtures <- function(work) {
  dir.create(work, recursive = TRUE, showWarnings = FALSE)
  fixtures <- c(
    'openapi3-catalogue' = 'inst/catalogue/schema.json',
    'openapi3-petstore' = 'inst/configuration/petstore.json',
    'openapi31-classifier' = 'inst/schema-stress/classifier-dev.json',
    'openapi31-natural-products' = 'inst/schema-stress/natural-products.json',
    'swagger2-yaml' = 'dev/audits/ir-golden/fixtures/swagger2.yaml'
  )
  shipped <- list.files(
    'inst',
    pattern = '\\.(json|ya?ml)$',
    recursive = TRUE,
    full.names = TRUE
  )
  shipped <- Filter(
    function(path) {
      document <- golden_read_document(path)
      !is.null(document$paths) &&
        (!is.null(document$openapi) || !is.null(document$swagger))
    },
    shipped
  )
  stopifnot(setequal(shipped, unname(fixtures[!startsWith(fixtures, 'dev/')])))
  fixtures <- vapply(fixtures, normalizePath, character(1), mustWork = TRUE)
  swagger <- golden_read_document(
    fixtures[['swagger2-yaml']],
    resolve_references = FALSE
  )
  json <- file.path(work, 'swagger2.json')
  jsonlite::write_json(
    swagger,
    json,
    auto_unbox = TRUE,
    null = 'null',
    pretty = TRUE
  )
  catalogue <- file.path(work, 'openapi3-catalogue.yaml')
  yaml12::write_yaml(
    jsonlite::read_json(fixtures[['openapi3-catalogue']]),
    catalogue
  )
  stopifnot(
    identical(
      golden_canonical(swagger),
      golden_canonical(golden_read_document(json))
    ),
    identical(
      golden_canonical(golden_read_document(fixtures[['openapi3-catalogue']])),
      golden_canonical(golden_read_document(catalogue))
    )
  )
  c(fixtures, 'swagger2-json' = json, 'openapi3-yaml' = catalogue)
}

golden_canonical <- function(x) {
  as.character(jsonlite::toJSON(
    x,
    auto_unbox = TRUE,
    null = 'null',
    na = 'null',
    digits = NA,
    pretty = TRUE
  ))
}

golden_sha <- function(text) {
  digest::digest(
    paste(text, collapse = '\n'),
    algo = 'sha256',
    serialize = FALSE
  )
}

golden_replacements <- function(extra = character()) {
  roots <- unique(c(
    extra,
    normalizePath(tempdir(), winslash = '/'),
    tempdir()
  ))
  list(
    fixed = c(
      stats::setNames(rep('<TMP>', length(roots)), roots)
    )
  )
}

golden_normalize <- function(text, replacements) {
  # Longest first so a nested temporary path is replaced whole.
  fixed <- replacements$fixed[order(-nchar(names(replacements$fixed)))]
  for (i in seq_along(fixed)) {
    text <- gsub(names(fixed)[[i]], fixed[[i]], text, fixed = TRUE)
  }
  text
}

# Replace source paths with stable fixture ids before serialization.
golden_scrub <- function(x, fixtures) {
  if (is.list(x)) {
    x <- lapply(x, golden_scrub, fixtures = fixtures)
  } else if (is.character(x)) {
    for (i in seq_along(fixtures)) {
      x <- gsub(fixtures[[i]], names(fixtures)[[i]], x, fixed = TRUE)
    }
  }
  x
}

golden_row <- function(kind, fixture, item, text) {
  data.frame(
    kind = kind,
    fixture = fixture,
    item = item,
    sha256 = golden_sha(text),
    stringsAsFactors = FALSE
  )
}

golden_keep <- function(keep, parts, text) {
  if (is.null(keep)) {
    return(invisible())
  }
  path <- do.call(file.path, c(list(keep), as.list(parts)))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeBin(charToRaw(paste(text, collapse = '\n')), path)
}

golden_records <- function(fixtures, replacements, keep) {
  rows <- list()
  for (id in names(fixtures)) {
    parsed <- tryCatch(
      suppressWarnings(suppressMessages(read_operations(fixtures[[id]]))),
      error = function(e) e
    )
    if (inherits(parsed, 'error')) {
      text <- golden_normalize(conditionMessage(parsed), replacements)
      golden_keep(keep, c('records', id, 'error.txt'), text)
      rows[[length(rows) + 1L]] <- golden_row('records', id, 'error', text)
      next
    }
    parsed <- golden_scrub(parsed, fixtures)
    emit <- function(item, value) {
      text <- golden_normalize(golden_canonical(value), replacements)
      golden_keep(keep, c('records', id, paste0(item, '.json')), text)
      rows[[length(rows) + 1L]] <<- golden_row('records', id, item, text)
    }
    for (group in c('operations', 'unsupported_operations')) {
      for (op in parsed[[group]]) {
        emit(paste(group, op$key), op)
      }
    }
    for (group in setdiff(
      names(parsed),
      c('operations', 'unsupported_operations')
    )) {
      emit(group, parsed[[group]])
    }
  }
  do.call(rbind, rows)
}

golden_validation <- function(fixtures, replacements, keep) {
  rows <- lapply(names(fixtures), function(id) {
    report <- tryCatch(
      validate_schema(fixtures[[id]]),
      error = function(e) list(error = conditionMessage(e))
    )
    report$validator <- NULL
    text <- golden_normalize(
      golden_canonical(golden_scrub(report, fixtures)),
      replacements
    )
    golden_keep(keep, c('validation', paste0(id, '.json')), text)
    golden_row('validation', id, 'report', text)
  })
  do.call(rbind, rows)
}

# Compares each fixture with a copy that drops a path and changes a summary,
# through both the directory comparison and the record comparison.
golden_comparison <- function(fixtures, work, replacements, keep) {
  rows <- list()
  for (id in names(fixtures)) {
    file <- fixtures[[id]]
    old_dir <- file.path(work, 'compare', id, 'old')
    new_dir <- file.path(work, 'compare', id, 'new')
    dir.create(old_dir, recursive = TRUE, showWarnings = FALSE)
    dir.create(new_dir, recursive = TRUE, showWarnings = FALSE)
    name <- basename(file)
    document <- golden_read_document(
      file,
      resolve_references = FALSE
    )
    file.copy(file, file.path(old_dir, name))
    changed <- document
    changed$paths[[length(changed$paths)]] <- NULL
    first <- names(changed$paths)[[1L]]
    for (method in intersect(
      names(changed$paths[[first]]),
      c('get', 'post', 'put', 'patch', 'delete')
    )[1L]) {
      changed$paths[[first]][[method]]$summary <- 'Changed summary'
    }
    new_file <- file.path(new_dir, name)
    if (grepl('ya?ml$', file)) {
      yaml12::write_yaml(changed, new_file)
    } else {
      jsonlite::write_json(
        changed,
        new_file,
        auto_unbox = TRUE,
        null = 'null',
        pretty = TRUE
      )
    }
    result <- tryCatch(
      suppressWarnings(suppressMessages(schema_diff(old_dir, new_dir))),
      error = function(e) list(error = conditionMessage(e))
    )
    text <- golden_normalize(
      golden_canonical(golden_scrub(result, c(old = old_dir, new = new_dir))),
      replacements
    )
    golden_keep(keep, c('comparison', id, 'schema_diff.json'), text)
    rows[[length(rows) + 1L]] <- golden_row(
      'comparison',
      id,
      'schema_diff',
      text
    )
    compared <- tryCatch(
      compare_operations(
        suppressWarnings(suppressMessages(read_operations(file.path(
          old_dir,
          name
        )))),
        suppressWarnings(suppressMessages(read_operations(new_file)))
      ),
      error = function(e) list(error = conditionMessage(e))
    )
    text <- golden_normalize(
      golden_canonical(golden_scrub(
        compared,
        c(old = old_dir, new = new_dir)
      )),
      replacements
    )
    golden_keep(keep, c('comparison', id, 'compare_operations.json'), text)
    rows[[length(rows) + 1L]] <- golden_row(
      'comparison',
      id,
      'compare_operations',
      text
    )
  }
  do.call(rbind, rows)
}

golden_clients <- function(fixtures, work, keep) {
  rows <- list()
  for (id in names(fixtures)) {
    root <- file.path(work, 'clients', id, 'goldenclient')
    dir.create(dirname(root), recursive = TRUE, showWarnings = FALSE)
    outcome <- tryCatch(
      suppressWarnings(suppressMessages(initialize_client(
        root,
        fixtures[[id]],
        package = 'goldenclient',
        title = 'Golden client',
        author = list(
          given = 'Golden',
          family = 'Maintainer',
          email = 'golden@example.org'
        ),
        license = 'MIT + file LICENSE',
        base_url = 'http://127.0.0.1:1'
      ))),
      error = function(e) e
    )
    if (inherits(outcome, 'error')) {
      text <- golden_normalize(
        conditionMessage(outcome),
        golden_replacements(dirname(root))
      )
      golden_keep(keep, c('clients', id, 'error.txt'), text)
      rows[[length(rows) + 1L]] <- golden_row('client', id, 'error', text)
      next
    }
    local_replacements <- golden_replacements(c(
      normalizePath(root, winslash = '/'),
      root,
      dirname(root)
    ))
    plan <- suppressWarnings(suppressMessages(generate_client(
      root,
      config = 'specmill.yml',
      mode = 'plan',
      validation = FALSE
    )))
    for (field in c('diagnostics', 'inventory')) {
      text <- golden_normalize(
        golden_canonical(plan[[field]]),
        local_replacements
      )
      golden_keep(keep, c('generation', id, paste0(field, '.json')), text)
      rows[[length(rows) + 1L]] <- golden_row('generation', id, field, text)
    }
    # Explicit baseline exclusions; never derive these from current diagnostics.
    # The unfiltered plan above keeps all six known blockers visible.
    blocked <- switch(
      id,
      'openapi31-classifier' = c(
        'POST /v1/sandbox/classify',
        'POST /v1/classify',
        'POST /v1/classify/batch',
        'POST /'
      ),
      'openapi31-natural-products' = c(
        'GET /chem/tanimoto',
        'GET /depict/2D_enhanced'
      ),
      character()
    )
    if (length(blocked)) {
      services <- list.files(file.path(root, 'apis'), full.names = TRUE)
      for (service in services) {
        policy <- golden_read_document(
          service,
          resolve_references = FALSE
        )
        policy$selection$include <- as.list(setdiff(
          unlist(policy$selection$include, use.names = FALSE),
          blocked
        ))
        yaml12::write_yaml(policy, service)
      }
    }
    generated <- tryCatch(
      suppressWarnings(suppressMessages(generate_client(
        root,
        config = 'specmill.yml',
        mode = 'apply',
        validation = FALSE
      ))),
      error = function(e) e
    )
    if (inherits(generated, 'error')) {
      stop('Generation failed for ', id, ': ', conditionMessage(generated))
    }
    files <- sort(list.files(root, recursive = TRUE, all.files = TRUE))
    for (file in files) {
      path <- file.path(root, file)
      raw <- readBin(path, 'raw', file.size(path))
      text <- if (any(raw == as.raw(0L))) {
        paste(as.character(raw), collapse = '')
      } else {
        golden_normalize(
          rawToChar(raw),
          local_replacements
        )
      }
      if (file == 'LICENSE') {
        text <- sub('^YEAR: [0-9]{4}', 'YEAR: <YEAR>', text)
      }
      if (file == '.specmill/manifest.json') {
        text <- sub(
          '("toolkit_version": )"[^"]+"',
          '\\1"<VERSION>"',
          text
        )
        # Both the ownership and input hash follow the varying copyright year.
        license_hash <- digest::digest(
          file = file.path(root, 'LICENSE'),
          algo = 'sha256'
        )
        text <- gsub(license_hash, '<LICENSE_HASH>', text, fixed = TRUE)
      }
      golden_keep(keep, c('clients', id, file), text)
      rows[[length(rows) + 1L]] <- golden_row('client', id, file, text)
    }
  }
  do.call(rbind, rows)
}

golden_snapshot <- function(keep = NULL) {
  golden_load()
  work <- tempfile('golden-')
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  fixtures <- golden_fixtures(work)
  replacements <- golden_replacements(work)
  snapshot <- rbind(
    golden_records(fixtures, replacements, keep),
    golden_validation(fixtures, replacements, keep),
    golden_comparison(fixtures, work, replacements, keep),
    golden_clients(fixtures, work, keep)
  )
  rownames(snapshot) <- NULL
  snapshot[order(snapshot$kind, snapshot$fixture, snapshot$item), ]
}

golden_write_baseline <- function(path = golden_baseline_path) {
  snapshot <- golden_snapshot()
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(snapshot, path, row.names = FALSE)
  cli::cli_alert_success(
    'Wrote {nrow(snapshot)} golden rows to {.path {path}}'
  )
  invisible(snapshot)
}

# Pure manifest comparison, also used to verify addition/removal/change detection.
golden_changes <- function(baseline, current) {
  key <- function(x) paste(x$kind, x$fixture, x$item, sep = '\t')
  stopifnot(!anyDuplicated(key(baseline)), !anyDuplicated(key(current)))
  merged <- merge(
    transform(baseline, key = key(baseline), expected = sha256)[
      c('key', 'expected')
    ],
    transform(current, key = key(current), actual = sha256)[c('key', 'actual')],
    by = 'key',
    all = TRUE
  )
  differs <- is.na(merged$expected) |
    is.na(merged$actual) |
    merged$expected != merged$actual
  merged[differs, , drop = FALSE]
}

# Returns the rows that differ. Assert nrow(result) == 0L for a failing gate.
golden_compare <- function(path = golden_baseline_path, keep = NULL) {
  baseline <- utils::read.csv(path, stringsAsFactors = FALSE)
  current <- golden_snapshot(keep)
  changes <- golden_changes(baseline, current)
  if (nrow(changes)) {
    cli::cli_alert_danger('{nrow(changes)} golden artifact{?s} differ')
  } else {
    cli::cli_alert_success('All {nrow(current)} golden artifacts match')
  }
  invisible(changes)
}
