portable_output_acceptance <- function() {
  root <- tempfile('portable-output-')
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(c(root, schema), recursive = TRUE), add = TRUE)
  name <- paste0('echo_', paste(rep('long_public_name_', 8L), collapse = ''), 'report')
  values <- c('\u00a0', '\u00bd', '\u00b0', '\U0001f600', 'quote"slash\\newline\n')
  literal <- getFromNamespace('r_literal', 'specmill')
  original <- setNames(list(values), '\u00e9')
  code <- literal(original)
  stopifnot(all(utf8ToInt(code) < 128L), identical(eval(parse(text = code)), original))
  document <- list(openapi = '3.0.3', info = list(title = 'Portable', version = '1'),
    paths = list('/report' = list(get = list(operationId = name,
      parameters = list(list(name = 'value', `in` = 'query', schema = list(type = 'string', default = values[[1L]]))),
      responses = list('200' = list(description = 'OK'))))))
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  specmill::initialize_client(root, schema, package = 'portableoutput', title = 'Portable Output',
    author = list(given = 'Test', family = 'Maintainer', email = 'test@example.org'),
    license = 'MIT + file LICENSE', base_url = 'https://example.invalid')
  run <- function(mode) specmill::generate_client(root, config = 'specmill.yml', mode = mode,
    artifacts = c('wrappers', 'documentation'))
  run('apply')
  portable <- getFromNamespace('portable_output_path', 'specmill')
  old <- paste0('R/', name, '.R')
  new <- portable(root, old)
  doc <- portable(root, paste0('man/', name, '.Rd'))
  stopifnot(file.exists(file.path(root, new)), file.exists(file.path(root, doc)),
    paste0('export(', name, ')') %in% readLines(file.path(root, 'NAMESPACE')),
    all(utf8ToInt(paste(readLines(file.path(root, new)), collapse = '\n')) < 128L))
  files <- list.files(root, recursive = TRUE)
  stopifnot(all(nchar(paste0('portableoutput/', files), type = 'bytes') <= 100L),
    all(nchar(basename(files), type = 'bytes') <= 100L),
    !identical(portable(root, paste0('R/', name, 'a.R')), portable(root, paste0('R/', name, 'b.R'))))
  run('check')
  # Simulate a manifest-owned long filename from a previous generator.
  manifest_path <- file.path(root, '.specmill/manifest.json')
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
  manifest$files[[old]] <- manifest$files[[new]]
  manifest$files[[new]] <- NULL
  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE)
  stopifnot(file.rename(file.path(root, new), file.path(root, old)))
  original_code <- readLines(file.path(root, old))
  writeLines(c(original_code, '# client edit'), file.path(root, old))
  stopifnot(inherits(tryCatch(run('apply'), error = identity), 'error'), file.exists(file.path(root, old)))
  writeLines(original_code, file.path(root, old))
  run('apply')
  stopifnot(!file.exists(file.path(root, old)), file.exists(file.path(root, new)))
  run('check')
  run('apply')
  cat('Portable output: byte limits, stable public names, collision suffixes, protected relocation, Unicode literal round-trip.\n')
}
if (sys.nframe() == 0L) portable_output_acceptance()
