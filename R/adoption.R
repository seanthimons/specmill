# Verify configured operations against the hand-written wrappers they would replace.
# Generation runs on a temporary copy, so the check covers exactly what apply writes.
verify_adoption <- function(
  root,
  config = 'specmill.yml',
  callbacks = new.env(parent = emptyenv()),
  wrappers = NULL
) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  project <- load_project(root, config, callbacks)
  configured <- list()
  for (service in project$services) {
    for (op in read_service_operations(service)$operations) {
      mapped <- configure_operation(op, service)
      if (!identical(mapped$spec$implementation, 'existing')) {
        configured[[mapped$operation$name]] <- mapped$spec$helper
      }
    }
  }
  manifest_path <- file.path(root, '.specmill/manifest.json')
  owned <- if (file.exists(manifest_path)) {
    file.path(root, names(jsonlite::read_json(manifest_path)$files))
  } else {
    character()
  }
  definitions <- client_definitions(root)
  definitions <- Filter(
    function(x) !x$file_path %in% owned,
    definitions[intersect(names(configured), names(definitions))]
  )
  wrappers <- wrappers %or% names(definitions)
  missing <- setdiff(wrappers, names(definitions))
  if (length(missing)) {
    stop('No hand-written definition for: ', paste(missing, collapse = ', '))
  }
  # Every candidate leaves the staged copy; only the requested wrappers are checked.
  sources <- vapply(definitions, function(x) substring(x$file_path, nchar(root) + 2L), character(1))
  records <- lapply(sources[wrappers], function(file) {
    list(file = file, status = 'verified', reason = NULL)
  })
  if (!length(records)) {
    return(list(operations = list(), contracts = list(), files = character()))
  }
  fail <- function(name, reason) {
    if (identical(records[[name]]$status, 'verified')) {
      records[[name]]$status <<- 'failed'
      records[[name]]$reason <<- reason
    }
  }

  # Stage a copy without the candidate definitions (and their roxygen blocks), then generate.
  stage <- tempfile('specmill-adoption-')
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  top <- setdiff(list.files(root, all.files = TRUE, no.. = TRUE), '.git')
  if (!all(file.copy(file.path(root, top), stage, recursive = TRUE))) {
    stop('Cannot stage the project for adoption checks')
  }
  whole_files <- character()
  for (file in unique(sources)) {
    exprs <- parse(file.path(root, file), keep.source = TRUE)
    ends <- vapply(attr(exprs, 'srcref'), function(x) x[[3L]], integer(1))
    selected <- vapply(exprs, function(expr) {
      is.call(expr) && as.character(expr[[1L]]) %in% c('<-', '=') &&
        is.symbol(expr[[2L]]) && as.character(expr[[2L]]) %in% names(definitions)
    }, logical(1))
    if (all(selected)) {
      whole_files <- c(whole_files, file)
    }
    lines <- readLines(file.path(root, file), warn = FALSE, encoding = 'UTF-8')
    drop <- unlist(lapply(which(selected), function(i) {
      seq.int(if (i > 1L) ends[[i - 1L]] + 1L else 1L, ends[[i]])
    }))
    # Remaining code moves aside so generation can own the original path.
    unlink(file.path(stage, file))
    if (!all(selected)) {
      rest <- file.path(stage, 'R', paste0('specmill-adoption-rest-', basename(file)))
      writeLines(lines[-drop], rest, useBytes = TRUE)
    }
  }
  generation <- tryCatch(
    generate_client(stage, config = config, callbacks = callbacks, mode = 'apply', artifacts = 'wrappers'),
    error = identity
  )
  if (inherits(generation, 'error')) {
    for (name in names(records)) {
      fail(name, paste('Generation failed:', conditionMessage(generation)))
    }
  }
  generated <- if (inherits(generation, 'error')) list() else client_definitions(stage)

  load_sources <- function(directory) {
    env <- new.env(parent = globalenv())
    for (file in sort(list.files(file.path(directory, 'R'), '\\.[Rr]$', full.names = TRUE))) {
      sys.source(file, env, keep.source = FALSE)
    }
    env
  }
  recorder <- new.env(parent = emptyenv())
  response <- list(specmill_adoption = 'response')
  stub <- function(helper) {
    force(helper)
    function(...) {
      recorder$calls[[length(recorder$calls) + 1L]] <- list(
        helper = helper,
        arguments = list(...),
        response = response
      )
      response
    }
  }
  run <- function(fn, inputs) {
    recorder$calls <- list()
    value <- tryCatch(do.call(fn, inputs), error = function(e) {
      structure(conditionMessage(e), class = 'specmill_adoption_error')
    })
    list(value = value, calls = recorder$calls)
  }
  sample_input <- function(schema) {
    if (length(schema$enum)) {
      return(unlist(schema$enum[1L]))
    }
    switch(
      schema$type %or% 'string',
      integer = 1L,
      number = 1,
      boolean = TRUE,
      array = sample_input(schema$items %or% list()),
      object = list(sample = 'sample'),
      'sample'
    )
  }
  rd_topics <- function(text) {
    topics <- roxygen2::roc_proc_text(roxygen2::rd_roclet(), text)
    # The source-file header differs when grouped wrappers move to their own files.
    lapply(topics, function(x) grep('^%', strsplit(format(x), '\n')[[1L]], value = TRUE, invert = TRUE))
  }

  contracts <- list()
  if (length(generated)) {
    original_env <- load_sources(root)
    generated_env <- load_sources(stage)
    operations <- generation$operations
    for (name in names(records)) {
      if (is.null(generated[[name]])) {
        fail(name, 'Generation did not produce the wrapper')
        next
      }
      helper <- configured[[name]]
      original_env[[helper]] <- stub(helper)
      generated_env[[helper]] <- stub(helper)
      original <- original_env[[name]]
      candidate <- generated_env[[name]]
      if (!identical(formals(original), formals(candidate))) {
        fail(name, 'Formals differ')
        next
      }
      op <- operations[[name]]
      schemas <- setNames(
        lapply(op$parameters, `[[`, 'schema'),
        parameter_names(op$parameters)
      )
      if (!is.null(op$body)) {
        schemas[[tail(names(formals(candidate)), 1L)]] <- op$body
      }
      defaults <- as.list(formals(original))
      required <- names(Filter(function(x) identical(x, quote(expr = )), defaults))
      optional <- setdiff(names(defaults), required)
      samples <- function(inputs) {
        lapply(setNames(inputs, inputs), function(x) sample_input(schemas[[x]]))
      }
      base_inputs <- samples(required)
      explicit <- c(base_inputs, samples(optional))
      variants <- list('required inputs' = base_inputs, 'explicit inputs' = explicit, 'no arguments' = list())
      for (input in optional) {
        for (value in list(explicit = explicit[[input]], 'FALSE' = FALSE, '0' = 0)) {
          label <- paste(input, '=', deparse(value))
          variants[[label]] <- c(base_inputs, setNames(list(value), input))
        }
      }
      for (label in names(variants)) {
        reference <- run(original, variants[[label]])
        if (!identical(run(candidate, variants[[label]]), reference)) {
          fail(name, paste('Behaviour differs with', label))
          break
        }
      }
      for (inputs in list(explicit, base_inputs)) {
        reference <- run(original, inputs)
        if (length(reference$calls) && !inherits(reference$value, 'specmill_adoption_error')) {
          contracts[[name]] <- list(inputs = inputs, calls = reference$calls, result = reference$value)
          break
        }
      }
      original_docs <- rd_topics(file_text(file.path(root, records[[name]]$file)))
      generated_docs <- rd_topics(file_text(generated[[name]]$file_path))
      same_docs <- if (length(generated_docs)) {
        identical(generated_docs, original_docs[names(generated_docs)])
      } else {
        is.null(original_docs[[paste0(name, '.Rd')]])
      }
      if (!same_docs) {
        fail(name, 'Documentation differs')
      }
    }
  }

  # A file adopts only when every definition in it is a checked, verified wrapper.
  files <- character()
  for (file in whole_files) {
    members <- names(sources)[sources == file]
    if (all(vapply(members, function(x) identical(records[[x]]$status, 'verified'), logical(1)))) {
      files[[file]] <- output_hash(file.path(root, file))
    }
  }
  for (name in names(records)) {
    if (identical(records[[name]]$status, 'verified') && !records[[name]]$file %in% names(files)) {
      fail(name, 'File contains other code or unverified wrappers; separate it before adoption')
    }
  }
  contracts <- contracts[intersect(names(contracts), names(Filter(
    function(x) x$status == 'verified',
    records
  )))]
  list(operations = records, contracts = contracts, files = files)
}
