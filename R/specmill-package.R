#' Generate and maintain R API clients
#'
#' Development-only tools for local schema parsing, reviewed YAML policy, wrapper and documentation generation, independent request contracts, and protected file maintenance. Generated clients own HTTP, authentication, and response parsing and do not need specmill at runtime.
#'
#' @details Start with initialize_client() for a new package or load_project() for an existing YAML integration. Review generate_client() plans before applying, then check freshness and run client tests. Unsupported schema operations remain explicit diagnostics.
#' @seealso \code{\link{initialize_client}}, \code{\link{generate_client}}, \code{\link{inspect_client}}, [Documentation website](https://seanthimons.github.io/specmill/).
#' @author NULL
#' @rdname specmill
#' @import dplyr
#' @import purrr
#' @import stringr
#' @import tibble
#' @import tidyr
#' @import cli
#' @importFrom stats setNames
#' @importFrom utils tail head
#' @importFrom roxygen2 roxygenise
#' @importFrom jsonvalidate json_validator
"_PACKAGE"
