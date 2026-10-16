coverage_report <- function(
  root,
  policy,
  callbacks = new.env(parent = emptyenv()),
  config = 'specmill.yml',
  mode = c('plan', 'apply')
) {
  mode <- match.arg(mode)
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  if (is.character(policy)) {
    policy <- config_data(read_config_yaml(policy))
  }
  config_fields(policy, c('baseline', 'groups'), 'coverage policy')
  config_fields(policy$groups, names(policy$groups), 'coverage groups')
  baseline_path <- project_path(
    root,
    config_string(policy$baseline, 'coverage baseline')
  )
  baseline <- if (file.exists(baseline_path)) {
    jsonlite::read_json(baseline_path)
  } else {
    list()
  }
  inspection <- inspect_client(root, config, callbacks)
  selected <- character()
  values <- list()
  outputs <- list()
  badges <- list()
  gaps <- list()
  delta <- function(current, previous) {
    if (
      is.null(previous) || is.na(previous) || abs(current - previous) < 1e-9
    ) {
      return('')
    }
    if (abs(current - round(current)) < 1e-9) {
      sprintf(' (%+d)', as.integer(round(current - previous)))
    } else {
      sprintf(' (%+.1f)', current - previous)
    }
  }
  for (name in names(policy$groups)) {
    group <- policy$groups[[name]]
    config_fields(
      group,
      c('services', 'label', 'badge', 'denominator', 'exclude'),
      'coverage group'
    )
    for (field in c('services', 'label', 'badge')) {
      config_string(group[[field]], field)
    }
    denominator <- if (is.null(group$denominator)) {
      'selected'
    } else {
      config_string(group$denominator, 'denominator')
    }
    if (!denominator %in% c('selected', 'schema')) {
      stop('Coverage denominator must be selected or schema')
    }
    exclude <- character()
    if (!is.null(group$exclude)) {
      if (!identical(denominator, 'schema')) {
        stop('Coverage exclude requires denominator: schema')
      }
      exclude <- vapply(
        as.list(group$exclude),
        config_string,
        character(1),
        label = 'coverage exclude'
      )
      for (pattern in exclude) {
        tryCatch(stringr::str_detect('', pattern), error = function(e) {
          stop('Coverage exclude: invalid regex ', pattern)
        })
      }
    }
    if (!grepl('^[a-z][a-z0-9_]*$', name)) {
      stop('Invalid coverage output prefix')
    }
    members <- grep(group$services, names(inspection$coverage), value = TRUE)
    if (!length(members) || length(intersect(selected, members))) {
      stop('Coverage groups are empty or overlap')
    }
    selected <- c(selected, members)
    if (identical(denominator, 'schema')) {
      counts <- coverage_schema_counts(inspection, members, exclude, root)
      total <- counts$total
      implemented <- counts$implemented
      gaps[[name]] <- counts$gaps
    } else {
      coverage <- inspection$coverage[members]
      total <- sum(vapply(coverage, `[[`, integer(1), 'total'))
      implemented <- sum(vapply(coverage, `[[`, integer(1), 'implemented'))
    }
    percent <- if (total) round(100 * implemented / total, 1) else 0
    color <- if (percent >= 80) {
      'brightgreen'
    } else if (percent >= 60) {
      'green'
    } else if (percent >= 40) {
      'yellow'
    } else if (percent >= 20) {
      'orange'
    } else {
      'red'
    }
    for (metric in c('coverage', 'endpoints', 'functions')) {
      key <- paste(name, metric, sep = '_')
      value <- switch(
        metric,
        coverage = percent,
        endpoints = total,
        functions = implemented
      )
      values[[key]] <- value
      outputs[[key]] <- if (metric == 'coverage') {
        sprintf('%.1f', value)
      } else {
        as.character(value)
      }
      outputs[[paste0(key, '_fmt')]] <- paste0(
        if (metric == 'coverage') {
          sprintf('%.1f%%', value)
        } else {
          as.character(value)
        },
        delta(value, baseline[[key]])
      )
    }
    outputs[[paste0(name, '_color')]] <- color
    path <- project_path(root, group$badge)
    badges[[path]] <- list(
      schemaVersion = 1,
      label = group$label,
      message = sprintf('%.1f%%', percent),
      color = color
    )
    cat(sprintf(
      '%s: %.1f%% (%d/%d)\n',
      group$label,
      percent,
      implemented,
      total
    ))
    if (identical(denominator, 'schema')) {
      cat(sprintf(
        '  %d schema operations without a wrapper (%d not selected)\n',
        nrow(gaps[[name]]),
        sum(gaps[[name]]$status == 'excluded')
      ))
    }
  }
  if (!setequal(selected, names(inspection$coverage))) {
    stop('Coverage policy omits configured services')
  }
  values$timestamp <- format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz = 'UTC')
  if (mode == 'apply') {
    for (path in names(badges)) {
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      jsonlite::write_json(
        badges[[path]],
        path,
        auto_unbox = TRUE,
        pretty = TRUE
      )
    }
    jsonlite::write_json(
      values,
      baseline_path,
      auto_unbox = TRUE,
      pretty = TRUE
    )
    write_github_outputs(unlist(outputs, use.names = TRUE))
  }
  invisible(list(
    baseline = values,
    outputs = outputs,
    badges = badges,
    gaps = gaps
  ))
}

# Schema-relative counts for one group: every operation in the schemas its services
# reference, once per schema file and method + path, minus the excluded patterns.
coverage_schema_counts <- function(inspection, members, exclude, root) {
  rows <- Filter(function(x) x$service %in% members, inspection$inventory)
  wrapped <- unlist(
    lapply(
      Filter(
        function(x) x$service %in% members && isTRUE(x$implemented),
        inspection$operations
      ),
      function(x) x$id
    ),
    use.names = FALSE
  )
  field <- function(name) vapply(rows, function(x) x[[name]], character(1))
  frame <- data.frame(
    id = field('id'),
    service = field('service'),
    key = field('key'),
    source = normalizePath(field('source'), winslash = '/', mustWork = FALSE),
    status = field('status'),
    stringsAsFactors = FALSE
  )
  frame$implemented <- frame$id %in% wrapped
  skipped <- rep(FALSE, nrow(frame))
  for (pattern in exclude) {
    skipped <- skipped | stringr::str_detect(frame$key, pattern)
  }
  frame <- frame[!skipped, , drop = FALSE]
  id <- paste(frame$source, frame$key)
  operations <- split(seq_len(nrow(frame)), factor(id, levels = unique(id)))
  summary <- lapply(operations, function(i) {
    statuses <- setdiff(frame$status[i], 'excluded')
    list(
      key = frame$key[[i[[1L]]]],
      schema = frame$source[[i[[1L]]]],
      status = if (length(statuses)) statuses[[1L]] else 'excluded',
      services = paste(unique(frame$service[i]), collapse = ', '),
      implemented = any(frame$implemented[i])
    )
  })
  gaps <- Filter(function(x) !x$implemented, summary)
  # Sources are normalized above, so the root must be too (a drive letter is added on Windows).
  root <- normalizePath(root, winslash = '/', mustWork = FALSE)
  prefix <- paste0(sub('/+$', '', root), '/')
  list(
    total = length(summary),
    implemented = sum(vapply(summary, `[[`, logical(1), 'implemented')),
    gaps = data.frame(
      key = vapply(gaps, `[[`, character(1), 'key'),
      schema = {
        schema <- vapply(gaps, `[[`, character(1), 'schema')
        inside <- startsWith(schema, prefix)
        schema[inside] <- substring(schema[inside], nchar(prefix) + 1L)
        schema
      },
      status = vapply(gaps, `[[`, character(1), 'status'),
      services = vapply(gaps, `[[`, character(1), 'services'),
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  )
}
