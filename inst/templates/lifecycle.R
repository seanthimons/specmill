# Load and attach helpers for R/zzz.R. specmill's configure_lifecycle() maintains
# this file; put your own code in R/zzz.R.

# Sets each named option only when the session has not set it already.
lifecycle_option_defaults <- function(defaults) {
  unset <- !(base::names(defaults) %in% base::names(base::options()))
  if (base::any(unset)) base::options(defaults[unset])
  base::invisible(base::names(defaults)[unset])
}

# Startup message for .onAttach(). suppressPackageStartupMessages() silences it,
# and it stays quiet while devtools::load_all() loads the package.
lifecycle_startup_message <- function(...) {
  if (base::nzchar(base::Sys.getenv('DEVTOOLS_LOAD'))) base::return(base::invisible())
  base::packageStartupMessage(...)
}

# One line per environment variable saying whether it is set. Values are never
# returned and nothing is sent.
lifecycle_credential_status <- function(variables) {
  base::paste0(variables, ': ', base::ifelse(base::nzchar(base::Sys.getenv(variables)), 'set', 'not set'), collapse = '\n')
}
