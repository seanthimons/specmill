roxygen_prose <- function(text) {
  text <- gsub('\\', '\\\\', text, fixed = TRUE)
  for (character in c('{', '}', '%')) {
    text <- gsub(character, paste0('\\', character), text, fixed = TRUE)
  }
  gsub('@', '@@', text, fixed = TRUE)
}

validate_documentation <- function(docs) {
  config_fields(
    docs,
    c(
      'title',
      'description',
      'parameters',
      'return',
      'lifecycle',
      'tags',
      'examples'
    ),
    'docs'
  )
  for (name in intersect(
    names(docs),
    c('title', 'description', 'return', 'lifecycle')
  )) {
    config_string(docs[[name]], paste('docs', name))
  }
  if (
    !is.null(docs$lifecycle) &&
      !docs$lifecycle %in%
        c(
          'experimental',
          'stable',
          'maturing',
          'superseded',
          'deprecated',
          'defunct',
          'questioning',
          'soft-deprecated'
        )
  ) {
    stop('Invalid lifecycle policy')
  }
  for (field in intersect(names(docs), c('parameters', 'tags'))) {
    config_fields(docs[[field]], names(docs[[field]]), paste('docs', field))
    for (value in docs[[field]]) {
      config_string(value, paste('docs', field))
    }
  }
  # Built-in code/structural tags cannot enter through a custom metadata map.
  builtins <- sub(
    '^roxy_tag_parse.roxy_tag_',
    '',
    grep(
      '^roxy_tag_parse.roxy_tag_',
      ls(asNamespace('roxygen2'), all.names = TRUE),
      value = TRUE
    )
  )
  forbidden <- setdiff(builtins, c('family', 'keywords', 'seealso', 'aliases'))
  if (
    any(names(docs$tags) %in% forbidden) ||
      any(!grepl('^[A-Za-z][A-Za-z0-9]*$', names(docs$tags)))
  ) {
    stop('Unsafe documentation tag')
  }
  if ('examples' %in% names(docs)) {
    if (!is.list(docs$examples) || !is.null(names(docs$examples))) {
      stop('docs examples must be a sequence of input maps')
    }
    for (example in docs$examples) {
      config_fields(example, names(example), 'example inputs')
    }
  }
  invisible(docs)
}

operation_documentation <- function(op, policy = list()) {
  validate_documentation(policy)
  parameters <- parameter_names(op$parameters)
  if (length(setdiff(names(policy$parameters), parameters))) {
    stop('Documentation references missing public parameter')
  }
  prose <- function(text) {
    text <- roxygen_prose(text)
    if (!is.null(policy$lifecycle)) {
      for (character in c('[', ']')) {
        text <- gsub(character, paste0('\\', character), text, fixed = TRUE)
      }
      # Convert code spans to inert Rd before Markdown can evaluate inline R.
      text <- stringr::str_replace_all(text, '`+[^`]+`+', function(span) {
        paste0('\\code{', sub('`+$', '', sub('^`+', '', span)), '}')
      })
      text <- gsub('`', '\\verb{`}', text, fixed = TRUE)
    }
    text
  }
  docs <- vapply(
    seq_along(parameters),
    function(i) {
      paste0(
        '@param ',
        parameters[[i]],
        ' ',
        prose(
          policy$parameters[[parameters[[i]]]] %or%
            op$parameters[[i]]$schema$description %or%
            op$parameters[[i]]$name
        ),
        if (identical(op$parameters[[i]]$name, op$iterate$fan_out)) {
          ' Accepts a vector: one request is sent per element and the results are combined.'
        }
      )
    },
    character(1)
  )
  body_argument <- body_argument_name(op)
  if (!is.null(op$body)) {
    body_text <- if (!is.null(op$body_description)) {
      prose(op$body_description)
    } else if (identical(op$body_media, 'application/octet-stream')) {
      'Raw vector of bytes to upload as application/octet-stream.'
    } else {
      'Request body.'
    }
    docs <- c(
      docs,
      paste0(
        '@param ',
        body_argument,
        ' ',
        body_text,
        if (
          isTRUE(op$iterate$split) &&
            !identical(op$body_media, 'application/octet-stream')
        ) {
          if (is.list(op$batch$max_items)) {
            ' Inputs are sent in chunks using the configured call-time item limit and the results are combined.'
          } else {
            paste0(
              ' Arrays longer than ',
              op$batch$max_items,
              ' items are sent in chunks of that size and the results are combined.'
            )
          }
        }
      )
    )
  }
  paged <- !is.null(op$paginate)
  if (paged) {
    index <- which(vapply(
      op$parameters,
      function(p) {
        identical(p$name, op$paginate$parameter) &&
          identical(p$location, op$paginate$location)
      },
      logical(1)
    ))[[1L]]
    docs <- c(
      docs,
      paste0(
        '@param all_pages TRUE (the default) requests page after page, starting at ',
        parameters[[index]],
        ', until a page comes back empty',
        if (!identical(op$paginate$completed, 'empty')) {
          ' or the client says it was the last'
        },
        ' or max_pages is reached, and returns the pages combined. FALSE ',
        'requests only the page given in ',
        parameters[[index]],
        '.'
      ),
      paste0(
        '@param max_pages Maximum number of pages requested when all_pages is ',
        'TRUE. Reaching it stops paging',
        if (!isFALSE(op$paginate$warn_limits)) ' with a warning',
        if (is.null(op$iterate)) {
          if (!isFALSE(op$paginate$metadata)) {
            "; attr(result, 'pagination')$stop_reason records why paging stopped."
          } else {
            '.'
          }
        } else {
          ', and it applies to each item or chunk.'
        }
      )
    )
  }
  text <- c(
    prose(policy$title %or% op$summary),
    '',
    if (is.null(policy$lifecycle)) '@noMd' else '@md',
    if (!is.null(policy$lifecycle) || !is.null(policy$description)) {
      '@description'
    },
    if (!is.null(policy$lifecycle)) {
      paste0('`r lifecycle::badge(', r_literal(policy$lifecycle), ')`')
    },
    if (!is.null(policy$lifecycle) && !is.null(policy$description)) '',
    if (!is.null(policy$description)) prose(policy$description),
    docs,
    paste0(
      '@return ',
      prose(
        policy$return %or%
          paste0(
            'Decoded response returned by the client request helper.',
            if (paged) {
              paste0(
                ' With all_pages = TRUE the pages are combined',
                if (is.null(op$iterate) && !isFALSE(op$paginate$metadata)) {
                  paste0(
                    ", and attr(result, 'pagination') lists requests, ",
                    'item_count and stop_reason.'
                  )
                } else {
                  '.'
                }
              )
            }
          )
      )
    ),
    vapply(
      names(policy$tags),
      function(name) paste0('@', name, ' ', prose(policy$tags[[name]])),
      character(1)
    ),
    if (!is.null(op$rdname)) paste0('@rdname ', op$rdname),
    '@export',
    if (length(policy$examples)) {
      c(
        '@examples',
        '\\dontrun{',
        vapply(
          policy$examples,
          function(inputs) {
            if (
              length(setdiff(
                names(inputs),
                c(parameters, if (!is.null(op$body)) body_argument)
              ))
            ) {
              stop('Example references missing public parameter')
            }
            paste0(
              op$name,
              '(',
              paste(
                vapply(
                  names(inputs),
                  function(name) {
                    value <- config_data(inputs[[name]])
                    index <- match(name, parameters)
                    if (
                      identical(name, body_argument) &&
                        identical(op$body_media, 'text/plain') &&
                        identical(op$text_encoding, 'lines') &&
                        is.list(value)
                    ) {
                      if (
                        !is.null(names(value)) ||
                          !all(vapply(
                            value,
                            function(x) {
                              is.character(x) && length(x) == 1L && !is.na(x)
                            },
                            logical(1)
                          ))
                      ) {
                        stop('Line body example must be a sequence of strings')
                      }
                      value <- vapply(
                        value,
                        identity,
                        character(1),
                        USE.NAMES = FALSE
                      )
                    }
                    if (
                      !is.na(index) &&
                        is.list(value) &&
                        op$parameters[[index]]$public_type %or%
                          '' %in%
                          c('character', 'logical', 'integer', 'numeric')
                    ) {
                      if (
                        !is.null(names(value)) ||
                          any(vapply(value, is.list, logical(1)))
                      ) {
                        stop(
                          'Primitive vector example must be a sequence of scalar values'
                        )
                      }
                      value <- unlist(value, use.names = FALSE)
                    }
                    if (!is.na(index)) {
                      value <- number_value(value, op$parameters[[index]]$schema)
                    }
                    paste0(
                      name,
                      ' = ',
                      r_literal(value)
                    )
                  },
                  character(1)
                ),
                collapse = ', '
              ),
              ')'
            )
          },
          character(1)
        ),
        '}'
      )
    }
  )
  paste(
    paste0(
      "#' ",
      strsplit(paste(text, collapse = '\n'), '\n', fixed = TRUE)[[1L]]
    ),
    collapse = '\n'
  )
}

document_output <- function(root, desired, remove = character()) {
  stage <- tempfile('specmill-documentation-')
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  inputs <- intersect(
    c('R', 'man', 'DESCRIPTION', 'NAMESPACE', 'data', 'inst', 'LICENSE'),
    list.files(root)
  )
  if (!all(c('R', 'DESCRIPTION') %in% inputs)) {
    stop('Documentation requires a package DESCRIPTION and R directory')
  }
  if (!all(file.copy(file.path(root, inputs), stage, recursive = TRUE))) {
    stop('Cannot stage documentation inputs')
  }
  for (name in remove) {
    staged <- project_path(stage, name)
    if (file.exists(staged)) unlink(staged)
  }
  for (name in names(desired)) {
    path <- project_path(stage, name)
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    original <- project_path(root, name)
    content <- if (endsWith(name, '.R') && file.exists(original) &&
        has_protected_lifecycle(original)) file_text(original) else desired[[name]]
    writeLines(enc2utf8(content), path, useBytes = TRUE)
  }
  script <- file.path(stage, 'document.R')
  writeLines(
    paste0(
      'roxygen2::roxygenise(',
      r_literal(stage),
      ", roclets = c('rd', 'namespace'))"
    ),
    script
  )
  log <- file.path(stage, 'documentation.log')
  status <- system2(
    file.path(R.home('bin'), 'Rscript'),
    shQuote(script),
    stdout = log,
    stderr = log
  )
  if (status != 0L) {
    stop(
      'Documentation failed: ',
      paste(readLines(log, warn = FALSE), collapse = '\n')
    )
  }
  files <- c(
    'NAMESPACE',
    paste0(
      'man/',
      list.files(file.path(stage, 'man'), '\\.(Rd|svg)$', recursive = TRUE)
    )
  )
  files <- files[file.exists(file.path(stage, files))]
  owners <- attr(desired, 'operations') %or% list()
  for (name in files) {
    if (endsWith(name, '.Rd')) {
      tools::parse_Rd(file.path(stage, name), encoding = 'UTF-8')
      sources <- unique(unlist(stringr::str_extract_all(
        head(readLines(file.path(stage, name), warn = FALSE), 3L),
        'R/[^ ,\\r\\n]+\\.R'
      )))
      selected_sources <- intersect(sources, names(owners))
      # Client-owned sources need initial help pages too. Existing pages remain
      # client-owned, including edits made directly to Rd rather than roxygen.
      if (!length(selected_sources) && file.exists(project_path(root, name))) {
        next
      }
      if (length(selected_sources) && length(setdiff(sources, selected_sources))) {
        stop('Mixed documentation includes an unowned source: ', name)
      }
      owners[[name]] <- unique(unlist(
        owners[selected_sources],
        use.names = FALSE
      ))
    } else if (identical(name, 'NAMESPACE')) {
      owners[[name]] <- unique(unlist(owners, use.names = FALSE))
    } else if (file.exists(file.path(root, name))) {
      # Existing shared figures are client assets, not newly adopted output.
      next
    } else {
      owners[[name]] <- unique(unlist(owners, use.names = FALSE))
    }
    if (!identical(portable_output_path(root, name), name)) {
      stop('Non-portable documentation filename; shorten the documentation topic: ', name)
    }
    desired[[name]] <- file_text(file.path(stage, name))
  }
  attr(desired, 'operations') <- owners
  desired
}
