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
lines <- sub('^## Unreleased.*$', paste0('## ', package, ' (development version)'), lines)
writeLines(lines, 'NEWS.md')
