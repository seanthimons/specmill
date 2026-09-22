# Helpers remain client-owned. Only initialization writes the baseline.
request_helper_scaffold <- function(
  helper,
  base_url,
  base_url_override,
  dry_run
) {
  template <- file_text(system.file(
    'templates/request.R',
    package = 'specmill',
    mustWork = TRUE
  ))
  settings <- list(
    helper = helper,
    base_url = base_url,
    base_url_override = base_url_override,
    dry_run = dry_run
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
  code <- sub(
    'api_request <-',
    paste0(settings$helper, ' <-'),
    code,
    fixed = TRUE
  )
  code <- gsub('BASE_URL', r_literal(settings$base_url), code, fixed = TRUE)
  gsub('DRY_RUN_ENV', r_literal(settings$dry_run), code, fixed = TRUE)
}

inspect_request_helpers <- function(root, helpers, definitions) {
  template <- file_text(system.file(
    'templates/request.R',
    package = 'specmill',
    mustWork = TRUE
  ))
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
