# Helpers remain client-owned. Only initialization writes the baseline.
request_helper_scaffold <- function(
  helper,
  base_url,
  base_url_override,
  dry_run,
  companions = character()
) {
  template <- request_helper_template(companions)
  settings <- list(
    helper = helper,
    base_url = base_url,
    base_url_override = base_url_override,
    dry_run = dry_run,
    companions = as.list(validate_companions(companions))
  )
  code <- request_helper_substitute(template, settings)
  list(
    code = code,
    provenance = as.character(jsonlite::toJSON(
      list(
        version = 1L,
        template_hash = text_hash(template),
        settings = settings,
        baseline_hash = text_hash(code),
        baseline = code
      ),
      auto_unbox = TRUE,
      pretty = TRUE,
      null = 'null'
    ))
  )
}

request_helper_substitute <- function(template, settings) {
  code <- sub(
    'base_url_override <- NULL # Initialization override',
    paste0(
      'base_url_override <- ',
      r_literal(settings$base_url_override),
      ' # Initialization override'
    ),
    template,
    fixed = TRUE
  )
  # Option names drop a leading dot: helper `.x` reads `<prefix>.x.batching`.
  code <- gsub(
    '.api_request.',
    paste0('.', sub('^[.]', '', settings$helper), '.'),
    code,
    fixed = TRUE
  )
  code <- gsub(
    'api_request',
    settings$helper,
    code,
    fixed = TRUE
  )
  code <- gsub('BASE_URL', r_literal(settings$base_url), code, fixed = TRUE)
  gsub('DRY_RUN_ENV', r_literal(settings$dry_run), code, fixed = TRUE)
}

inspect_request_helpers <- function(root, helpers, definitions) {
  setNames(
    lapply(unique(helpers), function(helper) {
      definition <- definitions[[helper]]
      path <- if (is.null(definition)) NULL else definition$file_path
      provenance <- project_path(
        root,
        paste0('.specmill/helpers/', helper, '.json')
      )
      result <- list(
        helper = helper,
        file = path,
        baseline = 'unknown',
        behavior = 'unverified: run relevant request/transport checks after manual adoption'
      )
      if (is.null(path) || !file.exists(provenance)) {
        return(result)
      }
      record <- jsonlite::read_json(provenance, simplifyVector = TRUE)
      if (
        !identical(record$version, 1L) ||
          !identical(record$settings$helper, helper) ||
          !identical(text_hash(record$baseline), record$baseline_hash)
      ) {
        stop('Invalid helper provenance: ', helper)
      }
      template <- request_helper_template(as.character(unlist(
        record$settings$companions,
        use.names = FALSE
      )))
      current <- request_helper_substitute(template, record$settings)
      local <- file_text(path)
      # Keep all three texts: a diff viewer can compare each without touching source.
      result$baseline <- 'known'
      result$template_hash <- record$template_hash
      result$current_template_hash <- text_hash(template)
      result$customized <- !identical(text_hash(local), record$baseline_hash)
      result$upstream_changed <- !identical(current, record$baseline)
      result$comparison <- list(
        baseline = record$baseline,
        local = local,
        proposed = current
      )
      formals_of <- function(text) {
        definitions <- as.list(parse(text = text))
        hit <- Filter(
          function(x) {
            is.call(x) &&
              identical(x[[1L]], as.name('<-')) &&
              identical(x[[2L]], as.name(helper))
          },
          definitions
        )
        if (
          length(hit) != 1L ||
            !is.call(hit[[1L]][[3L]]) ||
            !identical(hit[[1L]][[3L]][[1L]], as.name('function'))
        ) {
          return(character())
        }
        names(hit[[1L]][[3L]][[2L]])
      }
      result$missing_explicit_arguments <- setdiff(
        formals_of(current),
        formals_of(local)
      )
      result
    }),
    unique(helpers)
  )
}


validate_companions <- function(companions) {
  if (
    !is.character(companions) ||
      anyNA(companions) ||
      anyDuplicated(companions) ||
      !all(companions %in% c('batching', 'pagination'))
  ) {
    stop('companions must select batching and/or pagination without duplicates')
  }
  # Selection order does not change the emitted baseline.
  intersect(c('batching', 'pagination'), companions)
}

request_helper_template <- function(companions = character()) {
  companions <- validate_companions(companions)
  template <- file_text(system.file(
    'templates/request.R',
    package = 'specmill',
    mustWork = TRUE
  ))
  functions <- c(
    if ('batching' %in% companions) c('batched'),
    if ('pagination' %in% companions) {
      c('paginated', 'pagination_token', 'paginated_links')
    }
  )
  if (!length(functions)) {
    return(template)
  }
  replacements <- stats::setNames(paste0('api_request_', functions), functions)
  # Rewrite symbols, not strings or substrings in policy names and messages.
  rename <- function(expr, local_names) {
    if (is.symbol(expr) && as.character(expr) %in% names(replacements)) {
      return(as.name(replacements[[as.character(expr)]]))
    }
    if (is.call(expr)) {
      for (i in seq_along(expr)) {
        if (!identical(expr[[i]], quote(expr = ))) {
          expr[i] <- list(rename(expr[[i]], local_names))
        }
      }
      head <- expr[[1L]]
      if (
        is.symbol(head) &&
          !as.character(head) %in% local_names &&
          grepl('^[A-Za-z.][A-Za-z0-9._]*$', as.character(head)) &&
          !as.character(head) %in%
            c(
              'if',
              'for',
              'while',
              'repeat',
              'function',
              'break',
              'next',
              'return'
            ) &&
          !is.null(get0(
            as.character(head),
            envir = baseenv(),
            mode = 'function',
            inherits = FALSE
          ))
      ) {
        expr[[1L]] <- call('::', as.name('base'), head)
      }
    } else if (is.pairlist(expr)) {
      values <- as.list(expr)
      for (i in seq_along(values)) {
        if (!identical(values[[i]], quote(expr = ))) {
          values[i] <- list(rename(values[[i]], local_names))
        }
      }
      expr <- as.pairlist(values)
    }
    expr
  }
  code <- vapply(
    functions,
    function(name) {
      fn <- get(name, envir = asNamespace('specmill'), inherits = FALSE)
      if (name == 'batched') {
        formals(fn)$policy <- quote(getOption(
          paste0(
            tolower(sub('_DRY_RUN$', '', DRY_RUN_ENV)),
            '.api_request.batching'
          ),
          list()
        ))
      }
      if (name %in% c('paginated', 'paginated_links')) {
        formals(fn)['max_items'] <- list(NULL)
        formals(fn)$warn_limits <- TRUE
        formals(fn)$policy <- quote(getOption(
          paste0(
            tolower(sub('_DRY_RUN$', '', DRY_RUN_ENV)),
            '.api_request.pagination'
          ),
          list()
        ))
      }
      if (name == 'paginated_links') {
        formals(fn)$policy <- quote(getOption(
          paste0(
            tolower(sub('_DRY_RUN$', '', DRY_RUN_ENV)),
            '.api_request.pagination_links'
          ),
          list()
        ))
      }
      local_names <- names(formals(fn))
      expression <- call(
        '<-',
        as.name(replacements[[name]]),
        rename(
          as.call(c(
            list(as.name('function')),
            list(formals(fn), body(fn))
          )),
          local_names
        )
      )
      paste(
        c(
          if (name %in% c('batched', 'paginated', 'paginated_links')) {
            c(
              paste0("#' Client-owned ", name, ' companion'),
              paste0(
                "#' @param ",
                names(formals(fn)),
                ' ',
                unname(companion_argument_docs()[names(formals(fn))])
              ),
              "#' @export"
            )
          },
          deparse(expression, width.cutoff = 80L)
        ),
        collapse = '\n'
      )
    },
    character(1)
  )
  paste(c(template, code), collapse = '\n\n')
}


companion_argument_docs <- function() {
  c(
    fn = 'Client-owned single-request function to call.',
    items = 'Batch inputs, or an explicit response collection extractor for pagination.',
    size = 'Positive integer maximum batch length.',
    '...' = 'Fixed arguments passed unchanged to the single-request function.',
    policy = 'Named list of explicit shared client choices; individual pagination arguments override it.',
    mode = 'Explicit page, offset, or cursor strategy.',
    parameter = 'Exact public argument name or nested character-vector argument path.',
    size_parameter = 'Exact argument name or nested path for the page size.',
    page_size = 'Positive integer requested page size.',
    start = 'Initial page/offset integer, or initial opaque cursor string or NULL.',
    max_pages = 'Positive integer call bound, default 100.',
    max_items = 'Optional positive integer retained-item bound; NULL means no item cap.',
    next_cursor = 'Function extracting an opaque next cursor string or NULL.',
    completed = 'Optional function of response and state selecting metadata completion.',
    advance = 'Optional function of response, position and page_size returning the next position.',
    stop_on_short = 'Whether a short page signals completion, default FALSE.',
    error_policy = 'Request error policy: stop by default, or explicit partial/empty recovery with warnings.',
    warn_limits = 'Whether truncation warns, default TRUE in emitted companions.',
    format = 'Optional final-result formatter, applied after iteration consumes metadata.',
    request = 'A bodyless httr2 GET request with authentication and transport policy configured.',
    next_link = 'Explicit next-link extractor; defaults to the HTTP Link header.'
  )
}
