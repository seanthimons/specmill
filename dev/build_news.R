# Regenerate NEWS.md from Conventional Commits and version tags.
package <- read.dcf('DESCRIPTION')[1L, 'Package']
news <- autonewsmd::autonewsmd$new(
  repo_name = package,
  repo_path = getwd()
)
news$generate()
news$write(force = TRUE)

# Use package/version headings so pkgdown can render each release.
lines <- readLines('NEWS.md', warn = FALSE)
lines <- lines[!grepl('^# ', lines)]
lines <- sub('^## v', paste0('## ', package, ' '), lines)
lines <- sub(
  '^## Unreleased.*$',
  paste0('## ', package, ' (development version)'),
  lines
)

# Drop release commits (bullet plus wrapped link lines); they only list
# themselves, often with a pre-release SHA.
skipping <- FALSE
release <- vapply(
  lines,
  function(line) {
    if (grepl('^-\\s', line)) {
      skipping <<- grepl('^-\\s+release v[0-9]', line)
    } else if (!startsWith(line, '  ')) {
      skipping <<- FALSE
    }
    skipping
  },
  logical(1),
  USE.NAMES = FALSE
)
lines <- lines[!release]

# Drop section headings left without bullets, then extra blank lines.
section <- which(startsWith(lines, '#### '))
empty <- vapply(
  section,
  function(i) {
    rest <- lines[-seq_len(i)]
    end <- match(
      TRUE,
      grepl('^(#|Full set of changes)', rest),
      nomatch = length(rest) + 1L
    )
    !any(grepl('^-\\s', rest[seq_len(end - 1L)]))
  },
  logical(1)
)
lines <- lines[!seq_along(lines) %in% section[empty]]
blank <- !nzchar(trimws(lines))
lines <- lines[!(blank & c(TRUE, head(blank, -1L)))]
writeLines(lines, 'NEWS.md')
