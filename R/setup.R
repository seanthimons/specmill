initialization_scripts <- function(schema, settings) {
  multi <- is.data.frame(schema)
  arguments <- paste(
    vapply(
      names(settings),
      function(name) {
        paste0(name, ' = ', r_literal(settings[[name]]))
      },
      character(1)
    ),
    collapse = ',\n    '
  )
  list(
    'dev/init.R' = paste(
      c(
        '# Recreate the initial scaffold in a new directory. Review settings before use.',
        '# Later YAML and helper edits are maintained with dev/generate.R.',
        ".client_root <- specmill::script_root('init.R')",
        'init_main <- function(root) {',
        "  if (file.exists(root)) stop('Choose a new destination directory')",
        paste0('  schema <- ', r_literal(schema)),
        if (multi) {
          c(
            '  dir.create(root, recursive = TRUE)',
            '  inputs <- tempfile("init-schemas-", tmpdir = root)',
            '  dir.create(inputs)',
            '  on.exit(unlink(inputs, recursive = TRUE), add = TRUE)',
            '  for (i in seq_len(nrow(schema))) {',
            '    path <- schema$schema[[i]]',
            '    target <- file.path(inputs, basename(path))',
            '    if (!file.copy(file.path(.client_root, path), target)) stop("Cannot copy schema")',
            '    schema$schema[[i]] <- file.path(basename(inputs), basename(path))',
            '  }'
          )
        } else {
          '  schema <- file.path(.client_root, schema)'
        },
        '  specmill::initialize_client(root, schema,',
        paste0('    ', arguments, ')'),
        '}',
        'if (sys.nframe() == 0L) {',
        '  args <- commandArgs(trailingOnly = TRUE)',
        '  if (length(args) != 1L) stop("Usage: Rscript dev/init.R NEW_DIRECTORY")',
        '  init_main(args[[1L]])',
        '}'
      ),
      collapse = '\n'
    ),
    'dev/generate.R' = paste(
      c(
        '# Client-owned maintenance command. Load project callbacks here if needed.',
        ".client_root <- specmill::script_root('generate.R')",
        'generate_main <- function(root = .client_root, args = commandArgs(trailingOnly = TRUE)) {',
        "  specmill::generation_command(root, args = args, kind = 'stubs')",
        '}',
        'if (sys.nframe() == 0L) generate_main()'
      ),
      collapse = '\n'
    )
  )
}

#' Set up a client interactively
#'
#' Prompt for a local schema, a new client directory and package metadata, preview
#' configuration, then initialize only after confirmation. No HTTP calls are made.
#' @return Applied initialization records, invisibly, or NULL when cancelled.
#' @export
setup_client <- function() {
  if (!base::interactive()) {
    cli::cli_abort(
      'setup_client() requires an interactive R session; use initialize_client() in scripts.'
    )
  }
  ask <- function(prompt) {
    answer <- trimws(base::readline(paste0(prompt, ': ')))
    if (!nzchar(answer)) {
      cli::cli_abort('Setup cancelled; a value is required.')
    }
    answer
  }
  schema <- path.expand(ask('Local OpenAPI/Swagger schema file'))
  root <- path.expand(ask('New client directory'))
  if (file.exists(file.path(root, 'DESCRIPTION'))) {
    cli::cli_abort('Use maintenance commands for an existing client.')
  }
  settings <- list(
    package = ask('Package name'),
    title = ask('Package title'),
    author = list(
      given = ask('Author given name'),
      family = ask('Author family name'),
      email = ask('Author email')
    ),
    license = ask('License, for example MIT + file LICENSE')
  )
  base_url <- trimws(base::readline(
    'Base URL override, or Enter to use schema servers: '
  ))
  if (nzchar(base_url)) {
    settings$base_url <- base_url
  }
  proposal <- configure_client(root, schema, package = settings$package)
  print(proposal$changes)
  print(proposal$diagnostics)
  if (
    tolower(trimws(base::readline(
      'Create the client and development scripts? [y/N]: '
    ))) !=
      'y'
  ) {
    return(invisible(NULL))
  }
  result <- do.call(
    initialize_client,
    c(list(root = root, schema = schema), settings)
  )
  cli::cli_alert_success(
    'Client created. Review YAML, then run dev/generate.R with --plan.'
  )
  invisible(result)
}
