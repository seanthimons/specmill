#' Scaffold load and attach behaviour for a client
#'
#' Preview or create a client-owned `R/zzz.R` with `.onLoad()` and `.onAttach()`
#' stubs, and the helper file they call. Specmill remains a development
#' dependency.
#'
#' @param root Existing client package directory containing DESCRIPTION.
#' @param mode Preview by default; apply writes the files.
#' @return A list containing proposed text in files, changes with
#'   file/action/before/after, and collisions with `.onLoad()` or `.onAttach()`
#'   definitions outside `R/zzz.R`.
#' @details `R/zzz.R` is written once and belongs to the client: an existing
#'   file is reported as `kept` and never changed, and regeneration and pruning
#'   leave it alone. `R/client_lifecycle.R` holds three helpers and stays
#'   specmill's: running this function again updates it to the current
#'   template, and refuses if it was edited by hand. `prune = 'all'` keeps the
#'   helper file while `R/zzz.R` exists, because your code there may call it;
#'   delete `R/zzz.R` first to remove both.
#'
#'   The helpers set option defaults without replacing values the session
#'   already set, emit a startup message through `packageStartupMessage()`
#'   (silent under `suppressPackageStartupMessages()` and
#'   `devtools::load_all()`), and report which credential environment variables
#'   are set without returning their values. Nothing here makes an HTTP call.
#'   The stubs do nothing until you uncomment or add code.
#'
#'   `.onLoad()` or `.onAttach()` defined in another R file blocks application.
#' @seealso `configure_hooks`, `initialize_client`
#' @examples
#' \dontrun{
#' configure_lifecycle('path/to/client')$changes
#' configure_lifecycle('path/to/client', mode = 'apply')
#' }
#' @export
configure_lifecycle <- function(root, mode = c('plan', 'apply')) {
  mode <- match.arg(mode)
  package <- unname(read.dcf(project_path(root, 'DESCRIPTION'))[1L, 'Package'])
  files <- list(
    'R/client_lifecycle.R' = file_text(system.file(
      'templates/lifecycle.R',
      package = 'specmill',
      mustWork = TRUE
    )),
    'R/zzz.R' = paste(
      '# Package load and attach behaviour. This file is yours: it was written once',
      '# and is never regenerated. The helpers live in R/client_lifecycle.R.',
      '',
      '.onLoad <- function(libname, pkgname) {',
      '  # Option defaults that never replace a value the session already set:',
      paste0(
        '  # lifecycle_option_defaults(list(',
        package,
        '.run_verbose = FALSE))'
      ),
      '  invisible()',
      '}',
      '',
      '.onAttach <- function(libname, pkgname) {',
      '  # A startup message; suppressPackageStartupMessages() silences it:',
      '  # lifecycle_startup_message(pkgname, " ", as.character(utils::packageVersion(pkgname)))',
      '  # Which credential variables are set, without their values:',
      '  # lifecycle_startup_message(lifecycle_credential_status("MY_API_KEY"))',
      '  invisible()',
      '}',
      sep = '\n'
    )
  )
  changes <- lapply(names(files), function(file) {
    path <- project_path(root, file)
    before <- if (file.exists(path)) file_text(path) else NULL
    list(
      file = file,
      action = if (is.null(before)) {
        'create'
      } else if (identical(before, files[[file]])) {
        'unchanged'
      } else if (file == 'R/zzz.R') {
        'kept'
      } else {
        'update'
      },
      before = before,
      after = files[[file]]
    )
  })
  collisions <- Filter(
    function(x) {
      x$function_name %in%
        c('.onLoad', '.onAttach') &&
        !identical(
          normalizePath(x$file_path),
          normalizePath(file.path(root, 'R/zzz.R'), mustWork = FALSE)
        )
    },
    client_definitions(root)
  )
  if (mode == 'apply') {
    if (length(collisions)) {
      stop('Existing .onLoad or .onAttach outside R/zzz.R; adapt it instead')
    }
    actions <- vapply(changes, `[[`, character(1), 'action')
    if (actions[[1L]] != 'unchanged') {
      # Manifest-owned, so a hand-edited helper file is refused here.
      apply_files(root, files[1L], mode = 'apply')
    }
    if (
      actions[[2L]] == 'create' && !file.exists(project_path(root, 'R/zzz.R'))
    ) {
      # Written outside the manifest: the client owns it from the first byte.
      writeLines(files[[2L]], project_path(root, 'R/zzz.R'))
    }
  }
  list(files = files, changes = changes, collisions = collisions)
}
