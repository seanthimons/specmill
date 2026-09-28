# Copy a project, without Git metadata, to a temporary directory the caller removes.
stage_project <- function(root) {
  stage <- tempfile('specmill-adoption-')
  dir.create(stage)
  top <- setdiff(list.files(root, all.files = TRUE, no.. = TRUE), '.git')
  if (!all(file.copy(file.path(root, top), stage, recursive = TRUE))) {
    stop('Cannot stage the project for adoption checks')
  }
  stage
}

# The name bound by a top-level `name <- ...` or `name = ...` expression, else NULL.
definition_name <- function(expr) {
  if (
    is.call(expr) && length(expr) == 3L && is.symbol(expr[[2L]]) &&
      (identical(expr[[1L]], as.name('<-')) || identical(expr[[1L]], as.name('=')))
  ) {
    as.character(expr[[2L]])
  }
}

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
  stage <- stage_project(root)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  whole_files <- character()
  for (file in unique(sources)) {
    exprs <- parse(file.path(root, file), keep.source = TRUE)
    ends <- vapply(attr(exprs, 'srcref'), function(x) x[[3L]], integer(1))
    selected <- vapply(exprs, function(expr) {
      any(definition_name(expr) %in% names(definitions))
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
  # roc_proc_text() ignores DESCRIPTION, and generated blocks always set @md or @noMd,
  # so apply the client's markdown default to original blocks that set neither.
  markdown <- isTRUE(roxygen2::load_options(root)$markdown)
  markdown_blocks <- function(text) {
    if (!markdown) {
      return(text)
    }
    lines <- strsplit(text, '\n')[[1L]]
    roxygen <- grepl("^#'", lines)
    block <- cumsum(c(TRUE, roxygen[-1L] != roxygen[-length(lines)]))
    set <- tapply(grepl("^#'\\s*@(md|noMd)\\b", lines), block, any)
    last <- roxygen & c(block[-1L] != block[-length(lines)], TRUE) & !set[as.character(block)]
    lines[last] <- paste0(lines[last], "\n#' @md")
    paste(lines, collapse = '\n')
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
      original_docs <- rd_topics(markdown_blocks(file_text(file.path(root, records[[name]]$file))))
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

# Propose explicit operation mappings for hand-written wrappers. Only proposals that
# verify_adoption() confirms as equivalent are returned; the project is never written.
propose_mappings <- function(
  root,
  files,
  service,
  config = 'specmill.yml',
  callbacks = new.env(parent = emptyenv()),
  route = NULL,
  bindings = NULL,
  prelude = NULL
) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  project <- load_project(root, config, callbacks)
  target <- project$services[[service]]
  if (is.null(target)) {
    stop('Unknown service: ', service)
  }
  keys <- vapply(read_service_operations(target)$operations, `[[`, character(1), 'key')
  helper <- target$helper
  data_literal <- function(x) !is.language(x) || all(all.names(x) %in% literal_constructors)
  unescape <- function(x) gsub('@@', '@', gsub('\\\\([\\\\{}%])', '\\1', x))

  bind <- function(x, formal_names) {
    if (is.symbol(x) && as.character(x) %in% formal_names) {
      return(list(from = list('params', as.character(x))))
    }
    if (data_literal(x)) {
      return(list(value = eval(x, baseenv())))
    }
    if (is.call(x) && identical(x[[1L]], as.name('list'))) {
      children <- lapply(as.list(x)[-1L], bind, formal_names)
      if (!any(vapply(children, is.null, logical(1)))) {
        if (is.null(names(children))) {
          return(list(array = unname(children)))
        }
        if (all(nzchar(names(children)))) {
          return(list(object = children))
        }
      }
    }
    if (!is.null(bindings)) bindings(x)
  }

  documentation <- function(block, name, fn) {
    tags <- roxygen2::parse_text(c(block, paste(name, '<- NULL')), env = NULL)[[1L]]$tags
    docs <- list()
    parameters <- list()
    for (tag in tags) {
      if (tag$tag == 'title') {
        docs$title <- unescape(tag$val)
      } else if (tag$tag == 'description') {
        badge <- regmatches(tag$val, regexpr('`r lifecycle::badge\\("[a-z-]+"\\)`', tag$val))
        if (length(badge)) {
          docs$lifecycle <- sub('.*"([a-z-]+)".*', '\\1', badge)
        }
        prose <- trimws(sub('`r lifecycle::badge\\("[a-z-]+"\\)`', '', tag$val))
        if (nzchar(prose)) {
          docs$description <- unescape(prose)
        }
      } else if (tag$tag == 'param') {
        parameters[[tag$val$name]] <- unescape(tag$val$description)
      } else if (tag$tag == 'return') {
        docs$return <- unescape(tag$val)
      } else if (tag$tag == 'examples') {
        text <- strsplit(tag$val, '\n')[[1L]]
        docs$examples <- lapply(parse(text = text[!text %in% c('\\dontrun{', '}')]), function(call) {
          if (!is.call(call) || !identical(call[[1L]], as.name(name))) {
            stop('Example is not a call to ', name)
          }
          inputs <- as.list(match.call(fn, call))[-1L]
          if (!all(vapply(inputs, data_literal, logical(1)))) {
            stop('Computed example')
          }
          lapply(setNames(inputs, names(inputs) %or% character()), eval, baseenv())
        })
      } else if (!tag$tag %in% c('export', 'md', 'noMd')) {
        stop('Unsupported roxygen tag @', tag$tag)
      }
    }
    list(docs = docs, parameters = parameters)
  }

  screen <- function(name, fn, block) {
    code <- body(fn)
    code <- if (is.call(code) && identical(code[[1L]], as.name('{'))) as.list(code)[-1L] else list(code)
    arguments <- list()
    found <- if (!is.null(prelude)) prelude(code)
    if (!is.null(found)) {
      code <- code[-seq_len(found$statements)]
      arguments <- found$arguments
    }
    call <- if (length(code) == 1L) code[[1L]]
    if (is.call(call) && identical(call[[1L]], as.name('return')) && length(call) == 2L) {
      call <- call[[2L]]
    }
    # `result <- helper(...); result` (or `return(result)`)
    if (
      length(code) == 2L && is.call(code[[1L]]) && identical(code[[1L]][[1L]], as.name('<-')) &&
        is.symbol(code[[1L]][[2L]]) &&
        (identical(code[[2L]], code[[1L]][[2L]]) || identical(code[[2L]], call('return', code[[1L]][[2L]])))
    ) {
      call <- code[[1L]][[3L]]
    }
    if (!is.call(call) || !identical(call[[1L]], as.name(helper))) {
      stop('Body is not a single call to ', helper)
    }
    args <- as.list(call)[-1L]
    if (!length(args) || is.null(names(args)) || !all(nzchar(names(args)))) {
      stop('Helper arguments must all be named')
    }
    key <- if (is.null(route)) {
      method <- args[['method']]
      path <- args[['path']]
      if (!is.character(method) || !is.character(path)) {
        stop('Helper call has no literal method and path; supply route')
      }
      paste(toupper(method), path)
    } else {
      route(name, call)
    }
    if (!is.character(key) || length(key) != 1L || !key %in% keys) {
      stop('No selected operation matches ', paste(key, collapse = ', '))
    }
    formal_list <- as.list(formals(fn))
    if ('...' %in% names(formal_list)) {
      stop('Wrappers with ... need manual mapping')
    }
    documented <- if (length(block)) documentation(block, name, fn) else list(docs = list(), parameters = list())
    inputs <- lapply(setNames(names(formal_list), names(formal_list)), function(input) {
      # A missing default cannot be bound to a variable, so index each time.
      settings <- if (identical(formal_list[[input]], quote(expr = ))) {
        list(required = TRUE)
      } else if (data_literal(formal_list[[input]])) {
        value <- eval(formal_list[[input]], baseenv())
        type <- if (is.character(value)) {
          'character'
        } else if (is.logical(value)) {
          'logical'
        } else if (is.integer(value)) {
          'integer'
        } else if (is.numeric(value)) 'numeric'
        c(if (!is.null(type)) list(type = type), list(default = value))
      } else {
        stop('Computed default for ', input)
      }
      settings$description <- documented$parameters[[input]]
      settings
    })
    request <- lapply(setNames(names(args), names(args)), function(arg) {
      binding <- arguments[[arg]] %or% bind(args[[arg]], names(formal_list))
      if (is.null(binding)) {
        stop('Unmapped helper argument: ', arg)
      }
      binding
    })
    proposal <- list(
      name = name,
      inputs = if (length(inputs)) inputs else setNames(list(), character()),
      request = list(arguments = request)
    )
    if (length(documented$docs)) {
      proposal$docs <- documented$docs
    }
    list(key = key, proposal = proposal)
  }

  records <- list()
  proposals <- list()
  for (file in files) {
    path <- project_path(root, file)
    exprs <- parse(path, keep.source = TRUE)
    lines <- readLines(path, warn = FALSE, encoding = 'UTF-8')
    for (i in seq_along(exprs)) {
      name <- definition_name(exprs[[i]])
      value <- exprs[[i]][[3L]]
      if (is.null(name) || !is.call(value) || !identical(value[[1L]], as.name('function'))) {
        next
      }
      # The roxygen block is the run of comment lines directly above the definition.
      above <- rev(lines[seq_len(attr(exprs, 'srcref')[[i]][[1L]] - 1L)])
      block <- rev(above[seq_len(match(FALSE, grepl('^#', above), nomatch = length(above) + 1L) - 1L)])
      screened <- tryCatch(
        screen(name, eval(value, baseenv()), grep("^#'", block, value = TRUE)),
        error = identity
      )
      record <- list(file = file, status = 'retained', reason = NULL, key = screened$key)
      if (inherits(screened, 'error')) {
        record$reason <- conditionMessage(screened)
      } else if (!is.null(proposals[[screened$key]])) {
        record$reason <- paste('Operation already proposed for', proposals[[screened$key]]$name)
      } else {
        record$status <- 'proposed'
        proposals[[screened$key]] <- screened$proposal
      }
      records[[name]] <- record
    }
  }
  empty <- list(operations = records, proposals = list(), yaml = '', contracts = list(), files = character())
  if (!length(proposals)) {
    return(empty)
  }

  # Verify the proposals merged into a staged copy of the service file.
  services <- unlist(read_config_yaml(project_path(root, config))$services)
  service_file <- Filter(function(x) identical(read_config_yaml(project_path(root, x))$id, service), services)
  if (length(service_file) != 1L) {
    stop('Service must be defined in its own service file: ', service)
  }
  stage <- stage_project(root)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  staged <- file.path(stage, service_file)
  settings <- yaml::read_yaml(staged, handlers = list(seq = function(x) as.list(x)))
  settings$operations[names(proposals)] <- proposals
  yaml::write_yaml(settings, staged)
  wrappers <- vapply(proposals, `[[`, character(1), 'name')
  checked <- tryCatch(verify_adoption(stage, config, callbacks, unname(wrappers)), error = identity)
  for (name in wrappers) {
    reason <- if (inherits(checked, 'error')) {
      paste('Verification failed:', conditionMessage(checked))
    } else {
      checked$operations[[name]]$reason
    }
    if (!is.null(reason)) {
      records[[name]]$status <- 'retained'
      records[[name]]$reason <- reason
    }
  }
  if (inherits(checked, 'error')) {
    empty$operations <- records
    return(empty)
  }
  proposals <- proposals[wrappers %in% names(Filter(function(x) x$status == 'proposed', records))]
  list(
    operations = records,
    proposals = proposals,
    yaml = if (length(proposals)) yaml::as.yaml(list(operations = proposals)) else '',
    contracts = checked$contracts,
    files = checked$files
  )
}
