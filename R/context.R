# Compatibility functions run with explicitly supplied client policy.
# No client is loaded, sourced, or attached by package installation or loading.
# These names are the explicit compatibility context contract, plus columns
# evaluated by the existing data-frame pipelines. bind_tools() rebinds the
# compatibility functions into the client environment that supplies policy.
utils::globalVariables(c(
  '.fn',
  '.fn_file',
  'endpoint_key',
  'file_full',
  'file_short',
  'fn',
  'fn_full',
  'fn_short',
  'method',
  'n_hits',
  'n_short_count',
  'route',
  'ENDPOINT_PATTERNS_TO_EXCLUDE',
  'FRAMEWORK_PARAMS',
  'PAGINATION_REGISTRY',
  'body_requires_resolution',
  'get_body_schema_type',
  'render_endpoint_stubs',
  'resolve_stack',
  'select_schema_files',
  'supported_methods',
  'tg_config'
))
#' Bind legacy maintenance tools to a client context
#'
#' Install an extracted compatibility function group into an explicit client
#' policy environment.
#'
#' @param group Installed compatibility function group.
#' @param envir Explicit client context receiving installed functions.
#' @return The supplied environment invisibly, with bound functions added. Unknown groups or a non-environment target raise an error.
#' @details This is for existing endpoint-table integrations, not new project
#'   setup. Groups include schema, paths, inventory, scaffold, test_inventory,
#'   test_scaffold, test_validation, test_helpers, ast, runner, parser, drift,
#'   diff, and readiness. The client supplies required selection, rendering,
#'   fixture, and reporting policy. For readiness use asNamespace("specmill") as
#'   the parent and initialize audit_policy with the bound read_audit_policy()
#'   helper. Other groups also install supporting dependency exports where absent.
#' @seealso [Step-by-step guide](https://seanthimons.github.io/specmill/articles/troubleshooting.html).
#' @export
bind_tools <- function(group, envir) {
  stopifnot(is.environment(envir), group %in% names(tool_groups))
  for (package in if (group != 'readiness') {
    c('dplyr', 'purrr', 'stringr', 'tibble', 'tidyr', 'cli')
  }) {
    for (name in getNamespaceExports(package)) {
      if (!exists(name, envir = envir, inherits = FALSE)) {
        assign(name, getExportedValue(package, name), envir = envir)
      }
    }
  }
  if (group == 'schema') {
    assign('resolve_stack', new.env(hash = TRUE, parent = emptyenv()), envir)
  }
  for (name in tool_groups[[group]]) {
    fn <- get(name, envir = asNamespace('specmill'))
    if (is.function(fn)) {
      environment(fn) <- envir
    }
    assign(name, fn, envir = envir)
  }
  invisible(envir)
}

`%or%` <- function(x, y) if (is.null(x)) y else x

# Operation title text: a nonblank summary, else the first sentence of the
# description's first line, else the fallback (usually the function name).
# Help titles drop a final period, so text that is only a period is blank.
summary_text <- function(summary, description, fallback) {
  usable <- function(x) {
    is.character(x) &&
      length(x) == 1L &&
      !is.na(x) &&
      nzchar(trimws(sub('[.]\\s*$', '', x)))
  }
  if (usable(summary)) {
    return(summary)
  }
  lines <- if (is.character(description)) description else ''
  first <- strsplit(c(lines, '')[[1L]], '\n', fixed = TRUE)[[1L]]
  first <- trimws(sub('^([^.]*[.]).*$', '\\1', c(first, '')[[1L]]))
  if (usable(first)) first else fallback
}

# Per-package dry-run environment variable name, e.g. requestclient -> REQUESTCLIENT_DRY_RUN.
dry_run_env <- function(package) {
  paste0(toupper(gsub('[^A-Za-z0-9]', '_', package)), '_DRY_RUN')
}

# YAML/JSON read whole numbers as integers; number schemas render as doubles (100, not 100L).
number_value <- function(value, schema) {
  type <- if (identical(schema$type, 'array')) {
    schema$items$type
  } else {
    schema$type
  }
  if (is.integer(value) && identical(type, 'number')) {
    storage.mode(value) <- 'double'
  }
  value
}

# Functions deparse() can emit for data values.
literal_constructors <- c(
  'c',
  'list',
  'structure',
  'character',
  'integer',
  'numeric',
  'double',
  'logical',
  '-',
  ':'
)

# Escape schema strings as R literals. No remote text is evaluated as code.
# ponytail: render_operation() sets the guard for its dynamic extent instead of
# threading it through every renderer. render_operation() defaults the flag to FALSE,
# matching generate_client() when nothing is shadowed; outside it, literals stay guarded.
literal_state <- new.env(parent = emptyenv())
literal_state$guard <- TRUE

r_literal <- function(x, guard = literal_state$guard) {
  text <- paste(deparse(x, width.cutoff = 500L), collapse = '\n')
  if (any(utf8ToInt(enc2utf8(text)) > 127L)) {
    # Quoted names allow Unicode escapes; backtick names do not in R.
    if (!is.language(x) && !is.function(x)) {
      text <- paste(
        deparse(
          x,
          width.cutoff = 500L,
          control = c('keepNA', 'keepInteger', 'showAttributes')
        ),
        collapse = '\n'
      )
    }
    points <- utf8ToInt(enc2utf8(text))
    text <- paste0(
      vapply(
        points,
        function(point) {
          if (point <= 127L) intToUtf8(point) else sprintf('\\U%08x', point)
        },
        character(1)
      ),
      collapse = ''
    )
  }
  # Data constructors must not resolve through generated functions named list/c.
  # Language objects remain caller-owned expressions (development callbacks).
  # Generated wrappers guard only when the package shadows one of
  # literal_constructors (operation$guard_literals).
  if (guard && !is.language(x) && !is.function(x) && is.call(str2lang(text))) {
    paste0('base::evalq(', text, ', envir = base::baseenv())')
  } else {
    text
  }
}


# Names a client's NAMESPACE imports; imports shadow base in namespace lookup.
# An uninstalled package imported whole is assumed to shadow every constructor.
imported_names <- function(root) {
  if (!file.exists(file.path(root, 'NAMESPACE'))) {
    return(character())
  }
  imports <- parseNamespaceFile(basename(root), dirname(root))$imports
  unlist(lapply(imports, function(entry) {
    except <- if (identical(names(entry), c('', 'except'))) entry$except
    if (length(entry) == 2L && is.null(except)) {
      return(entry[[2L]])
    }
    exports <- tryCatch(getNamespaceExports(entry[[1L]]), error = function(e) {
      literal_constructors
    })
    setdiff(exports, except)
  }))
}
