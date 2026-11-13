# Root of a specmill source checkout, or NULL when the tests run from an
# installed or built package (R CMD check), where dev/ and R/ are absent.
source_root <- function() {
  root <- normalizePath(testthat::test_path('..', '..'), winslash = '/', mustWork = FALSE)
  description <- file.path(root, 'DESCRIPTION')
  if (
    file.exists(description) &&
      dir.exists(file.path(root, 'dev')) &&
      identical(unname(read.dcf(description, 'Package')[1, 1]), 'specmill')
  ) {
    root
  } else {
    NULL
  }
}

# Skip a test that reads repository sources outside the package.
skip_without_source <- function() {
  if (is.null(source_root())) {
    skip('needs a specmill source checkout')
  }
}
