# Reviewed result ordering: explicit row keys and leading columns for a wrapper
# whose service returns the same records in a varying order.

validate_result_order <- function(settings, label) {
  order <- settings$result_order
  config_fields(order, c('rows', 'columns'), paste(label, 'result_order'))
  if (!length(order)) {
    stop(label, ': result_order needs rows or columns')
  }
  for (field in names(order)) {
    columns <- config_sequence(
      order[[field]],
      paste0(label, ' result_order.', field)
    )
    if (!length(columns) || anyDuplicated(columns)) {
      stop(
        label,
        ': result_order.',
        field,
        ' must list each column name once'
      )
    }
  }
  if (identical(settings$implementation, 'existing')) {
    stop('result_order requires a generated implementation')
  }
  invisible(settings)
}

# The ordering runs inside the generated wrapper, so the client needs neither
# specmill nor a helper change. It orders a data frame that has rows and returns
# every other value (a dry-run request, NULL, an empty result, a list) unchanged.
result_order_lines <- function(order, name) {
  rows <- unlist(order$rows, use.names = FALSE)
  columns <- unlist(order$columns, use.names = FALSE)
  c(
    '  .specmill_order <- function(result) {',
    '    if (!base::is.data.frame(result) || !base::nrow(result)) base::return(result)',
    '    columns <- base::names(result)',
    paste0(
      '    if (base::anyDuplicated(columns)) base::stop(',
      r_literal(paste0('result_order needs unique column names: ', name)),
      ', call. = FALSE)'
    ),
    paste0(
      '    absent <- base::setdiff(',
      r_literal(unique(c(rows, columns))),
      ', columns)'
    ),
    paste0(
      '    if (base::length(absent)) base::stop(',
      r_literal(paste0('result_order columns are missing from ', name, ': ')),
      ', base::paste(absent, collapse = ", "), call. = FALSE)'
    ),
    # A data.table evaluates `[` arguments as column names and keeps a sort key.
    paste0(
      '    if (base::inherits(result, "data.table")) base::stop(',
      r_literal(paste0('result_order does not support data.table: ', name)),
      ', call. = FALSE)'
    ),
    '    index <- base::seq_len(base::nrow(result))',
    '    position <- base::seq_along(columns)',
    if (length(rows)) {
      c(
        # Unnamed keys cannot bind to an argument of order().
        paste0(
          '    keys <- base::unname(base::unclass(result)[',
          r_literal(rows),
          '])'
        ),
        paste0(
          '    if (!base::all(base::vapply(keys, base::is.atomic, base::logical(1)))) base::stop(',
          r_literal(paste0('result_order rows need atomic columns: ', name)),
          ', call. = FALSE)'
        ),
        # Radix ordering is stable and does not depend on the session locale.
        '    index <- base::do.call(base::order, base::c(keys, base::list(na.last = TRUE, method = "radix")))'
      )
    },
    if (length(columns)) {
      # Positions, not names: a column without a usable name is still kept.
      c(
        paste0(
          '    lead <- base::match(',
          r_literal(columns),
          ', columns)'
        ),
        '    rest <- base::setdiff(position, lead)',
        '    position <- base::c(lead, rest[base::order(columns[rest], method = "radix")])'
      )
    },
    '    kept <- base::attributes(result)',
    '    automatic <- base::.row_names_info(result) < 0L',
    '    result <- result[index, position, drop = FALSE]',
    '    if (automatic) base::attr(result, "row.names") <- base::.set_row_names(base::nrow(result))',
    # Subsetting drops attributes such as failed; ones it kept are current.
    '    for (name in base::setdiff(base::names(kept), base::names(base::attributes(result)))) base::attr(result, name) <- kept[[name]]',
    '    result',
    '  }'
  )
}

# Every value the wrapper function itself returns goes through the ordering:
# its last expression and each of its own return() calls. Returns that belong
# to a nested function (one request of a batch, one page) are left alone.
order_wrapper_result <- function(code, order, name) {
  lines <- strsplit(code, '\n', fixed = TRUE)[[1L]]
  last <- length(lines)
  stopifnot(
    last > 3L,
    grepl(' <- function\\(.*\\) \\{$', lines[[2L]]),
    identical(lines[[last]], '}')
  )
  # Without parse data no return would be found, and none rewritten.
  old <- options(keep.parse.data = TRUE)
  on.exit(options(old), add = TRUE)
  data <- utils::getParseData(parse(text = code, keep.source = TRUE))
  stopifnot(!is.null(data))
  parent <- stats::setNames(data$parent, data$id)
  definitions <- unique(data$parent[data$token == 'FUNCTION'])
  depth <- function(id) {
    count <- 0L
    while (!is.na(id) && id > 0L) {
      count <- count + id %in% definitions
      id <- parent[[as.character(id)]]
    }
    count
  }
  returns <- data$id[
    data$token == 'SYMBOL_FUNCTION_CALL' & data$text == 'return'
  ]
  # The call expression is the grandparent of the function-name token.
  calls <- unname(parent[as.character(parent[as.character(returns)])])
  calls <- calls[vapply(calls, depth, integer(1)) == 1L]
  edits <- do.call(
    rbind,
    lapply(calls, function(call) {
      open <- data[data$parent == call & data$token == "'('", ][1L, ]
      close <- data[data$id == call, ]
      rbind(
        data.frame(
          line = open$line1,
          after = open$col1,
          text = '.specmill_order('
        ),
        data.frame(line = close$line2, after = close$col2 - 1L, text = ')')
      )
    })
  )
  if (length(calls)) {
    # Later positions first, so earlier ones stay valid.
    edits <- edits[order(edits$line, edits$after, decreasing = TRUE), ]
    for (i in seq_len(nrow(edits))) {
      line <- lines[[edits$line[[i]]]]
      lines[[edits$line[[i]]]] <- paste0(
        substr(line, 1L, edits$after[[i]]),
        edits$text[[i]],
        substr(line, edits$after[[i]] + 1L, nchar(line))
      )
    }
  }
  paste(
    c(
      lines[1:2],
      result_order_lines(order, name),
      '  result <- {',
      lines[3:(last - 1L)],
      '  }',
      '  .specmill_order(result)',
      '}'
    ),
    collapse = '\n'
  )
}
