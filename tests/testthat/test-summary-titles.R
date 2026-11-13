summary_titles_schema <- function() {
  operation <- function(id, summary, description) {
    op <- list(
      operationId = id,
      responses = list('200' = list(description = 'OK'))
    )
    if (!is.null(summary)) {
      op$summary <- summary
    }
    if (!is.null(description)) {
      op$description <- description
    }
    list(post = op)
  }
  list(
    openapi = '3.0.3',
    info = list(title = 'Titles', version = '1'),
    servers = list(list(url = 'https://titles.invalid')),
    paths = list(
      '/missing' = operation(
        'planMissing',
        NULL,
        'Retrieve missing plans. More text.'
      ),
      '/empty' = operation('planEmpty', '', 'Save the plans.'),
      '/blank' = operation(
        'planStatus',
        '  \t',
        'Retrieve the status of plans.\nSecond line.'
      ),
      '/bare' = operation('planBare', '', NULL),
      '/named' = operation('planNamed', 'Submit plans', 'Ignored here.'),
      '/reviewed' = operation('planReviewed', '', 'Description title.')
    )
  )
}

test_that('blank or missing operation summaries get nonempty help titles', {
  skip_if_not_installed('httr2')
  root <- file.path(withr::local_tempdir(), 'titles')
  schema <- tempfile(fileext = '.json')
  jsonlite::write_json(summary_titles_schema(), schema, auto_unbox = TRUE)
  specmill::initialize_client(
    root,
    schema,
    package = 'titles',
    title = 'Title Fallbacks',
    license = 'MIT + file LICENSE',
    author = list(
      given = 'Example',
      family = 'Maintainer',
      email = 'you@example.org'
    ),
    base_url = 'https://titles.invalid'
  )
  service <- file.path(root, 'apis', list.files(file.path(root, 'apis')))
  expect_length(service, 1L)
  lines <- readLines(service)
  expect_identical(sum(lines == 'operations: {}'), 1L)
  lines[lines == 'operations: {}'] <- paste0(
    'operations: {POST /reviewed: {docs: {title: Reviewed title}}}'
  )
  writeLines(lines, service)
  result <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  expect_length(result$diagnostics, 0L)
  titles <- vapply(result$operations, `[[`, character(1), 'summary')
  names(titles) <- vapply(result$operations, `[[`, character(1), 'key')
  expect_identical(
    titles[c('POST /missing', 'POST /empty', 'POST /blank', 'POST /named')],
    c(
      'POST /missing' = 'Retrieve missing plans.',
      'POST /empty' = 'Save the plans.',
      'POST /blank' = 'Retrieve the status of plans.',
      'POST /named' = 'Submit plans'
    )
  )
  bare <- Filter(
    function(op) identical(op$key, 'POST /bare'),
    result$operations
  )[[1L]]
  expect_identical(bare$summary, bare$name)

  roxygen2::roxygenise(root, roclets = c('rd', 'namespace'))
  exports <- sub(
    '^export\\((.*)\\)$',
    '\\1',
    grep('^export\\(', readLines(file.path(root, 'NAMESPACE')), value = TRUE)
  )
  names <- vapply(result$operations, `[[`, character(1), 'name')
  expect_true(all(names %in% exports))
  pages <- file.path(root, 'man', paste0(names, '.Rd'))
  expect_true(all(file.exists(pages)))
  rd_title <- function(page) {
    rd <- tools::parse_Rd(page)
    tags <- vapply(rd, attr, character(1), 'Rd_tag')
    trimws(paste(unlist(rd[[which(tags == '\\title')]]), collapse = ''))
  }
  page_titles <- vapply(pages, rd_title, character(1))
  expect_true(all(nzchar(page_titles)))
  reviewed <- Filter(
    function(op) identical(op$key, 'POST /reviewed'),
    result$operations
  )[[1L]]
  expect_identical(
    unname(page_titles[[match(reviewed$name, names)]]),
    'Reviewed title'
  )
})

test_that('summary_text prefers summary, then description, then fallback', {
  summary_text <- getFromNamespace('summary_text', 'specmill')
  expect_identical(summary_text('Kept', 'Desc.', 'f'), 'Kept')
  expect_identical(summary_text(NULL, 'One. Two.', 'f'), 'One.')
  expect_identical(summary_text('', 'First line\nsecond.', 'f'), 'First line')
  expect_identical(summary_text(' \t', NULL, 'f'), 'f')
  expect_identical(summary_text(NA_character_, '   ', 'f'), 'f')
  expect_identical(summary_text(NULL, list(), 'f'), 'f')
  expect_identical(summary_text('.', '.NET clients only.', 'f'), 'f')
  expect_identical(summary_text(' . ', 'Plain text.', 'f'), 'Plain text.')
})
