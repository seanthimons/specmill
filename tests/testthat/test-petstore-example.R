test_that('the shipped Petstore example builds a stable, tested client', {
  for (package in c('httr2', 'callr', 'httpuv', 'pkgload', 'roxygen2')) {
    skip_if_not_installed(package)
  }
  root <- file.path(withr::local_tempdir(), 'petstoretrial')
  result <- petstore_example(root)
  expect_error(petstore_example(root), 'Choose a new directory')

  expect_length(result$operations, 19L)
  expect_length(result$diagnostics, 0L)
  selected <- Filter(function(x) x$status != 'excluded', result$inventory)
  expect_length(selected, 19L)
  expect_setequal(
    result$retained_sources,
    c('R/pet_custom.R', 'R/store_custom.R', 'R/user_custom.R')
  )
  custom <- c(
    'pet_create',
    'pet_update',
    'pet_upload_image',
    'store_order_create',
    'user_create',
    'user_update'
  )
  expect_true(all(file.exists(file.path(root, 'man', paste0(custom, '.Rd')))))
  names <- vapply(result$operations, `[[`, character(1), 'name')
  expect_true(all(c(custom, 'pet_find_by_tags', 'pet_delete') %in% names))

  # A second check finds nothing to regenerate.
  expect_no_error(generate_client(
    root,
    config = 'specmill.yml',
    mode = 'check',
    artifacts = c('wrappers', 'documentation')
  ))

  # The client's own localhost contract test covers all 19 endpoints.
  results <- callr::r(
    function(root) {
      as.data.frame(testthat::test_local(
        root,
        reporter = 'silent',
        stop_on_failure = FALSE
      ))
    },
    args = list(root)
  )
  expect_identical(sum(results$failed), 0L)
  expect_false(any(results$error))
  expect_gt(sum(results$nb), 0L)
})
